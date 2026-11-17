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

    /// The reader shows these headings once; the PDF shows them two or three
    /// times. So the duplication is not in the content — it is the PDF path
    /// emitting a heading as BOTH a section title and a block. Print sections
    /// and blocks together, which the earlier block-only diagnostic missed.
    func testReportSectionsAndBlocksTogether() {
        let shapes: [(String, String)] = [
            ("h1+h2", "[PREMIUM_H1]Part One[/PREMIUM_H1]\n[PREMIUM_H2]From Hexaflex to Two Lines[/PREMIUM_H2]\n\nBody."),
            ("md h2", "## From Hexaflex to Two Lines\n\nBody."),
            ("md h2 + premium", "## From Hexaflex to Two Lines\n[PREMIUM_H2]From Hexaflex to Two Lines[/PREMIUM_H2]\n\nBody."),
            ("h1 only", "[PREMIUM_H1]From Hexaflex to Two Lines[/PREMIUM_H1]\n\nBody."),
            ("md h1+h2 same", "# From Hexaflex to Two Lines\n## From Hexaflex to Two Lines\n\nBody.")
        ]
        for (name, content) in shapes {
            let doc = PDFAnalysisDocument.parse(from: content, title: "T", author: "A")
            let rendered = doc.sections.map { section in
                "§\(section.heading)[\(section.headingLevel)]{"
                    + section.blocks.map { "\($0.type):\($0.content.prefix(20))" }.joined(separator: ",")
                    + "}"
            }
            print("[SectionShape] \(name): \(rendered.joined(separator: " "))")
        }
    }

    /// Reproduces the shipped ACT Matrix guide, where the reader showed each
    /// heading once but the PDF showed it two or three times.
    func testHeadingAppearsOnceHoweverTheModelTitlesIt() {
        func rendered(_ content: String) -> [String] {
            let doc = PDFAnalysisDocument.parse(from: content, title: "T", author: "A")
            return doc.sections.flatMap { section -> [String] in
                let title = section.heading.map { [$0] } ?? []
                let headingBlocks = section.blocks
                    .filter { $0.type == .premiumH2 || $0.type == .heading2 || $0.type == .heading3 }
                    .map(\.content)
                return title + headingBlocks
            }
        }

        let title = "From Hexaflex to Two Lines"

        // Markdown heading (a section) plus a premium heading block — two.
        XCTAssertEqual(
            rendered("## \(title)\n[PREMIUM_H2]\(title)[/PREMIUM_H2]\n\nBody.").filter { $0 == title }.count,
            1
        )
        // `#` then `##` with one title — two sections.
        XCTAssertEqual(
            rendered("# \(title)\n## \(title)\n\nBody.").filter { $0 == title }.count,
            1
        )
        // All three at once — the page-7 case.
        XCTAssertEqual(
            rendered("# \(title)\n## \(title)\n[PREMIUM_H2]\(title)[/PREMIUM_H2]\n\nBody.")
                .filter { $0 == title }.count,
            1
        )
        // A genuinely different subheading inside a section is kept.
        let mixed = rendered("## \(title)\n[PREMIUM_H2]A Different Subheading[/PREMIUM_H2]\n\nBody.")
        XCTAssertTrue(mixed.contains(title))
        XCTAssertTrue(mixed.contains("A Different Subheading"))
    }

    /// Bracket debris is dropped during canonicalization, so no downstream
    /// renderer can print it.
    func testCanonicalizerStripsBracketDebris() {
        let canonical = EditorialMarkupCanonicalizer.canonicalize("Body one.\n[\n]\nBody two.")
        XCTAssertFalse(canonical.contains("\n[\n"), "a bare [ survived canonicalization")
        XCTAssertFalse(canonical.contains("\n]\n"), "a bare ] survived canonicalization")
        XCTAssertTrue(canonical.contains("Body one."))
        XCTAssertTrue(canonical.contains("Body two."))
    }

    /// Page 13 of the ACT Matrix guide printed a workability matrix as prose.
    /// Its cells rate items "---", and the parser treated any row containing
    /// "---" as a markdown separator, so the table ended after its header.
    func testTableRowsMayContainDashRatings() {
        let content = """
        This three-column functional analysis is replicable.

        Rating target | Short-term | Long-term | Toward what matters
        Avoidance | +++ (highly effective) | -- (worse) | --- (far from values)
        Reassurance-seeking | ++ | - | --
        Substance use | +++ | -- | ---
        """
        let produced = blocks(content)
        guard let table = produced.first(where: { $0.type == .table }) else {
            return XCTFail("the matrix must render as a table, got \(produced.map(\.type))")
        }
        XCTAssertEqual(table.tableData?.count, 4, "header plus three rated rows")
        XCTAssertEqual(table.tableData?.last, ["Substance use", "+++", "--", "---"])
        XCTAssertFalse(
            produced.contains { $0.type == .paragraph && $0.content.contains("|") },
            "no rated row may survive as prose"
        )
    }

    /// A real markdown alignment row is still dropped.
    func testGenuineAlignmentRowIsStillSkipped() {
        let content = """
        Intro line.

        Frame | Claim | Note
        --- | --- | ---
        Stoic | Assent precedes emotion | Classical
        Modern | Appraisal precedes emotion | Empirical
        """
        let produced = blocks(content)
        guard let table = produced.first(where: { $0.type == .table }) else {
            return XCTFail("expected a table, got \(produced.map(\.type))")
        }
        XCTAssertEqual(table.tableData?.count, 3, "the --- row must not become a data row")
        XCTAssertEqual(table.tableData?[0], ["Frame", "Claim", "Note"])
    }

    /// The reader showed Quick Glance bullets as literal "- " with wrapped
    /// lines running back to the margin, while the PDF showed real bullets.
    func testQuickGlanceBulletsAreParsedNotLeftAsLiteralDashes() {
        let lines = QuickGlanceLine.parse("""
        The ACT Matrix is a two-line diagram.
        - "Away moves" are rewarded in the short term.
        - Cognitive fusion is reframed as "hooks" plus "biting".
        • Already-bulleted lines are recognized too.
        """)

        XCTAssertEqual(lines.first, .paragraph("The ACT Matrix is a two-line diagram."))
        XCTAssertEqual(lines.filter { if case .bullet = $0 { return true } else { return false } }.count, 3)
        XCTAssertEqual(lines[1], .bullet("\"Away moves\" are rewarded in the short term."))
        for line in lines {
            if case .bullet(let text) = line {
                XCTAssertFalse(text.hasPrefix("-"), "the marker must be stripped, not rendered")
                XCTAssertFalse(text.hasPrefix("•"), "the marker must be stripped, not rendered")
            }
        }
    }

    /// A 41-page guide on a book whose core model is a 2x2 matrix shipped with
    /// ZERO visual cards. The per-request guidelines listed every block type
    /// except [VISUAL_*], so the most proximate instruction never asked for one.
    func testPerRequestGuidelinesRequireVisuals() {
        let message = InsightAtlasPromptGenerator.generateUserMessage(
            title: "T",
            author: "A",
            bookText: "The matrix has two axes. Toward moves and away moves sort into four quadrants."
        )
        XCTAssertTrue(message.contains("[VISUAL_"), "the guidelines must name visual blocks")
        XCTAssertTrue(
            message.lowercased().contains("4 and 8") || message.lowercased().contains("required"),
            "visuals must be mandated, not merely permitted"
        )
    }

    /// The generator is told which diagram THIS book needs, rather than being
    /// left to infer that any are wanted.
    func testVisualFrameworkHintsNameTheBooksOwnShape() {
        let quadrant = InsightAtlasPromptGenerator.visualFrameworkHints(
            for: "The ACT Matrix sorts experience along two axes into four quadrants."
        )
        XCTAssertTrue(quadrant.contains("VISUAL_QUADRANT"), "a 2x2 book must be told to draw one")

        let cycle = InsightAtlasPromptGenerator.visualFrameworkHints(
            for: "Worry becomes a self-perpetuating feedback loop."
        )
        XCTAssertTrue(cycle.contains("VISUAL_CYCLE"))

        // Prose with no structural vocabulary adds nothing.
        XCTAssertTrue(
            InsightAtlasPromptGenerator.visualFrameworkHints(for: "A gentle memoir about a childhood summer.").isEmpty
        )
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
