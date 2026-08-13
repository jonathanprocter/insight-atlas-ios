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

        XCTAssertEqual(manifest.version, "kokoro-int8-multi-lang-v1_0")
        XCTAssertEqual(
            manifest.downloadURL.absoluteString,
            "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-int8-multi-lang-v1_0.tar.bz2"
        )
        XCTAssertEqual(manifest.archiveByteCount, 131_839_838)
        XCTAssertEqual(
            manifest.sha256,
            "75654a84864be26f345f020f4070c2c019e96dd1b7f9bf6e2ffd59efac6aa5a3"
        )
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
            at: temporaryDirectory.appendingPathComponent("voices.bin")
        )

        XCTAssertFalse(KokoroModelInstallationValidator.isInstalled(at: temporaryDirectory))
    }

    func testArchivePathPolicyAcceptsOnlyRequiredFilesBelowExpectedRoot() {
        let root = KokoroModelManifest.production.archiveRootName

        XCTAssertEqual(
            KokoroArchivePathPolicy.destinationRelativePath(
                for: "\(root)/model.int8.onnx",
                archiveRoot: root
            ),
            "model.int8.onnx"
        )
        XCTAssertEqual(
            KokoroArchivePathPolicy.destinationRelativePath(
                for: "\(root)/espeak-ng-data/phondata",
                archiveRoot: root
            ),
            "espeak-ng-data/phondata"
        )
        XCTAssertNil(
            KokoroArchivePathPolicy.destinationRelativePath(
                for: "\(root)/dict/jieba.dict.utf8",
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
                for: "/tmp/model.int8.onnx",
                archiveRoot: root
            )
        )
        XCTAssertNil(
            KokoroArchivePathPolicy.destinationRelativePath(
                for: "other-root/model.int8.onnx",
                archiveRoot: root
            )
        )
    }

    private func createRequiredAssets(at root: URL) throws {
        let requiredFiles = [
            "model.int8.onnx",
            "voices.bin",
            "tokens.txt",
            "lexicon-us-en.txt",
            "lexicon-gb-en.txt",
            "LICENSE",
            "espeak-ng-data/phondata"
        ]

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
