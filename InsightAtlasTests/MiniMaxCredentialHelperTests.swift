import XCTest
@testable import InsightAtlas

/// Ensures MiniMax signed-in detection stays consistent across generation and narration.
final class MiniMaxCredentialHelperTests: XCTestCase {

    override func tearDown() {
        KeychainService.shared.clearMiniMaxAuth()
        super.tearDown()
    }

    func testHasStoredCredentialsFalseWhenEmpty() {
        KeychainService.shared.clearMiniMaxAuth()
        XCTAssertFalse(MiniMaxOAuthService.hasStoredCredentials)
    }

    func testHasStoredCredentialsTrueWithRefreshOnly() {
        KeychainService.shared.clearMiniMaxAuth()
        KeychainService.shared.minimaxRefreshToken = "refresh-token-fixture"
        XCTAssertTrue(MiniMaxOAuthService.hasStoredCredentials)
    }

    func testHasStoredCredentialsTrueWithAccessOnly() {
        KeychainService.shared.clearMiniMaxAuth()
        KeychainService.shared.minimaxAccessToken = "access-token-fixture"
        XCTAssertTrue(MiniMaxOAuthService.hasStoredCredentials)
    }

    func testClearAllKeysAlsoClearsMiniMax() {
        KeychainService.shared.minimaxAccessToken = "access-token-fixture"
        KeychainService.shared.minimaxRefreshToken = "refresh-token-fixture"
        KeychainService.shared.clearAllKeys()
        XCTAssertFalse(MiniMaxOAuthService.hasStoredCredentials)
        XCTAssertNil(KeychainService.shared.minimaxAccessToken)
        XCTAssertNil(KeychainService.shared.minimaxRefreshToken)
    }
}
