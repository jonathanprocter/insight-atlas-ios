//
//  MegaTranscriptNarration.swift
//  InsightAtlas
//
//  Development-only Mega Transcript narration support. A distributed build
//  must move the vendor credential and request behind a developer-controlled
//  backend; a mobile binary cannot keep a shared vendor secret confidential.
//

import AVFoundation
import Combine
import CryptoKit
import Foundation
import MediaPlayer
import Security
import UIKit

// MARK: - API models

struct MegaTranscriptVoice: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let languageCode: String
    let gender: String
    let provider: String
    let emotionAware: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, gender, provider
        case languageCode = "language_code"
        case emotionAware = "emotion_aware"
    }

    init(
        id: Int,
        name: String,
        languageCode: String,
        gender: String,
        provider: String,
        emotionAware: Bool
    ) {
        self.id = id
        self.name = name
        self.languageCode = languageCode
        self.gender = gender
        self.provider = provider
        self.emotionAware = emotionAware
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let decodedID = try container.decodeFlexibleIntIfPresent(forKey: .id),
              let decodedName = try container.decodeFlexibleStringIfPresent(forKey: .name),
              !decodedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: container.codingPath,
                    debugDescription: "A Mega Transcript voice requires a usable id and name."
                )
            )
        }

        id = decodedID
        name = decodedName
        // The request itself is filtered to English. Preserve catalog values
        // when present, while tolerating providers that omit redundant fields.
        languageCode = try container.decodeFlexibleStringIfPresent(forKey: .languageCode) ?? "en"
        gender = try container.decodeFlexibleStringIfPresent(forKey: .gender) ?? "unspecified"
        provider = try container.decodeFlexibleStringIfPresent(forKey: .provider) ?? "Mega Transcript"
        emotionAware = try container.decodeFlexibleBoolIfPresent(forKey: .emotionAware) ?? false
    }

    static func preferred(in voices: [MegaTranscriptVoice]) -> MegaTranscriptVoice? {
        let english = voices.filter {
            $0.languageCode.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .hasPrefix("en")
        }

        func named(_ expected: String) -> MegaTranscriptVoice? {
            english.first {
                $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    .localizedCaseInsensitiveCompare(expected) == .orderedSame
            }
        }

        return named("Arthur")
            ?? named("Mia")
            ?? english.first(where: \.emotionAware)
            ?? english.first
    }
}

struct MegaTranscriptVoiceListResponse: Codable, Sendable {
    let status: Bool
    let total: Int
    let voices: [MegaTranscriptVoice]

    enum CodingKeys: String, CodingKey {
        case status, total, voices
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        voices = try container.decode([MegaTranscriptVoice].self, forKey: .voices)
        status = try container.decodeFlexibleBoolIfPresent(forKey: .status) ?? true
        total = try container.decodeFlexibleIntIfPresent(forKey: .total) ?? voices.count
    }
}

struct MegaTranscriptTTSRequest: Codable, Sendable {
    let text: String
    let voiceID: Int

    enum CodingKeys: String, CodingKey {
        case text
        case voiceID = "voice_id"
    }
}

struct MegaTranscriptTTSResponse: Codable, Sendable {
    struct Results: Codable, Sendable {
        let data: String?
        let cost: Double?
        let msg: String?
        let status: Int?
        let userID: Int?
        let fileURL: String?

        enum CodingKeys: String, CodingKey {
            case data, cost, msg, status
            case userID = "user_id"
            case fileURL = "file_url"
        }

        init(
            data: String?,
            cost: Double?,
            msg: String?,
            status: Int?,
            userID: Int?,
            fileURL: String?
        ) {
            self.data = data
            self.cost = cost
            self.msg = msg
            self.status = status
            self.userID = userID
            self.fileURL = fileURL
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            // Only file_url is required for the next operation. Vendor
            // bookkeeping has changed type in otherwise successful responses,
            // so optional metadata must not invalidate a usable audio result.
            data = try? container.decodeFlexibleStringIfPresent(forKey: .data)
            cost = try? container.decodeFlexibleDoubleIfPresent(forKey: .cost)
            msg = try? container.decodeFlexibleStringIfPresent(forKey: .msg)
            status = try? container.decodeFlexibleIntIfPresent(forKey: .status)
            userID = try? container.decodeFlexibleIntIfPresent(forKey: .userID)
            fileURL = try? container.decodeFlexibleStringIfPresent(forKey: .fileURL)
        }
    }

    let id: String
    let status: String
    let taskName: String?
    let taskType: String?
    let createdAt: TimeInterval?
    let totalChars: Int?
    let results: Results

    enum CodingKeys: String, CodingKey {
        case id, status, results
        case taskName = "task_name"
        case taskType = "task_type"
        case createdAt = "created_at"
        case totalChars = "total_chars"
        case fileURL = "file_url"
        case cost
    }

    init(
        id: String,
        status: String,
        taskName: String?,
        taskType: String?,
        createdAt: TimeInterval?,
        totalChars: Int?,
        results: Results
    ) {
        self.id = id
        self.status = status
        self.taskName = taskName
        self.taskType = taskType
        self.createdAt = createdAt
        self.totalChars = totalChars
        self.results = results
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decodeFlexibleStringIfPresent(forKey: .id)) ?? ""
        status = (try? container.decodeFlexibleStringIfPresent(forKey: .status)) ?? ""
        taskName = try? container.decodeFlexibleStringIfPresent(forKey: .taskName)
        taskType = try? container.decodeFlexibleStringIfPresent(forKey: .taskType)
        createdAt = try? container.decodeFlexibleDoubleIfPresent(forKey: .createdAt)
        totalChars = try? container.decodeFlexibleIntIfPresent(forKey: .totalChars)

        if let nested = try? container.decode(Results.self, forKey: .results) {
            results = nested
        } else {
            // Some Mega Transcript surfaces expose the completed job's URL at
            // the job level. Supporting that shape costs no ambiguity because
            // the coordinator still requires a valid HTTPS URL before download.
            results = Results(
                data: nil,
                cost: try? container.decodeFlexibleDoubleIfPresent(forKey: .cost),
                msg: nil,
                status: nil,
                userID: nil,
                fileURL: try? container.decodeFlexibleStringIfPresent(forKey: .fileURL)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(taskName, forKey: .taskName)
        try container.encodeIfPresent(taskType, forKey: .taskType)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(totalChars, forKey: .totalChars)
        try container.encode(results, forKey: .results)
    }

    var indicatesCompletedAudio: Bool {
        if let rawURL = results.fileURL,
           let url = URL(string: rawURL),
           url.scheme?.localizedCaseInsensitiveCompare("https") == .orderedSame {
            return true
        }

        let normalizedStatus = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["complete", "completed", "success", "succeeded"].contains(normalizedStatus)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleStringIfPresent(forKey key: Key) throws -> String? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        if let value = try? decode(String.self, forKey: key) { return value }
        if let value = try? decode(Int64.self, forKey: key) { return String(value) }
        if let value = try? decode(Double.self, forKey: key), value.isFinite { return String(value) }
        if let value = try? decode(Bool.self, forKey: key) { return String(value) }
        throw DecodingError.typeMismatch(
            String.self,
            .init(codingPath: codingPath + [key], debugDescription: "Expected a string-compatible JSON scalar.")
        )
    }

    func decodeFlexibleIntIfPresent(forKey key: Key) throws -> Int? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        if let value = try? decode(Int.self, forKey: key) { return value }
        if let string = try? decode(String.self, forKey: key),
           let value = Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return value
        }
        if let value = try? decode(Double.self, forKey: key),
           value.isFinite,
           value.rounded(.towardZero) == value,
           value >= Double(Int.min),
           value <= Double(Int.max) {
            return Int(value)
        }
        throw DecodingError.typeMismatch(
            Int.self,
            .init(codingPath: codingPath + [key], debugDescription: "Expected an integer-compatible JSON scalar.")
        )
    }

    func decodeFlexibleDoubleIfPresent(forKey key: Key) throws -> Double? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        if let value = try? decode(Double.self, forKey: key), value.isFinite { return value }
        if let string = try? decode(String.self, forKey: key),
           let value = Double(string.trimmingCharacters(in: .whitespacesAndNewlines)),
           value.isFinite {
            return value
        }
        throw DecodingError.typeMismatch(
            Double.self,
            .init(codingPath: codingPath + [key], debugDescription: "Expected a number-compatible JSON scalar.")
        )
    }

    func decodeFlexibleBoolIfPresent(forKey key: Key) throws -> Bool? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        if let value = try? decode(Bool.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) {
            if value == 1 { return true }
            if value == 0 { return false }
        }
        if let string = try? decode(String.self, forKey: key) {
            switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes": return true
            case "false", "0", "no": return false
            default: break
            }
        }
        throw DecodingError.typeMismatch(
            Bool.self,
            .init(codingPath: codingPath + [key], debugDescription: "Expected a Boolean-compatible JSON scalar.")
        )
    }
}

enum MegaTranscriptError: LocalizedError {
    case missingKey
    case invalidURL
    case invalidResponse
    case badRequest(String?)
    case unauthorized(String?)
    case forbidden(String?)
    case notFound(String?)
    case rateLimited(String?)
    case generationTimedOut
    case serverError(statusCode: Int, detail: String?)
    case decodingFailed
    case missingAudioURL
    case downloadFailed(String?)
    case cancelled
    case network(URLError)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "Add your regenerated Mega Transcript API key in Settings → Audio & Narration."
        case .invalidURL:
            return "The Mega Transcript service address is invalid."
        case .invalidResponse:
            return "Mega Transcript returned an invalid response."
        case .badRequest(let detail):
            return detail ?? "Mega Transcript rejected the narration request."
        case .unauthorized(let detail):
            return detail ?? "Mega Transcript rejected the API key. Replace it in Developer Settings."
        case .forbidden(let detail):
            return detail ?? "This Mega Transcript key is not permitted to generate narration."
        case .notFound(let detail):
            return detail ?? "The requested Mega Transcript resource was not found."
        case .rateLimited(let detail):
            return detail ?? "Mega Transcript is rate limiting requests. Wait briefly before retrying."
        case .generationTimedOut:
            return "This summary exceeded Mega Transcript’s 600-second synchronous generation window. Liam remains available as the fallback narrator."
        case .serverError(let statusCode, let detail):
            return detail ?? "Mega Transcript is temporarily unavailable (HTTP \(statusCode))."
        case .decodingFailed:
            return "Mega Transcript returned data the app could not read."
        case .missingAudioURL:
            return "Mega Transcript completed the request without an audio download URL."
        case .downloadFailed(let detail):
            return detail ?? "The generated narration could not be downloaded."
        case .cancelled:
            return "Narration preparation was cancelled."
        case .network(let error):
            if error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
                return "The network connection is unavailable. Liam remains available as the fallback narrator."
            }
            return "Network error: \(error.localizedDescription)"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .rateLimited, .serverError, .downloadFailed, .network:
            return true
        default:
            return false
        }
    }
}

// MARK: - Credential storage

protocol MegaTranscriptCredentialStore: AnyObject {
    var hasAPIKey: Bool { get }
    func loadAPIKey() throws -> String?
    func saveAPIKey(_ key: String) throws
    func deleteAPIKey() throws
}

final class KeychainMegaTranscriptCredentialStore: MegaTranscriptCredentialStore {
    static let shared = KeychainMegaTranscriptCredentialStore()

    let service: String
    let account: String

    init(
        service: String = "\(Bundle.main.bundleIdentifier ?? "com.echoingempathos.InsightAtlas").megatranscript",
        account: String = "api-key"
    ) {
        self.service = service
        self.account = account
    }

    var hasAPIKey: Bool {
        guard let key = try? loadAPIKey() else { return false }
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func loadAPIKey() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        return String(data: data, encoding: .utf8)
    }

    func saveAPIKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MegaTranscriptError.missingKey }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: Data(trimmed.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var insertion = query
            attributes.forEach { insertion[$0.key] = $0.value }
            let addStatus = SecItemAdd(insertion as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus))
            }
        } else if updateStatus != errSecSuccess {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(updateStatus))
        }
    }

    func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}

// MARK: - API client

protocol MegaTranscriptServicing: AnyObject {
    var isConfigured: Bool { get }
    func listEnglishVoices() async throws -> [MegaTranscriptVoice]
    func generateNarration(text: String, voiceID: Int) async throws -> MegaTranscriptTTSResponse
    func downloadAudio(from url: URL) async throws -> Data
}

final class MegaTranscriptService: MegaTranscriptServicing {
    static let productionBaseURL: URL = {
        guard let url = URL(string: "https://api.megatranscript.com") else {
            preconditionFailure("The compiled Mega Transcript base URL is invalid.")
        }
        return url
    }()

    private struct APIErrorPayload: Decodable {
        let detail: String?
        let message: String?
    }

    private let baseURL: URL
    private let session: URLSession
    private let credentialStore: MegaTranscriptCredentialStore
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        baseURL: URL = MegaTranscriptService.productionBaseURL,
        session: URLSession = MegaTranscriptService.makeSession(),
        credentialStore: MegaTranscriptCredentialStore = KeychainMegaTranscriptCredentialStore.shared
    ) {
        self.baseURL = baseURL
        self.session = session
        self.credentialStore = credentialStore
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    var isConfigured: Bool { credentialStore.hasAPIKey }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 610
        configuration.timeoutIntervalForResource = 620
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }

    func listEnglishVoices() async throws -> [MegaTranscriptVoice] {
        let url = try endpoint(
            components: ["api", "external", "v1", "voices", "list"],
            queryItems: [URLQueryItem(name: "language_code", value: "en")]
        )
        let request = try authorizedRequest(url: url, method: "GET")
        let data = try await perform(request)
        do {
            let response = try decoder.decode(MegaTranscriptVoiceListResponse.self, from: data)
            guard response.status else { throw MegaTranscriptError.invalidResponse }
            return response.voices
        } catch let error as MegaTranscriptError {
            throw error
        } catch {
            throw logDecodeFailure("voices/list", data, error: error)
        }
    }

    func generateNarration(text: String, voiceID: Int) async throws -> MegaTranscriptTTSResponse {
        let url = try endpoint(
            components: ["api", "external", "v1", "tts", "generate", "sync"],
            queryItems: [URLQueryItem(name: "timeout", value: "600")]
        )
        var request = try authorizedRequest(url: url, method: "POST")
        request.timeoutInterval = 610
        do {
            request.httpBody = try encoder.encode(MegaTranscriptTTSRequest(text: text, voiceID: voiceID))
        } catch {
            throw MegaTranscriptError.decodingFailed
        }

        let data = try await perform(request)
        do {
            let response = try decoder.decode(MegaTranscriptTTSResponse.self, from: data)
            guard response.indicatesCompletedAudio else {
                throw logDecodeFailure(
                    "tts/generate/sync",
                    data,
                    error: MegaTranscriptError.invalidResponse
                )
            }
            return response
        } catch let error as MegaTranscriptError {
            throw error
        } catch {
            throw logDecodeFailure("tts/generate/sync", data, error: error)
        }
    }

    func downloadAudio(from url: URL) async throws -> Data {
        guard url.scheme?.lowercased() == "https" else { throw MegaTranscriptError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 610

        do {
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
            guard let http = response as? HTTPURLResponse else {
                throw MegaTranscriptError.invalidResponse
            }
            guard (200...299).contains(http.statusCode), !data.isEmpty else {
                throw MegaTranscriptError.downloadFailed(detail(from: data))
            }
            return data
        } catch is CancellationError {
            throw MegaTranscriptError.cancelled
        } catch let error as MegaTranscriptError {
            throw error
        } catch let error as URLError {
            throw MegaTranscriptError.network(error)
        } catch {
            throw MegaTranscriptError.downloadFailed(error.localizedDescription)
        }
    }

    private func endpoint(components: [String], queryItems: [URLQueryItem] = []) throws -> URL {
        guard baseURL.scheme?.lowercased() == "https" || baseURL.isFileURL else {
            throw MegaTranscriptError.invalidURL
        }
        var url = baseURL
        for component in components { url.appendPathComponent(component) }
        var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
        parts?.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let result = parts?.url else { throw MegaTranscriptError.invalidURL }
        return result
    }

    private func authorizedRequest(url: URL, method: String) throws -> URLRequest {
        guard let key = try credentialStore.loadAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty else {
            throw MegaTranscriptError.missingKey
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "X-API-Key")
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
            guard let http = response as? HTTPURLResponse else {
                throw MegaTranscriptError.invalidResponse
            }
            guard (200...299).contains(http.statusCode) else {
                throw map(statusCode: http.statusCode, data: data)
            }
            return data
        } catch is CancellationError {
            throw MegaTranscriptError.cancelled
        } catch let error as MegaTranscriptError {
            throw error
        } catch let error as URLError {
            throw MegaTranscriptError.network(error)
        } catch {
            throw MegaTranscriptError.invalidResponse
        }
    }

    private func map(statusCode: Int, data: Data) -> MegaTranscriptError {
        let apiDetail = detail(from: data)
        switch statusCode {
        case 400: return .badRequest(apiDetail)
        case 401: return .unauthorized(apiDetail)
        case 403: return .forbidden(apiDetail)
        case 404: return .notFound(apiDetail)
        case 408: return .generationTimedOut
        case 429: return .rateLimited(apiDetail)
        case 500...599: return .serverError(statusCode: statusCode, detail: apiDetail)
        default: return .serverError(statusCode: statusCode, detail: apiDetail)
        }
    }

    private func detail(from data: Data) -> String? {
        guard let payload = try? decoder.decode(APIErrorPayload.self, from: data) else { return nil }
        return payload.detail ?? payload.message
    }

    /// A 2xx response arrived but did not match the documented response shape.
    /// In Debug only, include the decoder context and response body so a future
    /// vendor schema change has an exact coding path. The body can contain a
    /// signed audio URL, so this diagnostic must never be emitted by Release.
    private func logDecodeFailure(
        _ label: String,
        _ data: Data,
        error: Error? = nil
    ) -> MegaTranscriptError {
#if DEBUG
        let body = String(data: data, encoding: .utf8) ?? "<non-utf8 \(data.count) bytes>"
        let snippet = body.count > 20_000 ? String(body.prefix(20_000)) + "…[truncated]" : body
        let decodeContext = error.map { "\nDECODER: \(String(describing: $0))" } ?? ""
        print("🎙️ [MegaTranscript] \(label): 2xx but response did NOT match expected schema.\(decodeContext)\nRAW BODY BELOW:\n\(snippet)\n🎙️ [MegaTranscript] --- end raw body ---")
#endif
        return .decodingFailed
    }
}

// MARK: - Narrator preference

final class MegaTranscriptNarratorPreferences {
    static let shared = MegaTranscriptNarratorPreferences()
    static let selectedVoiceIDKey = "megatranscript.selectedVoiceID"
    static let selectedVoiceNameKey = "megatranscript.selectedVoiceName"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedVoiceID: Int? {
        guard defaults.object(forKey: Self.selectedVoiceIDKey) != nil else { return nil }
        return defaults.integer(forKey: Self.selectedVoiceIDKey)
    }

    var selectedVoiceName: String? {
        defaults.string(forKey: Self.selectedVoiceNameKey)
    }

    func select(_ voice: MegaTranscriptVoice) {
        defaults.set(voice.id, forKey: Self.selectedVoiceIDKey)
        defaults.set(voice.name, forKey: Self.selectedVoiceNameKey)
    }

    func selectedVoice(from voices: [MegaTranscriptVoice]) -> MegaTranscriptVoice? {
        if let selectedVoiceID,
           let selected = voices.first(where: { $0.id == selectedVoiceID }) {
            return selected
        }
        guard let preferred = MegaTranscriptVoice.preferred(in: voices) else { return nil }
        select(preferred)
        return preferred
    }
}

// MARK: - Cache

struct MegaTranscriptNarrationCacheEntry: Sendable {
    let key: String
    let audioURL: URL
    let voiceID: Int
    let voiceName: String
    let duration: TimeInterval
    let generatedAt: Date
    let cost: Double?
}

actor MegaTranscriptNarrationCache {
    static let shared = MegaTranscriptNarrationCache()
    static let formatVersion = "megatranscript-wav-v1"

    private struct Metadata: Codable {
        let key: String
        let voiceID: Int
        let voiceName: String
        let duration: TimeInterval
        let generatedAt: Date
        let cost: Double?
        let localFilename: String
    }

    private let fileManager: FileManager
    private let rootDirectory: URL
    private let playbackDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        rootDirectory: URL? = nil,
        playbackDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        let applicationSupport = rootDirectory
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Narrations", isDirectory: true)
            ?? fileManager.temporaryDirectory.appendingPathComponent("Narrations", isDirectory: true)
        self.rootDirectory = applicationSupport
        self.playbackDirectory = playbackDirectory
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
    }

    nonisolated static func cacheKey(text: String, voiceID: Int) -> String {
        let payload = "\(formatVersion)\u{0}\(voiceID)\u{0}\(text)"
        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func entry(text: String, voiceID: Int) throws -> MegaTranscriptNarrationCacheEntry? {
        try entry(forKey: Self.cacheKey(text: text, voiceID: voiceID))
    }

    func entry(forKey key: String) throws -> MegaTranscriptNarrationCacheEntry? {
        let metadataURL = rootDirectory.appendingPathComponent("\(key).json")
        guard fileManager.fileExists(atPath: metadataURL.path),
              let data = try? Data(contentsOf: metadataURL),
              let metadata = try? decoder.decode(Metadata.self, from: data) else {
            return nil
        }
        let audioURL = rootDirectory.appendingPathComponent(metadata.localFilename)
        let fileSize = (try? audioURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard fileManager.fileExists(atPath: audioURL.path),
              fileSize > 0 else {
            try? fileManager.removeItem(at: metadataURL)
            return nil
        }
        return MegaTranscriptNarrationCacheEntry(
            key: metadata.key,
            audioURL: audioURL,
            voiceID: metadata.voiceID,
            voiceName: metadata.voiceName,
            duration: metadata.duration,
            generatedAt: metadata.generatedAt,
            cost: metadata.cost
        )
    }

    func store(
        audioData: Data,
        text: String,
        voice: MegaTranscriptVoice,
        duration: TimeInterval,
        cost: Double?
    ) throws -> MegaTranscriptNarrationCacheEntry {
        guard !audioData.isEmpty else { throw MegaTranscriptError.downloadFailed(nil) }
        try prepareDirectories()

        let key = Self.cacheKey(text: text, voiceID: voice.id)
        let filename = "\(key).wav"
        let audioURL = rootDirectory.appendingPathComponent(filename)
        let stagingURL = rootDirectory.appendingPathComponent(".\(filename).\(UUID().uuidString).partial")
        try audioData.write(to: stagingURL, options: .atomic)
        try protectFile(at: stagingURL)
        try promote(stagingURL, to: audioURL)

        let metadata = Metadata(
            key: key,
            voiceID: voice.id,
            voiceName: voice.name,
            duration: duration,
            generatedAt: Date(),
            cost: cost,
            localFilename: filename
        )
        let metadataData = try encoder.encode(metadata)
        try metadataData.write(
            to: rootDirectory.appendingPathComponent("\(key).json"),
            options: .atomic
        )
        try protectFile(at: rootDirectory.appendingPathComponent("\(key).json"))

        return MegaTranscriptNarrationCacheEntry(
            key: key,
            audioURL: audioURL,
            voiceID: voice.id,
            voiceName: voice.name,
            duration: duration,
            generatedAt: metadata.generatedAt,
            cost: cost
        )
    }

    func materialize(_ entry: MegaTranscriptNarrationCacheEntry, itemID: UUID) throws -> NarrationAsset {
        try prepareDirectories()
        let relativeName = "audio_\(itemID.uuidString).wav"
        let destination = playbackDirectory.appendingPathComponent(relativeName)
        let staging = playbackDirectory.appendingPathComponent(".\(relativeName).\(UUID().uuidString).partial")
        try? fileManager.removeItem(at: staging)
        try fileManager.copyItem(at: entry.audioURL, to: staging)
        try protectFile(at: staging)
        try promote(staging, to: destination)

        for ext in ["mp3", "m4a"] {
            try? fileManager.removeItem(
                at: playbackDirectory.appendingPathComponent("audio_\(itemID.uuidString).\(ext)")
            )
        }

        return NarrationAsset(
            relativeFileName: relativeName,
            voiceID: "megatranscript:\(entry.voiceID):\(entry.voiceName)",
            duration: entry.duration
        )
    }

    func remove(text: String, voiceID: Int, itemID: UUID? = nil) throws {
        let key = Self.cacheKey(text: text, voiceID: voiceID)
        try? fileManager.removeItem(at: rootDirectory.appendingPathComponent("\(key).wav"))
        try? fileManager.removeItem(at: rootDirectory.appendingPathComponent("\(key).json"))
        if let itemID {
            for ext in ["wav", "mp3", "m4a"] {
                try? fileManager.removeItem(
                    at: playbackDirectory.appendingPathComponent("audio_\(itemID.uuidString).\(ext)")
                )
            }
        }
    }

    func clear() throws {
        guard fileManager.fileExists(atPath: rootDirectory.path) else { return }
        let children = try fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: nil
        )
        for child in children { try fileManager.removeItem(at: child) }
    }

    private func prepareDirectories() throws {
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: playbackDirectory, withIntermediateDirectories: true)
        try protectFile(at: rootDirectory)
    }

    private func protectFile(at url: URL) throws {
        #if os(iOS)
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        #endif
    }

    private func promote(_ staging: URL, to destination: URL) throws {
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: staging)
        } else {
            try fileManager.moveItem(at: staging, to: destination)
        }
    }
}

// MARK: - Generation orchestration

enum NarrationPreparationProgress: Sendable, Equatable {
    case checkingCache
    case fetchingVoices
    case generating(narrator: String)
    case downloading
    case usingCache
    case fallingBackToLiam(reason: String)
    case ready(narrator: String)
}

struct MegaTranscriptNarrationResult {
    let asset: NarrationAsset
    let voice: MegaTranscriptVoice
    let cacheHit: Bool
    let cost: Double?
}

actor MegaTranscriptNarrationCoordinator {
    static let shared = MegaTranscriptNarrationCoordinator()

    private let service: MegaTranscriptServicing
    private let cache: MegaTranscriptNarrationCache
    private let preferences: MegaTranscriptNarratorPreferences
    private var inFlight: Set<UUID> = []

    init(
        service: MegaTranscriptServicing = MegaTranscriptService(),
        cache: MegaTranscriptNarrationCache = .shared,
        preferences: MegaTranscriptNarratorPreferences = .shared
    ) {
        self.service = service
        self.cache = cache
        self.preferences = preferences
    }

    nonisolated var isConfigured: Bool {
        KeychainMegaTranscriptCredentialStore.shared.hasAPIKey
    }

    func availableVoices() async throws -> [MegaTranscriptVoice] {
        let voices = try await service.listEnglishVoices()
        guard !voices.isEmpty else { throw MegaTranscriptError.invalidResponse }
        _ = preferences.selectedVoice(from: voices)
        return voices
    }

    func synthesize(
        text: String,
        itemID: UUID,
        progress: @escaping @Sendable (NarrationPreparationProgress) -> Void = { _ in }
    ) async throws -> MegaTranscriptNarrationResult {
        let exactSummary = text
        let spokenText = NarrationTextSanitizer.prepare(exactSummary)
        guard !spokenText.isEmpty else { throw NarrationServiceError.emptyText }
        guard !inFlight.contains(itemID) else { throw NarrationServiceError.alreadyInProgress }
        inFlight.insert(itemID)
        defer { inFlight.remove(itemID) }

        // A persisted voice selection lets an identical cached narration play
        // immediately, including after relaunch, without making any vendor
        // request or spending generation credits.
        progress(.checkingCache)
        if let selectedID = preferences.selectedVoiceID,
           let cached = try await cache.entry(text: exactSummary, voiceID: selectedID) {
            try Task.checkCancellation()
            progress(.usingCache)
            let asset = try await cache.materialize(cached, itemID: itemID)
            let cachedVoice = MegaTranscriptVoice(
                id: cached.voiceID,
                name: cached.voiceName,
                languageCode: "en",
                gender: "",
                provider: "megatranscript",
                emotionAware: false
            )
            progress(.ready(narrator: cached.voiceName))
            return MegaTranscriptNarrationResult(
                asset: asset,
                voice: cachedVoice,
                cacheHit: true,
                cost: cached.cost
            )
        }

        progress(.fetchingVoices)
        let voices = try await service.listEnglishVoices()
        guard let voice = preferences.selectedVoice(from: voices) else {
            throw MegaTranscriptError.invalidResponse
        }

        // The live catalog may have selected or corrected the voice, so check
        // that voice's cache before generating.
        progress(.checkingCache)
        if let cached = try await cache.entry(text: exactSummary, voiceID: voice.id) {
            try Task.checkCancellation()
            progress(.usingCache)
            let asset = try await cache.materialize(cached, itemID: itemID)
            progress(.ready(narrator: voice.name))
            return MegaTranscriptNarrationResult(
                asset: asset,
                voice: voice,
                cacheHit: true,
                cost: cached.cost
            )
        }

        progress(.generating(narrator: voice.name))
        let response = try await service.generateNarration(text: spokenText, voiceID: voice.id)
        try Task.checkCancellation()
        guard let rawURL = response.results.fileURL,
              let audioURL = URL(string: rawURL),
              audioURL.scheme?.lowercased() == "https" else {
            throw MegaTranscriptError.missingAudioURL
        }

        progress(.downloading)
        let data = try await service.downloadAudio(from: audioURL)
        try Task.checkCancellation()
        let duration = (try? AVAudioPlayer(data: data).duration) ?? 0
        let entry = try await cache.store(
            audioData: data,
            text: exactSummary,
            voice: voice,
            duration: duration,
            cost: response.results.cost
        )
        let asset = try await cache.materialize(entry, itemID: itemID)
        progress(.ready(narrator: voice.name))
        return MegaTranscriptNarrationResult(
            asset: asset,
            voice: voice,
            cacheHit: false,
            cost: response.results.cost
        )
    }

    func preview(text: String, voice: MegaTranscriptVoice) async throws -> URL {
        if let cached = try await cache.entry(text: text, voiceID: voice.id) {
            return cached.audioURL
        }
        let response = try await service.generateNarration(text: text, voiceID: voice.id)
        guard let rawURL = response.results.fileURL,
              let url = URL(string: rawURL),
              url.scheme?.lowercased() == "https" else {
            throw MegaTranscriptError.missingAudioURL
        }
        let data = try await service.downloadAudio(from: url)
        let duration = (try? AVAudioPlayer(data: data).duration) ?? 0
        let entry = try await cache.store(
            audioData: data,
            text: text,
            voice: voice,
            duration: duration,
            cost: response.results.cost
        )
        return entry.audioURL
    }

    func removeCachedNarration(text: String, audioVoiceID: String?, itemID: UUID) async throws {
        guard let audioVoiceID,
              let id = Self.megaVoiceID(from: audioVoiceID) else {
            return
        }
        try await cache.remove(text: text, voiceID: id, itemID: itemID)
    }

    nonisolated static func megaVoiceID(from storedVoiceID: String?) -> Int? {
        guard let storedVoiceID,
              storedVoiceID.hasPrefix("megatranscript:") else { return nil }
        let components = storedVoiceID.split(separator: ":", maxSplits: 2)
        guard components.count >= 2 else { return nil }
        return Int(components[1])
    }

    nonisolated static func megaVoiceName(from storedVoiceID: String?) -> String? {
        guard let storedVoiceID,
              storedVoiceID.hasPrefix("megatranscript:") else { return nil }
        let components = storedVoiceID.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        guard components.count == 3 else { return nil }
        let name = String(components[2]).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    func clearCache() async throws {
        try await cache.clear()
    }
}

enum NarrationTextSanitizer {
    static func prepare(_ content: String) -> String {
        var result = content
        result = result.replacingOccurrences(
            of: "\\[/?[A-Z_]+:?[^\\]]*\\]",
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "#{1,6}\\s+",
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "\\*{1,2}([^*]+)\\*{1,2}",
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "_{1,2}([^_]+)_{1,2}",
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "\\[([^\\]]+)\\]\\([^)]+\\)",
            with: "$1",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "^\\s*[-*•]\\s+",
            with: "",
            options: [.regularExpression, .anchored]
        )
        result = result.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Shared local playback

@MainActor
final class NarrationPlaybackController: NSObject, ObservableObject {
    static let shared = NarrationPlaybackController()

    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var currentURL: URL?
    @Published var playbackRate: Float = 1

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var notificationObservers: [NSObjectProtocol] = []
    private var title = ""
    private var author = ""
    private var coverImagePath: String?

    private override init() {
        super.init()
        installTimeObserver()
        installAudioNotifications()
        installRemoteCommands()
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        notificationObservers.forEach(NotificationCenter.default.removeObserver)
    }

    func play(url: URL, title: String, author: String, coverImagePath: String?) throws {
        try configureAudioSession()
        if currentURL != url {
            currentURL = url
            self.title = title
            self.author = author
            self.coverImagePath = coverImagePath
            player.replaceCurrentItem(with: AVPlayerItem(url: url))
            currentTime = 0
            duration = 0
        }
        player.playImmediately(atRate: playbackRate)
        isPlaying = true
        updateNowPlayingInfo()
    }

    func toggle() {
        isPlaying ? pause() : resume()
    }

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }

    func resume() {
        guard player.currentItem != nil else { return }
        player.playImmediately(atRate: playbackRate)
        isPlaying = true
        updateNowPlayingInfo()
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentURL = nil
        currentTime = 0
        duration = 0
        isPlaying = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func seek(to seconds: TimeInterval) {
        guard seconds.isFinite else { return }
        let target = max(0, min(seconds, duration > 0 ? duration : seconds))
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        currentTime = target
        updateNowPlayingInfo()
    }

    func setRate(_ rate: Float) {
        playbackRate = max(0.75, min(rate, 2))
        if isPlaying { player.rate = playbackRate }
        updateNowPlayingInfo()
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.allowBluetoothA2DP])
        try session.setActive(true)
    }

    private func installTimeObserver() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = time.seconds.isFinite ? max(0, time.seconds) : 0
                let itemDuration = self.player.currentItem?.duration.seconds ?? 0
                if itemDuration.isFinite && itemDuration > 0 { self.duration = itemDuration }
                if self.player.currentItem?.status == .readyToPlay,
                   self.player.rate == 0,
                   self.duration > 0,
                   self.currentTime >= self.duration - 0.25 {
                    self.isPlaying = false
                }
                self.updateNowPlayingInfo()
            }
        }
    }

    private func installAudioNotifications() {
        let center = NotificationCenter.default
        notificationObservers.append(
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main
            ) { [weak self] note in
                Task { @MainActor in self?.handleInterruption(note) }
            }
        )
        notificationObservers.append(
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main
            ) { [weak self] note in
                Task { @MainActor in self?.handleRouteChange(note) }
            }
        )
    }

    private func handleInterruption(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            pause()
        case .ended:
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            if AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume) {
                resume()
            }
        @unknown default:
            pause()
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              AVAudioSession.RouteChangeReason(rawValue: rawReason) == .oldDeviceUnavailable else { return }
        pause()
    }

    private func installRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        commands.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: event.positionTime) }
            return .success
        }
        commands.changePlaybackRateCommand.supportedPlaybackRates = [0.75, 1, 1.25, 1.5, 2]
        commands.changePlaybackRateCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackRateCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.setRate(event.playbackRate) }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard currentURL != nil else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: author,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? playbackRate : 0
        ]
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }

        if let coverImagePath,
           let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
           let image = UIImage(contentsOfFile: documents.appendingPathComponent(coverImagePath).path) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
