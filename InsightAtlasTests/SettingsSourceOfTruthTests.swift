import XCTest
@testable import InsightAtlas

@MainActor
final class SettingsSourceOfTruthTests: XCTestCase {

    func testAppEnvironmentSaveMirrorsIntoDataManager() {
        let env = AppEnvironment.shared
        let original = env.userSettings

        var updated = original
        updated.autoGenerateAudio = !original.autoGenerateAudio
        updated.preferredMode = .standard
        env.updateSettings(updated)

        XCTAssertEqual(
            DataManager.shared.userSettings.autoGenerateAudio,
            updated.autoGenerateAudio,
            "DataManager must mirror AppEnvironment after save"
        )
        XCTAssertEqual(DataManager.shared.userSettings.preferredMode, .standard)

        // Restore
        env.updateSettings(original)
    }

    func testDataManagerUpdateSettingsForwardsToEnvironment() {
        let env = AppEnvironment.shared
        let original = env.userSettings

        var updated = original
        updated.preferredSummaryType = .professional
        DataManager.shared.updateSettings(updated)

        XCTAssertEqual(env.userSettings.preferredSummaryType, .professional)

        env.updateSettings(original)
    }
}
