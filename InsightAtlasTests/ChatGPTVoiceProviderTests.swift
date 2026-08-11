import XCTest
@testable import InsightAtlas

final class ChatGPTVoiceProviderTests: XCTestCase {

    func testChatGPTVoiceIsThePrimaryProvider() {
        XCTAssertEqual(VoiceProvider.allCases.first, .chatgptVoice)
        XCTAssertEqual(VoiceProvider.chatgptVoice.displayName, "ChatGPT Voice (Experimental)")
        XCTAssertEqual(VoiceProvider.chatgptVoice.defaultVoiceID, "marin")
        XCTAssertFalse(VoiceProvider.chatgptVoice.requiresSeparateApiKey)
    }

    func testNewUserSettingsDefaultToChatGPTVoice() {
        XCTAssertEqual(UserSettings().voiceProvider, .chatgptVoice)
    }

    func testLegacySettingsWithoutVoiceProviderDefaultToChatGPTVoice() throws {
        let original = try JSONEncoder().encode(UserSettings(voiceProvider: .openai))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
        object.removeValue(forKey: "voiceProvider")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(UserSettings.self, from: legacyData)

        XCTAssertEqual(decoded.voiceProvider, .chatgptVoice)
    }

    func testFallbackOrderPrefersChatGPTThenSelectedStableProvider() {
        let availability = VoiceProviderAvailability(
            chatgptVoice: true,
            openAI: true,
            elevenLabs: true
        )

        XCTAssertEqual(
            VoiceProviderFallbackPlanner.orderedProviders(
                preferred: .elevenlabs,
                availability: availability
            ),
            [.chatgptVoice, .elevenlabs, .openai]
        )
    }

    func testFallbackOrderOmitsUnavailableProvidersAndDuplicates() {
        let availability = VoiceProviderAvailability(
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

    func testFallbackOrderUsesChatGPTOnlyWhenNoStableProviderIsConfigured() {
        let availability = VoiceProviderAvailability(
            chatgptVoice: true,
            openAI: false,
            elevenLabs: false
        )

        XCTAssertEqual(
            VoiceProviderFallbackPlanner.orderedProviders(
                preferred: .chatgptVoice,
                availability: availability
            ),
            [.chatgptVoice]
        )
    }
}
