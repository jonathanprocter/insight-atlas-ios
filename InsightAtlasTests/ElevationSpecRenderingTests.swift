import XCTest
import PDFKit
@testable import InsightAtlas

/// Renderer-side guarantees from the elevation spec, checked on real PDF
/// bytes: layout-verified table-of-contents page numbers, no intra-word
/// breaks in table cells, paragraphs that continue across pages instead of
/// leaving half a page blank, float-ahead around atomic blocks, the running
/// header, and figure/table captions that carry the descriptive title.
final class ElevationSpecRenderingTests: XCTestCase {

    private func render(_ document: PDFAnalysisDocument) throws -> PDFDocument {
        let data = try InsightAtlasPDFRenderer().render(document: document).pdfData
        guard let pdf = PDFDocument(data: data) else {
            XCTFail("not a readable PDF"); return PDFDocument()
        }
        return pdf
    }

    private func pageTexts(_ pdf: PDFDocument, dumpAs name: String? = nil) -> [String] {
        let texts = (0..<pdf.pageCount).map { pdf.page(at: $0)?.string ?? "" }
        if let name {
            let dir = URL(fileURLWithPath: "/private/tmp/insightatlas-elevation")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dump = texts.enumerated().map { "===== PAGE \($0.offset + 1) =====\n\($0.element)" }.joined(separator: "\n")
            try? dump.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        return texts
    }

    private func longParagraph(_ seed: String, sentences: Int) -> String {
        (0..<sentences).map { "\(seed) sentence \($0 + 1) carries the argument one step further than the one before it." }.joined(separator: " ")
    }

    private var sectionedDocument: PDFAnalysisDocument {
        var sections: [PDFAnalysisDocument.PDFSection] = []
        for n in 1...6 {
            var blocks: [PDFContentBlock] = []
            for p in 1...5 {
                blocks.append(PDFContentBlock(type: .paragraph, content: longParagraph("Section \(n) paragraph \(p)", sentences: 9)))
            }
            sections.append(.init(heading: "\(n). Theme Number \(n)", headingLevel: 2, descriptor: "What theme \(n) answers", blocks: blocks))
        }
        return PDFAnalysisDocument(book: .init(title: "Nineteen Ways of Looking at Consciousness", author: "Patrick House"), sections: sections)
    }

    func testTableOfContentsPageNumbersMatchWhereHeadingsLand() throws {
        let pdf = try render(sectionedDocument)
        let texts = pageTexts(pdf, dumpAs: "sectioned-toc.txt")
        let contents = texts.first { $0.hasPrefix("Contents") } ?? ""
        XCTAssertFalse(contents.isEmpty, "no Contents page")
        // PDFKit extracts each row's right-hand "N min  <page>" cell as its
        // own line, in row order; pair them with the titles in order.
        let minuteRows = contents.components(separatedBy: "\n")
            .compactMap { line -> Int? in
                guard let m = line.range(of: #"\d+\s*min\s+(\d+)\s*$"#, options: .regularExpression) else { return nil }
                return Int(String(line[m]).split(whereSeparator: { !$0.isNumber }).last ?? "")
            }
        XCTAssertEqual(minuteRows.count, 6, "expected one minutes/page cell per section row: \(contents)")
        for n in 1...6 {
            let title = "\(n). Theme Number \(n)"
            XCTAssertTrue(contents.contains(title), "Contents has no row for \(title)")
            let listed = n - 1 < minuteRows.count ? minuteRows[n - 1] : -1
            let actual = texts.enumerated().first { index, text in
                index > 1 && text.contains(title) && text.contains("What theme \(n) answers")
            }.map { $0.offset + 1 } ?? -2
            XCTAssertEqual(listed, actual, "Contents says \(title) is on page \(listed) but it is on \(actual)")
        }
        XCTAssertTrue(contents.contains("What theme 1 answers"), "descriptor line missing from Contents")
        XCTAssertTrue(contents.contains("min"), "per-section minutes missing from Contents")
    }

    func testTableCellsNeverBreakInsideAWord() throws {
        let table = PDFContentBlock(
            type: .table, content: "",
            metadata: ["title": "The five frameworks compared on what they explain and what they miss"],
            tableData: [
                ["Theory", "What consciousness is", "Where it lives", "Hard problem stance", "Fails to explain"],
                ["Predictive processing", "Compression of predictions", "Entire cortical hierarchy", "Dissolved", "Phenomenal character"],
                ["IIT", "Integrated information (phi)", "Posterior cortical hot zone", "Operationalized", "The cerebellum"],
                ["GNW", "Global broadcast", "Frontoparietal network", "Compatible with neural correlates", "Split-brain duplication"],
                ["Orch OR", "Quantum coherence", "Microtubules", "Preserved at quantum scale", "Decoherence timescales"],
                ["Movement-first (House)", "Internalized motor planning", "Sensorimotor loops", "Reformulated", "Locked-in patients"]
            ])
        let doc = PDFAnalysisDocument(book: .init(title: "T", author: "A"), sections: [.init(heading: "1. Frameworks", headingLevel: 2, blocks: [
            PDFContentBlock(type: .paragraph, content: "The five frameworks House triangulates differ on what they explain and what they miss."),
            table
        ])])
        let text = pageTexts(try render(doc)).joined(separator: "\n")
        for word in ["consciousness", "Compression", "Operationalized", "Frontoparietal", "Microtubules", "Sensorimotor", "Reformulated", "Decoherence"] {
            XCTAssertTrue(text.contains(word), "\(word) was broken across lines: \(text)")
        }
        XCTAssertTrue(text.contains("TABLE 1"), "table caption label missing")
        XCTAssertTrue(text.contains("five frameworks compared"), "table caption must carry the descriptive title")
    }

    func testParagraphContinuesOntoTheNextPageInsteadOfLeavingAGap() throws {
        // A page of short paragraphs, then a paragraph far too long for the
        // space left: it must split (first lines on page N, rest on N+1).
        var blocks: [PDFContentBlock] = []
        for p in 1...7 { blocks.append(PDFContentBlock(type: .paragraph, content: longParagraph("Opening paragraph \(p)", sentences: 4))) }
        blocks.append(PDFContentBlock(type: .paragraph, content: longParagraph("The long paragraph", sentences: 22)))
        let doc = PDFAnalysisDocument(book: .init(title: "T", author: "A"), sections: [.init(heading: "1. Pagination", headingLevel: 2, blocks: blocks)])
        let texts = pageTexts(try render(doc))
        let pagesWithLong = texts.enumerated().filter { $0.element.contains("The long paragraph sentence") }.map(\.offset)
        XCTAssertEqual(pagesWithLong.count, 2, "the long paragraph should span exactly two pages: \(pagesWithLong)")
        XCTAssertEqual(pagesWithLong[1], pagesWithLong[0] + 1)
        XCTAssertTrue(texts[pagesWithLong[0]].contains("The long paragraph sentence 1 "))
        XCTAssertTrue(texts[pagesWithLong[1]].contains("The long paragraph sentence 22 "))
    }

    func testParagraphsFloatAheadOfATallDiagramThatDoesNotFit() throws {
        var blocks: [PDFContentBlock] = []
        for p in 1...6 { blocks.append(PDFContentBlock(type: .paragraph, content: longParagraph("Lead paragraph \(p)", sentences: 5))) }
        blocks.append(PDFContentBlock(type: .flowchart, content: "", listItems: (1...8).map { "Step \($0) of the loop" }, metadata: ["title": "The confabulation loop: how a guess becomes a memory"]))
        blocks.append(PDFContentBlock(type: .paragraph, content: longParagraph("Trailing paragraph", sentences: 3)))
        blocks.append(PDFContentBlock(type: .paragraph, content: longParagraph("Second trailing paragraph", sentences: 3)))
        let doc = PDFAnalysisDocument(book: .init(title: "T", author: "A"), sections: [.init(heading: "1. Float ahead", headingLevel: 2, blocks: blocks)])
        let texts = pageTexts(try render(doc))
        let diagramPage = texts.firstIndex { $0.contains("Step 8 of the loop") } ?? -1
        let trailingPage = texts.firstIndex { $0.contains("Trailing paragraph sentence 1") } ?? -1
        XCTAssertGreaterThan(diagramPage, 0)
        XCTAssertLessThan(trailingPage, diagramPage, "the paragraph after the diagram should have floated into the gap before it")
    }

    func testRunningHeaderCarriesBookAndSectionTitles() throws {
        let texts = pageTexts(try render(sectionedDocument), dumpAs: "sectioned-header.txt")
        // Content pages: after cover + contents, before the closing page.
        let body = texts.dropFirst(2).dropLast()
        XCTAssertFalse(body.isEmpty)
        // Letter-spaced small caps extract with stray spaces; compare without them.
        let squeezed = body.map { $0.uppercased().filter { !$0.isWhitespace } }
        XCTAssertTrue(squeezed.allSatisfy { $0.contains("NINETEENWAYSOFLOOKINGATCONSCIOUSNESS") }, "book title missing from a running header: \(squeezed.first ?? "")")
        XCTAssertTrue(squeezed.contains { $0.contains("3.THEMENUMBER3") }, "section title missing from the running header")
        XCTAssertTrue(squeezed.allSatisfy { $0.contains("INSIGHTATLAS") }, "brand mark missing from a footer")
    }

    func testSpectrumFigureRendersPolesNodesAndCaption() throws {
        let block = PDFContentBlock(type: .spectrum, content: "", listItems: ["Rigid fixation", "Fluid conscious movement"],
                                    metadata: ["title": "The movement spectrum", "nodes": "Anchored, no nervous system|Sea squirt|Primate dexterity|Echolocating bat", "positions": "0.05|0.25|0.75|0.95"])
        let doc = PDFAnalysisDocument(book: .init(title: "T", author: "A"), sections: [.init(heading: "1. Spectrum", headingLevel: 2, blocks: [
            PDFContentBlock(type: .paragraph, content: "The movement spectrum runs from anchored organisms to fluid conscious movers."), block])])
        let text = pageTexts(try render(doc)).joined(separator: "\n")
        XCTAssertTrue(text.contains("FIGURE 1: THE MOVEMENT SPECTRUM"), text)
        XCTAssertTrue(text.contains("Rigid fixation") && text.contains("Fluid conscious movement"))
        XCTAssertTrue(text.contains("Echolocating bat"))
    }

    func testFlowchartNodeTextIsNeverTruncated() throws {
        let node = "Prediction is updated to incorporate the fabricated explanation"
        let block = PDFContentBlock(type: .flowchart, content: "", listItems: ["A stimulus or state arrives", "Brain cannot integrate it into its model", node], metadata: ["title": "The confabulation loop"])
        let doc = PDFAnalysisDocument(book: .init(title: "T", author: "A"), sections: [.init(heading: "1. Loop", headingLevel: 2, blocks: [PDFContentBlock(type: .paragraph, content: "The loop below."), block])])
        let text = pageTexts(try render(doc)).joined(separator: " ").replacingOccurrences(of: "\n", with: " ")
        XCTAssertTrue(text.contains("fabricated explanation"), "node text truncated: \(text)")
    }

    /// Writes a fixture modelled on the reviewed guide to a shared location
    /// for visual inspection (page images are produced by the host script).
    func testWriteReviewFixturePDF() throws {
        let content = ElevationSpecFixture.guide
        let data = try InsightAtlasPDFRenderer().render(markdownContent: content, title: "Nineteen Ways of Looking at Consciousness", author: "Patrick House").pdfData
        let dir = URL(fileURLWithPath: "/private/tmp/insightatlas-elevation")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: dir.appendingPathComponent("fixture.pdf"))
        XCTAssertGreaterThan(data.count, 10_000)
    }
}
