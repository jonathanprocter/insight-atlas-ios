import XCTest
@testable import InsightAtlas

/// A shipped guide rendered "The One-Page Summary" three times in a row and
/// printed bare `[` / `]` lines as body paragraphs. Both come out of
/// `PDFAnalysisDocument.parse`, which has three separate sites that append a
/// `.premiumH2` block.
final class PDFHeadingDuplicationTests: XCTestCase {

    private func blocks(_ content: String) -> [PDFContentBlock] {
        PDFAnalysisDocument
            .parse(from: content, title: "T", author: "A")
            .sections
            .flatMap(\.blocks)
    }

    private func headings(_ content: String) -> [String] {
        blocks(content)
            .filter { $0.type == .premiumH2 || $0.type == .heading2 }
            .map(\.content)
    }

    /// Diagnostic: print what each plausible authoring shape produces, so the
    /// duplicating path is identified from output rather than guessed at.
    func testReportHeadingShapes() {
        let shapes: [(String, String)] = [
            ("inline", "[PREMIUM_H2]The One-Page Summary[/PREMIUM_H2]\n\nBody text here."),
            ("multiline", "[PREMIUM_H2]\nThe One-Page Summary\n[/PREMIUM_H2]\n\nBody text here."),
            ("unterminated", "[PREMIUM_H2]The One-Page Summary\n\nBody text here."),
            ("inline+markdown", "[PREMIUM_H2]The One-Page Summary[/PREMIUM_H2]\n## The One-Page Summary\n\nBody."),
            ("markdown only", "## The One-Page Summary\n\nBody text here.")
        ]
        for (name, content) in shapes {
            let all = blocks(content).map { "\($0.type):\($0.content.prefix(28))" }
            print("[HeadingShape] \(name): \(headings(content)) | blocks=\(all)")
        }
    }

    /// Whatever the authoring shape, one heading must render once.
    func testHeadingIsNotDuplicated() {
        for content in [
            "[PREMIUM_H2]The One-Page Summary[/PREMIUM_H2]\n\nBody text here.",
            "[PREMIUM_H2]\nThe One-Page Summary\n[/PREMIUM_H2]\n\nBody text here."
        ] {
            XCTAssertEqual(
                headings(content), ["The One-Page Summary"],
                "duplicated for content: \(content.debugDescription)"
            )
        }
    }

    /// Page 22 of a shipped guide printed a borderless pipe table as prose even
    /// though `parse` has a borderless-table branch. Reproduce the exact shape.
    func testBorderlessPipeTableBecomesATableBlock() {
        let content = """
        Fourth, and most usefully, it provides an ethical orientation.

        Aspect | Mirror | Filtered mind
        Selection | None | Active
        Effort | None | Constant
        Distortion | None | Substantial
        Effect of content | Unchanged | Changed
        """
        let produced = blocks(content)
        print("[TableShape] \(produced.map { "\($0.type):\($0.content.prefix(24))" })")
        XCTAssertTrue(
            produced.contains { $0.type == .table },
            "the pipe rows must render as a table, not prose"
        )
        XCTAssertFalse(
            produced.contains { $0.type == .paragraph && $0.content.contains("|") },
            "no pipe row may survive as a paragraph"
        )
    }

    /// Page 55 dumped a VISUAL_NETWORK payload (`Node:` / `Link:` lines) as prose.
    func testUntaggedNodeLinkPayloadIsNotPrintedAsProse() {
        let content = """
        The practice is built around three foundational questions.

        Node: content | Content of experience | what is noticed
        Node: awareness | Awareness | what notices
        Node: mind | The mind | obstacle and instrument
        Link: content -> awareness
        Link: mind -> play
        """
        let produced = blocks(content)
        print("[GraphShape] \(produced.map { "\($0.type):\($0.content.prefix(24))" })")
        XCTAssertFalse(
            produced.contains { $0.type == .paragraph && ($0.content.hasPrefix("Node:") || $0.content.hasPrefix("Link:")) },
            "raw Node:/Link: DSL must never reach the page as prose"
        )
    }

    /// The shipped leak most likely came from a tagged visual whose payload
    /// failed to parse and was then dumped verbatim. Report what each tagged
    /// shape produces.
    func testTaggedVisualPayloadsNeverDumpRawDSL() {
        let shapes: [(String, String)] = [
            ("network", "[VISUAL_NETWORK: Reader's Map]\nNode: content | Content of experience | what is noticed\nNode: awareness | Awareness | what notices\nLink: content -> awareness\n[/VISUAL_NETWORK]"),
            ("network-arrow", "[VISUAL_NETWORK: Map]\nNode: content | Content of experience | what is noticed\nLink: content → awareness\n[/VISUAL_NETWORK]"),
            ("table-tagged", "[VISUAL_TABLE: Mirror]\nAspect | Mirror | Filtered mind\nSelection | None | Active\n[/VISUAL_TABLE]"),
            ("concept-map", "[CONCEPT_MAP: Reader's Map]\nCentral: Awareness\nNode: content | Content | noticed\n[/CONCEPT_MAP]")
        ]
        for (name, content) in shapes {
            let produced = blocks(content)
            print("[TaggedShape] \(name): \(produced.map { "\($0.type):\($0.content.prefix(30))" })")
            XCTAssertFalse(
                produced.contains { $0.type == .paragraph && ($0.content.contains("Node:") || $0.content.contains("Link:")) },
                "\(name) dumped raw DSL as prose"
            )
        }
    }

    /// An unrecognized visual tag degrades to `.generic`, which used to print
    /// its payload verbatim — the path that put a pipe table on page 22 and a
    /// node/link graph on page 55 of a shipped guide.
    func testUnknownVisualTagRecoversStructureInsteadOfDumpingText() {
        let table = PDFAnalysisDocument.structuredBlocksFromGenericPayload("""
        Aspect | Mirror | Filtered mind
        Selection | None | Active
        Effort | None | Constant
        """)
        XCTAssertEqual(table.first?.type, .table, "pipe rows must become a table")
        XCTAssertEqual(table.first?.tableData?.count, 3)
        XCTAssertEqual(table.first?.tableData?[1], ["Selection", "None", "Active"])

        let graph = PDFAnalysisDocument.structuredBlocksFromGenericPayload("""
        Node: content | Content of experience | what is noticed
        Node: awareness | Awareness | what notices
        Link: content -> awareness
        """)
        XCTAssertEqual(graph.first?.type, .flowchart, "node/link DSL must become a flow")
        XCTAssertEqual(graph.first?.listItems, ["Content of experience", "Awareness"])

        // Ordinary prose is untouched.
        let prose = PDFAnalysisDocument.structuredBlocksFromGenericPayload(
            "A sentence that merely mentions a | pipe character."
        )
        XCTAssertEqual(prose.first?.type, .paragraph)
    }

    /// Bracket-only lines are tag debris, never body copy.
    func testOrphanedBracketLinesAreNotRenderedAsParagraphs() {
        let content = "[\n]\n\nPersuasion Skills Black Book sits in a specific tradition."
        let paragraphs = blocks(content)
            .filter { $0.type == .paragraph }
            .map { $0.content.trimmingCharacters(in: .whitespacesAndNewlines) }

        XCTAssertFalse(paragraphs.contains("["), "a bare [ was rendered as a paragraph")
        XCTAssertFalse(paragraphs.contains("]"), "a bare ] was rendered as a paragraph")
        XCTAssertTrue(
            paragraphs.contains(where: { $0.hasPrefix("Persuasion Skills Black Book") }),
            "real body copy must survive"
        )
    }
}
