import XCTest
@testable import InsightAtlas

/// Locks the export gate used by every non-empty guide export path.
final class ManuscriptGateExportTests: XCTestCase {

    func testPassesCleanManuscript() throws {
        let content = """
        # Opening

        Irvin Yalom argues that the four ultimate concerns organize therapy.
        In summary, the guide closes cleanly.
        """
        let prepared = try ManuscriptGate.prepareForExport(content, title: "T", author: "A")
        XCTAssertFalse(prepared.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func testBlocksMidSentenceTruncation() {
        let truncated = "The therapeutic crisis peaks when Saul's depression becomes psychotic and he takes to his"
        XCTAssertThrowsError(
            try ManuscriptGate.prepareForExport(truncated, title: "T", author: "A")
        ) { error in
            XCTAssertTrue(error is ManuscriptGate.GateError)
        }
    }

    func testRepairsSafeDefectsBeforeExport() throws {
        // Soft hyphens + missing sentence space are normalized before the hard gate.
        let dirty = "self\u{00AD}constructed. them.The next idea stands complete. In summary, done."
        let prepared = try ManuscriptGate.prepareForExport(dirty, title: "T", author: "A")
        XCTAssertFalse(prepared.contains("\u{00AD}"))
        XCTAssertTrue(prepared.contains("them. The"))
    }
}
