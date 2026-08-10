import XCTest
@testable import InsightAtlas

final class ChatGPTVoiceServiceTests: XCTestCase {

    func testServiceUsesOAuthHeadersAndReturnsEncodedAudioMetadata() async throws {
        let pcm = Data([0x00, 0x01, 0x02, 0x03])
        let transport = RecordingChatGPTVoiceTransport(inbound: [
            .text("{\"type\":\"session.started\"}"),
            .text(try audioDeltaPayload(pcm)),
            .text("{\"type\":\"turn.done\",\"turn\":{\"role\":\"assistant\",\"transcript\":\"Narrated.\"}}")
        ])
        let encoded = Data([0x4d, 0x34, 0x41])
        let encoder = RecordingChatGPTVoiceEncoder(result: .init(data: encoded, duration: 1.25))
        let service = makeService(transport: transport, encoder: encoder)

        let result = try await service.generateAudio(text: "Narrate this.", voiceID: "marin")

        XCTAssertEqual(result.data, encoded)
        XCTAssertEqual(result.duration, 1.25, accuracy: 0.001)
        XCTAssertEqual(result.characterCount, 13)
        XCTAssertEqual(result.voiceID, "marin")

        let snapshot = await transport.snapshot()
        XCTAssertEqual(snapshot.request?.value(forHTTPHeaderField: "Authorization"), "Bearer oauth-token")
        XCTAssertEqual(snapshot.request?.value(forHTTPHeaderField: "chatgpt-account-id"), "acct_123")
        XCTAssertTrue(snapshot.closed)
        let appendedPCM = await encoder.appendedPCM()
        XCTAssertEqual(appendedPCM, [pcm])
    }

    func testServiceSendsSessionUpdateBeforeSequentialSpeakableChunks() async throws {
        let pcm1 = Data([0x00, 0x01])
        let pcm2 = Data([0x02, 0x03])
        let transport = RecordingChatGPTVoiceTransport(inbound: [
            .text("{\"type\":\"session.started\"}"),
            .text(try audioDeltaPayload(pcm1)),
            .text("{\"type\":\"turn.done\",\"turn\":{\"role\":\"assistant\",\"transcript\":\"First.\"}}"),
            .text(try audioDeltaPayload(pcm2)),
            .text("{\"type\":\"turn.done\",\"turn\":{\"role\":\"assistant\",\"transcript\":\"Second.\"}}")
        ])
        let encoder = RecordingChatGPTVoiceEncoder(result: .init(data: Data([1]), duration: 0.5))
        let config = ChatGPTVoiceConfig(
            endpoint: URL(string: "wss://api.openai.com/v1/live")!,
            model: "gpt-live-1-codex",
            defaultVoiceID: "marin",
            maximumTextChunkBytes: 18,
            maximumEventBytes: 1_000_000,
            sessionTimeout: 30,
            turnTimeout: 30
        )
        let service = makeService(transport: transport, encoder: encoder, config: config)

        _ = try await service.generateAudio(
            text: "First sentence. Second sentence.",
            voiceID: "cedar"
        )

        let messages = await transport.snapshot().sentPayloads
        XCTAssertEqual(messages.count, 3)
        XCTAssertEqual(try payloadType(messages[0]), "session.update")
        XCTAssertEqual(try payloadType(messages[1]), "session.context.append")
        XCTAssertEqual(try payloadType(messages[2]), "session.context.append")
        XCTAssertEqual(try contextText(messages[1]), "First sentence.")
        XCTAssertEqual(try contextText(messages[2]), "Second sentence.")
        let appendedPCM = await encoder.appendedPCM()
        XCTAssertEqual(appendedPCM, [pcm1, pcm2])
    }

    func testServiceRejectsEmptyAudioAndClosesResources() async throws {
        let transport = RecordingChatGPTVoiceTransport(inbound: [
            .text("{\"type\":\"session.started\"}"),
            .text("{\"type\":\"turn.done\",\"turn\":{\"role\":\"assistant\",\"transcript\":\"No audio.\"}}")
        ])
        let encoder = RecordingChatGPTVoiceEncoder(result: .init(data: Data(), duration: 0))
        let service = makeService(transport: transport, encoder: encoder)

        do {
            _ = try await service.generateAudio(text: "Narrate this.", voiceID: "marin")
            XCTFail("Expected empty audio to fail")
        } catch let error as ChatGPTVoiceServiceError {
            XCTAssertEqual(error, .emptyAudio)
        }

        let transportSnapshot = await transport.snapshot()
        let encoderCancelled = await encoder.wasCancelled()
        XCTAssertTrue(transportSnapshot.closed)
        XCTAssertTrue(encoderCancelled)
    }

    func testServiceMapsProviderAuthenticationErrorAndClosesResources() async throws {
        let transport = RecordingChatGPTVoiceTransport(inbound: [
            .text("{\"type\":\"session.started\"}"),
            .text("{\"type\":\"error\",\"status\":401,\"error\":{\"code\":\"invalid_token\",\"message\":\"Expired\"}}")
        ])
        let encoder = RecordingChatGPTVoiceEncoder(result: .init(data: Data([1]), duration: 1))
        let service = makeService(transport: transport, encoder: encoder)

        do {
            _ = try await service.generateAudio(text: "Narrate this.", voiceID: "marin")
            XCTFail("Expected authentication failure")
        } catch let error as ChatGPTVoiceServiceError {
            XCTAssertEqual(error, .authenticationFailed)
        }

        let transportSnapshot = await transport.snapshot()
        let encoderCancelled = await encoder.wasCancelled()
        XCTAssertTrue(transportSnapshot.closed)
        XCTAssertTrue(encoderCancelled)
    }

    func testServiceRejectsMalformedPCM() async throws {
        let malformedPCM = Data([0x00])
        let transport = RecordingChatGPTVoiceTransport(inbound: [
            .text("{\"type\":\"session.started\"}"),
            .text(try audioDeltaPayload(malformedPCM))
        ])
        let encoder = RecordingChatGPTVoiceEncoder(result: .init(data: Data([1]), duration: 1))
        let service = makeService(transport: transport, encoder: encoder)

        do {
            _ = try await service.generateAudio(text: "Narrate this.", voiceID: "marin")
            XCTFail("Expected malformed PCM failure")
        } catch let error as ChatGPTVoiceProtocolError {
            XCTAssertEqual(error, .invalidPCMFrameAlignment)
        }
    }

    func testServiceMapsTransportTimeout() async throws {
        let transport = RecordingChatGPTVoiceTransport(inbound: [
            .failure(URLError(.timedOut))
        ])
        let encoder = RecordingChatGPTVoiceEncoder(result: .init(data: Data([1]), duration: 1))
        let service = makeService(transport: transport, encoder: encoder)

        do {
            _ = try await service.generateAudio(text: "Narrate this.", voiceID: "marin")
            XCTFail("Expected timeout")
        } catch let error as ChatGPTVoiceServiceError {
            XCTAssertEqual(error, .timeout)
        }

        let transportSnapshot = await transport.snapshot()
        XCTAssertTrue(transportSnapshot.closed)
    }

    private func audioDeltaPayload(_ data: Data) throws -> String {
        let payload = try JSONSerialization.data(withJSONObject: [
            "type": "output_audio.delta",
            "audio": data.base64EncodedString()
        ])
        return try XCTUnwrap(String(data: payload, encoding: .utf8))
    }

    private func makeService(
        transport: RecordingChatGPTVoiceTransport,
        encoder: RecordingChatGPTVoiceEncoder,
        config: ChatGPTVoiceConfig = .default
    ) -> ChatGPTVoiceService {
        ChatGPTVoiceService(
            credentialProvider: StubChatGPTVoiceCredentialProvider(
                credentials: .init(accessToken: "oauth-token", accountID: "acct_123")
            ),
            transportFactory: { transport },
            encoderFactory: { encoder },
            config: config
        )
    }

    private func payloadType(_ data: Data) throws -> String? {
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return json["type"] as? String
    }

    private func contextText(_ data: Data) throws -> String? {
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let content = try XCTUnwrap(json["content"] as? [[String: Any]])
        return content.first?["text"] as? String
    }
}

private struct StubChatGPTVoiceCredentialProvider: ChatGPTVoiceCredentialProviding {
    let credentials: ChatGPTVoiceCredentials

    func validCredentials() async throws -> ChatGPTVoiceCredentials {
        credentials
    }
}

private actor RecordingChatGPTVoiceTransport: ChatGPTVoiceTransporting {
    enum Inbound {
        case text(String)
        case failure(Error)
    }

    struct Snapshot {
        let request: URLRequest?
        let sentPayloads: [Data]
        let closed: Bool
    }

    private var inbound: [Inbound]
    private var request: URLRequest?
    private var sentPayloads: [Data] = []
    private var closed = false

    init(inbound: [Inbound]) {
        self.inbound = inbound
    }

    func connect(request: URLRequest) async throws {
        self.request = request
    }

    func send(_ payload: Data) async throws {
        sentPayloads.append(payload)
    }

    func receive(maximumBytes: Int, timeout: TimeInterval) async throws -> String {
        guard !inbound.isEmpty else {
            throw ChatGPTVoiceTransportError.closedBeforeCompletion
        }
        switch inbound.removeFirst() {
        case .text(let text):
            guard text.lengthOfBytes(using: .utf8) <= maximumBytes else {
                throw ChatGPTVoiceTransportError.messageTooLarge
            }
            return text
        case .failure(let error):
            throw error
        }
    }

    func close() async {
        closed = true
    }

    func snapshot() -> Snapshot {
        Snapshot(request: request, sentPayloads: sentPayloads, closed: closed)
    }
}

private actor RecordingChatGPTVoiceEncoder: ChatGPTVoiceAudioEncoding {
    private let result: ChatGPTEncodedAudio
    private var pcm: [Data] = []
    private var cancelled = false

    init(result: ChatGPTEncodedAudio) {
        self.result = result
    }

    func appendPCM(_ data: Data) async throws {
        pcm.append(data)
    }

    func finish() async throws -> ChatGPTEncodedAudio {
        result
    }

    func cancel() async {
        cancelled = true
    }

    func appendedPCM() -> [Data] {
        pcm
    }

    func wasCancelled() -> Bool {
        cancelled
    }
}
