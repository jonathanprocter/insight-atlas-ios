import XCTest
@testable import InsightAtlas

/// Tests for the additive structure pass (Phase 6 — §C1 reading chips, §B5 pull quotes).
final class PDFRedesignPhase6StructureTests: XCTestCase {

    private func doc(_ sections: [PDFAnalysisDocument.PDFSection]) -> PDFAnalysisDocument {
        PDFAnalysisDocument(book: .init(title: "T", author: "A"), sections: sections)
    }

    private func themeSection(_ n: Int, paragraph: String) -> PDFAnalysisDocument.PDFSection {
        .init(heading: "Theme \(n): Sample", headingLevel: 1,
              blocks: [PDFContentBlock(type: .paragraph, content: paragraph)])
    }

    func testThemeGetsReadingChipWithProgress() {
        let input = doc([
            themeSection(1, paragraph: "A short body."),
            themeSection(2, paragraph: "Another short body.")
        ])
        let out = DocumentStructureEnhancer().enhance(input)

        let chip = out.sections[0].blocks.first
        XCTAssertEqual(chip?.type, .readingChip)
        XCTAssertEqual(chip?.metadata?["progress"], "Theme 1 of 2")
        XCTAssertNotNil(chip?.metadata?["readingTime"])
        XCTAssertEqual(out.sections[1].blocks.first?.metadata?["progress"], "Theme 2 of 2")
    }

    func testPullQuoteInsertedFromQuotableSentence() {
        let sentence = "Defusion is most valuable when the mind ceases to hold an automatic veto over a meaningful life"
        let input = doc([themeSection(1, paragraph: sentence + ". A trailing note follows here.")])
        let out = DocumentStructureEnhancer().enhance(input)

        let quotes = out.sections[0].blocks.filter { $0.type == .premiumQuote && $0.metadata?["pullQuote"] == "true" }
        XCTAssertEqual(quotes.count, 1)
        XCTAssertTrue(quotes.first?.content.contains("automatic veto") ?? false)
        // The original paragraph is preserved (additive, never mutated).
        XCTAssertTrue(out.sections[0].blocks.contains { $0.type == .paragraph && $0.content.contains("automatic veto") })
    }

    func testNonThemeSectionUntouched() {
        let input = doc([.init(heading: "Strategic Briefing", headingLevel: 1,
                               blocks: [PDFContentBlock(type: .paragraph, content: "Briefing.")])])
        let out = DocumentStructureEnhancer().enhance(input)
        XCTAssertEqual(out.sections[0].blocks.count, 1)
        XCTAssertEqual(out.sections[0].blocks.first?.type, .paragraph)
    }

    func testNoPullQuoteWhenNoQuotableSentence() {
        // All sentences too short to qualify.
        let input = doc([themeSection(1, paragraph: "Too short. Also short. Tiny.")])
        let out = DocumentStructureEnhancer().enhance(input)
        XCTAssertFalse(out.sections[0].blocks.contains { $0.type == .premiumQuote })
        // Reading chip is still added.
        XCTAssertEqual(out.sections[0].blocks.first?.type, .readingChip)
    }
}
