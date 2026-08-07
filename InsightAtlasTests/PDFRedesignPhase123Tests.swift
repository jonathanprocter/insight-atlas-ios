import XCTest
import CoreGraphics
@testable import InsightAtlas

/// Tests for the PDF redesign correctness cluster (Phases 1–3):
///   • CitationBudgetEngine   — faithful port of citation-system-spec.md §2
///   • PDFDiagramGeometry     — computed loop geometry (Directives §A4)
///   • DiagramPromotionEngine — arrow-chain → diagram promotion (§A4)
///   • ReferentialIntegrityValidator — figure numbering + integrity (§A1–A3)
final class PDFRedesignPhase123Tests: XCTestCase {

    // MARK: - Helpers

    private func makeDoc(_ blocks: [PDFContentBlock], heading: String = "Section") -> PDFAnalysisDocument {
        PDFAnalysisDocument(
            book: .init(title: "Test", author: "Author"),
            sections: [.init(heading: heading, headingLevel: 1, blocks: blocks)]
        )
    }

    private func citation(_ source: String, fn: CitationFunction) -> Citation {
        Citation(sourceId: source, title: source, authors: "Author",
                 fn: fn, audience: "Accessible",
                 whyOneLiner: "a fresh one-liner", claimContext: "context")
    }

    // MARK: - Phase 3: Citation budget engine

    func testOneCardPerSource() {
        let engine = CitationBudgetEngine()
        let ledger = CitationLedger()
        // Earn card budget by recording non-citation components first.
        (0..<10).forEach { _ in engine.recordComponent("paragraph", ledger: ledger) }

        XCTAssertEqual(engine.resolveRenderForm(citation("herman", fn: .mechanism), ledger: ledger), .card)
        // A second mention of the same source can never be a card again.
        XCTAssertEqual(engine.resolveRenderForm(citation("herman", fn: .mechanism), ledger: ledger), .chip)
    }

    func testLabelFatigueDemotesFourthToChip() {
        let engine = CitationBudgetEngine()
        let ledger = CitationLedger()
        (0..<20).forEach { _ in engine.recordComponent("paragraph", ledger: ledger) }

        // Interleave a component between citations so the consecutive-repeat rule
        // does not fire before the label-fatigue rule under test.
        XCTAssertEqual(engine.resolveRenderForm(citation("a", fn: .evidence), ledger: ledger), .card)
        engine.recordComponent("paragraph", ledger: ledger)
        XCTAssertEqual(engine.resolveRenderForm(citation("b", fn: .evidence), ledger: ledger), .card)
        engine.recordComponent("paragraph", ledger: ledger)
        XCTAssertEqual(engine.resolveRenderForm(citation("c", fn: .evidence), ledger: ledger), .card)
        engine.recordComponent("paragraph", ledger: ledger)
        // 4th card of the same label demotes.
        XCTAssertEqual(engine.resolveRenderForm(citation("d", fn: .evidence), ledger: ledger), .chip)
        XCTAssertEqual(ledger.cardsByLabel[.evidence], 3)
    }

    func testGlobalShareCapAtThirtyPercent() {
        let engine = CitationBudgetEngine()
        let ledger = CitationLedger()

        // With only 2 prior components, a card would be 1/3 ≈ 33% > 30% → chip.
        engine.recordComponent("paragraph", ledger: ledger)
        engine.recordComponent("paragraph", ledger: ledger)
        XCTAssertEqual(engine.resolveRenderForm(citation("a", fn: .mechanism), ledger: ledger), .chip)

        // One more component brings the projected share to 1/4 = 25% ≤ 30% → card.
        let ledger2 = CitationLedger()
        (0..<3).forEach { _ in engine.recordComponent("paragraph", ledger: ledger2) }
        XCTAssertEqual(engine.resolveRenderForm(citation("a", fn: .mechanism), ledger: ledger2), .card)
    }

    func testNoThreeConsecutiveCitationCards() {
        let engine = CitationBudgetEngine()
        let ledger = CitationLedger()
        (0..<20).forEach { _ in engine.recordComponent("paragraph", ledger: ledger) }

        XCTAssertEqual(engine.resolveRenderForm(citation("a", fn: .mechanism), ledger: ledger), .card)
        XCTAssertEqual(engine.resolveRenderForm(citation("b", fn: .parallelTrack), ledger: ledger), .card)
        // Two citation cards in a row already; a third consecutive must demote.
        XCTAssertEqual(engine.resolveRenderForm(citation("c", fn: .practitioner), ledger: ledger), .chip)
    }

    // MARK: - Phase 2: Loop diagram geometry

    func testLoopGeometryEndpointsOnCircle() {
        for nodeCount in 3...6 {
            let g = PDFDiagramGeometry.solveLoop(
                center: CGPoint(x: 230, y: 200), radius: 150,
                nodeCount: nodeCount, nodeSize: CGSize(width: 120, height: 46)
            )
            XCTAssertEqual(g.nodes.count, nodeCount)
            XCTAssertEqual(g.arcs.count, nodeCount)
            // All node centers and arc endpoints lie on the true circle (< 1pt).
            XCTAssertLessThan(PDFDiagramGeometry.maxRadialError(g), 1.0,
                              "node/endpoints off-circle for n=\(nodeCount)")
            // Every arc endpoint clears every node box by the clearance margin.
            XCTAssertGreaterThanOrEqual(PDFDiagramGeometry.minEndpointClearance(g),
                                        PDFDiagramGeometry.clearance - 0.5,
                                        "endpoint too close to a node for n=\(nodeCount)")
        }
    }

    // MARK: - Phase 2: Diagram promotion

    func testLinearChainPromotedToProcessTimeline() {
        let doc = makeDoc([PDFContentBlock(
            type: .paragraph,
            content: "The sequence: Fusion → Recognition → Distance → Contact → Choice → Direction.")])
        let out = DiagramPromotionEngine().promote(doc)
        let diagrams = out.sections[0].blocks.filter { $0.type == .processTimeline }
        XCTAssertEqual(diagrams.count, 1)
        XCTAssertEqual(diagrams.first?.listItems?.count, 6)
        // Surrounding prose is preserved, not swallowed.
        XCTAssertTrue(out.sections[0].blocks.contains { $0.type == .paragraph && $0.content.contains("sequence") })
    }

    func testFeedbackLoopPromotedToLoopDiagram() {
        let doc = makeDoc([PDFContentBlock(
            type: .paragraph,
            content: "It becomes a vicious loop: Rule → Vigilance → Guarded behavior → Reduced intimacy → Rule.")])
        let out = DiagramPromotionEngine().promote(doc)
        let loops = out.sections[0].blocks.filter { $0.type == .loopDiagram }
        XCTAssertEqual(loops.count, 1)
        // The duplicated origin node is collapsed: 5 arrow-nodes → 4 loop nodes.
        XCTAssertEqual(loops.first?.listItems?.count, 4)
    }

    func testTwoPoleConstructPromotedToSpectrum() {
        let doc = makeDoc([PDFContentBlock(
            type: .paragraph,
            content: "Overidentification ↔ Dissociation")])
        let out = DiagramPromotionEngine().promote(doc)
        let spectrums = out.sections[0].blocks.filter { $0.type == .spectrum }
        XCTAssertEqual(spectrums.count, 1)
        XCTAssertEqual(spectrums.first?.listItems?.count, 2)
    }

    // MARK: - Phase 1: Referential integrity

    func testGhostReferenceDetected() {
        let doc = makeDoc([PDFContentBlock(type: .paragraph,
                                           content: "The matrix prevents overusing defusion.")])
        let (_, report) = ReferentialIntegrityValidator().process(doc, repairViolations: false)
        XCTAssertFalse(report.isValid)
        XCTAssertEqual(report.violations.first?.category, .ghostReference)
    }

    func testResolvableReferenceRewrittenToExplicitFigure() {
        let doc = makeDoc([
            PDFContentBlock(type: .paragraph, content: "As the figure shows, defusion works."),
            PDFContentBlock(type: .processTimeline, content: "", listItems: ["A", "B", "C"])
        ])
        let (processed, report) = ReferentialIntegrityValidator().process(doc, repairViolations: false)
        XCTAssertTrue(report.isValid, report.summary)
        XCTAssertTrue(processed.sections[0].blocks[0].content.contains("Figure 1"))
        // The figure block carries its assigned number in metadata.
        XCTAssertEqual(processed.sections[0].blocks[1].metadata?["figureNumber"], "1")
    }

    func testOrphanColonLeadInDetectedAndRepaired() {
        let doc = makeDoc([
            PDFContentBlock(type: .paragraph, content: "Rate each domain from 0 to 5:"),
            PDFContentBlock(type: .paragraph, content: "A balanced profile matters more than a single high score.")
        ])
        // Detection
        let (_, report) = ReferentialIntegrityValidator().process(doc, repairViolations: false)
        XCTAssertTrue(report.violations.contains { $0.category == .orphanLeadIn })

        // Repair (Release behavior): the orphaned lead-in is suppressed.
        let (repaired, repairedReport) = ReferentialIntegrityValidator().process(doc, repairViolations: true)
        XCTAssertEqual(repaired.sections[0].blocks.count, 1)
        XCTAssertTrue(repaired.sections[0].blocks[0].content.contains("balanced profile"))
        XCTAssertTrue(repairedReport.violations.allSatisfy { $0.repaired })
    }

    func testGhostReferenceRepairSuppressesSentenceAtomically() {
        let doc = makeDoc([PDFContentBlock(
            type: .paragraph,
            content: "The pyramid supports calibrated confidence. Defusion still helps in practice.")])
        let (repaired, _) = ReferentialIntegrityValidator().process(doc, repairViolations: true)
        let content = repaired.sections[0].blocks.first?.content ?? ""
        XCTAssertFalse(content.lowercased().contains("pyramid"))
        XCTAssertTrue(content.contains("Defusion still helps"))
    }
}
