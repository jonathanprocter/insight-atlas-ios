//
//  KokoroNarrationTests.swift
//  InsightAtlasTests
//
//  Focused tests for the on-device narration pipeline (Pocket / Apple Voice):
//  - Spoken-text sanitizing and listening-edition preparation.
//  - NarrationState persistence and backward compatibility on LibraryItem.
//  - Provider fallback policy, audio validation and progress reporting.
//

import XCTest
import AVFoundation
@testable import InsightAtlas

final class KokoroNarrationTests: XCTestCase {

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

    // MARK: - Stable provider fallback policy

    func testNarrationFallbackPolicyPrefersKokoroWhenInstalled() {
        XCTAssertEqual(
            NarrationFallbackPolicy.orderedRoutes(
                preferred: .kokoro,
                kokoroConfigured: true
            ),
            [.kokoro, .appleVoice]
        )
    }

    func testNarrationFallbackPolicyOnlyRoutesToOnDeviceEngines() {
        // Routes contain only on-device engines: Kokoro when installed, and
        // the Apple system voice, which needs no download. No hosted provider
        // ever appears.
        XCTAssertEqual(
            NarrationFallbackPolicy.orderedRoutes(
                preferred: .kokoro,
                kokoroConfigured: false
            ),
            [.appleVoice]
        )
        XCTAssertEqual(
            NarrationFallbackPolicy.orderedRoutes(
                preferred: .apple,
                kokoroConfigured: true
            ),
            [.appleVoice, .kokoro]
        )
    }

    /// `AVSpeechSynthesizer.write` emits a zero-length buffer after every
    /// sentence. The renderer used to treat the first one as the end of the
    /// utterance, so every system-voice narration was cut to its opening
    /// sentence. Runs on real speech synthesis only (device, or the
    /// "Designed for iPad" Mac destination); the simulator renders nothing.
    func testAppleSpeechRendersEverySentenceNotJustTheFirst() async throws {
#if targetEnvironment(simulator)
        throw XCTSkip("AVSpeechSynthesizer does not deliver offline render buffers in the iOS simulator")
#else
        guard let voice = AppleVoiceCatalog.defaultVoice() else {
            throw XCTSkip("No system voice installed")
        }
        let sentence = "Self-compassion means treating yourself with the same kindness you would offer a good friend."
        let single = try await AppleSpeechAudioService.shared.generateAudio(text: sentence, voiceID: voice.identifier)
        XCTAssertGreaterThan(single.duration, 1)

        let paragraph = Array(repeating: sentence, count: 8).joined(separator: " ")
        let whole = try await AppleSpeechAudioService.shared.generateAudio(text: paragraph, voiceID: voice.identifier)

        // Eight sentences must take materially longer than one; allow generous
        // slack for prosody differences but reject anything near a single sentence.
        XCTAssertGreaterThan(
            whole.duration,
            single.duration * 5,
            "narration stopped at the first sentence boundary (\(whole.duration)s vs \(single.duration)s for one sentence)"
        )

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("apple-narration-multi-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        try whole.data.write(to: url)
        let validated = try await NarrationAudioValidation.validatedDuration(
            at: url,
            declaredDuration: whole.duration
        )
        XCTAssertEqual(validated, whole.duration, accuracy: 0.5)
#endif
    }

    /// Multi-chunk renders share one synthesizer and one output file; every
    /// chunk's sentences must land, in order, in the single asset.
    func testAppleSpeechMultiChunkRenderKeepsEveryChunk() async throws {
#if targetEnvironment(simulator)
        throw XCTSkip("AVSpeechSynthesizer does not deliver offline render buffers in the iOS simulator")
#else
        guard let voice = AppleVoiceCatalog.defaultVoice() else {
            throw XCTSkip("No system voice installed")
        }
        let sentence = "Each chunk of the narration must be rendered in full before the next one begins. "
        // Three paragraphs, each over half the default chunk limit, so the
        // production chunker (not a test-only limit) yields exactly three.
        let paragraph = String(repeating: sentence, count: 16)
        let text = Array(repeating: paragraph, count: 3).joined(separator: "\n\n")
        XCTAssertEqual(AppleSpeechAudioService.chunk(text).count, 3)

        let one = try await AppleSpeechAudioService.shared.generateAudio(text: paragraph, voiceID: voice.identifier)
        var reported: [(Int, Int)] = []
        let lock = NSLock()
        let all = try await AppleSpeechAudioService.shared.generateAudio(
            text: text,
            voiceID: voice.identifier,
            onProgress: { done, total in lock.withLock { reported.append((done, total)) } }
        )
        XCTAssertGreaterThan(all.duration, one.duration * 2.5)
        XCTAssertEqual(lock.withLock { reported.map(\.0) }, [1, 2, 3])
#endif
    }

    func testMiniMaxM3IsAWrittenGuideProviderNotAnAudioSynthesizer() {
        XCTAssertFalse(AIProvider.minimax.supportsDirectAudioGeneration)
    }

    func testNarrationStartsFromTheListeningEditionByDefault() {
        // The MiniMax rewrite only warms the script cache in the background;
        // initial synthesis never waits on it.
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
        // Keep the playback session on `.default` with no CategoryOptions.
        // Older SDKs exposed `.allowBluetoothHFP`; referencing that symbol no
        // longer compiles on current Xcode, and A2DP is also deliberately off
        // to avoid device `paramErr` failures observed in TestFlight.
        XCTAssertEqual(NarrationPlaybackPolicy.mode, .default)
        XCTAssertTrue(NarrationPlaybackPolicy.options.isEmpty)
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
}
