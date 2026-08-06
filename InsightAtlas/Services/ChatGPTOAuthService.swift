import Foundation
import Security
import CryptoKit
import Combine

// MARK: - ⚠️ UNOFFICIAL "Sign in with ChatGPT" (Codex) OAuth
//
// This routes guide generation through the signed-in user's ChatGPT
// subscription via the reverse-engineered Codex backend. It is NOT supported
// by OpenAI, may violate its Terms of Service, and can cause the account to be
// rate-limited or banned. OpenAI can rotate the client_id / endpoints / request
// shape at any time, which will silently break this path. Values below are the
// community-documented Codex flow (Aug 2026) and are centralized here so they
// can be updated in one place.

enum ChatGPTOAuthConfig {
    static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    static let authorizeURL = "https://auth.openai.com/oauth/authorize"
    static let tokenURL = "https://auth.openai.com/oauth/token"
    static let redirectURI = "http://localhost:1455/auth/callback"
    static let scopes = "openid profile email offline_access"
    /// Chat Completions–compatible Codex endpoint.
    static let inferenceURL = "https://chatgpt.com/backend-api/codex/v1/chat/completions"
    /// Adjust to a model your ChatGPT plan can access.
    static let defaultModel = "gpt-5.6-terra"
}

enum ChatGPTOAuthError: LocalizedError {
    case notSignedIn
    case invalidCallback
    case tokenExchangeFailed(String)
    case inferenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Not signed in to ChatGPT."
        case .invalidCallback: return "The sign-in response was invalid."
        case .tokenExchangeFailed(let m): return "Token exchange failed: \(m)"
        case .inferenceFailed(let m): return "ChatGPT generation failed: \(m)"
        }
    }
}

/// PKCE verifier/challenge pair (S256).
struct PKCE {
    let verifier: String
    let challenge: String

    init() {
        var bytes = [UInt8](repeating: 0, count: 48)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let v = Data(bytes).iaBase64URL()
        verifier = v
        challenge = Data(SHA256.hash(data: Data(v.utf8))).iaBase64URL()
    }
}

private extension Data {
    func iaBase64URL() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

@MainActor
final class ChatGPTOAuthService: ObservableObject {
    static let shared = ChatGPTOAuthService()

    @Published private(set) var isSignedIn: Bool = KeychainService.shared.hasChatGPTAuth

    private let keychain = KeychainService.shared
    private var pendingPKCE: PKCE?
    private var pendingState: String?

    /// Keychain is a synchronous, thread-safe singleton, so presence can be
    /// checked off the main actor (e.g. from the AIService actor).
    nonisolated static var hasStoredCredentials: Bool { KeychainService.shared.hasChatGPTAuth }
    nonisolated static var storedAccountID: String? { KeychainService.shared.chatgptAccountID }

    var redirectPrefix: String { ChatGPTOAuthConfig.redirectURI }

    /// Builds the authorization URL and stashes the PKCE + state for the callback.
    func authorizationURL() -> URL {
        let pkce = PKCE()
        pendingPKCE = pkce
        let state = UUID().uuidString
        pendingState = state

        var comps = URLComponents(string: ChatGPTOAuthConfig.authorizeURL)!
        comps.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: ChatGPTOAuthConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: ChatGPTOAuthConfig.redirectURI),
            URLQueryItem(name: "scope", value: ChatGPTOAuthConfig.scopes),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            // Codex hints — harmless if the server ignores them.
            URLQueryItem(name: "id_token_add_organizations", value: "true"),
            URLQueryItem(name: "codex_cli_simplified_flow", value: "true")
        ]
        return comps.url!
    }

    /// Handles the intercepted localhost redirect, exchanging the code for tokens.
    func handleCallback(url: URL) async throws {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = comps.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw ChatGPTOAuthError.invalidCallback
        }
        if let returned = comps.queryItems?.first(where: { $0.name == "state" })?.value,
           let expected = pendingState, returned != expected {
            throw ChatGPTOAuthError.invalidCallback
        }
        guard let verifier = pendingPKCE?.verifier else { throw ChatGPTOAuthError.invalidCallback }
        try await exchangeCode(code, verifier: verifier)
        pendingPKCE = nil
        pendingState = nil
    }

    /// Returns a non-expired access token, refreshing if needed.
    func validAccessToken() async throws -> String {
        guard let token = keychain.chatgptAccessToken else { throw ChatGPTOAuthError.notSignedIn }
        if let expiryStr = keychain.chatgptTokenExpiry, let expiry = Double(expiryStr),
           Date().timeIntervalSince1970 > expiry - 60 {
            try await refresh()
            return keychain.chatgptAccessToken ?? token
        }
        return token
    }

    func signOut() {
        keychain.clearChatGPTAuth()
        isSignedIn = false
    }

    // MARK: - Token exchange

    private func exchangeCode(_ code: String, verifier: String) async throws {
        let data = try await postForm([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": ChatGPTOAuthConfig.redirectURI,
            "client_id": ChatGPTOAuthConfig.clientID,
            "code_verifier": verifier
        ])
        try storeTokenResponse(data)
        isSignedIn = true
    }

    private func refresh() async throws {
        guard let refreshToken = keychain.chatgptRefreshToken else { throw ChatGPTOAuthError.notSignedIn }
        let data = try await postForm([
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": ChatGPTOAuthConfig.clientID
        ])
        try storeTokenResponse(data)
    }

    private func postForm(_ form: [String: String]) async throws -> Data {
        var req = URLRequest(url: URL(string: ChatGPTOAuthConfig.tokenURL)!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = form
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .iaFormValue) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw ChatGPTOAuthError.tokenExchangeFailed("HTTP \(code): \(body)")
        }
        return data
    }

    private func storeTokenResponse(_ data: Data) throws {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String else {
            throw ChatGPTOAuthError.tokenExchangeFailed("no access_token in response")
        }
        keychain.chatgptAccessToken = access
        if let refresh = json["refresh_token"] as? String { keychain.chatgptRefreshToken = refresh }
        if let expiresIn = json["expires_in"] as? Double {
            keychain.chatgptTokenExpiry = String(Date().timeIntervalSince1970 + expiresIn)
        }
        if let idToken = json["id_token"] as? String,
           let account = Self.accountID(fromIDToken: idToken) {
            keychain.chatgptAccountID = account
        }
    }

    /// Decodes the id_token JWT payload to recover the ChatGPT account id
    /// (sent as the `chatgpt-account-id` header on Codex requests).
    static func accountID(fromIDToken token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var b64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let auth = json["https://api.openai.com/auth"] as? [String: Any] {
            return (auth["chatgpt_account_id"] as? String) ?? (auth["account_id"] as? String)
        }
        return json["chatgpt_account_id"] as? String
    }
}

// MARK: - Codex inference client

struct ChatGPTCodexClient {
    func generate(
        systemPrompt: String,
        userMessage: String,
        model: String,
        accessToken: String,
        accountID: String?
    ) async throws -> String {
        var req = URLRequest(url: URL(string: ChatGPTOAuthConfig.inferenceURL)!)
        req.httpMethod = "POST"
        req.timeoutInterval = 300
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("codex_cli_rs", forHTTPHeaderField: "originator")
        if let accountID { req.setValue(accountID, forHTTPHeaderField: "chatgpt-account-id") }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage]
            ],
            "stream": false
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw ChatGPTOAuthError.inferenceFailed("no HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ChatGPTOAuthError.inferenceFailed("HTTP \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ChatGPTOAuthError.inferenceFailed("unparseable response")
        }
        // Chat Completions shape.
        if let choices = json["choices"] as? [[String: Any]],
           let msg = choices.first?["message"] as? [String: Any],
           let content = msg["content"] as? String {
            return content
        }
        // Responses API fallback shape.
        if let output = json["output_text"] as? String { return output }
        throw ChatGPTOAuthError.inferenceFailed("unexpected response shape")
    }
}

private extension CharacterSet {
    static let iaFormValue: CharacterSet = {
        var cs = CharacterSet.urlQueryAllowed
        cs.remove(charactersIn: "&=+")
        return cs
    }()
}
