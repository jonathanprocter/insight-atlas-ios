import XCTest
@testable import InsightAtlas

/// Synthetic exercise of the table fragmentation path — forces an 8-row table to
/// split in a controlled build so the row-atomic / header-repeat / floor /
/// measure==draw / column-alignment logic runs before it fires in the wild.
/// Cells are short (single-line rows) so heights are font-independent and ≥2
/// rows always fit per fragment; the test asserts structure, not exact counts.
final class TableFragmentationTests: XCTestCase {

    private func table(rows n: Int) -> [[String]] {
        var rows: [[String]] = [["Dim", "Control", "Commit"]]
        for i in 1...n { rows.append(["R\(i)a", "R\(i)b", "R\(i)c"]) }
        return rows
    }

    func testTableSplitsRowAtomicWithRepeatedHeader() {
        let renderer = PDFContentBlockRenderer()
        let width = PDFStyleConfiguration.PageLayout.contentWidth
        let t = table(rows: 8)
        // Small budget forces multiple fragments; short rows guarantee ≥2 fit.
        let frags = renderer.planTableFragments(tableData: t, maxWidth: width, firstBudget: 200, pageBudget: 200)

        XCTAssertNotNil(frags, "An 8-row table must be splittable at a 200pt budget")
        guard let frags else { return }
        XCTAssertGreaterThanOrEqual(frags.count, 2)

        let header = t[0]
        var dataRowsSeen = 0
        for f in frags {
            XCTAssertEqual(f.rows.first, header, "Fragment row 0 must be the repeated header")
            XCTAssertEqual(f.rows.dropFirst().filter { $0 == header }.count, 0, "Header appears exactly once, not duplicated in data")
            XCTAssertGreaterThanOrEqual(f.rows.count - 1, 2, "Each fragment carries ≥2 data rows")
            XCTAssertEqual(f.rows.first?.count, header.count, "Column count identical across fragments")
            XCTAssertGreaterThan(f.plannedHeight, 0)
            dataRowsSeen += f.rows.count - 1
        }
        XCTAssertEqual(dataRowsSeen, t.count - 1, "All data rows partitioned exactly once, none lost or duplicated")
    }

    func testSmallTableDoesNotSplit() {
        // Short rows: any single-row group is a runt below the height floor
        // (max(120, 30) = 120pt), so a 3-short-row table still pushes whole.
        let renderer = PDFContentBlockRenderer()
        let width = PDFStyleConfiguration.PageLayout.contentWidth
        let t = table(rows: 3)
        let frags = renderer.planTableFragments(tableData: t, maxWidth: width, firstBudget: 100, pageBudget: 100)
        XCTAssertNil(frags, "A short-rowed 3-data-row table must push whole, never orphan a single-row runt")
    }

    /// Regression for the 2402pt-table bug: a table whose rows are each too tall
    /// to pair (only one fits per page) must still FRAGMENT — one tall row per
    /// card, header repeated — instead of being rejected and pushed whole to
    /// overflow the page by multiples. The height-aware floor accepts a single
    /// row that is tall enough to be a card on its own.
    private func tallTable(rows n: Int) -> [[String]] {
        let para = String(repeating: "This cell holds a long paragraph that wraps across many lines to force a tall row. ", count: 6)
        var rows: [[String]] = [["Dimension", "Control Story", "Commitment Story"]]
        for i in 1...n { rows.append(["Row \(i) axis", para, para]) }
        return rows
    }

    func testTallRowsFragmentOnePerCardInsteadOfPushingWhole() {
        let renderer = PDFContentBlockRenderer()
        let width = PDFStyleConfiguration.PageLayout.contentWidth
        let t = tallTable(rows: 4)
        // Page budget only fits ~one tall row + chrome → greedy yields 1 row/group.
        // (Each data row here is a 6× wrapped paragraph, comfortably > 120pt, so
        // it would have been rejected as a runt under the old ≥2-rows floor.)
        let frags = renderer.planTableFragments(tableData: t, maxWidth: width, firstBudget: 320, pageBudget: 320)
        XCTAssertNotNil(frags, "A tall-rowed table must fragment, not push whole and overflow")
        guard let frags else { return }
        XCTAssertGreaterThanOrEqual(frags.count, 2)

        let header = t[0]
        var dataRowsSeen = 0
        for f in frags {
            XCTAssertEqual(f.rows.first, header, "Header repeats as row 0 of every fragment")
            XCTAssertGreaterThan(f.plannedHeight, 0)
            dataRowsSeen += f.rows.count - 1
        }
        XCTAssertEqual(dataRowsSeen, t.count - 1, "All data rows partitioned exactly once")
    }
}
