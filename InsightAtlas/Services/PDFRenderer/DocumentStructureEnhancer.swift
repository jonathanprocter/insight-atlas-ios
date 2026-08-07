import Foundation

// MARK: - Document Structure Enhancer (Phase 6 — Directives §C1, §B5)
//
// Additive, pagination-safe pass over the assembled document. It never mutates
// or reorders existing blocks; it only INSERTS:
//   • a section-opener reading-time + "Theme N of M" chip at the top of each
//     synthesis theme (§C1), and
//   • one pull quote per theme, lifting an editorial sentence from the body as a
//     pacing anchor (§B5).
//
// All wayfinding keys off the synthesis's own thematic architecture (theme
// ordinal / count), never source-book chapters.

struct DocumentStructureEnhancer {

    func enhance(_ document: PDFAnalysisDocument) -> PDFAnalysisDocument {
        var doc = document
        let themeCount = doc.sections.filter { isTheme($0) }.count
        guard themeCount > 0 else { return doc }

        var themeOrdinal = 0
        for sIdx in doc.sections.indices where isTheme(doc.sections[sIdx]) {
            themeOrdinal += 1
            var blocks = doc.sections[sIdx].blocks

            // Reading-time + progress chip (computed from this theme's own words).
            let words = blocks.reduce(0) { $0 + wordCount($1.content) }
            let minutes = max(1, Int((Double(words) / 200.0).rounded()))
            let chip = PDFContentBlock(
                type: .readingChip, content: "",
                metadata: ["readingTime": String(minutes),
                           "progress": "Theme \(themeOrdinal) of \(themeCount)"])
            blocks.insert(chip, at: 0)

            // One pull quote, lifted from the first paragraph that yields a
            // suitable editorial sentence.
            if let (index, quote) = pullQuote(from: blocks) {
                blocks.insert(
                    PDFContentBlock(type: .premiumQuote, content: quote, metadata: ["pullQuote": "true"]),
                    at: index)
            }

            doc.sections[sIdx].blocks = blocks
        }
        return doc
    }

    // MARK: - Helpers

    private func isTheme(_ section: PDFAnalysisDocument.PDFSection) -> Bool {
        section.heading?.hasPrefix("Theme ") ?? false
    }

    private func wordCount(_ s: String) -> Int {
        s.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    /// Find the first paragraph with a quotable sentence; return the insertion
    /// index (just after that paragraph) and the quote text.
    private func pullQuote(from blocks: [PDFContentBlock]) -> (index: Int, quote: String)? {
        for (i, block) in blocks.enumerated() where block.type == .paragraph {
            if let sentence = quotableSentence(in: block.content) {
                return (i + 1, sentence)
            }
        }
        return nil
    }

    /// Pick a punchy, self-contained sentence: 8–26 words, no colon lead-in, no
    /// figure/table reference, not a question or list fragment.
    private func quotableSentence(in content: String) -> String? {
        let sentences = content
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: ". ")
        for raw in sentences {
            var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if s.hasSuffix(".") { s = String(s.dropLast()) }
            let words = wordCount(s)
            guard words >= 8, words <= 26 else { continue }
            let lowered = s.lowercased()
            if s.hasSuffix(":") || s.hasSuffix("?") { continue }
            if lowered.contains("figure ") || lowered.contains("table ") { continue }
            if s.contains("**") || s.hasPrefix("-") || s.hasPrefix("•") { continue }
            return s + "."
        }
        return nil
    }
}
