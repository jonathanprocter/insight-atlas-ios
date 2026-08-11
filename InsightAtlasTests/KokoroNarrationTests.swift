//
//  KokoroNarrationTests.swift
//  InsightAtlasTests
//
//  Focused tests for the narration fallback pipeline and Liam integration:
//  - Deterministic long-text splitting (never truncates, respects the ceiling).
//  - NarrationState persistence and backward compatibility on LibraryItem.
//  - Missing-token behavior (no crash, precise error).
//  - Duplicate-job prevention, exercised via an injected URLProtocol mock.
//

import XCTest
@testable import InsightAtlas

final class KokoroNarrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Ensure a clean, tokenless state for narration tests.
        try? KokoroTTSClient.removeAPIKey()
        MockNarrationURLProtocol.reset()
    }

    override func tearDown() {
        try? KokoroTTSClient.removeAPIKey()
        MockNarrationURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - Text Splitting

    func testShortTextProducesSingleChunk() {
        let text = "This is a short summary that fits comfortably in one request."
        let chunks = KokoroNarrationService.splitText(text, maxCharacters: 4500)
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks.first, text)
    }

    func testEmptyTextProducesNoChunks() {
        XCTAssertTrue(KokoroNarrationService.splitText("   \n\n  ", maxCharacters: 4500).isEmpty)
    }

    func testLongTextSplitsWithoutExceedingLimit() {
        // Build ~12,000 characters across many paragraphs and sentences.
        let paragraph = (1...20)
            .map { "Sentence number \($0) explores an idea in a fair amount of detail." }
            .joined(separator: " ")
        let text = Array(repeating: paragraph, count: 12).joined(separator: "\n\n")
        XCTAssertGreaterThan(text.count, 5000)

        let max = 4500
        let chunks = KokoroNarrationService.splitText(text, maxCharacters: max)

        XCTAssertGreaterThan(chunks.count, 1)
        for chunk in chunks {
            XCTAssertLessThanOrEqual(chunk.count, max, "Chunk exceeded the request ceiling")
            XCTAssertFalse(chunk.isEmpty)
        }
    }

    func testLongTextPreservesAllWords() {
        let paragraph = (1...15)
            .map { "Word\($0) alpha bravo charlie delta echo foxtrot." }
            .joined(separator: " ")
        let text = Array(repeating: paragraph, count: 10).joined(separator: "\n\n")

        let chunks = KokoroNarrationService.splitText(text, maxCharacters: 4500)

        // No text loss: every whitespace-delimited token from the source must
        // appear across the reassembled chunks.
        let sourceTokens = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let joinedTokens = Set(chunks.joined(separator: " ").split(whereSeparator: { $0.isWhitespace }).map(String.init))
        for token in sourceTokens {
            XCTAssertTrue(joinedTokens.contains(token), "Missing token after split: \(token)")
        }
    }

    func testOversizedSingleWordIsHardSliced() {
        let giant = String(repeating: "x", count: 10_000)
        let chunks = KokoroNarrationService.splitText(giant, maxCharacters: 4500)
        XCTAssertGreaterThan(chunks.count, 1)
        for chunk in chunks {
            XCTAssertLessThanOrEqual(chunk.count, 4500)
        }
        XCTAssertEqual(chunks.joined().count, giant.count)
    }

    // MARK: - NarrationState on LibraryItem

    func testNarrationStateRoundTrips() throws {
        var item = LibraryItem(title: "T", author: "A", fileType: .pdf)
        item.narrationState = .generating

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(LibraryItem.self, from: data)

        XCTAssertEqual(decoded.narrationState, .generating)
        XCTAssertEqual(decoded.effectiveNarrationState, .generating)
    }

    func testLegacyItemWithoutStateDerivesReadyWhenAudioPresent() throws {
        // narrationState nil (as legacy items were saved), but audio exists.
        var item = LibraryItem(title: "T", author: "A", fileType: .pdf)
        item.audioFileURL = "audio_abc.mp3"
        item.audioDuration = 42
        item.narrationState = nil

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(LibraryItem.self, from: data)

        XCTAssertNil(decoded.narrationState)
        XCTAssertEqual(decoded.effectiveNarrationState, .ready)
    }

    func testLegacyItemWithoutStateDerivesNotGeneratedWhenNoAudio() {
        let item = LibraryItem(title: "T", author: "A", fileType: .pdf)
        XCTAssertNil(item.narrationState)
        XCTAssertEqual(item.effectiveNarrationState, .notGenerated)
    }

    // MARK: - Token handling

    func testMissingTokenIsReportedAndDoesNotCrash() async {
        XCTAssertNil(KokoroTTSClient.currentAPIKey())
        let service = KokoroNarrationService()
        XCTAssertFalse(service.isTokenConfigured)

        do {
            _ = try await service.synthesizeAsset(text: "Hello there, this is a test.", itemId: UUID())
            XCTFail("Expected missingToken error")
        } catch let error as NarrationServiceError {
            switch error {
            case .missingToken:
                break // expected
            default:
                XCTFail("Expected .missingToken, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testTokenStoreAndRemoveRoundTrip() throws {
        XCTAssertNil(KokoroTTSClient.currentAPIKey())
        try KokoroTTSClient.storeAPIKey("test-token-value")
        XCTAssertEqual(KokoroTTSClient.currentAPIKey(), "test-token-value")
        try KokoroTTSClient.removeAPIKey()
        XCTAssertNil(KokoroTTSClient.currentAPIKey())
    }

    // MARK: - Stable provider fallback policy

    func testNarrationFallbackPolicyUsesMegaThenOpenAIThenLiam() {
        XCTAssertEqual(
            NarrationFallbackPolicy.orderedRoutes(
                megaTranscriptConfigured: true,
                openAIConfigured: true,
                liamConfigured: true
            ),
            [.megaTranscript, .openAI, .liam]
        )
    }

    func testNarrationFallbackPolicySkipsOnlyUnconfiguredProvidersWithoutReordering() {
        XCTAssertEqual(
            NarrationFallbackPolicy.orderedRoutes(
                megaTranscriptConfigured: false,
                openAIConfigured: true,
                liamConfigured: true
            ),
            [.openAI, .liam]
        )
        XCTAssertEqual(
            NarrationFallbackPolicy.orderedRoutes(
                megaTranscriptConfigured: true,
                openAIConfigured: false,
                liamConfigured: true
            ),
            [.megaTranscript, .liam]
        )
        XCTAssertEqual(
            NarrationFallbackPolicy.orderedRoutes(
                megaTranscriptConfigured: false,
                openAIConfigured: false,
                liamConfigured: true
            ),
            [.liam]
        )
    }

    func testOpenAITTSRequestUsesSupportedSpeechSchema() throws {
        let request = OpenAITTSRequest(text: "Read this exactly.", voiceID: "onyx")
        let data = try JSONEncoder().encode(request)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["model"] as? String, "gpt-4o-mini-tts")
        XCTAssertEqual(json["input"] as? String, "Read this exactly.")
        XCTAssertEqual(json["voice"] as? String, "onyx")
        XCTAssertEqual(json["response_format"] as? String, "mp3")
        XCTAssertEqual(json["speed"] as? Double, 1.0)
        XCTAssertFalse((json["instructions"] as? String)?.isEmpty ?? true)
        XCTAssertNil(json["chatgpt-account-id"])
    }

    // MARK: - Duplicate-job prevention

    func testDuplicateConcurrentJobsAreRejected() async throws {
        try KokoroTTSClient.storeAPIKey("test-token-value")
        defer { try? KokoroTTSClient.removeAPIKey() }

        // A session whose requests hang until we release them, so the first job
        // is guaranteed to still be in flight when the second one is issued.
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockNarrationURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = KokoroTTSClient(session: session)
        let service = KokoroNarrationService(client: client)

        let requestStarted = expectation(description: "first request started")
        MockNarrationURLProtocol.onRequestStarted = { requestStarted.fulfill() }

        let itemId = UUID()
        let text = "This is a sufficiently long sentence to narrate for the test."

        let first = Task { try await service.synthesizeAsset(text: text, itemId: itemId) }

        await fulfillment(of: [requestStarted], timeout: 5)

        // Second concurrent call for the same item must be rejected as duplicate.
        do {
            _ = try await service.synthesizeAsset(text: text, itemId: itemId)
            XCTFail("Expected alreadyInProgress for duplicate job")
        } catch NarrationServiceError.alreadyInProgress {
            // expected
        } catch {
            XCTFail("Expected .alreadyInProgress, got \(error)")
        }

        // Release the first request and let it unwind (it will fail on the 401,
        // which is fine — we only care that the duplicate was blocked).
        MockNarrationURLProtocol.release()
        _ = try? await first.value
    }
}

// MARK: - Mock URLProtocol

/// Deterministic URLProtocol that signals when a request begins and holds it
/// open until explicitly released, then returns HTTP 401. Used to keep a
/// narration job "in flight" while a duplicate is attempted.
final class MockNarrationURLProtocol: URLProtocol {
    static var onRequestStarted: (() -> Void)?
    private static var gate = DispatchSemaphore(value: 0)

    static func reset() {
        onRequestStarted = nil
        gate = DispatchSemaphore(value: 0)
    }

    static func release() {
        gate.signal()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        Self.onRequestStarted?()
        // Hold the request open on a background queue until released.
        DispatchQueue.global().async {
            _ = Self.gate.wait(timeout: .now() + 10)
            let response = HTTPURLResponse(
                url: self.request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: Data("{\"error\":{\"message\":\"unauthorized\"}}".utf8))
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }
}
