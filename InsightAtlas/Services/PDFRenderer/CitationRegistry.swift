import Foundation

// MARK: - Citation Registry & The Library (Phase 5 — Citation Spec §4)
//
// Collects every citation the generator emitted, runs them through the budget
// engine (so render forms are assigned for audit / future inline use), and
// builds the single "The Library" end-page: each source appears exactly once,
// grouped by function and ordered by render priority, with an audience-level
// pill and its fresh one-line "why".

/// A citation as emitted in the thematic-synthesis JSON. Optional on the
/// response so existing payloads without citations still decode.
struct CitationDTO: Codable {
    let sourceId: String
    let title: String
    let authors: String
    let function: String       // maps to CitationFunction.rawValue
    let audience: String
    let whyOneLiner: String
    let claimContext: String?
}

struct CitationRegistry {

    /// Build the Library section, or nil when there are no citations.
    /// - Parameter priorComponentCount: number of components already assembled,
    ///   used to seed the budget ledger's global-share accounting.
    static func makeLibrarySection(from citations: [CitationDTO], priorComponentCount: Int) -> PDFAnalysisDocument.PDFSection? {
        guard !citations.isEmpty else { return nil }

        // Dedupe by sourceId (first mention wins) — one entry per source.
        var seen = Set<String>()
        var unique: [CitationDTO] = []
        for c in citations where !seen.contains(c.sourceId) {
            seen.insert(c.sourceId)
            unique.append(c)
        }

        // Run the budget engine so demotions are computed (audited by the
        // referential validator; consumed inline in a later pass).
        let engine = CitationBudgetEngine()
        let ledger = CitationLedger()
        for _ in 0..<max(0, priorComponentCount) { engine.recordComponent("paragraph", ledger: ledger) }
        for dto in unique {
            let fn = CitationFunction(rawValue: dto.function) ?? .primarySource
            _ = engine.resolveRenderForm(
                Citation(sourceId: dto.sourceId, title: dto.title, authors: dto.authors,
                         fn: fn, audience: dto.audience, whyOneLiner: dto.whyOneLiner,
                         claimContext: dto.claimContext ?? ""),
                ledger: ledger)
        }

        // Group by function, ordered by renderPriority then label.
        let grouped = Dictionary(grouping: unique) { CitationFunction(rawValue: $0.function) ?? .primarySource }
        let orderedFns = grouped.keys.sorted { a, b in
            a.renderPriority != b.renderPriority ? a.renderPriority < b.renderPriority : a.label < b.label
        }

        var blocks: [PDFContentBlock] = [
            PDFContentBlock(
                type: .paragraph,
                content: "Every source cited in this guide, organized by the role it played in the synthesis — not alphabetically. Inline cards appear once per source; everything else lives here.")
        ]

        for fn in orderedFns {
            blocks.append(PDFContentBlock(type: .heading3, content: fn.label))
            for dto in grouped[fn] ?? [] {
                blocks.append(PDFContentBlock(
                    type: .libraryEntry,
                    content: "",
                    metadata: [
                        "title": dto.title,
                        "authors": dto.authors,
                        "why": dto.whyOneLiner,
                        "level": dto.audience,
                        "colorToken": fn.colorToken,
                        "sourceId": dto.sourceId
                    ]))
            }
        }

        return PDFAnalysisDocument.PDFSection(heading: "The Library", headingLevel: 1, blocks: blocks)
    }
}
