import XCTest
@testable import InsightAtlas

/// conceptMap defect batch: adaptive radial geometry (grow to hold every concept,
/// no overlap, no clip, no cap), measure==draw parity, header-line parse skip,
/// and a ceiling-crossing record so an oversized map can never ambush us silently.
final class ConceptMapGeometryTests: XCTestCase {

    private let diag = PDFDiagramRenderer(
        pageSize: PDFStyleConfiguration.PageLayout.pageSize,
        contentRect: PDFStyleConfiguration.PageLayout.contentRect
    )
    private let width: CGFloat = 400   // representative concept-map container width
    private let contentCeiling: CGFloat = 648

    func testGeometrySweepNoOverlapNoClip() {
        for n in 2...30 {
            let g = diag.conceptMapGeometry(count: n, maxWidth: width)
            let half = sin(.pi / CGFloat(n))
            // Non-overlap: neighbor half-chord (orbit*sin) ≥ satellite radius.
            XCTAssertGreaterThanOrEqual(g.orbit * half + 0.5, g.satellite, "n=\(n): satellites overlap")
            // Width-fit: orbit + satellite stays inside the half-width.
            XCTAssertLessThanOrEqual(g.orbit + g.satellite, width / 2, "n=\(n): map exceeds container width")
            // Satellite is a real node (floor), never degenerate.
            XCTAssertGreaterThanOrEqual(g.satellite, 16 - 0.001, "n=\(n): satellite below floor")
        }
    }

    func testMeasureEqualsGeometry() {
        // calculateConceptMapHeight must reserve exactly header + geo.mapHeight +
        // padding*2 + blockSpacing — the same geometry the renderer draws.
        for n in [3, 6, 8, 12, 20] {
            let g = diag.conceptMapGeometry(count: n, maxWidth: width)
            let expected = 28 + g.mapHeight + 16 * 2 + PDFStyleConfiguration.Spacing.blockSpacing
            let actual = diag.calculateConceptMapHeight(centralConcept: "C", relatedConcepts: Array(repeating: "x", count: n), maxWidth: width)
            XCTAssertEqual(actual, expected, accuracy: 0.001, "n=\(n): measure diverges from geometry")
        }
    }

    func testCeilingCrossingIsBeyondRealContent() {
        // Record where a full map (header+map+padding) would cross the page
        // content height. Must be well beyond real content (≤ ~20 concepts).
        var crossing: Int? = nil
        for n in 2...60 {
            let g = diag.conceptMapGeometry(count: n, maxWidth: width)
            let total = 28 + g.mapHeight + 32
            if total > contentCeiling { crossing = n; break }
        }
        // Width binds orbit before height reaches the ceiling → on this width the
        // map should never cross (crossing == nil). If it ever does, it must be
        // far past any observed content, and the designated answer is scale-to-fit.
        if let c = crossing {
            XCTAssertGreaterThan(c, 30, "map crosses page ceiling at n=\(c) — earlier than expected")
        }
        // Real-content guarantee: 20 concepts fits comfortably.
        let g20 = diag.conceptMapGeometry(count: 20, maxWidth: width)
        XCTAssertLessThan(28 + g20.mapHeight + 32, contentCeiling, "20-concept map must fit a page")
    }

    func testParseSkipsBareHeaderKeepsRealConcepts() {
        let (central, related) = PDFAnalysisDocument.parseConceptMap(from: [
            "Central: Clear mutual commitment",
            "Orbiting elements:",                 // bare header — must be dropped
            "Listening",                          // plain concept — kept
            "Desired outcome: the goal"           // X: Y — kept as "Desired outcome — the goal"
        ])
        XCTAssertEqual(central, "Clear mutual commitment")
        XCTAssertFalse(related.contains { $0.lowercased().contains("orbiting elements") }, "header leaked as a concept")
        XCTAssertTrue(related.contains("Listening"))
        XCTAssertTrue(related.contains { $0.contains("Desired outcome") && $0.contains("the goal") }, "X: Y concept dropped")
        XCTAssertEqual(related.count, 2, "exactly the two real concepts, header skipped")
    }

    // LIVE-PATH GATE. The generator emits [VISUAL_CONCEPT_MAP], which the PDF
    // renders via InsightVisual.parse → parseLineFormat(.conceptMap) →
    // ConceptMapData.branches — NOT via PDFAnalysisDocument.parseConceptMap
    // (that serves the legacy [CONCEPT_MAP] tag; testParseSkipsBareHeaderKeeps…
    // above is now that path's own coverage, demoted from the conceptMap gate).
    // A green there with a red render is exactly the "right assertion, wrong
    // function" failure this test exists to prevent: it pins the parser the
    // export actually uses — bare "X:" headers dropped, em-dash bullets stripped.
    func testLiveVisualConceptMapParserDropsHeaderAndEmDash() {
        let lines = [
            "Central: A self not reducible to caregiving",
            "Orbiting domains:",          // bare structural header — must be dropped
            "— values",                   // em-dash bullet — prefix must be stripped
            "— play and pleasure",
            "bodily needs"                // plain concept — kept verbatim
        ]
        guard let visual = InsightVisualParser.parse(tag: "VISUAL_CONCEPT_MAP", title: "Concept Map", lines: lines),
              case let .conceptMap(data) = visual.payload else {
            return XCTFail("VISUAL_CONCEPT_MAP did not parse to a conceptMap payload")
        }
        XCTAssertEqual(data.center, "A self not reducible to caregiving")
        XCTAssertFalse(data.branches.contains { $0.hasSuffix(":") }, "bare header leaked as a branch node")
        XCTAssertFalse(data.branches.contains { $0.hasPrefix("—") }, "em-dash prefix leaked into a branch label")
        XCTAssertTrue(data.branches.contains("values"), "em-dash concept lost its label after strip")
        XCTAssertTrue(data.branches.contains("play and pleasure"))
        XCTAssertTrue(data.branches.contains("bodily needs"))
        XCTAssertEqual(data.branches.count, 3, "exactly the three real concepts — header dropped, none spilled")
    }

    // LIVE-PATH GATE (the one the export actually hit). The generator's IMPLICIT
    // map — "Central: …" + blank-line-separated em-dash orbiters — routes
    // parse → parseImplicitVisualBlocks → parseCentralConceptMap, a THIRD parser
    // distinct from [VISUAL_CONCEPT_MAP] (parseLineFormat) and [CONCEPT_MAP]
    // (PDFAnalysisDocument.parseConceptMap). Pinned END-TO-END through the public
    // parse() so it's route-agnostic: header dropped, em-dash stripped, and NO
    // 8-branch cap (the former `>= 8` cap spilled concepts 9+ as loose bullets).
    func testImplicitCentralConceptMapDropsHeaderStripsEmDashNoCap() {
        let content = """
        ## Rewriting the Dominant Narrative

        Central: A self not reducible to caregiving

        Orbiting domains:

        — values

        — play and pleasure

        — bodily needs

        — vocation

        — friendship

        — sexuality and intimacy

        — cultural belonging

        — creativity

        — rest

        — chosen forms of contribution
        """
        let doc = PDFAnalysisDocument.parse(from: content, title: "T", author: "A")
        let blocks = doc.sections.flatMap { $0.blocks }
        guard let map = blocks.first(where: { $0.type == .conceptMap }) else {
            return XCTFail("implicit Central: map did not produce a conceptMap block")
        }
        let branches = map.listItems ?? []
        XCTAssertEqual(map.metadata?["central"], "A self not reducible to caregiving")
        XCTAssertFalse(branches.contains { $0.hasSuffix(":") }, "bare header leaked as a branch node")
        XCTAssertFalse(branches.contains { $0.hasPrefix("—") }, "em-dash prefix leaked into a branch label")
        XCTAssertTrue(branches.contains("values"), "em-dash concept lost its label after strip")
        XCTAssertTrue(branches.contains("chosen forms of contribution"), "concept 9+ truncated by the old 8-cap")
        XCTAssertEqual(branches.count, 10, "all ten concepts — header dropped, none capped, none spilled")
    }

    // BACKWARD-SAFETY GATE for the radar/hierarchy OFFER removal (2026-08-10,
    // ruling (d)). The types are no longer offered, but a STORED guide generated
    // before the cut may still carry the tags; re-export renders from persisted
    // markdown, so the parse-side must stay TOLERANT: legacy content degrades to
    // clean bullets, never leaks raw tag text, never vanishes. This makes the cut
    // permanently safe rather than observably safe — it passes before AND after
    // the offer removal precisely because the cut never touched the parse path.
    func testRemovedVisualTypesStillDegradeCleanlyOnLegacyContent() {
        for tag in ["VISUAL_RADAR", "VISUAL_HIERARCHY"] {
            let content = """
            ## Legacy Section

            [\(tag): Legacy]
            first axis
            second axis
            third axis
            [/\(tag)]
            """
            let doc = PDFAnalysisDocument.parse(from: content, title: "T", author: "A")
            let blocks = doc.sections.flatMap { $0.blocks }
            XCTAssertTrue(blocks.contains { $0.type == .bulletList },
                          "\(tag): legacy content must still degrade to a bullet list")
            let leaked = blocks.contains { block in
                block.content.contains("[\(tag)") ||
                (block.listItems ?? []).contains { $0.contains("[\(tag)") }
            }
            XCTAssertFalse(leaked, "\(tag): raw tag text leaked into the render")
        }
    }

    // RULED-CONSOLIDATION gate (2026-08-10). The single shared per-concept
    // sanitizer that all three concept-map parsers now route through — pins each
    // ruling so the parsers cannot re-diverge (the failure class that produced
    // "right assertion, wrong function" twice). Route-specific parser tests above
    // (parseConceptMap / VISUAL_CONCEPT_MAP / implicit Central:) prove each caller
    // reaches this; this proves the canonical behavior itself.
    func testSharedConceptBranchSanitizerRulings() {
        // Ruling 1 — canonical bullet set { - * • — → }, spaced or bare.
        XCTAssertEqual(PDFAnalysisDocument.sanitizeConceptBranch("— values"), "values")
        XCTAssertEqual(PDFAnalysisDocument.sanitizeConceptBranch("- values"), "values")
        XCTAssertEqual(PDFAnalysisDocument.sanitizeConceptBranch("* values"), "values")
        XCTAssertEqual(PDFAnalysisDocument.sanitizeConceptBranch("• values"), "values")
        XCTAssertEqual(PDFAnalysisDocument.sanitizeConceptBranch("→ values"), "values")
        // Ruling 3 — bare colon header → nil (skip); "X: Y" → "X — Y".
        XCTAssertNil(PDFAnalysisDocument.sanitizeConceptBranch("Orbiting domains:"))
        XCTAssertEqual(PDFAnalysisDocument.sanitizeConceptBranch("Desired outcome: the goal"),
                       "Desired outcome — the goal")
        // Ruling 2 — inline markdown incl. **bold** stripped (nodes render plain).
        XCTAssertEqual(PDFAnalysisDocument.sanitizeConceptBranch("**values**"), "values")
        // Non-concepts return nil so callers `continue`.
        XCTAssertNil(PDFAnalysisDocument.sanitizeConceptBranch(""))
    }

    // MARK: - Native Pyramid Renderer (capability-audit Batch 2)

    // measure==draw parity on the public height API: reserved height must equal
    // the geometry the renderer draws (fixed 46pt bands + 6pt gaps, 28 header,
    // 16 padding both sides, + blockSpacing).
    func testPyramidMeasureEqualsGeometry() {
        for n in [1, 3, 5, 8] {
            let levels = Array(repeating: "level", count: n)
            let bands = CGFloat(n) * 46 + CGFloat(max(0, n - 1)) * 6
            let expected = 28 + bands + 16 * 2 + PDFStyleConfiguration.Spacing.blockSpacing
            XCTAssertEqual(diag.calculatePyramidHeight(levels: levels, maxWidth: width),
                           expected, accuracy: 0.001, "n=\(n): pyramid measure diverges from geometry")
        }
    }

    // End-to-end: a [VISUAL_PYRAMID] block must route to a NATIVE .pyramid block
    // (drawn as stacked bands) — NOT degrade to a .bulletList. This is the whole
    // point of the batch, and it's the exact fate the Cognitive Defusion pyramid
    // (rendered as loose "LEVEL N —"/"Supported by" prose) needed.
    func testPyramidVisualRoutesToNativeBlockNotBullets() {
        let content = """
        ## Section

        [VISUAL_PYRAMID: Support Pyramid]
        Technique
        Functional target
        Values and workability
        Shared rationale
        Therapeutic alliance
        [/VISUAL_PYRAMID]
        """
        let doc = PDFAnalysisDocument.parse(from: content, title: "T", author: "A")
        let blocks = doc.sections.flatMap { $0.blocks }
        guard let pyramid = blocks.first(where: { $0.type == .pyramid }) else {
            return XCTFail("VISUAL_PYRAMID must render as a native .pyramid block, not degrade")
        }
        XCTAssertEqual(pyramid.listItems?.count, 5, "all five levels carried into the native block")
        XCTAssertFalse(blocks.contains { $0.type == .bulletList }, "pyramid must not degrade to a bullet list")
    }

    // MARK: - Native Cycle Renderer (capability-audit Batch 2)

    func testCycleRoutesToNativeBlockNotBullets() {
        let content = """
        ## Section

        [VISUAL_CYCLE: Change Cycle]
        Awareness
        Acceptance
        Action
        Integration
        [/VISUAL_CYCLE]
        """
        let doc = PDFAnalysisDocument.parse(from: content, title: "T", author: "A")
        let blocks = doc.sections.flatMap { $0.blocks }
        guard let cycle = blocks.first(where: { $0.type == .cycle }) else {
            return XCTFail("VISUAL_CYCLE must render as a native .cycle block, not degrade")
        }
        XCTAssertEqual(cycle.listItems?.count, 4, "all four stages carried into the native block")
        XCTAssertFalse(blocks.contains { $0.type == .bulletList }, "cycle must not degrade to a bullet list")
    }

    // Ring geometry is width-bound (like the concept map), so a real-count cycle
    // must fit a page — never silently overflow. Deterministic + bounded.
    func testCycleHeightFitsPageForRealCounts() {
        for n in 2...12 {
            let stages = Array(repeating: "stage", count: n)
            let h = diag.calculateCycleHeight(stages: stages, maxWidth: width)
            XCTAssertGreaterThan(h, 0, "n=\(n): non-positive cycle height")
            XCTAssertLessThan(h, contentCeiling, "n=\(n): cycle should fit a page at real counts")
        }
    }

    // MARK: - Native Funnel / Bar / Pie Renderers (capability-audit Batch 2)
    // These three previously degraded to a .table; assert they now route to their
    // native block and no table is emitted.

    func testFunnelRoutesToNativeBlockNotTable() {
        let content = """
        ## Section

        [VISUAL_FUNNEL: Conversion]
        Visitors: 1000
        Signups: 400
        Active: 150
        Paying: 40
        [/VISUAL_FUNNEL]
        """
        let doc = PDFAnalysisDocument.parse(from: content, title: "T", author: "A")
        let blocks = doc.sections.flatMap { $0.blocks }
        XCTAssertTrue(blocks.contains { $0.type == .funnel }, "funnel must render as a native .funnel block")
        XCTAssertFalse(blocks.contains { $0.type == .table }, "funnel must not degrade to a table")
    }

    func testBarChartRoutesToNativeBlockWithValues() {
        let content = """
        ## Section

        [VISUAL_BAR_CHART: Scores]
        Alpha: 12
        Beta: 30
        Gamma: 18
        [/VISUAL_BAR_CHART]
        """
        let doc = PDFAnalysisDocument.parse(from: content, title: "T", author: "A")
        let blocks = doc.sections.flatMap { $0.blocks }
        guard let bar = blocks.first(where: { $0.type == .barChart }) else {
            return XCTFail("bar chart must render as a native .barChart block")
        }
        XCTAssertEqual(bar.listItems?.count, 3, "all three labels carried")
        XCTAssertEqual(bar.metadata?["values"], "12.0|30.0|18.0", "values carried in metadata for the renderer")
        XCTAssertFalse(blocks.contains { $0.type == .table }, "bar chart must not degrade to a table")
    }

    func testPieChartRoutesToNativeBlockWithValues() {
        let content = """
        ## Section

        [VISUAL_PIE_CHART: Split]
        Work: 50
        Sleep: 30
        Play: 20
        [/VISUAL_PIE_CHART]
        """
        let doc = PDFAnalysisDocument.parse(from: content, title: "T", author: "A")
        let blocks = doc.sections.flatMap { $0.blocks }
        guard let pie = blocks.first(where: { $0.type == .pieChart }) else {
            return XCTFail("pie chart must render as a native .pieChart block")
        }
        XCTAssertEqual(pie.listItems?.count, 3, "all three segments carried")
        XCTAssertFalse(blocks.contains { $0.type == .table }, "pie chart must not degrade to a table")
    }

    // MARK: - Pinning invariant (capability-audit Batch 1)

    // THE STRUCTURAL GUARD: every visual type the prompt offers as a NATIVE
    // diagram must route to its native block and NEVER degrade to a bullet list
    // or bare paragraph (the diagram-to-bullets premium killer). If a future edit
    // reverts a routing or offers a type the PDF can't draw, this fails loudly —
    // the offer↔renderer contract can no longer drift silently.
    func testOfferedNativeVisualsNeverDegradeInPDF() {
        let cases: [(tag: String, body: String, expected: PDFContentBlock.BlockType)] = [
            ("VISUAL_CONCEPT_MAP", "Central: Core\nA\nB\nC", .conceptMap),
            ("VISUAL_FLOWCHART", "First\nSecond\nThird", .flowchart),
            ("VISUAL_PYRAMID", "Top\nMiddle\nBase", .pyramid),
            ("VISUAL_CYCLE", "Plan\nDo\nReview", .cycle),
            ("VISUAL_FUNNEL", "Visitors: 100\nLeads: 40\nSales: 10", .funnel),
            ("VISUAL_BAR_CHART", "Alpha: 12\nBeta: 30", .barChart),
            ("VISUAL_PIE_CHART", "Work: 60\nRest: 40", .pieChart)
        ]
        for c in cases {
            let content = "## Section\n\n[\(c.tag): T]\n\(c.body)\n[/\(c.tag)]"
            let blocks = PDFAnalysisDocument.parse(from: content, title: "T", author: "A")
                .sections.flatMap { $0.blocks }
            XCTAssertTrue(blocks.contains { $0.type == c.expected },
                          "\(c.tag): expected native \(c.expected) block")
            XCTAssertFalse(blocks.contains { $0.type == .bulletList },
                           "\(c.tag): degraded to a bullet list")
        }
    }

    // MARK: - Flowchart Reclassifier (capability-audit Batch B — structural)

    // A "Branch — X" hub flowchart is mislabeled hub-and-spoke content → must be
    // reclassified to a native concept map. A genuine causal sequence must NOT be
    // touched (conservative: the rule fires only on hub markers).
    func testHubFlowchartReclassifiesButSequenceSurvives() {
        let hub = PDFContentBlock(type: .flowchart, content: "", listItems: [
            "Branch — Metaphorical reframing", "Passengers on the Bus", "Leaves on a Stream", "Thoughts as Hands"
        ], metadata: ["title": "Process Flow"])
        let seq = PDFContentBlock(type: .flowchart, content: "", listItems: [
            "Trigger event", "Automatic thought", "Rigid rule-following", "Narrowed behavior"
        ], metadata: ["title": "Process Flow"])
        let doc = PDFAnalysisDocument(
            book: PDFAnalysisDocument.BookMetadata(title: "T", author: "A"),
            sections: [PDFAnalysisDocument.PDFSection(blocks: [hub, seq])]
        )
        let blocks = FlowchartReclassifier().reclassify(doc).sections.flatMap { $0.blocks }
        guard let cm = blocks.first(where: { $0.type == .conceptMap }) else {
            return XCTFail("hub flowchart must reclassify to a concept map")
        }
        XCTAssertEqual(cm.metadata?["central"], "Metaphorical reframing", "central = hub label")
        XCTAssertEqual(cm.listItems?.count, 3, "the three spokes carried as branches")
        XCTAssertEqual(blocks.filter { $0.type == .flowchart }.count, 1, "genuine sequence must remain a flowchart")
    }
}
