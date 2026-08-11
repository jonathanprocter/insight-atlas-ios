import XCTest
@testable import InsightAtlas

final class KokoroVoiceRegistryTests: XCTestCase {

    func testHeartIsTheApprovedDefaultVoice() {
        let voice = KokoroVoiceRegistry.defaultVoice

        XCTAssertEqual(voice.voiceID, "af_heart")
        XCTAssertEqual(voice.speakerID, 3)
        XCTAssertEqual(voice.name, "Heart")
        XCTAssertEqual(voice.provider, .kokoro)
    }

    func testRegistryContainsAllEnglishV10Voices() {
        XCTAssertEqual(KokoroVoiceRegistry.allVoices.count, 28)
        XCTAssertTrue(KokoroVoiceRegistry.allVoices.allSatisfy { $0.provider == .kokoro })
    }

    func testVoiceAndSpeakerIDsAreUnique() {
        let voiceIDs = KokoroVoiceRegistry.allVoices.map(\.voiceID)
        let speakerIDs = KokoroVoiceRegistry.allVoices.map(\.speakerID)

        XCTAssertEqual(Set(voiceIDs).count, voiceIDs.count)
        XCTAssertEqual(Set(speakerIDs).count, speakerIDs.count)
    }

    func testRegistryResolvesByVoiceIDAndSpeakerID() {
        XCTAssertEqual(KokoroVoiceRegistry.voice(byVoiceID: "af_heart")?.speakerID, 3)
        XCTAssertEqual(KokoroVoiceRegistry.voice(speakerID: 3)?.voiceID, "af_heart")
        XCTAssertNil(KokoroVoiceRegistry.voice(byVoiceID: "not-a-voice"))
        XCTAssertNil(KokoroVoiceRegistry.voice(speakerID: 999))
    }

    func testVoiceIDsUseOfficialAccentAndPresentationPrefixes() {
        let expectedPrefixes = ["af_", "am_", "bf_", "bm_"]

        XCTAssertTrue(
            KokoroVoiceRegistry.allVoices.allSatisfy { voice in
                expectedPrefixes.contains { voice.voiceID.hasPrefix($0) }
            }
        )
    }
}
