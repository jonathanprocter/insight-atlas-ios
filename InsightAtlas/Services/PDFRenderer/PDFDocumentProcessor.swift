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

        let validator = ReferentialIntegrityValidator()

        let checked: PDFAnalysisDocument
        let report: ReferentialIntegrityValidator.Report

        #if DEBUG
        (checked, report) = validator.process(promoted, repairViolations: false)
        if !report.isValid {
            print("❌ [PDF Referential Integrity]\n\(report.summary)")
            throw ReferentialIntegrityValidator.ValidationError.violations(report)
        }
        #else
        (checked, report) = validator.process(promoted, repairViolations: true)
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
