//
//  MiniMaxOAuthService.swift
//  InsightAtlas
//
//  MiniMax's custom user-code polling OAuth flow with PKCE (NOT a redirect /
//  authorization-code flow — there is no callback URL). Sign-in requests a
//  user code, opens MiniMax's verification page in the browser, and polls the
//  token endpoint until the user approves. The resulting access token is used
//  as a bearer token against MiniMax's Anthropic-compatible Messages endpoint
//  for guide generation (see AIService `.minimax`).
//

import Foundation
import CryptoKit
import UIKit

// MARK: - Configuration

/// Verified ground-truth OAuth + inference configuration for MiniMax.
enum MiniMaxOAuthConfig {
    static let clientID      = "78257093-7e40-4613-99e0-527b14b39113"
    static let portalBaseURL = "https://api.minimax.io"
    static let deviceCodeURL = portalBaseURL + "/oauth/code"
    static let tokenURL      = portalBaseURL + "/oauth/token"

    /// Anthropic-compatible Messages endpoint (Bearer auth, no anthropic-version).
    static let inferenceURL  = "https://api.minimax.io/anthropic/v1/messages"

    static let scopes        = "group_id profile model.completion"
    static let grantType     = "urn:ietf:params:oauth:grant-type:user_code"

    /// Primary model served through this OAuth (Anthropic Messages endpoint).
    static let defaultModel  = "MiniMax-M3"

    /// The client_id is a production value, so sign-in is always available.
    static var isConfigured: Bool { true }
}

// MARK: - Errors

enum MiniMaxOAuthError: LocalizedError {
    case notSignedIn
    case deviceCodeFailed(String)
    case expired
    case denied
    case tokenExchangeFailed(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Not signed in to MiniMax. Sign in from Settings → API Access."
        case .deviceCodeFailed(let detail):
            return "Couldn't start MiniMax sign-in: \(detail)"
        case .expired:
            return "MiniMax sign-in timed out before it was approved. Try again."
        case .denied:
            return "MiniMax sign-in was declined."
        case .tokenExchangeFailed(let detail):
            return "MiniMax sign-in failed: \(detail)"
        }
    }
}

// MARK: - Device (user) code

/// The pending user-code challenge shown to the user during sign-in.
struct MiniMaxUserCode: Equatable {
    let userCode: String
    let verificationURI: String
    let verificationURIComplete: String?
    let interval: TimeInterval
    let expiresAt: Date

    /// Best link to open: the complete URI (pre-fills the code) if provided.
    var bestVerificationURL: URL? {
        URL(string: verificationURIComplete ?? verificationURI)
    }
}

// MARK: - PKCE

private struct PKCE {
    let verifier: String
    let challenge: String

    init() {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        verifier = Data(bytes).mmBase64URLEncoded()
        let hash = SHA256.hash(data: Data(verifier.utf8))
        challenge = Data(hash).mmBase64URLEncoded()
    }
}

private extension Data {
    func mmBase64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Service

@MainActor
final class MiniMaxOAuthService: ObservableObject {
    static let shared = MiniMaxOAuthService()

    @Published private(set) var isSignedIn: Bool
    /// Non-nil while a sign-in is awaiting the user's approval in the browser.
    @Published private(set) var pendingCode: MiniMaxUserCode?

    init() {
        self.isSignedIn = MiniMaxOAuthService.hasStoredCredentials
    }

    /// Non-isolated snapshot for use off the main actor (e.g. AIService).
    nonisolated static var hasStoredCredentials: Bool {
        KeychainService.shared.minimaxAccessToken?.isEmpty == false
    }

    // MARK: Sign in / out

    /// Runs the full user-code flow: request code → open browser → poll token.
    func signIn() async throws {
        pendingCode = nil
        defer { pendingCode = nil }

        let pkce = PKCE()
        let state = UUID().uuidString
        let code = try await requestUserCode(pkce: pkce, state: state)
        pendingCode = code

        if let url = code.bestVerificationURL {
            await UIApplication.shared.open(url)
        }

        try await pollForToken(userCode: code.userCode, verifier: pkce.verifier, code: code)
        isSignedIn = true
    }

    func signOut() {
        KeychainService.shared.clearMiniMaxAuth()
        isSignedIn = false
    }

    // MARK: Tokens

    /// Returns a non-expired access token, refreshing first when needed.
    func validAccessToken() async throws -> String {
        guard let token = KeychainService.shared.minimaxAccessToken, !token.isEmpty else {
            throw MiniMaxOAuthError.notSignedIn
        }
        if let expiryString = KeychainService.shared.minimaxTokenExpiry,
           let expiry = Double(expiryString),
           Date().timeIntervalSince1970 > (expiry - 60) {
            try await refresh()
            return KeychainService.shared.minimaxAccessToken ?? token
        }
        return token
    }

    // MARK: Flow steps

    private func requestUserCode(pkce: PKCE, state: String) async throws -> MiniMaxUserCode {
        let data: Data
        do {
            data = try await postForm(MiniMaxOAuthConfig.deviceCodeURL, fields: [
                "response_type": "code",
                "client_id": MiniMaxOAuthConfig.clientID,
                "scope": MiniMaxOAuthConfig.scopes,
                "code_challenge": pkce.challenge,
                "code_challenge_method": "S256",
                "state": state
            ], extraHeaders: ["x-request-id": UUID().uuidString])
        } catch let error as MiniMaxOAuthError {
            if case .tokenExchangeFailed(let detail) = error {
                throw MiniMaxOAuthError.deviceCodeFailed(detail)
            }
            throw error
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let userCode = json["user_code"] as? String,
              let verificationURI = json["verification_uri"] as? String else {
            throw MiniMaxOAuthError.deviceCodeFailed("unexpected response")
        }
        guard (json["state"] as? String) == state else {
            throw MiniMaxOAuthError.deviceCodeFailed("state mismatch")
        }

        // MiniMax returns `interval` in MILLISECONDS.
        let intervalMs = (json["interval"] as? Double) ?? 2000
        let expiresAt = Self.resolveExpiry(json["expired_in"] ?? json["expires_in"])

        return MiniMaxUserCode(
            userCode: userCode,
            verificationURI: verificationURI,
            verificationURIComplete: json["verification_uri_complete"] as? String,
            interval: max(2, intervalMs / 1000),
            expiresAt: expiresAt
        )
    }

    private func pollForToken(userCode: String, verifier: String, code: MiniMaxUserCode) async throws {
        // Matches the Hermes reference flow: poll, and treat any non-200 as a
        // hard error; on 200 the JSON `status` is "success" / "error" / "pending".
        while Date() < code.expiresAt {
            let (data, status) = try await postFormRaw(MiniMaxOAuthConfig.tokenURL, fields: [
                "grant_type": MiniMaxOAuthConfig.grantType,
                "client_id": MiniMaxOAuthConfig.clientID,
                "user_code": userCode,
                "code_verifier": verifier
            ])

            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]

            guard status == 200 else {
                let msg = ((json["base_resp"] as? [String: Any])?["status_msg"] as? String)
                    ?? (String(data: data, encoding: .utf8) ?? "")
                throw MiniMaxOAuthError.tokenExchangeFailed("HTTP \(status) \(msg)")
            }

            switch json["status"] as? String {
            case "success":
                try storeTokenResponse(json)
                return
            case "error":
                throw MiniMaxOAuthError.denied
            default:
                // "pending" (or any other non-terminal status) → keep waiting.
                try await Task.sleep(nanoseconds: UInt64(code.interval * 1_000_000_000))
            }
        }
        throw MiniMaxOAuthError.expired
    }

    private func refresh() async throws {
        guard let refreshToken = KeychainService.shared.minimaxRefreshToken, !refreshToken.isEmpty else {
            throw MiniMaxOAuthError.notSignedIn
        }
        let data = try await postForm(MiniMaxOAuthConfig.tokenURL, fields: [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": MiniMaxOAuthConfig.clientID
        ])
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        try storeTokenResponse(json)
    }

    // MARK: Networking

    /// POSTs a form body and returns the data, throwing on non-2xx.
    private func postForm(_ urlString: String, fields: [String: String], extraHeaders: [String: String] = [:]) async throws -> Data {
        let (data, status) = try await postFormRaw(urlString, fields: fields, extraHeaders: extraHeaders)
        guard (200...299).contains(status) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw MiniMaxOAuthError.tokenExchangeFailed("HTTP \(status) \(body)")
        }
        return data
    }

    /// POSTs a form body and returns the raw data + HTTP status (no throwing on 4xx).
    private func postFormRaw(_ urlString: String, fields: [String: String], extraHeaders: [String: String] = [:]) async throws -> (Data, Int) {
        guard let url = URL(string: urlString) else {
            throw MiniMaxOAuthError.tokenExchangeFailed("invalid URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (key, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = fields
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .mmURLQueryValueAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        return (data, status)
    }

    private func storeTokenResponse(_ json: [String: Any]) throws {
        guard let accessToken = json["access_token"] as? String, !accessToken.isEmpty else {
            throw MiniMaxOAuthError.tokenExchangeFailed("missing access_token")
        }
        KeychainService.shared.minimaxAccessToken = accessToken
        if let refreshToken = json["refresh_token"] as? String {
            KeychainService.shared.minimaxRefreshToken = refreshToken
        }
        if let expiry = json["expires_in"] ?? json["expired_in"] {
            KeychainService.shared.minimaxTokenExpiry = String(Self.resolveExpiry(expiry).timeIntervalSince1970)
        }
    }

    /// MiniMax expresses expiry either as an absolute unix-millisecond timestamp
    /// or as a relative TTL in seconds; support both defensively.
    private static func resolveExpiry(_ value: Any?) -> Date {
        let now = Date()
        let number: Double
        switch value {
        case let d as Double: number = d
        case let i as Int: number = Double(i)
        case let s as String: number = Double(s) ?? 0
        default: return now.addingTimeInterval(300)
        }
        guard number > 0 else { return now.addingTimeInterval(300) }
        // Hermes heuristic: values larger than half of "now in ms" are absolute
        // unix-millisecond timestamps; otherwise treat as a TTL in seconds.
        let nowMs = now.timeIntervalSince1970 * 1000
        if number > nowMs / 2 {
            return Date(timeIntervalSince1970: number / 1000)
        }
        return now.addingTimeInterval(number)
    }
}

private extension CharacterSet {
    /// Allowed characters for x-www-form-urlencoded query values.
    static let mmURLQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()
}
