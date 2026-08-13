import Foundation
import Security

public enum KokoroTTSError: LocalizedError {
    case missingAPIKey
    case emptyText
    case textTooLong(maximumCharacters: Int)
    case invalidResponse
    case server(statusCode: Int, message: String)
    case invalidAudio
    case documentsDirectoryUnavailable

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "The Kokoro API key is not stored in the Keychain."
        case .emptyText:
            return "The summary contains no text to narrate."
        case let .textTooLong(maximumCharacters):
            return "The summary exceeds the \(maximumCharacters)-character narration limit."
        case .invalidResponse:
            return "The Kokoro service returned an invalid response."
        case let .server(statusCode, message):
            return "Kokoro request failed (HTTP \(statusCode)): \(message)"
        case .invalidAudio:
            return "The Kokoro service returned an empty audio file."
        case .documentsDirectoryUnavailable:
            return "The app's Documents directory is unavailable."
        }
    }
}

private struct KokoroSpeechRequest: Encodable {
    let model: String
    let input: String
    let voice: String
    let responseFormat: String
    let speed: Double

    enum CodingKeys: String, CodingKey {
        case model, input, voice, speed
        case responseFormat = "response_format"
    }
}

private struct KokoroErrorEnvelope: Decodable {
    struct ErrorBody: Decodable {
        let message: String
    }

    let error: ErrorBody
}

/// Liam-only client for completed summary narration.
///
/// The voice is not a caller-selectable parameter. The client always sends
/// `am_liam`, and the production gateway independently rejects every other
/// voice, preventing an accidental fallback in either layer.
public actor KokoroTTSClient {
    public static let defaultBaseURL = URL(string: "https://kokoro-tts.procterai.cc/v1")!
    public static let keychainService = "cc.procterai.kokoro-tts"
    public static let keychainAccount = "ios-primary"
    public static let voice = "am_liam"
    public static let maximumCharactersPerRequest = 5_000

    private let baseURL: URL
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    public init(baseURL: URL = KokoroTTSClient.defaultBaseURL, session: URLSession = KokoroTTSClient.makeDefaultSession()) {
        self.baseURL = baseURL
        self.session = session
    }

    /// A session with sane timeouts so a stalled request can't wedge narration.
    /// The previous default (`.shared` + a 320s request timeout) could keep a
    /// single chunk pending for over five minutes, which is what made narration
    /// appear to hang.
    public static func makeDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 90    // no progress for 90s → fail
        config.timeoutIntervalForResource = 180  // whole request must finish in 180s
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }

    /// Call once during private development or secure provisioning. Never
    /// hard-code the bearer token in source or commit it to version control.
    public static func storeAPIKey(_ apiKey: String) throws {
        let data = Data(apiKey.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var insert = query
            attributes.forEach { insert[$0.key] = $0.value }
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus))
            }
        } else if updateStatus != errSecSuccess {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(updateStatus))
        }
    }

    public static func removeAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    public static func currentAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    public func health() async throws -> Bool {
        let healthURL = baseURL.deletingLastPathComponent().appendingPathComponent("health")
        let (_, response) = try await session.data(from: healthURL)
        guard let http = response as? HTTPURLResponse else {
            throw KokoroTTSError.invalidResponse
        }
        return http.statusCode == 200
    }

    /// Generates one completed Liam MP3 and atomically stores it at the URL
    /// controlled by the calling app. Existing audio at that URL is replaced
    /// only after the new download has completed and passed validation.
    @discardableResult
    public func synthesizeAndSave(
        text: String,
        to destinationURL: URL,
        speed: Double = 1.0
    ) async throws -> URL {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else {
            throw KokoroTTSError.emptyText
        }
        guard normalizedText.count <= Self.maximumCharactersPerRequest else {
            throw KokoroTTSError.textTooLong(maximumCharacters: Self.maximumCharactersPerRequest)
        }

        let temporaryDownload = try await downloadCompletedMP3(text: normalizedText, speed: speed)
        let fileManager = FileManager.default
        let parent = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)

        let stagingURL = parent.appendingPathComponent(
            ".\(destinationURL.lastPathComponent).\(UUID().uuidString).partial"
        )
        try? fileManager.removeItem(at: stagingURL)
        try fileManager.moveItem(at: temporaryDownload, to: stagingURL)

        if fileManager.fileExists(atPath: destinationURL.path) {
            _ = try fileManager.replaceItemAt(destinationURL, withItemAt: stagingURL)
        } else {
            try fileManager.moveItem(at: stagingURL, to: destinationURL)
        }
        return destinationURL
    }

    /// Convenience method that stores the completed MP3 under
    /// Documents/GeneratedAudio and returns its persistent file URL.
    @discardableResult
    public func synthesizeSummaryToDocuments(
        text: String,
        suggestedFileName: String,
        speed: Double = 1.0
    ) async throws -> URL {
        guard let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            throw KokoroTTSError.documentsDirectoryUnavailable
        }

        let folder = documents.appendingPathComponent("GeneratedAudio", isDirectory: true)
        let fileName = Self.safeMP3FileName(from: suggestedFileName)
        return try await synthesizeAndSave(
            text: text,
            to: folder.appendingPathComponent(fileName),
            speed: speed
        )
    }

    private func downloadCompletedMP3(text: String, speed: Double) async throws -> URL {
        let endpoint = baseURL.appendingPathComponent("audio/speech")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 90
        try authorize(&request)
        request.httpBody = try encoder.encode(
            KokoroSpeechRequest(
                model: "kokoro",
                input: text,
                voice: Self.voice,
                responseFormat: "mp3",
                speed: speed
            )
        )

        let (temporaryDownload, response) = try await session.download(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw KokoroTTSError.invalidResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            let data = (try? Data(contentsOf: temporaryDownload)) ?? Data()
            try validate(response: response, data: data)
            throw KokoroTTSError.invalidResponse
        }

        let values = try temporaryDownload.resourceValues(forKeys: [.fileSizeKey])
        guard (values.fileSize ?? 0) > 0 else {
            throw KokoroTTSError.invalidAudio
        }
        return temporaryDownload
    }

    private func authorize(_ request: inout URLRequest) throws {
        guard let apiKey = Self.currentAPIKey() else {
            throw KokoroTTSError.missingAPIKey
        }
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw KokoroTTSError.invalidResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            let message = (try? decoder.decode(KokoroErrorEnvelope.self, from: data).error.message)
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw KokoroTTSError.server(statusCode: http.statusCode, message: message)
        }
    }

    private static func safeMP3FileName(from suggestedName: String) -> String {
        let trimmed = suggestedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = trimmed.isEmpty ? "summary-\(UUID().uuidString)" : trimmed
        let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let components = source.components(separatedBy: forbidden)
        let cleaned = components.joined(separator: "-").prefix(120)
        let base = String(cleaned).trimmingCharacters(in: .whitespacesAndNewlines)
        if base.lowercased().hasSuffix(".mp3") {
            return base
        }
        return "\(base).mp3"
    }
}
