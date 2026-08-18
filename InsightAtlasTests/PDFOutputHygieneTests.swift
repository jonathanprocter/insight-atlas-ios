import XCTest
import PDFKit
@testable import InsightAtlas

/// Renders real PDF bytes and reads the text back out.
///
/// The existing PDF suites build documents and assert on the model, but never
/// render — so markup that survives into the printed page passes them all.
/// This drives the renderer end to end and inspects the actual output, which is
/// the only way to catch syntax reaching the reader.
final class PDFOutputHygieneTests: XCTestCase {

    private func renderText(_ document: PDFAnalysisDocument) throws -> String {
        let data = try InsightAtlasPDFRenderer().render(document: document).pdfData
        XCTAssertFalse(data.isEmpty, "renderer produced no PDF data")

        guard let pdf = PDFDocument(data: data) else {
            XCTFail("rendered bytes are not a readable PDF")
            return ""
        }
        XCTAssertGreaterThan(pdf.pageCount, 0, "PDF has no pages")

        return (0..<pdf.pageCount)
            .compactMap { pdf.page(at: $0)?.string }
            .joined(separator: "\n")
    }

    /// Content deliberately carrying every markup form the app has leaked at
    /// some point: bold, italics, a heading marker, an editorial tag, a table
    /// separator row, and a bare list number.
    private var markupHeavyDocument: PDFAnalysisDocument {
        PDFAnalysisDocument(
            book: .init(title: "The Narrative Therapy Workbook", author: "Brené Brown"),
            sections: [
                .init(
                    heading: "Problem Saturation",
                    headingLevel: 1,
                    blocks: [
                        PDFContentBlock(
                            type: .paragraph,
                            content: "Externalization separates **the person** from *the problem*."
                        ),
                        PDFContentBlock(
                            type: .bulletList,
                            content: "",
                            listItems: [
                                "Notice the dominant story as it arrives",
                                "Name the story rather than inhabiting it"
                            ]
                        ),
                        PDFContentBlock(
                            type: .table,
                            content: "",
                            tableData: [
                                ["Process", "Counterpart"],
                                ["Experiential avoidance", "Acceptance"]
                            ]
                        )
                    ]
                )
            ]
        )
    }

    func testRendererProducesAReadablePDF() throws {
        let text = try renderText(markupHeavyDocument)
        XCTAssertTrue(
            text.contains("Problem Saturation"),
            "section heading missing from rendered output"
        )
    }

    /// Inline emphasis markers must be consumed by the renderer, never printed.
    func testEmphasisMarkersDoNotReachThePage() throws {
        let text = try renderText(markupHeavyDocument)
        XCTAssertFalse(text.contains("**"), "bold markers printed literally in the PDF")
        XCTAssertTrue(text.contains("the person"), "bold text lost entirely")
    }

    /// Editorial tags are structure for the parser, never content.
    func testEditorialTagsDoNotReachThePage() throws {
        let text = try renderText(markupHeavyDocument)
        for tag in ["[VISUAL_", "[PREMIUM_H", "[INSIGHT_NOTE", "[ACTION_BOX", "[/"] {
            XCTAssertFalse(text.contains(tag), "\(tag) reached the rendered PDF")
        }
    }

    /// The markdown alignment row is syntax, not a table row.
    func testTableSeparatorRowIsNotPrinted() throws {
        let text = try renderText(markupHeavyDocument)
        XCTAssertFalse(text.contains("|---|"), "table separator row printed in the PDF")
        XCTAssertTrue(text.contains("Experiential avoidance"), "table content missing")
    }

    /// Accented author names must survive rendering intact.
    func testAccentedAuthorNameSurvivesRendering() throws {
        let text = try renderText(markupHeavyDocument)
        XCTAssertFalse(text.contains("BRENé"), "author name split at the accent in the PDF")
    }

    /// A list must never contain an empty or dash-only entry.
    func testNoPlaceholderListItemsAreRendered() throws {
        let document = PDFAnalysisDocument(
            book: .init(title: "Test", author: "Author"),
            sections: [
                .init(
                    heading: "Sequence",
                    headingLevel: 1,
                    blocks: [
                        PDFContentBlock(
                            type: .numberedList,
                            content: "",
                            listItems: ["Notice the critic's voice", "Locate it in the body"]
                        )
                    ]
                )
            ]
        )
        let text = try renderText(document)
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            XCTAssertFalse(
                trimmed.allSatisfy { $0 == "-" || $0 == "—" || $0 == "." },
                "a placeholder list item was rendered: \(trimmed)"
            )
        }
    }

    // MARK: - Text layer extractability

    /// Cormorant Garamond substitutes ligature glyphs for fi, fl, ff, ct and st.
    /// Those glyphs carry a broken ToUnicode mapping, so with ligatures enabled
    /// the page renders perfectly while the extractable text layer loses
    /// letters: "filed" came out "iled", "act" as "ac", "understanding" as
    /// "unders anding". That breaks PDF search, copy-paste, VoiceOver, and any
    /// downstream text analysis of the exported document.
    func testLigatureProneWordsSurviveTextExtraction() throws {
        let prone = [
            "filed", "office", "different", "affect", "fluent",
            "act", "fact", "perfect", "understanding", "still", "first"
        ]
        let sentence = prone.joined(separator: " ") + "."

        let document = PDFAnalysisDocument(
            book: .init(title: "Ligature Check", author: "Author"),
            sections: [
                .init(
                    heading: "Extraction",
                    headingLevel: 1,
                    blocks: [PDFContentBlock(type: .paragraph, content: sentence)]
                )
            ]
        )

        let text = try renderText(document)
        var missing: [String] = []
        for word in prone where !text.contains(word) {
            missing.append(word)
        }
        XCTAssertTrue(
            missing.isEmpty,
            "these words lost letters in the PDF text layer: \(missing.joined(separator: ", "))"
        )
    }

    /// A stray single letter on its own is the signature of a ligature glyph
    /// whose components were split apart during extraction.
    func testNoOrphanedSingleLettersInExtractedText() throws {
        let document = PDFAnalysisDocument(
            book: .init(title: "Ligature Check", author: "Author"),
            sections: [
                .init(
                    heading: "Extraction",
                    headingLevel: 1,
                    blocks: [
                        PDFContentBlock(
                            type: .paragraph,
                            content: "The difficult fact is that perfect understanding still acts first."
                        )
                    ]
                )
            ]
        )

        let text = try renderText(document)
        let orphans = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count == 1 && "ftisl".contains($0) }
        XCTAssertTrue(
            orphans.isEmpty,
            "orphaned letters found in the text layer: \(orphans.joined(separator: " "))"
        )
    }
}
