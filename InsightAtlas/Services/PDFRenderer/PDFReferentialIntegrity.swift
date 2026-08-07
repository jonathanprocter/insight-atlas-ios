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
        var isValid: Bool { violations.isEmpty }
        var summary: String {
            if violations.isEmpty {
                return "Referential integrity OK — \(figureCount) figure(s), \(tableCount) table(s), 0 violations."
            }
            let lines = violations.map {
                "  • [\($0.category.rawValue)] §\($0.sectionIndex).\($0.blockIndex): \($0.message)\($0.repaired ? " (repaired)" : "")"
            }
            return "Referential integrity: \(violations.count) violation(s)\n" + lines.joined(separator: "\n")
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

    // MARK: - Deictic → explicit rewrite

    private func rewriteResolvableReferences(_ document: PDFAnalysisDocument, index: FigureIndex) -> PDFAnalysisDocument {
        var doc = document
        for (sIdx, section) in doc.sections.enumerated() {
            let hasFigure = index.sectionHasFigure[sIdx] ?? false
            let hasTable = index.sectionHasTable[sIdx] ?? false
            let figNum = index.sectionFirstFigure[sIdx]
            let tblNum = index.sectionFirstTable[sIdx]

            var blocks = section.blocks
            for (bIdx, block) in blocks.enumerated() where Self.proseTypes.contains(block.type) {
                var text = block.content
                if hasFigure, let figNum = figNum {
                    for phrase in Self.figureDeictic {
                        text = replace(phrase, with: "Figure \(figNum)", in: text)
                    }
                }
                if hasTable, let tblNum = tblNum {
                    for phrase in Self.tableDeictic {
                        text = replace(phrase, with: "Table \(tblNum)", in: text)
                    }
                }
                for phrase in Self.ambiguousDeictic {
                    if hasTable, let tblNum = tblNum {
                        text = replace(phrase, with: "Table \(tblNum)", in: text)
                    } else if hasFigure, let figNum = figNum {
                        text = replace(phrase, with: "Figure \(figNum)", in: text)
                    }
                }
                if text != block.content { blocks[bIdx] = block.replacingContent(text) }
            }
            doc.sections[sIdx].blocks = blocks
        }
        return doc
    }

    // MARK: - Violation detection

    private func findViolations(_ document: PDFAnalysisDocument, index: FigureIndex) -> [Violation] {
        var violations: [Violation] = []

        for (sIdx, section) in document.sections.enumerated() {
            let hasFigure = index.sectionHasFigure[sIdx] ?? false
            let hasTable = index.sectionHasTable[sIdx] ?? false

            for (bIdx, block) in section.blocks.enumerated() {

                // 1. Ghost references — deictic phrases that survived the rewrite.
                if Self.proseTypes.contains(block.type) {
                    let lowered = block.content.lowercased()
                    for phrase in Self.figureDeictic where lowered.contains(phrase) && !hasFigure {
                        violations.append(Violation(
                            category: .ghostReference, sectionIndex: sIdx, blockIndex: bIdx,
                            message: "references \"\(phrase)\" but no figure renders in this section"))
                    }
                    for phrase in Self.tableDeictic where lowered.contains(phrase) && !hasTable {
                        violations.append(Violation(
                            category: .ghostReference, sectionIndex: sIdx, blockIndex: bIdx,
                            message: "references \"\(phrase)\" but no table renders in this section"))
                    }
                    for phrase in Self.ambiguousDeictic where lowered.contains(phrase) && !(hasFigure || hasTable) {
                        violations.append(Violation(
                            category: .ghostReference, sectionIndex: sIdx, blockIndex: bIdx,
                            message: "references \"\(phrase)\" but no figure or table renders in this section"))
                    }

                    // 2. Dangling explicit figure/table numbers.
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
        let hasDangling = violations.contains { $0.category == .danglingFigureNumber }
        let hasOrphan = violations.contains { $0.category == .orphanLeadIn }

        let units = splitSentences(content)
        let kept = units.filter { unit in
            let lowered = unit.lowercased()
            if hasOrphan && unit.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix(":") { return false }
            if hasGhost && ghostPhrases.contains(where: { lowered.contains($0) }) { return false }
            if hasDangling && (lowered.range(of: #"\b(figure|table)\s+\d+"#, options: .regularExpression) != nil) { return false }
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
        let rewritten = rewriteResolvableReferences(numbered, index: index)
        var violations = findViolations(rewritten, index: index)

        var report = Report(
            violations: violations,
            figureCount: index.assignedFigures.count,
            tableCount: index.assignedTables.count
        )

        guard !violations.isEmpty, repairViolations else {
            return (rewritten, report)
        }

        // Only sentence-suppressible categories are auto-repaired; reconciliation
        // violations signal a construction bug and are reported, not rewritten.
        let repairable: Set<Violation.Category> = [.ghostReference, .danglingFigureNumber, .orphanLeadIn]
        let repaired = repair(rewritten, violations: violations.filter { repairable.contains($0.category) })
        for i in violations.indices where repairable.contains(violations[i].category) {
            violations[i].repaired = true
        }
        report.violations = violations
        return (repaired, report)
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
