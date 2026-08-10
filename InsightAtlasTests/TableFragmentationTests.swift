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
        // header + 3 data rows (< 4) can never make two ≥2-row groups → push whole.
        let renderer = PDFContentBlockRenderer()
        let width = PDFStyleConfiguration.PageLayout.contentWidth
        let t = table(rows: 3)
        let frags = renderer.planTableFragments(tableData: t, maxWidth: width, firstBudget: 100, pageBudget: 100)
        XCTAssertNil(frags, "A 3-data-row table must push whole, never orphan a single-row runt")
    }
}
