import XCTest
@testable import InsightAtlas

final class ProviderConfigurationTests: XCTestCase {

    func testKokoroIsTheOnlyNarrationProvider() {
        XCTAssertEqual(VoiceProvider.allCases, [.kokoro])
        XCTAssertEqual(VoiceProvider.kokoro.displayName, "Kokoro (On-Device)")
        XCTAssertEqual(VoiceProvider.kokoro.defaultVoiceID, "af_heart")
        XCTAssertEqual(VoiceProvider.kokoro.audioFileExtension, "wav")
        XCTAssertFalse(VoiceProvider.kokoro.requiresSeparateApiKey)
    }

    func testSupportedGenerationProvidersExcludeRetiredOpenAIModesAndIncludeMiniMax() {
        XCTAssertEqual(AIProvider.allCases, [.claude, .openRouter, .minimax])
        XCTAssertEqual(UserSettings().preferredProvider, .claude)
    }

    func testNewUserSettingsDefaultToKokoro() {
        XCTAssertEqual(UserSettings().voiceProvider, .kokoro)
    }

    func testLegacySettingsWithoutVoiceProviderDefaultToKokoro() throws {
        let original = try JSONEncoder().encode(UserSettings(playbackSpeed: .faster))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
        object.removeValue(forKey: "voiceProvider")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(UserSettings.self, from: legacyData)

        XCTAssertEqual(decoded.voiceProvider, .kokoro)
        XCTAssertEqual(decoded.playbackSpeed, .faster)
    }

    func testRetiredProviderValuesMigrateWithoutResettingOtherPreferences() throws {
        let original = try JSONEncoder().encode(
            UserSettings(
                preferredProvider: .claude,
                preferredReaderProfile: .academic,
                autoGenerateAudio: false,
                playbackSpeed: .fast,
                voiceProvider: .kokoro
            )
        )
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
        object["preferredProvider"] = "openai"
        object["voiceProvider"] = "elevenlabs"
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(UserSettings.self, from: legacyData)

        XCTAssertEqual(decoded.preferredProvider, .claude)
        XCTAssertEqual(decoded.voiceProvider, .kokoro)
        XCTAssertEqual(decoded.preferredReaderProfile, .academic)
        XCTAssertFalse(decoded.autoGenerateAudio)
        XCTAssertEqual(decoded.playbackSpeed, .fast)
    }

    func testRegenerationOffersEverySupportedGenerationProvider() {
        XCTAssertEqual(RegenerateView.supportedProviders, AIProvider.allCases)
    }

    func testFallbackPlannerUsesKokoroOnlyWhenInstalled() {
        XCTAssertEqual(
            VoiceProviderFallbackPlanner.orderedProviders(
                preferred: .kokoro,
                availability: VoiceProviderAvailability(kokoro: true)
            ),
            [.kokoro]
        )
        XCTAssertEqual(
            VoiceProviderFallbackPlanner.orderedProviders(
                preferred: .kokoro,
                availability: VoiceProviderAvailability(kokoro: false)
            ),
            []
        )
    }
}
