import XCTest
@testable import InsightAtlas

final class ProviderConfigurationTests: XCTestCase {

    func testNarrationProvidersAreOnDeviceOnly() {
        // Kokoro plus the Apple system voice — both fully on-device; no hosted
        // provider ever returns to this list.
        XCTAssertEqual(VoiceProvider.allCases, [.kokoro, .apple])
        XCTAssertEqual(VoiceProvider.kokoro.displayName, "Kokoro (On-Device)")
        XCTAssertEqual(VoiceProvider.kokoro.defaultVoiceID, "af_heart")
        XCTAssertEqual(VoiceProvider.kokoro.audioFileExtension, "wav")
        XCTAssertFalse(VoiceProvider.kokoro.requiresSeparateApiKey)
        XCTAssertEqual(VoiceProvider.apple.displayName, "Apple Voice (On-Device)")
        XCTAssertEqual(VoiceProvider.apple.audioFileExtension, "wav")
        XCTAssertFalse(VoiceProvider.apple.requiresSeparateApiKey)
    }

    func testSupportedGenerationProvidersExcludeRetiredOpenAIModesAndIncludeMiniMax() {
        XCTAssertEqual(AIProvider.allCases, [.minimax, .claude, .openRouter])
        XCTAssertEqual(UserSettings().preferredProvider, .minimax)
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

        // A retired "openai" selection lands on MiniMax, the current default.
        XCTAssertEqual(decoded.preferredProvider, .minimax)
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
                availability: VoiceProviderAvailability(kokoro: true, apple: false)
            ),
            [.kokoro]
        )
        XCTAssertEqual(
            VoiceProviderFallbackPlanner.orderedProviders(
                preferred: .kokoro,
                availability: VoiceProviderAvailability(kokoro: false, apple: false)
            ),
            []
        )
    }

    func testFallbackPlannerOffersAppleVoiceWhenPreferred() {
        XCTAssertEqual(
            VoiceProviderFallbackPlanner.orderedProviders(
                preferred: .apple,
                availability: VoiceProviderAvailability(kokoro: false, apple: true)
            ),
            [.apple]
        )
    }

    /// The planner used to return only the preferred provider, so a missing
    /// Kokoro install produced an empty route list and narration hard-failed
    /// even though an Apple voice was ready.
    func testFallbackPlannerDegradesToAppleWhenKokoroIsMissing() {
        XCTAssertEqual(
            VoiceProviderFallbackPlanner.orderedProviders(
                preferred: .kokoro,
                availability: VoiceProviderAvailability(kokoro: false, apple: true)
            ),
            [.apple]
        )
        XCTAssertEqual(
            VoiceProviderFallbackPlanner.orderedProviders(
                preferred: .kokoro,
                availability: VoiceProviderAvailability(kokoro: true, apple: true)
            ),
            [.kokoro, .apple]
        )
        XCTAssertEqual(
            VoiceProviderFallbackPlanner.orderedProviders(
                preferred: .apple,
                availability: VoiceProviderAvailability(kokoro: true, apple: true)
            ),
            [.apple, .kokoro]
        )
    }

    func testNarrationRoutesFallBackAcrossEngines() {
        XCTAssertEqual(
            NarrationFallbackPolicy.orderedRoutes(preferred: .apple, kokoroConfigured: true),
            [.appleVoice, .kokoro]
        )
        XCTAssertEqual(
            NarrationFallbackPolicy.orderedRoutes(preferred: .kokoro, kokoroConfigured: false),
            [.appleVoice]
        )
        XCTAssertEqual(
            NarrationFallbackPolicy.orderedRoutes(preferred: .kokoro, kokoroConfigured: true),
            [.kokoro, .appleVoice]
        )
    }
}
