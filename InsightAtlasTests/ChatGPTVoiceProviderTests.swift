import XCTest
@testable import InsightAtlas

final class VoiceProviderTests: XCTestCase {

    func testKokoroIsThePrimaryProvider() {
        XCTAssertEqual(VoiceProvider.allCases.first, .kokoro)
        XCTAssertEqual(VoiceProvider.kokoro.displayName, "Kokoro (On-Device)")
        XCTAssertEqual(VoiceProvider.kokoro.defaultVoiceID, "af_heart")
        XCTAssertEqual(VoiceProvider.kokoro.audioFileExtension, "wav")
        XCTAssertFalse(VoiceProvider.kokoro.requiresSeparateApiKey)
    }

    func testNewUserSettingsDefaultToKokoro() {
        XCTAssertEqual(UserSettings().voiceProvider, .kokoro)
    }

    func testLegacySettingsWithoutVoiceProviderDefaultToKokoro() throws {
        let original = try JSONEncoder().encode(UserSettings(voiceProvider: .openai))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
        object.removeValue(forKey: "voiceProvider")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(UserSettings.self, from: legacyData)

        XCTAssertEqual(decoded.voiceProvider, .kokoro)
    }

    func testDecodingPreservesAnExplicitCloudProvider() throws {
        let encoded = try JSONEncoder().encode(UserSettings(voiceProvider: .elevenlabs))
        let decoded = try JSONDecoder().decode(UserSettings.self, from: encoded)

        XCTAssertEqual(decoded.voiceProvider, .elevenlabs)
    }

    func testFallbackOrderRespectsAvailablePreferredProviderThenStableOptions() {
        let availability = VoiceProviderAvailability(
            kokoro: true,
            chatgptVoice: true,
            openAI: true,
            elevenLabs: true
        )

        XCTAssertEqual(
            VoiceProviderFallbackPlanner.orderedProviders(
                preferred: .openai,
                availability: availability
            ),
            [.openai, .kokoro, .elevenlabs, .chatgptVoice]
        )
    }

    func testFallbackOrderUsesKokoroWhenPreferredProviderIsUnavailable() {
        let availability = VoiceProviderAvailability(
            kokoro: true,
            chatgptVoice: false,
            openAI: false,
            elevenLabs: true
        )

        XCTAssertEqual(
            VoiceProviderFallbackPlanner.orderedProviders(
                preferred: .openai,
                availability: availability
            ),
            [.kokoro, .elevenlabs]
        )
    }

    func testFallbackOrderOmitsUnavailableProvidersAndDuplicates() {
        let availability = VoiceProviderAvailability(
            kokoro: false,
            chatgptVoice: false,
            openAI: true,
            elevenLabs: false
        )

        XCTAssertEqual(
            VoiceProviderFallbackPlanner.orderedProviders(
                preferred: .openai,
                availability: availability
            ),
            [.openai]
        )
    }

    func testChatGPTVoiceIsLastWhenStableProvidersAreAvailable() {
        let availability = VoiceProviderAvailability(
            kokoro: true,
            chatgptVoice: true,
            openAI: true,
            elevenLabs: true
        )

        let providers = VoiceProviderFallbackPlanner.orderedProviders(
            preferred: .kokoro,
            availability: availability
        )

        XCTAssertEqual(providers.last, .chatgptVoice)
    }
}
