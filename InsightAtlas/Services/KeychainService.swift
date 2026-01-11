import Foundation
import Security
import os.log

private let logger = Logger(subsystem: "com.insightatlas", category: "Keychain")

/// Secure storage service for sensitive data using the iOS Keychain
/// Provides type-safe access to API keys and other credentials
final class KeychainService {

    // MARK: - Singleton

    static let shared = KeychainService()

    private init() {}

    // MARK: - Error Descriptions

    /// Convert OSStatus to human-readable error description
    private func errorDescription(for status: OSStatus) -> String {
        switch status {
        case errSecSuccess:
            return "Success"
        case errSecItemNotFound:
            return "Item not found"
        case errSecDuplicateItem:
            return "Duplicate item"
        case errSecAuthFailed:
            return "Authentication failed"
        case errSecInteractionNotAllowed:
            return "Interaction not allowed (device locked)"
        case errSecDecode:
            return "Unable to decode data"
        case errSecNotAvailable:
            return "Keychain not available"
        case errSecParam:
            return "Invalid parameter"
        case errSecAllocate:
            return "Failed to allocate memory"
        case errSecUserCanceled:
            return "User canceled operation"
        case errSecBadReq:
            return "Bad request"
        case errSecIO:
            return "I/O error"
        case errSecMissingEntitlement:
            return "Missing entitlement"
        default:
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return message
            }
            return "Unknown error (OSStatus: \(status))"
        }
    }

    // MARK: - Constants

    private enum Keys {
        static let claudeApiKey = "com.insightatlas.claude-api-key"
        static let openaiApiKey = "com.insightatlas.openai-api-key"
        static let elevenLabsApiKey = "com.insightatlas.elevenlabs-api-key"
    }

    // MARK: - Public Interface

    /// Claude API key stored securely in Keychain
    var claudeApiKey: String? {
        get { retrieve(key: Keys.claudeApiKey) }
        set {
            if let value = newValue, !value.isEmpty {
                save(key: Keys.claudeApiKey, value: value)
            } else {
                delete(key: Keys.claudeApiKey)
            }
        }
    }

    /// OpenAI API key stored securely in Keychain
    var openaiApiKey: String? {
        get { retrieve(key: Keys.openaiApiKey) }
        set {
            if let value = newValue, !value.isEmpty {
                save(key: Keys.openaiApiKey, value: value)
            } else {
                delete(key: Keys.openaiApiKey)
            }
        }
    }

    /// Check if Claude API key is configured
    var hasClaudeApiKey: Bool {
        claudeApiKey?.isEmpty == false
    }

    /// Check if OpenAI API key is configured
    var hasOpenAIApiKey: Bool {
        openaiApiKey?.isEmpty == false
    }

    /// ElevenLabs API key stored securely in Keychain
    /// Used for text-to-speech audio narration
    var elevenLabsApiKey: String? {
        get { retrieve(key: Keys.elevenLabsApiKey) }
        set {
            if let value = newValue, !value.isEmpty {
                save(key: Keys.elevenLabsApiKey, value: value)
            } else {
                delete(key: Keys.elevenLabsApiKey)
            }
        }
    }

    /// Check if ElevenLabs API key is configured
    var hasElevenLabsApiKey: Bool {
        elevenLabsApiKey?.isEmpty == false
    }

    /// Clear all stored API keys
    func clearAllKeys() {
        delete(key: Keys.claudeApiKey)
        delete(key: Keys.openaiApiKey)
        delete(key: Keys.elevenLabsApiKey)
    }

    // MARK: - Private Keychain Operations

    @discardableResult
    private func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            logger.error("Keychain save failed: Unable to encode value for key '\(key, privacy: .private)'")
            return false
        }

        // Delete existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            logger.error("Keychain save failed for key '\(key, privacy: .private)': \(self.errorDescription(for: status))")
            return false
        }

        logger.debug("Keychain save succeeded for key '\(key, privacy: .private)'")
        return true
    }

    private func retrieve(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Migration Support

    /// Result of a keychain migration operation
    struct MigrationResult {
        let claudeKeyMigrated: Bool
        let openaiKeyMigrated: Bool
        let alreadyCompleted: Bool
        let error: String?

        var anyKeyMigrated: Bool {
            claudeKeyMigrated || openaiKeyMigrated
        }
    }

    /// Migrate API keys from UserDefaults to Keychain (one-time migration)
    /// - Returns: MigrationResult with details about what was migrated
    @discardableResult
    func migrateFromUserDefaults() -> MigrationResult {
        let defaults = UserDefaults.standard
        let settingsKey = "insight_atlas_settings"

        // Check if migration already done
        if defaults.bool(forKey: "keychain_migration_completed") {
            logger.debug("Keychain migration already completed, skipping")
            return MigrationResult(
                claudeKeyMigrated: false,
                openaiKeyMigrated: false,
                alreadyCompleted: true,
                error: nil
            )
        }

        logger.info("Starting keychain migration from UserDefaults")

        var claudeKeyMigrated = false
        var openaiKeyMigrated = false

        // Try to load old settings
        guard let data = defaults.data(forKey: settingsKey) else {
            logger.info("No existing settings found in UserDefaults, marking migration complete")
            defaults.set(true, forKey: "keychain_migration_completed")
            return MigrationResult(
                claudeKeyMigrated: false,
                openaiKeyMigrated: false,
                alreadyCompleted: false,
                error: nil
            )
        }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                logger.error("Keychain migration failed: Settings data is not a valid dictionary")
                return MigrationResult(
                    claudeKeyMigrated: false,
                    openaiKeyMigrated: false,
                    alreadyCompleted: false,
                    error: "Settings data format invalid"
                )
            }

            // Migrate Claude API key
            if let claudeKey = json["claudeApiKey"] as? String, !claudeKey.isEmpty {
                if save(key: Keys.claudeApiKey, value: claudeKey) {
                    claudeKeyMigrated = true
                    logger.info("Claude API key migrated successfully")
                } else {
                    logger.error("Failed to migrate Claude API key to Keychain")
                }
            }

            // Migrate OpenAI API key
            if let openaiKey = json["openaiApiKey"] as? String, !openaiKey.isEmpty {
                if save(key: Keys.openaiApiKey, value: openaiKey) {
                    openaiKeyMigrated = true
                    logger.info("OpenAI API key migrated successfully")
                } else {
                    logger.error("Failed to migrate OpenAI API key to Keychain")
                }
            }

            // Remove API keys from UserDefaults (keep other settings)
            var mutableJson = json
            mutableJson.removeValue(forKey: "claudeApiKey")
            mutableJson.removeValue(forKey: "openaiApiKey")

            let updatedData = try JSONSerialization.data(withJSONObject: mutableJson)
            defaults.set(updatedData, forKey: settingsKey)
            logger.debug("Removed API keys from UserDefaults settings")

        } catch {
            logger.error("Keychain migration failed: \(error.localizedDescription)")
            return MigrationResult(
                claudeKeyMigrated: claudeKeyMigrated,
                openaiKeyMigrated: openaiKeyMigrated,
                alreadyCompleted: false,
                error: error.localizedDescription
            )
        }

        // Mark migration as complete
        defaults.set(true, forKey: "keychain_migration_completed")
        logger.info("Keychain migration completed. Claude: \(claudeKeyMigrated), OpenAI: \(openaiKeyMigrated)")

        return MigrationResult(
            claudeKeyMigrated: claudeKeyMigrated,
            openaiKeyMigrated: openaiKeyMigrated,
            alreadyCompleted: false,
            error: nil
        )
    }
}
