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
import AVFoundation
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

    // MARK: - Spoken-text hygiene

    func testSanitizerHandlesLongUnbalancedMarkupInBoundedTime() {
        let source = String(repeating: "ordinary_word * value _ ", count: 5_000)
            + String(repeating: "**unfinished ~~revised `code ", count: 1_000)
        let started = CFAbsoluteTimeGetCurrent()

        let spoken = NarrationTextSanitizer.prepare(source)

        let elapsed = CFAbsoluteTimeGetCurrent() - started
        XCTAssertLessThan(elapsed, 2.0, "sanitizer took too long on adversarial unbalanced input")
        XCTAssertTrue(spoken.contains("ordinary_word"))
        XCTAssertTrue(spoken.contains("unfinished"))
        XCTAssertFalse(spoken.contains("**"))
        XCTAssertFalse(spoken.contains("~~"))
        XCTAssertFalse(spoken.contains("`"))
    }

    func testUnbalancedRepeatedDelimitersAreRemovedWithoutLosingWords() {
        let spoken = NarrationTextSanitizer.prepare(
            "An **unfinished emphasis, a ~~revised phrase, and `noticing remain readable."
        )

        XCTAssertTrue(spoken.contains("unfinished emphasis"))
        XCTAssertTrue(spoken.contains("revised phrase"))
        XCTAssertTrue(spoken.contains("noticing"))
        XCTAssertFalse(spoken.contains("**"))
        XCTAssertFalse(spoken.contains("~~"))
        XCTAssertFalse(spoken.contains("`"))
    }

    func testNarrationSanitizerRemovesPresentationSyntaxWithoutLosingMeaning() {
        let source = """
        # **Practice**
        > Read [acceptance](https://example.com) and ![cover](cover.png).
        1. Try `noticing` instead of ~~control~~.
        [INSIGHT_NOTE]Stay present.[/INSIGHT_NOTE]
        | Process | Response |
        |---|---|
        | Fusion | Defusion |
        """

        let spoken = NarrationTextSanitizer.prepare(source)

        for expected in ["Practice", "acceptance", "cover", "noticing", "control", "Stay present", "Fusion", "Defusion"] {
            XCTAssertTrue(spoken.contains(expected), "lost semantic narration text: \(expected)")
        }
        for syntax in ["#", "**", "[", "]", "(", ")", "`", "~~", "|---|", "| Process |"] {
            XCTAssertFalse(spoken.contains(syntax), "narration retained presentation syntax: \(syntax)")
        }
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

    func testNarrationFallbackPolicyUsesOnlyInstalledOnDeviceKokoro() {
        XCTAssertEqual(
            NarrationFallbackPolicy.orderedRoutes(
                kokoroConfigured: true
            ),
            [.kokoro]
        )
    }

    func testNarrationFallbackPolicyNeverRoutesToUnavailableHostedLiam() {
        XCTAssertTrue(
            NarrationFallbackPolicy.orderedRoutes(
                kokoroConfigured: false
            ).isEmpty
        )
        XCTAssertEqual(
            NarrationFallbackPolicy.orderedRoutes(
                kokoroConfigured: true
            ),
            [.kokoro]
        )
        XCTAssertTrue(
            NarrationFallbackPolicy.orderedRoutes(
                kokoroConfigured: false
            ).isEmpty
        )
    }

    func testMiniMaxM3IsAWrittenGuideProviderNotAnAudioSynthesizer() {
        XCTAssertFalse(AIProvider.minimax.supportsDirectAudioGeneration)
    }

    func testFirstNarrationDoesNotWaitForOptionalLLMRewrite() {
        XCTAssertFalse(NarrationPreparationPolicy.rewritesBeforeInitialSynthesis)
    }

    func testProfessionalListeningEditionHasPracticalSpokenWordBudget() {
        XCTAssertEqual(
            NarrationListeningEdition.maximumWords(for: .professional),
            2_400
        )
    }

    func testListeningEditionIsBoundedSyntaxFreeAndCoversTheWholeGuide() {
        let paragraphs = (0..<12).map { index in
            let marker = index == 0 ? "OpeningAnchor" : (index == 11 ? "ClosingAnchor" : "Section\(index)")
            return "[PREMIUM_H2]\(marker)[/PREMIUM_H2]\n" +
                Array(repeating: "Meaningful sentence \(index) supports reflective application.", count: 10)
                    .joined(separator: " ")
        }
        let guide = paragraphs.joined(separator: "\n\n")

        let edition = NarrationListeningEdition.prepare(
            guide,
            summaryType: .professional,
            maximumWordsOverride: 120
        )

        XCTAssertLessThanOrEqual(edition.split(whereSeparator: { $0.isWhitespace }).count, 120)
        XCTAssertTrue(edition.contains("OpeningAnchor"))
        XCTAssertTrue(edition.contains("ClosingAnchor"))
        XCTAssertFalse(edition.contains("[PREMIUM_H2]"))
        XCTAssertFalse(edition.contains("**"))
    }

    func testListeningEditionStopsSampledSectionsOnSentenceBoundaries() {
        let guide = [
            "Opening context establishes the premise. A second sentence expands the premise with detail.",
            "Middle context develops the argument. Another complete sentence adds an important qualification.",
            "Closing context integrates the lesson. The final sentence names a practical next step."
        ].joined(separator: "\n\n")

        let edition = NarrationListeningEdition.prepare(
            guide,
            summaryType: .professional,
            maximumWordsOverride: 14
        )

        for paragraph in edition.components(separatedBy: "\n\n") {
            XCTAssertTrue(paragraph.hasSuffix("."), "Narration must not end mid-sentence: \(paragraph)")
        }
    }

    func testPlaybackSessionPolicyAvoidsDeviceInvalidBluetoothOption() {
        XCTAssertEqual(NarrationPlaybackPolicy.mode, .default)
        XCTAssertFalse(NarrationPlaybackPolicy.options.contains(.allowBluetoothHFP))
        XCTAssertFalse(NarrationPlaybackPolicy.options.contains(.allowBluetoothA2DP))
    }

    func testUnsupportedAudioContainerCannotBePromoted() {
        XCTAssertFalse(NarrationAudioValidation.hasSupportedContainer(Data("not audio".utf8)))
        XCTAssertFalse(NarrationAudioValidation.hasSupportedContainer(Data()))
        XCTAssertTrue(NarrationAudioValidation.hasSupportedContainer(Data("RIFFvalid".utf8)))
    }

    func testDeceptiveRiffHeaderFailsStagedPlayabilityValidation() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("invalid-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("RIFFnot-a-wave".utf8).write(to: url)

        do {
            _ = try await NarrationAudioValidation.validatedDuration(
                at: url,
                declaredDuration: 1
            )
            XCTFail("header-only bytes must not be promoted as playable narration")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    func testPlayableStagedWavePassesValidation() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("valid-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let format = try XCTUnwrap(AVAudioFormat(
            standardFormatWithSampleRate: 22_050,
            channels: 1
        ))
        var file: AVAudioFile? = try AVAudioFile(forWriting: url, settings: format.settings)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: 2_205
        ))
        buffer.frameLength = 2_205
        try file?.write(from: buffer)
        file = nil

        let duration = try await NarrationAudioValidation.validatedDuration(
            at: url,
            declaredDuration: 0.1
        )
        XCTAssertGreaterThan(duration, 0)
    }

    func testRawOSStatusFailureMapsToActionableRegenerationMessage() {
        let message = NarrationPlaybackFailureMessage.message(
            for: NSError(domain: NSOSStatusErrorDomain, code: -50)
        )
        XCTAssertFalse(message.contains("OSStatus"))
        XCTAssertFalse(message.contains("-50"))
        XCTAssertTrue(message.localizedCaseInsensitiveContains("regenerate"))
    }

    // MARK: - Synthesis progress

    func testSynthesizingProgressReportsWholePercentages() {
        XCTAssertEqual(
            NarrationPreparationProgress.synthesizing(narrator: "Kokoro", completed: 0, total: 10).percentComplete, 0
        )
        XCTAssertEqual(
            NarrationPreparationProgress.synthesizing(narrator: "Kokoro", completed: 5, total: 10).percentComplete, 50
        )
        XCTAssertEqual(
            NarrationPreparationProgress.synthesizing(narrator: "Kokoro", completed: 10, total: 10).percentComplete, 100
        )
        XCTAssertEqual(NarrationPreparationProgress.ready(narrator: "Kokoro").percentComplete, 100)
    }

    func testSynthesizingProgressHandlesDegenerateTotals() {
        XCTAssertEqual(
            NarrationPreparationProgress.synthesizing(narrator: "Kokoro", completed: 3, total: 0).percentComplete, 0
        )
        XCTAssertEqual(
            NarrationPreparationProgress.synthesizing(narrator: "Kokoro", completed: 99, total: 10).percentComplete, 100
        )
    }

    /// A long guide rounds to 0% for the first several chunks, which reads as a
    /// stall. The chunk counter is what shows the work is moving.
    func testChunkCountIsReportedEvenWhenPercentageHasNotMoved() {
        let early = NarrationPreparationProgress.synthesizing(narrator: "Kokoro", completed: 1, total: 400)
        XCTAssertEqual(early.percentComplete, 0)
        XCTAssertEqual(early.chunkProgressDescription, "1 of 400")
    }

    func testNonSynthesisStagesHaveNoChunkCount() {
        XCTAssertNil(NarrationPreparationProgress.loadingModel(narrator: "Kokoro").chunkProgressDescription)
        XCTAssertNil(NarrationPreparationProgress.checkingCache.chunkProgressDescription)
    }

    /// A cold model load is slow and silent; it must be distinguishable from a
    /// stalled first chunk.
    func testModelLoadingIsItsOwnStage() {
        let stage = NarrationPreparationProgress.loadingModel(narrator: "Kokoro · Heart")
        XCTAssertNil(stage.percentComplete)
        XCTAssertEqual(stage.statusDescription, "Loading the Kokoro · Heart voice model…")
    }

    func testIndeterminateStagesHaveNoPercentage() {
        XCTAssertNil(NarrationPreparationProgress.checkingCache.percentComplete)
        XCTAssertNil(NarrationPreparationProgress.generating(narrator: "Kokoro").percentComplete)
        XCTAssertNil(NarrationPreparationProgress.downloading.percentComplete)
    }

    func testNarrationContainerDetectionRecognizesWAVM4AAndMP3() {
        XCTAssertEqual(
            NarrationService.fileExtension(for: Data("RIFFtest".utf8)),
            "wav"
        )
        XCTAssertEqual(
            NarrationService.fileExtension(for: Data([0, 0, 0, 0]) + Data("ftyp".utf8)),
            "m4a"
        )
        XCTAssertEqual(
            NarrationService.fileExtension(for: Data([0x49, 0x44, 0x33, 0x04])),
            "mp3"
        )
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
