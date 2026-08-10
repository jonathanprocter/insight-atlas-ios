import Foundation

// MARK: - Credentials

struct ChatGPTVoiceCredentials: Equatable, Sendable {
    let accessToken: String
    let accountID: String
}

protocol ChatGPTVoiceCredentialProviding: Sendable {
    func validCredentials() async throws -> ChatGPTVoiceCredentials
}

struct ChatGPTOAuthVoiceCredentialProvider: ChatGPTVoiceCredentialProviding {
    func validCredentials() async throws -> ChatGPTVoiceCredentials {
        let accessToken = try await ChatGPTOAuthService.shared.validAccessToken()
        guard let accountID = ChatGPTOAuthService.storedAccountID,
              !accountID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ChatGPTVoiceServiceError.notSignedIn
        }
        return ChatGPTVoiceCredentials(accessToken: accessToken, accountID: accountID)
    }
}

// MARK: - Transport

protocol ChatGPTVoiceTransporting: Sendable {
    func connect(request: URLRequest) async throws
    func send(_ payload: Data) async throws
    func receive(maximumBytes: Int, timeout: TimeInterval) async throws -> String
    func close() async
}

enum ChatGPTVoiceTransportError: LocalizedError, Equatable {
    case notConnected
    case invalidTextPayload
    case invalidServerMessage
    case messageTooLarge
    case closedBeforeCompletion

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "ChatGPT Voice is not connected."
        case .invalidTextPayload:
            return "ChatGPT Voice could not send an invalid text payload."
        case .invalidServerMessage:
            return "ChatGPT Voice returned an invalid WebSocket message."
        case .messageTooLarge:
            return "ChatGPT Voice returned an oversized WebSocket message."
        case .closedBeforeCompletion:
            return "ChatGPT Voice closed before narration completed."
        }
    }
}

private final class ChatGPTVoiceURLSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        // Never forward an OAuth bearer token across a redirect.
        completionHandler(nil)
    }
}

actor URLSessionChatGPTVoiceTransport: ChatGPTVoiceTransporting {
    private let delegate: ChatGPTVoiceURLSessionDelegate
    private let session: URLSession
    private var task: URLSessionWebSocketTask?

    init() {
        let delegate = ChatGPTVoiceURLSessionDelegate()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.delegate = delegate
        self.session = URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: nil
        )
    }

    func connect(request: URLRequest) async throws {
        guard task == nil else { return }
        let webSocketTask = session.webSocketTask(with: request)
        task = webSocketTask
        webSocketTask.resume()
    }

    func send(_ payload: Data) async throws {
        guard let task else {
            throw ChatGPTVoiceTransportError.notConnected
        }
        guard let text = String(data: payload, encoding: .utf8) else {
            throw ChatGPTVoiceTransportError.invalidTextPayload
        }
        try await task.send(.string(text))
    }

    func receive(maximumBytes: Int, timeout: TimeInterval) async throws -> String {
        guard let task else {
            throw ChatGPTVoiceTransportError.notConnected
        }
        task.maximumMessageSize = maximumBytes

        return try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                let message = try await task.receive()
                let text: String
                switch message {
                case .string(let value):
                    text = value
                case .data(let data):
                    guard let value = String(data: data, encoding: .utf8) else {
                        throw ChatGPTVoiceTransportError.invalidServerMessage
                    }
                    text = value
                @unknown default:
                    throw ChatGPTVoiceTransportError.invalidServerMessage
                }

                guard text.lengthOfBytes(using: .utf8) <= maximumBytes else {
                    throw ChatGPTVoiceTransportError.messageTooLarge
                }
                return text
            }
            group.addTask {
                let nanoseconds = UInt64(max(timeout, 0.001) * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanoseconds)
                task.cancel(with: .goingAway, reason: nil)
                throw URLError(.timedOut)
            }

            guard let first = try await group.next() else {
                throw ChatGPTVoiceTransportError.closedBeforeCompletion
            }
            group.cancelAll()
            return first
        }
    }

    func close() async {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        session.invalidateAndCancel()
        _ = delegate
    }
}

// MARK: - Service

enum ChatGPTVoiceServiceError: LocalizedError, Equatable {
    case notSignedIn
    case authenticationFailed
    case providerRejected(String)
    case timeout
    case connectionClosed
    case emptyAudio
    case outputTooLarge
    case unsupportedVoice

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Sign in with ChatGPT before using ChatGPT Voice."
        case .authenticationFailed:
            return "ChatGPT Voice authentication failed. Sign in again and retry."
        case .providerRejected(let message):
            return "ChatGPT Voice rejected the narration request: \(message)"
        case .timeout:
            return "ChatGPT Voice timed out before narration completed."
        case .connectionClosed:
            return "ChatGPT Voice closed before narration completed."
        case .emptyAudio:
            return "ChatGPT Voice produced no playable audio."
        case .outputTooLarge:
            return "ChatGPT Voice exceeded the safe narration output limit."
        case .unsupportedVoice:
            return "The selected ChatGPT Voice is not supported."
        }
    }
}

final class ChatGPTVoiceService: AudioServiceProtocol, @unchecked Sendable {
    typealias TransportFactory = @Sendable () -> any ChatGPTVoiceTransporting
    typealias EncoderFactory = @Sendable () throws -> any ChatGPTVoiceAudioEncoding

    let provider: VoiceProvider = .chatgptVoice

    var isConfigured: Bool {
        ChatGPTOAuthService.hasStoredCredentials
    }

    private let credentialProvider: any ChatGPTVoiceCredentialProviding
    private let transportFactory: TransportFactory
    private let encoderFactory: EncoderFactory
    private let config: ChatGPTVoiceConfig

    init(
        credentialProvider: any ChatGPTVoiceCredentialProviding = ChatGPTOAuthVoiceCredentialProvider(),
        transportFactory: TransportFactory? = nil,
        encoderFactory: EncoderFactory? = nil,
        config: ChatGPTVoiceConfig = .default
    ) {
        self.credentialProvider = credentialProvider
        self.transportFactory = transportFactory ?? { URLSessionChatGPTVoiceTransport() }
        self.encoderFactory = encoderFactory ?? { try ChatGPTVoiceM4AEncoder() }
        self.config = config
    }

    func validateApiKey() async throws -> Bool {
        _ = try await credentialProvider.validCredentials()
        return true
    }

    func generateAudio(text: String, voiceID: String) async throws -> GeneratedAudio {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else {
            throw ChatGPTVoiceServiceError.emptyAudio
        }
        guard ChatGPTVoiceConfig.supportedVoiceIDs.contains(voiceID) else {
            throw ChatGPTVoiceServiceError.unsupportedVoice
        }

        let credentials: ChatGPTVoiceCredentials
        do {
            credentials = try await credentialProvider.validCredentials()
        } catch let error as ChatGPTVoiceServiceError {
            throw error
        } catch {
            throw ChatGPTVoiceServiceError.notSignedIn
        }

        let chunks = try ChatGPTVoiceTextChunker.chunks(
            normalizedText,
            maximumBytes: config.maximumTextChunkBytes
        )
        let request = try ChatGPTVoiceRequestBuilder.makeWebSocketRequest(
            token: credentials.accessToken,
            accountID: credentials.accountID,
            requestIDs: ChatGPTVoiceRequestIDs(),
            config: config
        )
        let sessionPayload = try ChatGPTVoiceRequestBuilder.sessionUpdatePayload(
            voiceID: voiceID,
            instructions: Self.narrationInstructions
        )

        let transport = transportFactory()
        let encoder = try encoderFactory()
        var completed = false

        do {
            try await transport.connect(request: request)
            try await transport.send(sessionPayload)
            try await waitForSessionStart(using: transport)

            var receivedAudioBytes = 0
            for chunk in chunks {
                let payload = try ChatGPTVoiceRequestBuilder.speakableContextPayload(text: chunk)
                try await transport.send(payload)
                receivedAudioBytes += try await receiveTurnAudio(
                    using: transport,
                    encoder: encoder,
                    currentAudioByteCount: receivedAudioBytes
                )
            }

            guard receivedAudioBytes > 0 else {
                throw ChatGPTVoiceServiceError.emptyAudio
            }
            let encoded = try await encoder.finish()
            guard !encoded.data.isEmpty, encoded.duration > 0 else {
                throw ChatGPTVoiceServiceError.emptyAudio
            }

            completed = true
            await transport.close()
            return GeneratedAudio(
                data: encoded.data,
                duration: encoded.duration,
                characterCount: normalizedText.count,
                voiceID: voiceID
            )
        } catch {
            if !completed {
                await encoder.cancel()
            }
            await transport.close()
            throw mapError(error)
        }
    }

    private func waitForSessionStart(
        using transport: any ChatGPTVoiceTransporting
    ) async throws {
        while true {
            let payload = try await transport.receive(
                maximumBytes: config.maximumEventBytes,
                timeout: config.sessionTimeout
            )
            let event = try ChatGPTVoiceEventParser.parse(payload)
            switch event {
            case .sessionStarted:
                return
            case .providerError(let message, let fatalAuthentication):
                throw fatalAuthentication
                    ? ChatGPTVoiceServiceError.authenticationFailed
                    : ChatGPTVoiceServiceError.providerRejected(message)
            case .audio, .transcriptDelta, .turnDone, .ignored:
                continue
            }
        }
    }

    private func receiveTurnAudio(
        using transport: any ChatGPTVoiceTransporting,
        encoder: any ChatGPTVoiceAudioEncoding,
        currentAudioByteCount: Int
    ) async throws -> Int {
        var audioByteCount = 0
        while true {
            let payload = try await transport.receive(
                maximumBytes: config.maximumEventBytes,
                timeout: config.turnTimeout
            )
            let event = try ChatGPTVoiceEventParser.parse(payload)
            switch event {
            case .audio(let pcm):
                try ChatGPTPCMValidator.validate(pcm)
                guard currentAudioByteCount + audioByteCount <= config.maximumOutputAudioBytes - pcm.count else {
                    throw ChatGPTVoiceServiceError.outputTooLarge
                }
                try await encoder.appendPCM(pcm)
                audioByteCount += pcm.count
            case .turnDone(let role, _):
                if role == .assistant {
                    return audioByteCount
                }
            case .providerError(let message, let fatalAuthentication):
                throw fatalAuthentication
                    ? ChatGPTVoiceServiceError.authenticationFailed
                    : ChatGPTVoiceServiceError.providerRejected(message)
            case .sessionStarted, .transcriptDelta, .ignored:
                continue
            }
        }
    }

    private func mapError(_ error: Error) -> Error {
        if let serviceError = error as? ChatGPTVoiceServiceError {
            return serviceError
        }
        if let urlError = error as? URLError, urlError.code == .timedOut {
            return ChatGPTVoiceServiceError.timeout
        }
        if let transportError = error as? ChatGPTVoiceTransportError,
           transportError == .closedBeforeCompletion {
            return ChatGPTVoiceServiceError.connectionClosed
        }
        return error
    }

    private static let narrationInstructions = """
    You are the narration engine for an educational reading app. Read each supplied passage aloud exactly as written. Preserve wording, order, names, numbers, headings, and punctuation cues. Do not summarize, answer, comment, add an introduction, or add a conclusion. Use a calm, polished audiobook cadence and continue speaking until the complete passage is finished.
    """
}
