import XCTest
@testable import InsightAtlas

final class ChatGPTVoiceProtocolTests: XCTestCase {

    func testDefaultConfigurationUsesOpenAIGPTLiveEndpoint() throws {
        let config = ChatGPTVoiceConfig.default

        XCTAssertEqual(config.endpoint.scheme, "wss")
        XCTAssertEqual(config.endpoint.host, "api.openai.com")
        XCTAssertEqual(config.endpoint.path, "/v1/live")
        XCTAssertEqual(config.model, "gpt-live-1-codex")
        XCTAssertEqual(config.defaultVoiceID, "marin")
    }

    func testWebSocketRequestIncludesOAuthAndAccountHeaders() throws {
        let ids = ChatGPTVoiceRequestIDs(
            realtimeSessionID: "realtime-1",
            sessionID: "session-1",
            threadID: "thread-1"
        )

        let request = try ChatGPTVoiceRequestBuilder.makeWebSocketRequest(
            token: "secret-token",
            accountID: "acct_123",
            requestIDs: ids,
            config: .default
        )

        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "chatgpt-account-id"), "acct_123")
        XCTAssertEqual(request.value(forHTTPHeaderField: "OpenAI-Alpha"), "quicksilver=v2")
        XCTAssertEqual(request.value(forHTTPHeaderField: "session-id"), "session-1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "thread-id"), "thread-1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-session-id"), "realtime-1")
        XCTAssertEqual(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "model" })?.value, "gpt-live-1-codex")
    }

    func testRequestBuilderRejectsNonOpenAIEndpoint() {
        let config = ChatGPTVoiceConfig(
            endpoint: URL(string: "wss://example.com/v1/live")!,
            model: "gpt-live-1-codex",
            defaultVoiceID: "marin",
            maximumTextChunkBytes: 500,
            maximumEventBytes: 1_000_000,
            sessionTimeout: 30,
            turnTimeout: 30
        )

        XCTAssertThrowsError(
            try ChatGPTVoiceRequestBuilder.makeWebSocketRequest(
                token: "token",
                accountID: "acct",
                requestIDs: .init(),
                config: config
            )
        )
    }

    func testSessionUpdatePayloadUsesSelectedVoiceAndNarrationInstructions() throws {
        let data = try ChatGPTVoiceRequestBuilder.sessionUpdatePayload(
            voiceID: "cedar",
            instructions: "Read exactly as written."
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let session = try XCTUnwrap(json["session"] as? [String: Any])
        let audio = try XCTUnwrap(session["audio"] as? [String: Any])
        let output = try XCTUnwrap(audio["output"] as? [String: Any])

        XCTAssertEqual(json["type"] as? String, "session.update")
        XCTAssertEqual(session["instructions"] as? String, "Read exactly as written.")
        XCTAssertEqual(output["voice"] as? String, "cedar")
    }

    func testSpeakableContextPayloadContainsInputText() throws {
        let data = try ChatGPTVoiceRequestBuilder.speakableContextPayload(text: "Narrate this sentence.")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let content = try XCTUnwrap(json["content"] as? [[String: Any]])

        XCTAssertEqual(json["type"] as? String, "session.context.append")
        XCTAssertEqual(json["channel"] as? String, "speakable")
        XCTAssertEqual(content.first?["type"] as? String, "input_text")
        XCTAssertEqual(content.first?["text"] as? String, "Narrate this sentence.")
    }

    func testTextChunkerEnforcesUTF8ByteLimitAndPreservesText() throws {
        let text = "First sentence. Second sentence with café. 第三句话。"
        let chunks = try ChatGPTVoiceTextChunker.chunks(text, maximumBytes: 24)

        XCTAssertGreaterThan(chunks.count, 1)
        XCTAssertTrue(chunks.allSatisfy { $0.lengthOfBytes(using: .utf8) <= 24 })
        XCTAssertEqual(chunks.joined(separator: " ").replacingOccurrences(of: "  ", with: " "), text)
    }

    func testEventParserDecodesAudioDelta() throws {
        let expected = Data([0x00, 0x01, 0x02, 0x03])
        let payloadData = try JSONSerialization.data(withJSONObject: [
            "type": "output_audio.delta",
            "audio": expected.base64EncodedString()
        ])
        let payload = try XCTUnwrap(String(data: payloadData, encoding: .utf8))

        let event = try ChatGPTVoiceEventParser.parse(payload)

        XCTAssertEqual(event, .audio(expected))
    }

    func testEventParserDecodesAssistantTurnCompletion() throws {
        let payload = """
        {"type":"turn.done","turn":{"role":"assistant","transcript":"Finished narration."}}
        """

        XCTAssertEqual(
            try ChatGPTVoiceEventParser.parse(payload),
            .turnDone(role: .assistant, transcript: "Finished narration.")
        )
    }

    func testEventParserClassifiesAuthenticationErrors() throws {
        let payload = """
        {"type":"error","status":401,"error":{"code":"invalid_token","message":"Expired"}}
        """

        XCTAssertEqual(
            try ChatGPTVoiceEventParser.parse(payload),
            .providerError(message: "Expired", fatalAuthentication: true)
        )
    }

    func testEventParserBoundsProviderErrorMessages() throws {
        let untrustedMessage = String(repeating: "x", count: 5_000)
        let payloadData = try JSONSerialization.data(withJSONObject: [
            "type": "error",
            "error": ["code": "provider_error", "message": untrustedMessage]
        ])
        let payload = try XCTUnwrap(String(data: payloadData, encoding: .utf8))

        guard case .providerError(let message, _) = try ChatGPTVoiceEventParser.parse(payload) else {
            return XCTFail("Expected provider error")
        }
        XCTAssertLessThanOrEqual(message.count, 500)
    }

    func testEventParserRejectsMalformedJSONAndBase64() {
        XCTAssertThrowsError(try ChatGPTVoiceEventParser.parse("not-json"))
        XCTAssertThrowsError(try ChatGPTVoiceEventParser.parse("{\"type\":\"output_audio.delta\",\"audio\":\"***\"}"))
    }

    func testPCMValidatorRequiresCompleteSixteenBitFrames() throws {
        XCTAssertNoThrow(try ChatGPTPCMValidator.validate(Data([0x00, 0x01, 0x02, 0x03])))
        XCTAssertThrowsError(try ChatGPTPCMValidator.validate(Data([0x00])))
        XCTAssertThrowsError(try ChatGPTPCMValidator.validate(Data()))
    }
}
