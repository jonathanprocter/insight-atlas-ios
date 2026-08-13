import Foundation

// MARK: - PDF Document Processor
//
// The single post-assembly transform pass over a PDFAnalysisDocument, run at the
// top of `InsightAtlasPDFRenderer.render(document:)` — the one choke point every
// generation path (thematic JSON, markdown parse, ParsedAnalysisContent) funnels
// through before pixels.
//
// Pass order matters:
//   1. Diagram promotion (Phase 2) — lifts arrow-chain prose into diagram blocks
//      FIRST, so the diagrams exist to be numbered and to satisfy references.
//   2. Referential integrity (Phase 1) — number figures/tables, rewrite deictic
//      references to explicit ones, validate, and (in Release) repair.
//
// Failure policy (per product decision):
//   • DEBUG   → hard-abort: throw so every violation surfaces during development
//     and the golden regression test can flip red→green.
//   • Release → auto-repair + log: suppress offending sentences atomically and
//     still produce a PDF, so an on-device user waiting on an export never gets a
//     hard failure over one stray reference.
//
// NOTE (Phase 3 seam): `CitationBudgetEngine` is delivered and unit-tested in this
// batch, but its document-level wiring activates in Phase 4/5, where citations
// become first-class (taxonomy classification supplies each citation's `fn` and
// `audience`) and The Library page gives the demotions something to reconcile
// against. It is intentionally not run here yet — there are no classifiable
// citation objects in the assembled model until the taxonomy lands.

struct PDFDocumentProcessor {

    struct Processed {
        let document: PDFAnalysisDocument
        let integrityReport: ReferentialIntegrityValidator.Report
    }

    /// Process the assembled document. Throws in DEBUG when referential integrity
    /// fails; auto-repairs and logs in Release.
    static func process(_ document: PDFAnalysisDocument) throws -> Processed {
        let promoted = DiagramPromotionEngine().promote(document)

        // Structural reclassification (capability-audit Batch B): the generator
        // mislabels hub-and-spoke content as flowcharts; convert those to concept
        // maps BEFORE numbering so the manifest/figure labels reflect the real type.
        let reclassified = FlowchartReclassifier().reclassify(promoted)

        let validator = ReferentialIntegrityValidator()

        let checked: PDFAnalysisDocument
        let report: ReferentialIntegrityValidator.Report

        #if DEBUG
        (checked, report) = validator.process(reclassified, repairViolations: false)
        if !report.isValid {
            print("❌ [PDF Referential Integrity]\n\(report.summary)")
            throw ReferentialIntegrityValidator.ValidationError.violations(report)
        }
        #else
        (checked, report) = validator.process(reclassified, repairViolations: true)
        if !report.isValid {
            print("⚠️ [PDF Referential Integrity] auto-repaired in Release build\n\(report.summary)")
        }
        #endif

        // Builds-stage triage — always logged (independent of violations) so the
        // manifest/distance checklist is available on any real export.
        if !report.visualManifest.isEmpty {
            print("📊 [PDF Visual Manifest]\n  " + report.visualManifest.joined(separator: "\n  "))
        }
        if !report.referenceDistances.isEmpty {
            print("📏 [PDF Reference Distances — farthest first]\n  " + report.referenceDistances.joined(separator: "\n  "))
        }

        // Additive structure pass: section-opener chips + pull quotes (Phase 6).
        let enhanced = DocumentStructureEnhancer().enhance(checked)
        return Processed(document: enhanced, integrityReport: report)
    }
}

// MARK: - Flowchart Reclassifier (capability-audit Batch B — structural)
//
// The generator persistently mislabels hub-and-spoke content ("Branch — X" plus
// parallel members) as [VISUAL_FLOWCHART], producing a wall of near-identical
// process diagrams. Prompt guidance (terse rules, then a few-shot example) was
// confirmed to reach the model and was demonstrably ignored, so we enforce the
// intent STRUCTURALLY: a flowchart whose first node is a hub marker
// ("Branch — …", "Category: …") is not an ordered sequence — convert it to a
// native concept map (central = the hub label, spokes = the members). This is
// conservative by construction: a genuine causal flowchart never opens with a
// hub marker, so real process diagrams are left untouched.
struct FlowchartReclassifier {

    func reclassify(_ document: PDFAnalysisDocument) -> PDFAnalysisDocument {
        var converted = 0
        var doc = document
        doc.sections = document.sections.map { section in
            var s = section
            s.blocks = section.blocks.map { block -> PDFContentBlock in
                guard block.type == .flowchart,
                      let nodes = block.listItems, nodes.count >= 3,
                      let central = hubCentral(from: nodes.first ?? "") else {
                    return block
                }
                let branches = nodes.dropFirst().compactMap { PDFAnalysisDocument.sanitizeConceptBranch($0) }
                guard branches.count >= 2 else { return block }   // needs a real hub + ≥2 spokes
                converted += 1
                var meta = block.metadata ?? [:]
                meta["central"] = central
                meta["title"] = "Concept Map"
                return PDFContentBlock(type: .conceptMap, content: "", listItems: branches, metadata: meta)
            }
            return s
        }
        if converted > 0 {
            print("🖼️ [PDF Visual] reclassified \(converted) hub-flowchart(s) → concept map (structural)")
        }
        return doc
    }

    /// Hub markers that reveal a "central concept + members" structure mislabeled
    /// as a flowchart. Deliberately narrow so genuine sequences are never caught.
    private static let hubMarker = try? NSRegularExpression(
        pattern: #"^\s*(branch|category|theme|group|cluster)\s*[—–\-:]\s*"#,
        options: [.caseInsensitive]
    )

    /// Returns the central concept if `firstNode` is a hub marker like
    /// "Branch — Metaphorical reframing", else nil.
    private func hubCentral(from firstNode: String) -> String? {
        guard let regex = Self.hubMarker else { return nil }
        let ns = firstNode as NSString
        guard let m = regex.firstMatch(in: firstNode, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let central = ns.substring(from: m.range.length).trimmingCharacters(in: .whitespaces)
        return central.isEmpty ? nil : central
    }
}
