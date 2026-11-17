import XCTest
@testable import InsightAtlas

final class SourceTextStoreTests: XCTestCase {

    private var tempRoot: URL!
    private var fileManager: FileManager!

    override func setUpWithError() throws {
        fileManager = .default
        tempRoot = fileManager.temporaryDirectory
            .appendingPathComponent("SourceTextStoreTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fileManager.removeItem(at: tempRoot)
        tempRoot = nil
    }

    func testSaveLoadExistsAndDelete() {
        let id = UUID()
        // Point store at temp by using real Documents — these tests use the
        // production Documents/sources path but unique IDs so they do not clash.
        XCTAssertFalse(SourceTextStore.exists(id))
        XCTAssertTrue(SourceTextStore.save("Chapter one of the manuscript.", for: id))
        XCTAssertTrue(SourceTextStore.exists(id))
        XCTAssertEqual(SourceTextStore.load(id), "Chapter one of the manuscript.")
        SourceTextStore.delete(id)
        XCTAssertFalse(SourceTextStore.exists(id))
        XCTAssertNil(SourceTextStore.load(id))
    }

    func testEmptySaveRejected() {
        let id = UUID()
        XCTAssertFalse(SourceTextStore.save("   \n  ", for: id))
        XCTAssertFalse(SourceTextStore.exists(id))
    }

    func testPruneOrphans() {
        let keep = UUID()
        let drop = UUID()
        XCTAssertTrue(SourceTextStore.save("keep", for: keep))
        XCTAssertTrue(SourceTextStore.save("drop", for: drop))
        SourceTextStore.pruneOrphans(keeping: [keep])
        XCTAssertTrue(SourceTextStore.exists(keep))
        XCTAssertFalse(SourceTextStore.exists(drop))
        SourceTextStore.delete(keep)
    }
}

final class NarrationVisualSpeechScrubberTests: XCTestCase {
    func testRemovesDiagramTalk() {
        let input = "As you can see, the diagram shows the loop. Meanwhile the thesis holds."
        let output = NarrationVisualSpeechScrubber.scrub(input)
        XCTAssertFalse(output.lowercased().contains("as you can see"))
        XCTAssertFalse(output.lowercased().contains("the diagram shows"))
        XCTAssertTrue(output.lowercased().contains("thesis holds"))
    }
}

final class NarrationPreparationPolicyTests: XCTestCase {
    func testListeningEditionSpeaksFirst() {
        XCTAssertFalse(
            NarrationPreparationPolicy.rewritesBeforeInitialSynthesis,
            "First listen must not block on MiniMax rewrite"
        )
    }
}
