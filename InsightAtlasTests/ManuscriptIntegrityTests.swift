import XCTest
@testable import InsightAtlas

/// Track A acceptance fixtures. Locks the manufacturing-integrity layer:
/// `ManuscriptNormalizer` (safe repairs) and `ManuscriptPreflight` (hard
/// pass/fail). Fixtures mirror the defects observed in the Love's Executioner
/// export audit.
final class ManuscriptIntegrityTests: XCTestCase {

    // MARK: - A1 · Normalizer (safe repairs)

    func testRepairsCorruptedHyphenBetweenWords() {
        // Both soft-hyphen and replacement-character corruptions become a real
        // hyphen when they sit inside a hyphenated compound.
        XCTAssertEqual(ManuscriptNormalizer.normalize("self\u{00AD}constructed"), "self-constructed")
        XCTAssertEqual(ManuscriptNormalizer.normalize("self\u{FFFD}constructed"), "self-constructed")
        XCTAssertEqual(ManuscriptNormalizer.normalize("here-and\u{FFFD}now"), "here-and-now")
        XCTAssertEqual(ManuscriptNormalizer.normalize("participant\u{00AD}observer"), "participant-observer")
    }

    func testStripsZeroWidthAndDanglingHyphens() {
        // BOM/zero-width always removed; a discretionary hyphen not flanked by
        // word characters is dropped rather than turned into a stray dash.
        XCTAssertEqual(ManuscriptNormalizer.normalize("word\u{FEFF}"), "word")
        XCTAssertEqual(ManuscriptNormalizer.normalize("end\u{00AD} next"), "end next")
    }

    func testRepairsMissingSentenceSpace() {
        XCTAssertEqual(
            ManuscriptNormalizer.normalize("open them.The therapeutic"),
            "open them. The therapeutic"
        )
    }

    func testLeavesInitialsAndAcronymsUntouched() {
        // Uppercase-before means no false split of "D.Y" or "U.S.".
        XCTAssertEqual(ManuscriptNormalizer.normalize("Irvin D.Yalom"), "Irvin D.Yalom")
        XCTAssertEqual(ManuscriptNormalizer.normalize("the U.S.Army"), "the U.S.Army")
    }

    func testCanonicalNameCorrection() {
        XCTAssertEqual(ManuscriptNormalizer.normalize("as Irving Yalom argues"), "as Irvin Yalom argues")
        XCTAssertEqual(ManuscriptNormalizer.normalize("Irving D. Yalom"), "Irvin D. Yalom")
    }

    func testDoesNotRewriteDifferentPerson() {
        // Exact-string table must not touch a legitimately different name.
        XCTAssertEqual(ManuscriptNormalizer.normalize("Marilyn Yalom"), "Marilyn Yalom")
    }

    func testNormalizationIsIdempotent() {
        let input = "self\u{00AD}constructed. them.The Irving Yalom\u{FEFF}"
        let once = ManuscriptNormalizer.normalize(input)
        XCTAssertEqual(ManuscriptNormalizer.normalize(once), once)
    }

    // MARK: - A2 · Preflight (hard pass/fail)

    func testBlocksMidSentenceTruncation() {
        // The Saul-section defect: ends mid-clause.
        let content = "The therapeutic crisis peaks when Saul's depression becomes psychotic and he takes to his"
        let report = ManuscriptPreflight.inspect(content: content)
        XCTAssertFalse(report.passed)
        XCTAssertTrue(report.errors.contains { $0.category == .truncation })
    }

    func testBlocksBrandStringInBody() {
        let content = """
        The four ultimate concerns organize the book.
        Where the weight of understanding becomes the clarity to act.
        """
        let report = ManuscriptPreflight.inspect(content: content)
        XCTAssertFalse(report.passed)
        XCTAssertTrue(report.errors.contains { $0.category == .brandInBody })
    }

    func testBlocksSurvivingProhibitedGlyph() {
        let report = ManuscriptPreflight.inspect(content: "self\u{FFFD}constructed. In summary, done.")
        XCTAssertTrue(report.errors.contains { $0.category == .prohibitedGlyph })
    }

    func testBlocksSurvivingMissingSpace() {
        let report = ManuscriptPreflight.inspect(content: "open them.The therapeutic crisis resolved.")
        XCTAssertTrue(report.errors.contains { $0.category == .missingSpace })
    }

    func testBlocksNonCanonicalName() {
        let report = ManuscriptPreflight.inspect(content: "Irving Yalom wrote this. In summary, done.")
        XCTAssertTrue(report.errors.contains { $0.category == .nonCanonicalName })
    }

    func testCleanNormalizedManuscriptPasses() {
        // A manuscript that has been through the normalizer and ends with a
        // closing element should pass the gate.
        let raw = """
        [PREMIUM_H1]Isolation[/PREMIUM_H1]
        Yalom distinguishes loneliness from a more radical separateness.
        [TAKEAWAYS]
        The distance intimacy cannot abolish remains, and that is the point.
        [/TAKEAWAYS]
        """
        let report = ManuscriptPreflight.inspect(content: ManuscriptNormalizer.normalize(raw))
        XCTAssertTrue(report.passed, "Unexpected errors: \(report.errors)")
    }

    func testNormalizeThenInspectClearsRepairableDefects() {
        // End-to-end: the export path normalizes first, so repairable defects
        // (glyphs, spaces, names) must NOT survive to become gate errors.
        let raw = "Irving Yalom on the self\u{00AD}constructed prison. them.The end. In summary, complete."
        let report = ManuscriptPreflight.inspect(content: ManuscriptNormalizer.normalize(raw))
        XCTAssertFalse(report.errors.contains { $0.category == .prohibitedGlyph })
        XCTAssertFalse(report.errors.contains { $0.category == .missingSpace })
        XCTAssertFalse(report.errors.contains { $0.category == .nonCanonicalName })
    }
}
