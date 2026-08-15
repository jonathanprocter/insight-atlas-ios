import XCTest
@testable import InsightAtlas

final class KeychainServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear keys before each test
        KeychainService.shared.clearAllKeys()
    }

    override func tearDown() {
        // Clean up after tests
        KeychainService.shared.clearAllKeys()
        super.tearDown()
    }

    // MARK: - Claude API Key Tests

    func testSaveAndRetrieveClaudeApiKey() {
        let testKey = "sk-ant-test-key-12345"

        KeychainService.shared.claudeApiKey = testKey

        XCTAssertEqual(
            KeychainService.shared.claudeApiKey,
            testKey,
            "Should retrieve the saved Claude API key"
        )
    }

    func testClaudeApiKeyInitiallyNil() {
        XCTAssertNil(
            KeychainService.shared.claudeApiKey,
            "Claude API key should be nil initially"
        )
    }

    func testDeleteClaudeApiKey() {
        let testKey = "sk-ant-test-key-12345"

        // Save key
        KeychainService.shared.claudeApiKey = testKey
        XCTAssertNotNil(KeychainService.shared.claudeApiKey)

        // Delete key by setting to nil
        KeychainService.shared.claudeApiKey = nil
        XCTAssertNil(
            KeychainService.shared.claudeApiKey,
            "Claude API key should be nil after deletion"
        )
    }

    func testDeleteClaudeApiKeyWithEmptyString() {
        let testKey = "sk-ant-test-key-12345"

        // Save key
        KeychainService.shared.claudeApiKey = testKey
        XCTAssertNotNil(KeychainService.shared.claudeApiKey)

        // Delete key by setting to empty string
        KeychainService.shared.claudeApiKey = ""
        XCTAssertNil(
            KeychainService.shared.claudeApiKey,
            "Claude API key should be nil after setting empty string"
        )
    }

    func testHasClaudeApiKey() {
        XCTAssertFalse(
            KeychainService.shared.hasClaudeApiKey,
            "hasClaudeApiKey should be false initially"
        )

        KeychainService.shared.claudeApiKey = "sk-ant-test-key"
        XCTAssertTrue(
            KeychainService.shared.hasClaudeApiKey,
            "hasClaudeApiKey should be true after setting key"
        )

        KeychainService.shared.claudeApiKey = nil
        XCTAssertFalse(
            KeychainService.shared.hasClaudeApiKey,
            "hasClaudeApiKey should be false after clearing key"
        )
    }

    // MARK: - OpenRouter API Key Tests

    func testSaveAndRetrieveOpenRouterApiKey() {
        let testKey = "sk-or-test-key-67890"

        KeychainService.shared.openRouterApiKey = testKey

        XCTAssertEqual(
            KeychainService.shared.openRouterApiKey,
            testKey,
            "Should retrieve the saved OpenRouter API key"
        )
    }

    func testOpenRouterApiKeyInitiallyNil() {
        XCTAssertNil(
            KeychainService.shared.openRouterApiKey,
            "OpenRouter API key should be nil initially"
        )
    }

    func testDeleteOpenRouterApiKey() {
        let testKey = "sk-or-test-key-67890"

        // Save key
        KeychainService.shared.openRouterApiKey = testKey
        XCTAssertNotNil(KeychainService.shared.openRouterApiKey)

        // Delete key
        KeychainService.shared.openRouterApiKey = nil
        XCTAssertNil(
            KeychainService.shared.openRouterApiKey,
            "OpenRouter API key should be nil after deletion"
        )
    }

    func testHasOpenRouterApiKey() {
        XCTAssertFalse(
            KeychainService.shared.hasOpenRouterApiKey,
            "hasOpenRouterApiKey should be false initially"
        )

        KeychainService.shared.openRouterApiKey = "sk-or-test-key"
        XCTAssertTrue(
            KeychainService.shared.hasOpenRouterApiKey,
            "hasOpenRouterApiKey should be true after setting key"
        )
    }

    // MARK: - Retired Provider Tests

    /// OpenAI is retired. Migration must discard any legacy key rather than
    /// carrying it into the Keychain.
    func testLegacyOpenAIKeyIsPurgedOnMigration() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "keychain_migration_completed")
        let legacySettings: [String: Any] = [
            "openaiApiKey": "sk-openai-legacy-key",
            "claudeApiKey": "sk-ant-legacy-key"
        ]
        defaults.set(
            try? JSONSerialization.data(withJSONObject: legacySettings),
            forKey: "insight_atlas_settings"
        )

        let result = KeychainService.shared.migrateFromUserDefaults()

        XCTAssertTrue(
            result.openaiKeyPurged,
            "A legacy OpenAI key should be reported as purged"
        )
        XCTAssertTrue(
            result.claudeKeyMigrated,
            "The Claude key should still migrate normally"
        )

        let stored = defaults.data(forKey: "insight_atlas_settings")
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        XCTAssertNil(
            stored?["openaiApiKey"],
            "The legacy OpenAI key should be stripped from UserDefaults"
        )
    }

    // MARK: - Multiple Keys Tests

    func testMultipleKeysIndependent() {
        let claudeKey = "sk-ant-claude-key"
        let openRouterKey = "sk-or-key"

        KeychainService.shared.claudeApiKey = claudeKey
        KeychainService.shared.openRouterApiKey = openRouterKey

        XCTAssertEqual(KeychainService.shared.claudeApiKey, claudeKey)
        XCTAssertEqual(KeychainService.shared.openRouterApiKey, openRouterKey)

        // Deleting one should not affect the other
        KeychainService.shared.claudeApiKey = nil
        XCTAssertNil(KeychainService.shared.claudeApiKey)
        XCTAssertEqual(KeychainService.shared.openRouterApiKey, openRouterKey)
    }

    func testClearAllKeys() {
        KeychainService.shared.claudeApiKey = "sk-ant-claude-key"
        KeychainService.shared.openRouterApiKey = "sk-or-key"

        XCTAssertTrue(KeychainService.shared.hasClaudeApiKey)
        XCTAssertTrue(KeychainService.shared.hasOpenRouterApiKey)

        KeychainService.shared.clearAllKeys()

        XCTAssertFalse(KeychainService.shared.hasClaudeApiKey)
        XCTAssertFalse(KeychainService.shared.hasOpenRouterApiKey)
        XCTAssertNil(KeychainService.shared.claudeApiKey)
        XCTAssertNil(KeychainService.shared.openRouterApiKey)
    }

    // MARK: - Update Key Tests

    func testUpdateExistingKey() {
        let initialKey = "sk-ant-initial-key"
        let updatedKey = "sk-ant-updated-key"

        KeychainService.shared.claudeApiKey = initialKey
        XCTAssertEqual(KeychainService.shared.claudeApiKey, initialKey)

        KeychainService.shared.claudeApiKey = updatedKey
        XCTAssertEqual(
            KeychainService.shared.claudeApiKey,
            updatedKey,
            "Should update to new key value"
        )
    }

    // MARK: - Edge Cases

    func testKeyWithSpecialCharacters() {
        let specialKey = "sk-ant-key!@#$%^&*()_+-=[]{}|;':\",./<>?"

        KeychainService.shared.claudeApiKey = specialKey
        XCTAssertEqual(
            KeychainService.shared.claudeApiKey,
            specialKey,
            "Should handle special characters in key"
        )
    }

    func testKeyWithUnicodeCharacters() {
        let unicodeKey = "sk-ant-key-🔑-émoji-中文"

        KeychainService.shared.claudeApiKey = unicodeKey
        XCTAssertEqual(
            KeychainService.shared.claudeApiKey,
            unicodeKey,
            "Should handle unicode characters in key"
        )
    }

    func testVeryLongKey() {
        let longKey = String(repeating: "a", count: 10000)

        KeychainService.shared.claudeApiKey = longKey
        XCTAssertEqual(
            KeychainService.shared.claudeApiKey,
            longKey,
            "Should handle very long keys"
        )
    }

    // MARK: - Persistence Tests

    func testKeyPersistsAcrossAccesses() {
        let testKey = "sk-ant-persistent-key"

        KeychainService.shared.claudeApiKey = testKey

        // Access multiple times
        for _ in 0..<10 {
            XCTAssertEqual(KeychainService.shared.claudeApiKey, testKey)
        }
    }

    // MARK: - Singleton Tests

    func testSingletonInstance() {
        let instance1 = KeychainService.shared
        let instance2 = KeychainService.shared

        // Should be the same instance
        XCTAssertTrue(instance1 === instance2, "Should return the same singleton instance")
    }

    func testSingletonSharedState() {
        let testKey = "sk-ant-shared-state-key"

        // Set via shared instance
        KeychainService.shared.claudeApiKey = testKey

        // Should be accessible from same shared instance
        let retrieved = KeychainService.shared.claudeApiKey
        XCTAssertEqual(retrieved, testKey)
    }
}
