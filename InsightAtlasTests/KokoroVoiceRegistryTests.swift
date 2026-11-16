import XCTest
@testable import InsightAtlas

final class KokoroVoiceRegistryTests: XCTestCase {

    func testAlbaIsTheDefaultVoice() {
        let voice = KokoroVoiceRegistry.defaultVoice

        XCTAssertEqual(voice.voiceID, "alba")
        XCTAssertEqual(voice.speakerID, 0)
        XCTAssertEqual(voice.name, "Alba")
        XCTAssertEqual(voice.provider, .kokoro)
        XCTAssertEqual(voice.referenceAudioRelativePath, "voices/alba.wav")
    }

    func testRegistryListsTheBundledPocketVoices() {
        XCTAssertEqual(KokoroVoiceRegistry.allVoices.count, 11)
        XCTAssertTrue(KokoroVoiceRegistry.allVoices.allSatisfy { $0.provider == .kokoro })
    }

    func testVoiceAndSpeakerIDsAreUnique() {
        let voiceIDs = KokoroVoiceRegistry.allVoices.map(\.voiceID)
        let speakerIDs = KokoroVoiceRegistry.allVoices.map(\.speakerID)

        XCTAssertEqual(Set(voiceIDs).count, voiceIDs.count)
        XCTAssertEqual(Set(speakerIDs).count, speakerIDs.count)
    }

    func testRegistryResolvesByVoiceIDAndSpeakerID() {
        XCTAssertEqual(KokoroVoiceRegistry.voice(byVoiceID: "charles")?.speakerID, 5)
        XCTAssertEqual(KokoroVoiceRegistry.voice(speakerID: 5)?.voiceID, "charles")
        XCTAssertNil(KokoroVoiceRegistry.voice(byVoiceID: "not-a-voice"))
        XCTAssertNil(KokoroVoiceRegistry.voice(speakerID: 999))
    }

    /// A Kokoro voice id persisted by an earlier build must fall through to the
    /// default rather than resolve to something.
    func testLegacyKokoroVoiceIDsNoLongerResolve() {
        XCTAssertNil(KokoroVoiceRegistry.voice(byVoiceID: "af_heart"))
        XCTAssertFalse(KokoroVoiceRegistry.isValidVoiceID("bm_daniel"))
    }

    /// Every registered voice must have a reference clip the installer requires,
    /// otherwise the model would validate as installed and then fail to speak.
    func testEveryVoiceClipIsARequiredInstallFile() {
        for voice in KokoroVoiceRegistry.allVoices {
            XCTAssertTrue(
                KokoroModelInstallationValidator.requiredRelativePaths.contains(voice.referenceAudioRelativePath),
                "\(voice.voiceID) clip is not a required install file"
            )
        }
    }
}
