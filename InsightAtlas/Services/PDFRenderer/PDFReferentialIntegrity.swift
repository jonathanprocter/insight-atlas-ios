import Foundation

// MARK: - Referential Integrity (Phase 1 — Directives §A1–A3)
//
// A post-assembly pass over the PDFAnalysisDocument block stream that guarantees
// no shipped PDF references a figure/matrix/pyramid/table/visual that did not
// render, and no colon lead-in introduces content that never appears.
//
// Responsibilities:
//   1. Assign document-wide sequential Figure N / Table N numbers (stored in
//      block metadata) — numbering keys off the synthesis's own order, never
//      source-book chapters.
//   2. Rewrite resolvable deictic references ("the visual") into explicit,
//      checkable references ("Figure 6").
//   3. Detect violations: ghost references with no resolving figure in-section,
//      dangling explicit figure numbers, and orphaned colon lead-ins.
//   4. Repair atomically (suppress the offending sentence(s) as a unit) or, in
//      DEBUG, surface the violations by throwing.

struct ReferentialIntegrityValidator {

    // MARK: Public types

    struct Violation {
        enum Category: String {
            case ghostReference = "GHOST_REFERENCE"
            case danglingFigureNumber = "DANGLING_FIGURE_NUMBER"
            case orphanLeadIn = "ORPHAN_LEAD_IN"
            case libraryDuplicate = "LIBRARY_DUPLICATE"
            case libraryMissing = "LIBRARY_MISSING"
        }
        let category: Category
        let sectionIndex: Int
        let blockIndex: Int
        let message: String
        var repaired: Bool = false
    }

    struct Report {
        var violations: [Violation]
        var figureCount: Int
        var tableCount: Int
        /// Invariant residue: explicit "Figure/Table N" strings that still have no
        /// rendered target N after the pass (load-bearing danglers awaiting a build
        /// or an authored rewrite). Empty ⇒ the referential invariant holds.
        var unresolvedReferences: [String] = []
        /// Builds-stage triage manifest: one row per rendered figure/table with
        /// its cache and referenced state (the "cached surplus" column — assets
        /// that never became blocks — is not recoverable at render time and is
        /// gathered separately from VisualSelectionService).
        var visualManifest: [String] = []
        /// Soft signal for the "exists but distant" case (e.g. p73): block-distance
        /// from each in-prose reference to its resolved target, sorted farthest-first.
        var referenceDistances: [String] = []
        var isValid: Bool { violations.isEmpty }
        /// The hard, boolean invariant the cut stage must satisfy.
        var invariantHolds: Bool { unresolvedReferences.isEmpty }
        var summary: String {
            var out: String
            if violations.isEmpty {
                out = "Referential integrity OK — \(figureCount) figure(s), \(tableCount) table(s), 0 violations."
            } else {
                let lines = violations.map {
                    "  • [\($0.category.rawValue)] §\($0.sectionIndex).\($0.blockIndex): \($0.message)\($0.repaired ? " (repaired)" : "")"
                }
                out = "Referential integrity: \(violations.count) violation(s)\n" + lines.joined(separator: "\n")
            }
            if !unresolvedReferences.isEmpty {
                out += "\n❌ INVARIANT FAILED — \(unresolvedReferences.count) reference(s) with no rendered target:\n  - "
                    + unresolvedReferences.joined(separator: "\n  - ")
            }
            if !visualManifest.isEmpty {
                out += "\n— Visual manifest —\n  " + visualManifest.joined(separator: "\n  ")
            }
            if !referenceDistances.isEmpty {
                out += "\n— Reference distances (farthest first) —\n  " + referenceDistances.joined(separator: "\n  ")
            }
            return out
        }
    }

    enum ValidationError: Error, LocalizedError {
        case violations(Report)
        var errorDescription: String? {
            switch self {
            case .violations(let report): return report.summary
            }
        }
    }

    // MARK: Configuration

    /// Figure-like block types that receive a "Figure N" number.
    private static let figureTypes: Set<PDFContentBlock.BlockType> = [
        .visual, .flowchart, .processTimeline, .conceptMap, .loopDiagram, .spectrum
    ]

    /// Block types that satisfy a colon lead-in (they render enumerated/tabular
    /// content or a diagram).
    private static let resolvingTypes: Set<PDFContentBlock.BlockType> = [
        .table, .bulletList, .numberedList, .flowchart, .processTimeline,
        .conceptMap, .loopDiagram, .spectrum, .visual, .exercise, .actionBox, .keyTakeaways
    ]

    /// Text-bearing block types whose prose is scanned for references.
    private static let proseTypes: Set<PDFContentBlock.BlockType> = [
        .paragraph, .foundationalNarrative, .insightNote, .alternativePerspective,
        .researchInsight, .example, .blockquote
    ]

    private static let figureDeictic = [
        "the pyramid", "the figure", "the visual", "the diagram", "the chart",
        "the graphic", "the illustration", "the spectrum", "the loop", "the stepper"
    ]
    private static let tableDeictic = ["the table", "the rubric", "the rating table", "the grid"]
    // "matrix" can be satisfied by either a figure or a table.
    private static let ambiguousDeictic = ["the matrix"]

    private static let leadInCues = [
        "follow", "these", "below", "rate", "rating", "scale", "table", "matrix",
        "list", "steps", "dimensions", "domains", "columns", "0 to", "1 to",
        "0-", "1-", "as such", "the following"
    ]

    // MARK: - Figure numbering

    private struct FigureIndex {
        var sectionHasFigure: [Int: Bool] = [:]
        var sectionHasTable: [Int: Bool] = [:]
        var sectionFirstFigure: [Int: Int] = [:]
        var sectionFirstTable: [Int: Int] = [:]
        var assignedFigures: Set<Int> = []
        var assignedTables: Set<Int> = []
    }

    /// Assign sequential figure/table numbers into block metadata and build an
    /// index of what each section contains.
    private func assignFigureNumbers(_ document: PDFAnalysisDocument) -> (PDFAnalysisDocument, FigureIndex) {
        var doc = document
        var index = FigureIndex()
        var figureCounter = 0
        var tableCounter = 0

        for (sIdx, section) in doc.sections.enumerated() {
            var blocks = section.blocks
            for (bIdx, block) in blocks.enumerated() {
                if Self.figureTypes.contains(block.type) {
                    figureCounter += 1
                    var meta = block.metadata ?? [:]
                    meta["figureLabel"] = "Figure"
                    meta["figureNumber"] = String(figureCounter)
                    blocks[bIdx] = block.replacingMetadata(meta)
                    index.assignedFigures.insert(figureCounter)
                    if index.sectionFirstFigure[sIdx] == nil { index.sectionFirstFigure[sIdx] = figureCounter }
                    index.sectionHasFigure[sIdx] = true
                } else if block.type == .table {
                    tableCounter += 1
                    var meta = block.metadata ?? [:]
                    meta["figureLabel"] = "Table"
                    meta["figureNumber"] = String(tableCounter)
                    blocks[bIdx] = block.replacingMetadata(meta)
                    index.assignedTables.insert(tableCounter)
                    if index.sectionFirstTable[sIdx] == nil { index.sectionFirstTable[sIdx] = tableCounter }
                    index.sectionHasTable[sIdx] = true
                }
            }
            doc.sections[sIdx].blocks = blocks
        }
        return (doc, index)
    }

    // MARK: - Deictic → explicit rewrite (REMOVED)
    //
    // `rewriteResolvableReferences` was deleted. It mapped ordinary deictic
    // phrases ("the figure", "the loop") onto a section's FIRST figure, silently
    // fabricating explicit references that then passed the referential invariant.
    // On the degenerate single-section export path it mapped everything onto
    // "Figure 1". This violated the shipped policy (strip decorative, flag
    // load-bearing, never fabricate/silently-correct), so the behavior is gone —
    // deictics stay as natural prose and only explicit numeric references are
    // validated.

    // MARK: - Violation detection

    private func findViolations(_ document: PDFAnalysisDocument, index: FigureIndex) -> [Violation] {
        var violations: [Violation] = []

        for (sIdx, section) in document.sections.enumerated() {
            for (bIdx, block) in section.blocks.enumerated() {

                if Self.proseTypes.contains(block.type) {
                    // Deictic ghost detection removed: idioms like "the loop" / "the
                    // figure" are ordinary language, not figure references. Flagging
                    // them produced false positives (and, via the removed rewriter,
                    // fabricated refs). Only EXPLICIT numeric references are validated.
                    for (kind, assigned) in [("Figure", index.assignedFigures), ("Table", index.assignedTables)] {
                        for number in explicitReferences(kind: kind, in: block.content) where !assigned.contains(number) {
                            violations.append(Violation(
                                category: .danglingFigureNumber, sectionIndex: sIdx, blockIndex: bIdx,
                                message: "references \(kind) \(number), which does not exist"))
                        }
                    }
                }

                // 3. Orphaned colon lead-in.
                if isColonLeadIn(block) {
                    let next = bIdx + 1 < section.blocks.count ? section.blocks[bIdx + 1] : nil
                    let resolved = next.map { Self.resolvingTypes.contains($0.type) } ?? false
                    if !resolved {
                        violations.append(Violation(
                            category: .orphanLeadIn, sectionIndex: sIdx, blockIndex: bIdx,
                            message: "colon lead-in introduces content that never renders"))
                    }
                }
            }
        }

        // Doc-level: The Library ⟷ inline citation reconciliation (Spec §4/§5.6).
        var libraryIds: [String] = []
        var inlineIds: [String] = []
        for (sIdx, section) in document.sections.enumerated() {
            for (bIdx, block) in section.blocks.enumerated() {
                if block.type == .libraryEntry, let id = block.metadata?["sourceId"] {
                    if libraryIds.contains(id) {
                        violations.append(Violation(
                            category: .libraryDuplicate, sectionIndex: sIdx, blockIndex: bIdx,
                            message: "source \"\(id)\" appears more than once in The Library"))
                    }
                    libraryIds.append(id)
                }
                if let id = block.metadata?["citationSourceId"] { inlineIds.append(id) }
            }
        }
        let librarySet = Set(libraryIds)
        for id in Set(inlineIds) where !librarySet.contains(id) {
            violations.append(Violation(
                category: .libraryMissing, sectionIndex: -1, blockIndex: -1,
                message: "inline citation \"\(id)\" has no entry in The Library"))
        }

        return violations
    }

    private func isColonLeadIn(_ block: PDFContentBlock) -> Bool {
        guard block.type == .paragraph, (block.listItems ?? []).isEmpty else { return false }
        let trimmed = block.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasSuffix(":") else { return false }
        let lowered = trimmed.lowercased()
        return Self.leadInCues.contains { lowered.contains($0) }
    }

    // MARK: - Repair (atomic sentence suppression)

    private func repair(_ document: PDFAnalysisDocument, violations: [Violation]) -> PDFAnalysisDocument {
        var doc = document
        // Group violations by section → block.
        var byBlock: [Int: [Int: [Violation]]] = [:]
        for v in violations { byBlock[v.sectionIndex, default: [:]][v.blockIndex, default: []].append(v) }

        for (sIdx, blockMap) in byBlock {
            guard sIdx < doc.sections.count else { continue }
            var rebuilt: [PDFContentBlock] = []
            for (bIdx, block) in doc.sections[sIdx].blocks.enumerated() {
                guard let vs = blockMap[bIdx] else { rebuilt.append(block); continue }
                let cleaned = suppressSentences(in: block.content, for: vs)
                if cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue // whole block was the offending reference — drop it
                }
                rebuilt.append(block.replacingContent(cleaned))
            }
            doc.sections[sIdx].blocks = rebuilt
        }
        return doc
    }

    /// Remove, as an atomic unit, every sentence implicated by this block's
    /// violations — the orphaned lead-in and the ghost reference are suppressed
    /// together so the prose never dangles.
    private func suppressSentences(in content: String, for violations: [Violation]) -> String {
        let ghostPhrases = Self.figureDeictic + Self.tableDeictic + Self.ambiguousDeictic
        let hasGhost = violations.contains { $0.category == .ghostReference }
        let hasOrphan = violations.contains { $0.category == .orphanLeadIn }

        let units = splitSentences(content)
        let kept = units.filter { unit in
            let lowered = unit.lowercased()
            if hasOrphan && unit.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix(":") { return false }
            if hasGhost && ghostPhrases.contains(where: { lowered.contains($0) }) { return false }
            return true
        }
        return kept.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Orchestration entry point

    /// Number figures, rewrite resolvable references, then validate. When
    /// `repairViolations` is true (Release), offending sentences are suppressed
    /// and a repaired document is returned; otherwise the document is returned
    /// unrepaired and the caller decides how to react to the report.
    func process(_ document: PDFAnalysisDocument, repairViolations: Bool) -> (PDFAnalysisDocument, Report) {
        let (numbered, index) = assignFigureNumbers(document)

        // Deictic REWRITING removed (policy violation): converting ordinary phrases
        // like "the figure"/"the loop" into explicit "Figure N" references silently
        // FABRICATED references that then satisfied the invariant — strictly worse
        // than the sentence-suppressor we removed, because it manufactured
        // invariant-passing garbage. Deictics now stay as natural prose; only
        // explicit numeric references are validated. Policy: strip decorative,
        // flag load-bearing, never fabricate or silently correct.

        // Tiered dangling-reference handling (pre-layout, block→block, so no height
        // calc ever sees the stripped text):
        //  • auto-strip PARENTHETICAL refs to non-existent numbers — "(see Figure 5)",
        //    ", as shown in Table 2" — decoration, meaning-preserving, safe.
        //  • LOAD-BEARING refs — "Table 1 helps distinguish…" — are left untouched;
        //    a machine must not mangle a sentence whose argument IS the missing
        //    figure. They surface as violations + in `unresolvedReferences`.
        let dereferenced = stripDecorativeDanglingReferences(numbered, index: index)

        var violations = findViolations(dereferenced, index: index)

        var report = Report(
            violations: violations,
            figureCount: index.assignedFigures.count,
            tableCount: index.assignedTables.count
        )
        report.unresolvedReferences = unresolvedReferences(dereferenced, index: index)
        (report.visualManifest, report.referenceDistances) = buildManifest(dereferenced, index: index)

        guard !violations.isEmpty, repairViolations else {
            return (dereferenced, report)
        }

        // Dangling numbers are deliberately NOT sentence-suppressed — they are
        // resolved by the decorative strip, satisfied by a built figure/table
        // later, or flagged for authoring. Only deictic ghosts and orphan lead-ins
        // are safe to atomically suppress.
        let repairable: Set<Violation.Category> = [.ghostReference, .orphanLeadIn]
        let repaired = repair(dereferenced, violations: violations.filter { repairable.contains($0.category) })
        for i in violations.indices where repairable.contains(violations[i].category) {
            violations[i].repaired = true
        }
        report.violations = violations
        report.unresolvedReferences = unresolvedReferences(repaired, index: index)
        (report.visualManifest, report.referenceDistances) = buildManifest(repaired, index: index)
        return (repaired, report)
    }

    // MARK: - Tiered dangling-reference handling

    /// Auto-strip PARENTHETICAL references to non-existent figure/table numbers,
    /// preserving the surrounding sentence. Load-bearing references (where the
    /// number is integral to the clause) match no decorative pattern and are left
    /// intact for `findViolations` / `unresolvedReferences` to flag.
    private func stripDecorativeDanglingReferences(_ document: PDFAnalysisDocument, index: FigureIndex) -> PDFAnalysisDocument {
        var doc = document
        for (sIdx, section) in doc.sections.enumerated() {
            var blocks = section.blocks
            for (bIdx, block) in blocks.enumerated() where Self.proseTypes.contains(block.type) {
                var text = block.content
                for (kind, assigned) in [("Figure", index.assignedFigures), ("Table", index.assignedTables)] {
                    let danglers = Set(explicitReferences(kind: kind, in: text).filter { !assigned.contains($0) })
                    for number in danglers {
                        text = stripDecorativeReference(kind: kind, number: number, in: text)
                    }
                }
                if text != block.content { blocks[bIdx] = block.replacingContent(text) }
            }
            doc.sections[sIdx].blocks = blocks
        }
        return doc
    }

    /// Remove only clearly-decorative occurrences of `kind number`
    /// (e.g. "(see Figure 5)", ", as shown in Table 2", "; see Figure 3 below").
    /// A load-bearing occurrence ("Figure 5 shows…", "closes Figure 5") matches
    /// none of these and is returned unchanged.
    private func stripDecorativeReference(kind: String, number: Int, in text: String) -> String {
        let ref = "\(kind)\\s+\(number)"
        let patterns = [
            // Parenthetical: "(Figure 5)", "(see Figure 5)", "(see also Figure 5 below)"
            "\\s*\\(\\s*(?:see\\s+(?:also\\s+)?)?\(ref)(?:\\s*[,;]?\\s*(?:above|below))?\\s*\\)",
            // Trailing decorative clause: ", as shown in Figure 5", "; see Table 2"
            "[,;]?\\s*(?:as\\s+(?:shown|illustrated|depicted|seen)\\s+in|see(?:\\s+also)?)\\s+\(ref)\\b"
        ]
        var result = text
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        return normalizeWhitespaceAfterStrip(result)
    }

    /// Tidy the punctuation/spacing a strip can leave behind ("word ." → "word.",
    /// empty "()", doubled spaces).
    private func normalizeWhitespaceAfterStrip(_ text: String) -> String {
        var t = text
        for (pattern, template) in [("\\s+([,.;:!?])", "$1"), ("\\(\\s*\\)", ""), ("\\s{2,}", " ")] {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(t.startIndex..<t.endIndex, in: t)
            t = regex.stringByReplacingMatches(in: t, range: range, withTemplate: template)
        }
        return t.trimmingCharacters(in: .whitespaces)
    }

    /// The invariant enumerator: every explicit "Figure/Table N" still present with
    /// no rendered target N. Empty ⇒ invariant holds.
    private func unresolvedReferences(_ document: PDFAnalysisDocument, index: FigureIndex) -> [String] {
        var out: [String] = []
        for (sIdx, section) in document.sections.enumerated() {
            for (bIdx, block) in section.blocks.enumerated() where Self.proseTypes.contains(block.type) {
                for (kind, assigned) in [("Figure", index.assignedFigures), ("Table", index.assignedTables)] {
                    for number in explicitReferences(kind: kind, in: block.content) where !assigned.contains(number) {
                        out.append("\(kind) \(number) — §\(sIdx).\(bIdx) (load-bearing; needs a built \(kind.lowercased()) or an authored rewrite)")
                    }
                }
            }
        }
        return out
    }

    // MARK: - Builds-stage manifest + distance diagnostics

    /// Render-time triage: one manifest row per rendered figure/table (type,
    /// cache state for visuals, and whether prose references it) plus a
    /// farthest-first list of reference→target block distances.
    ///
    /// NOT computable here: "cached but never emitted" surplus — the cache has no
    /// key enumeration and `localURL(for:)` is a one-way hash, so that column is
    /// gathered in the builds stage from the upstream candidate list
    /// (`VisualSelectionService`), not at the render choke point.
    private func buildManifest(_ document: PDFAnalysisDocument, index: FigureIndex) -> (manifest: [String], distances: [String]) {
        struct Target { let type: String; let global: Int; let cached: Bool? }
        struct Ref { let key: String; let global: Int; let sIdx: Int; let bIdx: Int }
        var targets: [String: Target] = [:]
        var refs: [Ref] = []

        var global = 0
        for (sIdx, section) in document.sections.enumerated() {
            for (bIdx, block) in section.blocks.enumerated() {
                if Self.figureTypes.contains(block.type) || block.type == .table {
                    let kind = (block.type == .table) ? "Table" : "Figure"
                    if let numStr = block.metadata?["figureNumber"], Int(numStr) != nil {
                        let cached: Bool? = block.type == .visual
                            ? (block.visualURL.map { VisualAssetCache.shared.isCached(remoteURL: $0) } ?? false)
                            : nil
                        targets["\(kind) \(numStr)"] = Target(type: "\(block.type)", global: global, cached: cached)
                    }
                }
                if Self.proseTypes.contains(block.type) {
                    for kind in ["Figure", "Table"] {
                        for number in explicitReferences(kind: kind, in: block.content) {
                            refs.append(Ref(key: "\(kind) \(number)", global: global, sIdx: sIdx, bIdx: bIdx))
                        }
                    }
                }
                global += 1
            }
        }

        let referenced = Set(refs.map { $0.key })
        func numericParts(_ key: String) -> (String, Int) {
            let comps = key.split(separator: " ")
            return (String(comps.first ?? ""), Int(comps.last ?? "") ?? 0)
        }
        let manifest: [String] = targets.keys.sorted { a, b in
            let (ak, an) = numericParts(a), (bk, bn) = numericParts(b)
            return ak == bk ? an < bn : ak < bk
        }.map { key in
            let t = targets[key]!
            let cachedStr = t.cached.map { $0 ? "cached:yes" : "cached:NO" } ?? "cached:n/a"
            return "\(key) [\(t.type)] \(cachedStr) \(referenced.contains(key) ? "referenced:yes" : "referenced:NO")"
        }

        // Distances (only for references that resolve to a real target).
        let sortable: [(dist: Int, line: String)] = refs.compactMap { r in
            guard let t = targets[r.key] else { return nil }
            let d = abs(r.global - t.global)
            return (d, "\(r.key) @ §\(r.sIdx).\(r.bIdx) → target \(d) block(s) away")
        }.sorted { $0.dist > $1.dist }
        var distances = sortable.prefix(15).map { $0.line }
        if sortable.count > 15 { distances.append("… \(sortable.count - 15) more") }

        return (manifest, distances)
    }

    // MARK: - Text helpers

    private func replace(_ phrase: String, with replacement: String, in text: String) -> String {
        guard let pattern = try? NSRegularExpression(pattern: "\\b\(NSRegularExpression.escapedPattern(for: phrase))\\b", options: [.caseInsensitive]) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return pattern.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }

    private func explicitReferences(kind: String, in text: String) -> [Int] {
        guard let regex = try? NSRegularExpression(pattern: "\\b\(kind)\\s+(\\d+)\\b") else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let r = Range(match.range(at: 1), in: text) else { return nil }
            return Int(text[r])
        }
    }

    /// Split into sentence units, keeping terminators (. ! ? :).
    private func splitSentences(_ text: String) -> [String] {
        var units: [String] = []
        var current = ""
        let chars = Array(text)
        for (i, ch) in chars.enumerated() {
            current.append(ch)
            if ".!?:".contains(ch) {
                let atEnd = i + 1 >= chars.count
                let nextIsBreak = !atEnd && (chars[i + 1] == " " || chars[i + 1] == "\n")
                if atEnd || nextIsBreak {
                    units.append(current)
                    current = ""
                }
            }
        }
        if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { units.append(current) }
        return units
    }
}

// MARK: - PDFContentBlock convenience copies

extension PDFContentBlock {
    /// Return a copy with replaced metadata (the model's stored fields are `let`).
    func replacingMetadata(_ newMetadata: [String: String]) -> PDFContentBlock {
        PDFContentBlock(type: type, content: content, listItems: listItems,
                        metadata: newMetadata, tableData: tableData,
                        visualURL: visualURL, visualType: visualType)
    }

    /// Return a copy with replaced content.
    func replacingContent(_ newContent: String) -> PDFContentBlock {
        PDFContentBlock(type: type, content: newContent, listItems: listItems,
                        metadata: metadata, tableData: tableData,
                        visualURL: visualURL, visualType: visualType)
    }
}
