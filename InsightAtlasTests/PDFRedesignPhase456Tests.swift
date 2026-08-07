import XCTest
import UIKit
@testable import InsightAtlas

/// Tests for the PDF redesign citation + semantic-color cluster (Phases 4–6a):
///   • CitationTaxonomy      — loads bundled taxonomy, maps function → label/color
///   • CitationRegistry      — The Library: dedupe, group, order (Spec §4)
///   • Reconciliation checks — Library ⟷ inline (Spec §5.6)
///   • Semantic color tokens — WCAG AA contrast (Directives §C3)
final class PDFRedesignPhase456Tests: XCTestCase {

    private func makeDoc(_ blocks: [PDFContentBlock], heading: String = "Section") -> PDFAnalysisDocument {
        PDFAnalysisDocument(
            book: .init(title: "Test", author: "Author"),
            sections: [.init(heading: heading, headingLevel: 1, blocks: blocks)]
        )
    }

    private func dto(_ id: String, fn: String, why: String = "a fresh reason") -> CitationDTO {
        CitationDTO(sourceId: id, title: id.capitalized, authors: "Author",
                    function: fn, audience: "Accessible", whyOneLiner: why, claimContext: nil)
    }

    // MARK: - Phase 4: Taxonomy

    func testTaxonomyMapsFunctionToLabelAndColor() {
        XCTAssertEqual(CitationFunction.evidence.label, "The Evidence")
        XCTAssertEqual(CitationFunction.counterpoint.colorToken, "caution")
        XCTAssertEqual(CitationFunction.mechanism.colorToken, "burgundy")
        XCTAssertEqual(CitationFunction.practitioner.colorToken, "practice")
        // counterpoint (the only caution function) resolves to the amber accent.
        XCTAssertEqual(CitationFunction.counterpoint.accentColor, PDFStyleConfiguration.Colors.semanticCaution)
    }

    // MARK: - Phase 5: The Library

    func testLibraryDedupesGroupsAndOrders() {
        let citations = [
            dto("herman", fn: "counterpoint"),
            dto("rft", fn: "mechanism"),
            dto("herman", fn: "counterpoint"),   // duplicate source
            dto("masuda", fn: "evidence")
        ]
        let section = CitationRegistry.makeLibrarySection(from: citations, priorComponentCount: 20)
        XCTAssertNotNil(section)

        let entries = section!.blocks.filter { $0.type == .libraryEntry }
        // One entry per unique source.
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(Set(entries.compactMap { $0.metadata?["sourceId"] }), ["herman", "rft", "masuda"])

        // Grouped by function with heading3 group headers.
        let groupHeaders = section!.blocks.filter { $0.type == .heading3 }.map { $0.content }
        XCTAssertTrue(groupHeaders.contains("The Counterpoint"))
        XCTAssertTrue(groupHeaders.contains("The Mechanism"))
        XCTAssertTrue(groupHeaders.contains("The Evidence"))

        // renderPriority ordering: counterpoint (1) precedes evidence (2) and mechanism (2).
        XCTAssertEqual(groupHeaders.first, "The Counterpoint")
    }

    func testLibraryEntryCarriesFunctionColorToken() {
        let section = CitationRegistry.makeLibrarySection(from: [dto("herman", fn: "counterpoint")], priorComponentCount: 5)
        let entry = section!.blocks.first { $0.type == .libraryEntry }
        XCTAssertEqual(entry?.metadata?["colorToken"], "caution")
        XCTAssertEqual(entry?.metadata?["level"], "Accessible")
    }

    func testNoCitationsYieldsNoLibrary() {
        XCTAssertNil(CitationRegistry.makeLibrarySection(from: [], priorComponentCount: 0))
    }

    // MARK: - Phase 5: Reconciliation

    func testDuplicateLibraryEntryFlagged() {
        let doc = makeDoc([
            PDFContentBlock(type: .libraryEntry, content: "", metadata: ["sourceId": "x", "title": "X"]),
            PDFContentBlock(type: .libraryEntry, content: "", metadata: ["sourceId": "x", "title": "X"])
        ], heading: "The Library")
        let (_, report) = ReferentialIntegrityValidator().process(doc, repairViolations: false)
        XCTAssertTrue(report.violations.contains { $0.category == .libraryDuplicate })
    }

    func testInlineCitationWithoutLibraryEntryFlagged() {
        let doc = makeDoc([
            PDFContentBlock(type: .paragraph, content: "A supported claim.", metadata: ["citationSourceId": "ghost-source"])
        ])
        let (_, report) = ReferentialIntegrityValidator().process(doc, repairViolations: false)
        XCTAssertTrue(report.violations.contains { $0.category == .libraryMissing })
    }

    // MARK: - Phase 6a: Semantic color contrast (WCAG AA)

    func testSemanticAccentsMeetContrastOnCream() {
        let cream = PDFStyleConfiguration.Colors.bgSecondary
        for accent in [
            PDFStyleConfiguration.Colors.semanticNotes,
            PDFStyleConfiguration.Colors.semanticEvidence,
            PDFStyleConfiguration.Colors.semanticPractice,
            PDFStyleConfiguration.Colors.semanticCaution
        ] {
            // Used as bold label / accent text → AA large (≥ 3.0:1).
            XCTAssertTrue(WCAGContrast.meetsAA(accent, on: cream, large: true),
                          "accent contrast \(WCAGContrast.ratio(accent, cream)) < 3.0")
        }
        // Body text on the amber caution background must clear AA normal.
        XCTAssertTrue(WCAGContrast.meetsAA(PDFStyleConfiguration.Colors.textBody,
                                           on: PDFStyleConfiguration.Colors.semanticCautionBg))
    }
}
