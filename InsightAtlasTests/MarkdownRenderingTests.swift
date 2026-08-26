import XCTest
import SwiftUI
import ZIPFoundation
@testable import InsightAtlas

/// Inline markdown and bare markdown tables reached readers with their syntax
/// intact: asterisks printed literally, and table rows collapsed into one run
/// of prose because the paragraph accumulator joins its lines with spaces.
final class MarkdownRenderingTests: XCTestCase {

    private func plainText(_ attributed: AttributedString) -> String {
        String(attributed.characters)
    }

    // MARK: - Inline emphasis

    func testBoldMarkersAreConsumed() {
        let result = plainText(parseMarkdownBold("This is **important** text"))
        XCTAssertEqual(result, "This is important text")
        XCTAssertFalse(result.contains("*"))
    }

    /// The reported bug: single-asterisk italics printed their markers.
    func testItalicMarkersAreConsumed() {
        let result = plainText(parseMarkdownBold("The word *arbitrary* matters"))
        XCTAssertEqual(result, "The word arbitrary matters")
        XCTAssertFalse(result.contains("*"))
    }

    func testUnderscoreItalicMarkersAreConsumed() {
        let result = plainText(parseMarkdownBold("The word _arbitrary_ matters"))
        XCTAssertEqual(result, "The word arbitrary matters")
        XCTAssertFalse(result.contains("_"))
    }

    func testBoldAndItalicTogether() {
        let result = plainText(parseMarkdownBold("**Bold** and *italic* together"))
        XCTAssertEqual(result, "Bold and italic together")
    }

    /// Bold must not be shredded into two italics by the single-asterisk pass.
    func testBoldIsNotMisreadAsItalic() {
        XCTAssertEqual(plainText(parseMarkdownBold("**strong**")), "strong")
    }

    /// Underscores inside identifiers are not emphasis.
    func testIntraWordUnderscoresSurvive() {
        let result = plainText(parseMarkdownBold("Use VISUAL_TABLE not a raw grid"))
        XCTAssertEqual(result, "Use VISUAL_TABLE not a raw grid")
    }

    func testMultiplicationAsteriskIsNotEmphasis() {
        let result = plainText(parseMarkdownBold("Rows * columns = cells"))
        XCTAssertEqual(result, "Rows * columns = cells")
    }

    func testLinksCodeImagesAndStrikethroughRenderWithoutSyntax() {
        let result = plainText(parseMarkdownBold(
            "Use [acceptance](https://example.com), `noticing`, ![a compass](compass.png), and ~~control~~."
        ))

        XCTAssertEqual(result, "Use acceptance, noticing, a compass, and control.")
        for syntax in ["[", "](", "`", "![", "~~"] {
            XCTAssertFalse(result.contains(syntax), "reader retained presentation syntax: \(syntax)")
        }
    }

    // MARK: - Table row detection

    func testFullyDelimitedRowIsATable() {
        XCTAssertTrue(ContentBlockParser.isTableRow("| A | B | C |"))
    }

    /// Generated tables regularly omit the trailing pipe.
    func testRowWithoutTrailingPipeIsATable() {
        XCTAssertTrue(ContentBlockParser.isTableRow("| A | B | C"))
    }

    /// ...or the edge pipes entirely.
    func testRowWithoutEdgePipesIsATable() {
        XCTAssertTrue(ContentBlockParser.isTableRow("A | B | C"))
    }

    func testSeparatorRowIsRecognized() {
        XCTAssertTrue(ContentBlockParser.isTableSeparatorRow("|---|---|"))
        XCTAssertTrue(ContentBlockParser.isTableSeparatorRow("| :--- | ---: |"))
        XCTAssertTrue(ContentBlockParser.isTableRow("|---|---|"))
    }

    /// A sentence with one pipe is prose, not a table.
    func testSinglePipeSentenceIsNotATable() {
        XCTAssertFalse(ContentBlockParser.isTableRow("Willingness | acceptance is the aim."))
    }

    func testEmptyLineIsNotATable() {
        XCTAssertFalse(ContentBlockParser.isTableRow(""))
        XCTAssertFalse(ContentBlockParser.isTableRow("   "))
    }

    func testProseWithoutPipesIsNotATable() {
        XCTAssertFalse(ContentBlockParser.isTableRow("Experiential avoidance is the core process."))
    }

    // MARK: - End to end

    /// The exact reported shape: a bare markdown table must become a table
    /// block, not a paragraph.
    func testBareMarkdownTableBecomesATableBlock() {
        let content = """
        Some framing prose.

        | Pathological Process | Therapeutic Counterpart | Core Mechanism |
        |---|---|---|
        | Experiential avoidance | Acceptance and willingness | Willing contact |
        | Cognitive fusion | Cognitive defusion | Thoughts as mental events |

        Closing prose.
        """

        let blocks = ContentBlockParser.parse(content)
        let tables = blocks.filter { $0.type == .table }
        XCTAssertEqual(tables.count, 1, "the markdown table should produce exactly one table block")

        let rows = tables.first?.tableData ?? []
        XCTAssertEqual(rows.count, 3, "header plus two data rows, separator dropped")
        XCTAssertEqual(rows.first?.count, 3)
        XCTAssertEqual(rows.first?.first, "Pathological Process")

        // And the table text must not have leaked into a paragraph.
        let paragraphs = blocks.filter { $0.type == .paragraph }.map(\.content).joined(separator: " ")
        XCTAssertFalse(paragraphs.contains("Experiential avoidance"))
    }

    func testTableWithoutEdgePipesAlsoBecomesATable() {
        let content = """
        Process | Counterpart
        Avoidance | Acceptance
        Fusion | Defusion
        """
        let tables = ContentBlockParser.parse(content).filter { $0.type == .table }
        XCTAssertEqual(tables.count, 1)
        XCTAssertEqual(tables.first?.tableData.count, 3)
    }

    /// One pipe-bearing line on its own stays prose rather than becoming a
    /// one-row table.
    func testLoneRowStaysProse() {
        let blocks = ContentBlockParser.parse("Cost | benefit thinking dominates here.")
        XCTAssertTrue(blocks.filter { $0.type == .table }.isEmpty)
    }

    // MARK: - Bracket residue

    /// The reported artifact: a lone "[" and "]" separated by a blank line,
    /// printed above a heading.
    func testStrayBracketLinesAreNotRendered() {
        let content = """
        [

        ]

        # The Failure Mode of Control

        Body prose follows.
        """
        let blocks = ContentBlockParser.parse(content)
        let text = blocks.map { $0.content }.joined(separator: " ")
        XCTAssertFalse(text.contains("["), "a stray opening bracket reached the reader")
        XCTAssertFalse(text.contains("]"), "a stray closing bracket reached the reader")
        XCTAssertTrue(
            blocks.contains { $0.content == "The Failure Mode of Control" },
            "the heading after the residue must still render"
        )
    }

    func testBracketResidueLineDetection() {
        XCTAssertTrue(ContentBlockParser.isBracketResidueLine("["))
        XCTAssertTrue(ContentBlockParser.isBracketResidueLine("]"))
        XCTAssertTrue(ContentBlockParser.isBracketResidueLine("  [ ]  "))
        XCTAssertTrue(ContentBlockParser.isBracketResidueLine("![]()"))
        XCTAssertFalse(ContentBlockParser.isBracketResidueLine("[sic]"))
        XCTAssertFalse(ContentBlockParser.isBracketResidueLine("Ordinary prose."))
        XCTAssertFalse(ContentBlockParser.isBracketResidueLine(""))
    }

    func testEmptyBracketPairIsStrippedFromProse() {
        XCTAssertEqual(
            ContentBlockParser.strippedOrphanEditorialTags("Before [] after"),
            "Before after"
        )
        XCTAssertEqual(
            ContentBlockParser.strippedOrphanEditorialTags("Before [  ] after"),
            "Before after"
        )
    }

    func testEmptyMarkdownLinksAndImagesAreStripped() {
        XCTAssertEqual(
            ContentBlockParser.strippedOrphanEditorialTags("Cover ![](cover.jpg) here"),
            "Cover here"
        )
        XCTAssertEqual(
            ContentBlockParser.strippedOrphanEditorialTags("Link []() here"),
            "Link here"
        )
    }

    /// Real citations and bracketed asides must survive all of the above.
    func testMeaningfulBracketsSurvive() {
        XCTAssertEqual(
            ContentBlockParser.strippedOrphanEditorialTags("The author [sic] argues [1]."),
            "The author [sic] argues [1]."
        )
    }
}

final class ExportContentHygieneTests: XCTestCase {
    private let source = """
    # Practice Guide

    Use **core** skills, *acceptance*, _willingness_, `noticing`, and ~~control~~.
    Read [the source](https://example.com) and inspect ![a compass](compass.png).
    Before [RESEARCH_INSIGHT]the evidence[/RESEARCH_INSIGHT] after.
    Malformed **unfinished emphasis, ~~revised language, and `noticing remain readable.

    | Process | Response |
    |---|---|
    | Fusion | Defusion |

    - First step
    - Second step

    ## Final Takeaway

    Carry the insight forward.
    """

    private var item: InsightAtlas.LibraryItem {
        InsightAtlas.LibraryItem(
            title: "Export Hygiene",
            author: "Test Author",
            fileType: .pdf,
            summaryContent: source
        )
    }

    private let forbiddenSyntax = [
        "**core**", "*acceptance*", "_willingness_", "`noticing`", "~~control~~",
        "[the source](", "![a compass](", "[RESEARCH_INSIGHT]", "[/RESEARCH_INSIGHT]",
        "|---|---|", "| Process | Response |", "**unfinished", "~~revised", "`noticing"
    ]

    private func assertSemanticTextSurvives(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        for expected in ["Practice Guide", "core", "acceptance", "willingness", "noticing", "control", "the source", "a compass", "the evidence", "unfinished emphasis", "revised language", "Fusion", "Defusion", "Final Takeaway"] {
            XCTAssertTrue(text.contains(expected), "lost semantic export text: \(expected)", file: file, line: line)
        }
    }

    private func assertNoPresentationSyntax(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        for syntax in forbiddenSyntax {
            XCTAssertFalse(text.contains(syntax), "export retained presentation syntax: \(syntax)", file: file, line: line)
        }
    }

    func testMarkdownNamedExportContainsReadableTextNotMarkdownSyntax() throws {
        let url = try DataManager.shared.exportGuide(item, format: .markdown)
        defer { try? FileManager.default.removeItem(at: url) }

        let text = try String(contentsOf: url, encoding: .utf8)
        assertSemanticTextSurvives(text)
        assertNoPresentationSyntax(text)
    }

    func testPlainTextExportContainsNoMarkdownSyntax() throws {
        let url = try DataManager.shared.exportGuide(item, format: .plainText)
        defer { try? FileManager.default.removeItem(at: url) }

        let text = try String(contentsOf: url, encoding: .utf8)
        assertSemanticTextSurvives(text)
        assertNoPresentationSyntax(text)
    }

    func testHTMLExportConvertsSyntaxWithoutDisplayingMarkers() throws {
        let url = try DataManager.shared.exportGuide(item, format: .html)
        defer { try? FileManager.default.removeItem(at: url) }

        let html = try String(contentsOf: url, encoding: .utf8)
        assertSemanticTextSurvives(html)
        assertNoPresentationSyntax(html)
        XCTAssertTrue(html.contains("<strong>core</strong>"))
        XCTAssertTrue(html.contains("<code>noticing</code>"))
        XCTAssertTrue(html.contains("<a href=\"https://example.com\">the source</a>"))
        XCTAssertTrue(html.contains("a compass"), "image alt text should remain accessible")
    }

    func testDOCXExportDocumentXMLContainsNoMarkdownSyntax() throws {
        let url = try DataManager.shared.exportGuide(item, format: .docx)
        defer { try? FileManager.default.removeItem(at: url) }

        guard let archive = try? Archive(url: url, accessMode: .read),
              let entry = archive.first(where: { $0.path.hasSuffix("word/document.xml") }) else {
            return XCTFail("DOCX did not contain word/document.xml")
        }

        var data = Data()
        _ = try archive.extract(entry) { data.append($0) }
        guard let xml = String(data: data, encoding: .utf8) else {
            return XCTFail("word/document.xml was not UTF-8")
        }

        assertSemanticTextSurvives(xml)
        assertNoPresentationSyntax(xml)
    }
}
