import XCTest
@testable import InsightAtlas

/// Guide bodies moved out of UserDefaults into files. The store must never lose
/// a guide: losing one destroys work the user cannot regenerate identically.
final class GuideBodyStoreTests: XCTestCase {

    private var ids: [UUID] = []

    override func tearDown() {
        ids.forEach { GuideBodyStore.delete($0) }
        ids = []
        super.tearDown()
    }

    private func freshID() -> UUID {
        let id = UUID()
        ids.append(id)
        return id
    }

    func testRoundTrip() {
        let id = freshID()
        let body = "# A Guide\n\nWith several paragraphs of real content."
        XCTAssertTrue(GuideBodyStore.save(body, for: id))
        XCTAssertEqual(GuideBodyStore.load(id), body)
    }

    func testMissingBodyReadsAsNil() {
        XCTAssertNil(GuideBodyStore.load(freshID()))
    }

    func testOverwriteReplacesEntirely() {
        let id = freshID()
        GuideBodyStore.save(String(repeating: "long original content. ", count: 200), for: id)
        GuideBodyStore.save("short", for: id)
        XCTAssertEqual(GuideBodyStore.load(id), "short", "stale bytes survived the overwrite")
    }

    func testDeleteRemovesTheBody() {
        let id = freshID()
        GuideBodyStore.save("body", for: id)
        GuideBodyStore.delete(id)
        XCTAssertNil(GuideBodyStore.load(id))
    }

    /// Unicode and newlines must survive: guides carry em dashes, curly quotes
    /// and accented author names.
    func testUnicodeAndStructureSurvive() {
        let id = freshID()
        let body = "Brené Brown — “vulnerability” is not weakness.\n\n• A bullet\n\n\tIndented."
        GuideBodyStore.save(body, for: id)
        XCTAssertEqual(GuideBodyStore.load(id), body)
    }

    func testLargeBodySurvives() {
        let id = freshID()
        let body = String(repeating: "A sentence of guide prose that repeats. ", count: 5_000)
        XCTAssertTrue(GuideBodyStore.save(body, for: id))
        XCTAssertEqual(GuideBodyStore.load(id)?.count, body.count)
    }

    /// Pruning must remove only bodies with no library item, never a live one.
    func testPruningKeepsLiveBodiesAndRemovesOrphans() {
        let live = freshID()
        let orphan = freshID()
        GuideBodyStore.save("live body", for: live)
        GuideBodyStore.save("orphan body", for: orphan)

        GuideBodyStore.pruneOrphans(keeping: [live])

        XCTAssertEqual(GuideBodyStore.load(live), "live body", "a live guide body was pruned")
        XCTAssertNil(GuideBodyStore.load(orphan), "an orphaned body survived pruning")
    }

    /// An empty body is indistinguishable from no body and must not resurrect
    /// as an empty guide.
    func testEmptyBodyReadsAsNil() {
        let id = freshID()
        GuideBodyStore.save("", for: id)
        XCTAssertNil(GuideBodyStore.load(id))
    }
}
