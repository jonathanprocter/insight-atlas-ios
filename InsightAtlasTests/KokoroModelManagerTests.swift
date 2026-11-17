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

    func testProductionManifestMatchesVerifiedOfficialArchive() throws {
        let manifest = KokoroModelManifest.production

        XCTAssertEqual(manifest.version, "pocket-tts-int8-2026-01-26-ia1")
        XCTAssertEqual(manifest.downloadURL.absoluteString, "https://models.procterai.cc/pocket-tts/pocket-tts-int8-2026-01-26-ia1.tar.bz2")
        // Measured against the uploaded R2 object on 2026-10-12:
        //   curl -sL <downloadURL> -o a.tar.bz2 && shasum -a 256 a.tar.bz2
        // Re-measure rather than copying these values forward.
        XCTAssertEqual(manifest.archiveByteCount, 98_882_041)
        XCTAssertEqual(manifest.sha256, "9070eac57cd5fb7d09af334ceb9b810f078e0a89c4f9b27143c6e6aea4e1810e")
        XCTAssertGreaterThanOrEqual(manifest.minimumAvailableCapacity, 450 * 1_024 * 1_024)
    }

    func testEmptyDirectoryIsNotAValidInstallation() {
        XCTAssertFalse(KokoroModelInstallationValidator.isInstalled(at: temporaryDirectory))
    }

    func testCompleteRequiredAssetSetIsAValidInstallation() throws {
        try createRequiredAssets(at: temporaryDirectory)

        XCTAssertTrue(KokoroModelInstallationValidator.isInstalled(at: temporaryDirectory))
    }

    func testMissingCoreAssetInvalidatesInstallation() throws {
        try createRequiredAssets(at: temporaryDirectory)
        try FileManager.default.removeItem(
            at: temporaryDirectory.appendingPathComponent("lm_main.int8.onnx")
        )

        XCTAssertFalse(KokoroModelInstallationValidator.isInstalled(at: temporaryDirectory))
    }

    func testArchivePathPolicyAcceptsOnlyRequiredFilesBelowExpectedRoot() {
        let root = KokoroModelManifest.production.archiveRootName

        XCTAssertEqual(
            KokoroArchivePathPolicy.destinationRelativePath(
                for: "\(root)/lm_main.int8.onnx",
                archiveRoot: root
            ),
            "lm_main.int8.onnx"
        )
        XCTAssertEqual(
            KokoroArchivePathPolicy.destinationRelativePath(
                for: "\(root)/voices/alba.wav",
                archiveRoot: root
            ),
            "voices/alba.wav"
        )
        XCTAssertNil(
            KokoroArchivePathPolicy.destinationRelativePath(
                for: "\(root)/test_wavs/bria.wav",
                archiveRoot: root
            )
        )
        XCTAssertNil(
            KokoroArchivePathPolicy.destinationRelativePath(
                for: "\(root)/voices/nested/alba.wav",
                archiveRoot: root
            )
        )
    }

    func testArchivePathPolicyRejectsTraversalAbsoluteAndUnexpectedRoots() {
        let root = KokoroModelManifest.production.archiveRootName

        XCTAssertNil(
            KokoroArchivePathPolicy.destinationRelativePath(
                for: "\(root)/../outside.txt",
                archiveRoot: root
            )
        )
        XCTAssertNil(
            KokoroArchivePathPolicy.destinationRelativePath(
                for: "/tmp/lm_main.int8.onnx",
                archiveRoot: root
            )
        )
        XCTAssertNil(
            KokoroArchivePathPolicy.destinationRelativePath(
                for: "other-root/lm_main.int8.onnx",
                archiveRoot: root
            )
        )
    }

    private func createRequiredAssets(at root: URL) throws {
        let requiredFiles = KokoroModelInstallationValidator.requiredRelativePaths

        for relativePath in requiredFiles {
            let fileURL = root.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data([0x01]).write(to: fileURL)
        }
    }
}
