import XCTest
@testable import InsightAtlas

final class KokoroModelManagerTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KokoroModelManagerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
        try super.tearDownWithError()
    }

    func testProductionManifestPinsFluidAudioANEVersion() {
        let manifest = KokoroModelManifest.production

        XCTAssertEqual(manifest.version, "kokoro-ane-fluid-0.15.6")
        XCTAssertGreaterThanOrEqual(manifest.minimumAvailableCapacity, 750 * 1_024 * 1_024)
    }

    func testEmptyDirectoryIsNotAValidInstallation() {
        XCTAssertFalse(KokoroModelInstallationValidator.isInstalled(at: temporaryDirectory))
    }

    func testMarkerWithoutCompiledModelIsNotAValidInstallation() throws {
        try Data("ready".utf8).write(
            to: temporaryDirectory.appendingPathComponent(".insightatlas-kokoro-ane-ready-v1")
        )

        XCTAssertFalse(KokoroModelInstallationValidator.isInstalled(at: temporaryDirectory))
    }

    func testMarkerAndCompiledModelAreAValidInstallation() throws {
        try Data("ready".utf8).write(
            to: temporaryDirectory.appendingPathComponent(".insightatlas-kokoro-ane-ready-v1")
        )
        try FileManager.default.createDirectory(
            at: temporaryDirectory.appendingPathComponent("KokoroAlbert.mlmodelc"),
            withIntermediateDirectories: true
        )

        XCTAssertTrue(KokoroModelInstallationValidator.isInstalled(at: temporaryDirectory))
    }
}
