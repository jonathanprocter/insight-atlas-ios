import Foundation

// MARK: - Citation Budget Engine (Phase 3 — Directives §B1, Citation Spec §2)
//
// A faithful Swift port of the `resolveRenderForm` TypeScript module from
// `citation-system-spec.md` §2. It classifies each citation's render form by
// walking the document in order and enforcing four budgets:
//
//   1. One citation CARD per source per document, ever. Repeat → chip.
//   2. Max 3 cards per label (function) per document. 4th+ → chip.
//   3. Citation cards ≤ 30% of ALL component instances.
//   4. Never 3 identical component types consecutively (applies to all
//      components, not only citations).
//
// Anything demoted still registers in the document-level source registry and
// (Phase 5) renders once on The Library page. This engine is deterministic and
// side-effect free apart from the mutable `CitationLedger` it threads through,
// mirroring the reference implementation exactly.

/// The relationship of a source to the claim it supports. Drives label + color.
/// Raw values match `citation-taxonomy.json` (`function` keys) verbatim.
enum CitationFunction: String, Codable, CaseIterable {
    case primarySource = "primary_source"
    case mechanism
    case evidence
    case counterpoint
    case parallelTrack = "parallel_track"
    case practitioner
}

/// The demotion ladder. Raw values match the spec's `demotionLadder`.
enum CitationRenderForm: String, Codable {
    case card
    case chip
    case shelf
    case libraryOnly = "library_only"
}

/// A single citation instance encountered while assembling the document.
/// Field names mirror the `Citation` interface in Spec §2.
struct Citation {
    let sourceId: String        // stable key, e.g. "herman-trauma-recovery"
    let title: String
    let authors: String
    let fn: CitationFunction
    let audience: String        // one of the taxonomy's audienceLevels
    let whyOneLiner: String     // ≤ 12 words, composed fresh per citation
    let claimContext: String    // the sentence/section this citation supports
}

/// Mutable state threaded through the document walk. Mirrors `Ledger` in Spec §2.
final class CitationLedger {
    var cardsBySource: [String: Int] = [:]
    var cardsByLabel: [CitationFunction: Int] = [:]
    /// Rolling window of emitted component-type tokens ("citation_card",
    /// "citation_chip", or an arbitrary non-citation component key).
    var lastComponents: [String] = []
    var totalComponents: Int = 0
    var totalCitationCards: Int = 0

    init() {}
}

/// Budget constants — identical to the `BUDGET` object in Spec §2.
enum CitationBudget {
    static let maxCardsPerSource = 1
    static let maxCardsPerLabel = 3
    static let maxConsecutiveSame = 2
    static let maxCardShare = 0.30
}

/// Resolves the render form for each citation against the running ledger.
struct CitationBudgetEngine {

    /// Direct port of `resolveRenderForm`. Classify → check budgets → emit form.
    func resolveRenderForm(_ c: Citation, ledger: CitationLedger) -> CitationRenderForm {
        let perSource = ledger.cardsBySource[c.sourceId] ?? 0
        let perLabel = ledger.cardsByLabel[c.fn] ?? 0

        // Rule 1 — a source only ever gets ONE card. Repeat mention → chip.
        if perSource >= CitationBudget.maxCardsPerSource {
            return demote(c, to: .chip, ledger: ledger)
        }

        // Rule 2 — label fatigue: 4th+ use of the same label demotes to chip.
        if perLabel >= CitationBudget.maxCardsPerLabel {
            return demote(c, to: .chip, ledger: ledger)
        }

        // Rule 3 — global share: citation cards may not exceed 30% of components.
        let projectedShare =
            Double(ledger.totalCitationCards + 1) / Double(ledger.totalComponents + 1)
        if projectedShare > CitationBudget.maxCardShare {
            return demote(c, to: .chip, ledger: ledger)
        }

        // Rule 4 — rhythm: never 3 identical component types in a row.
        let tail = ledger.lastComponents.suffix(CitationBudget.maxConsecutiveSame)
        if tail.count >= CitationBudget.maxConsecutiveSame,
           tail.allSatisfy({ $0 == "citation_card" }) {
            return demote(c, to: .chip, ledger: ledger)
        }

        commit(ledger, c, form: .card)
        return .card
    }

    /// Records a non-citation component in the ledger so that global-share
    /// (Rule 3) and consecutive-repeat (Rule 4) accounting spans ALL component
    /// types, not just citations — as the shared `Ledger` in the spec implies.
    /// `typeKey` is a stable token for the component class (e.g. block type).
    func recordComponent(_ typeKey: String, ledger: CitationLedger) {
        ledger.lastComponents.append(typeKey)
        ledger.totalComponents += 1
        if ledger.lastComponents.count > 8 { ledger.lastComponents.removeFirst() }
    }

    // MARK: - Private (mirrors the spec's `demote` / `commit`)

    private func demote(_ c: Citation, to form: CitationRenderForm, ledger: CitationLedger) -> CitationRenderForm {
        // Chips can further collapse: 3+ chips in one section → margin shelf
        // (applied by the section-level shelf pass, Phase 5). Anything demoted
        // still ALWAYS gets a Library entry (Spec §4).
        commit(ledger, c, form: form)
        return form
    }

    private func commit(_ l: CitationLedger, _ c: Citation, form: CitationRenderForm) {
        if form == .card {
            l.cardsBySource[c.sourceId, default: 0] += 1
            l.cardsByLabel[c.fn, default: 0] += 1
            l.totalCitationCards += 1
            l.lastComponents.append("citation_card")
        } else {
            l.lastComponents.append("citation_\(form.rawValue)")
        }
        l.totalComponents += 1
        if l.lastComponents.count > 8 { l.lastComponents.removeFirst() }
    }
}
