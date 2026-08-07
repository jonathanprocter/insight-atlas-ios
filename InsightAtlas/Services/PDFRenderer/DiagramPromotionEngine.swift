import Foundation

// MARK: - Diagram Promotion Engine (Phase 2 — Directives §A4)
//
// Detects conceptual models that the source set as plain paragraphs with arrow
// characters and promotes them to drawn diagram components:
//
//   • Linear arrow chain  (X → Y → Z)            → horizontal process stepper
//   • Chain returning to its origin / feedback   → computed loop diagram
//   • Two-pole construct   (A ↔ B)               → spectrum with healthy zone
//
// The engine is a pure transform over the assembled PDFAnalysisDocument. Prose
// surrounding a promoted chain is preserved as its own paragraph block(s), so
// only the arrow region is lifted out.

struct DiagramPromotionEngine {

    private enum ChainKind { case linear, loop, spectrum }

    private struct Detection {
        let kind: ChainKind
        let nodes: [String]
        let range: Range<String.Index>   // range within the (arrow-normalized) content
    }

    /// Loop cues that turn an arrow chain into a feedback loop even when the
    /// last node is not literally the first.
    private static let loopKeywords = [
        "loop", "feedback", "self-reinforc", "self-confirm", "confirms itself",
        "cycle", "vicious", "reinforces", "circular"
    ]

    func promote(_ document: PDFAnalysisDocument) -> PDFAnalysisDocument {
        var doc = document
        doc.sections = document.sections.map { section in
            var s = section
            s.blocks = section.blocks.flatMap { promoteBlock($0) }
            return s
        }
        return doc
    }

    // MARK: - Per-block

    private func promoteBlock(_ block: PDFContentBlock) -> [PDFContentBlock] {
        guard block.type == .paragraph else { return [block] }

        let content = normalizeArrows(block.content)
        guard let detection = detect(in: content) else { return [block] }

        var result: [PDFContentBlock] = []

        let prefix = String(content[content.startIndex..<detection.range.lowerBound])
            .trimmingCharacters(in: CharacterSet(charactersIn: " \n\t—-–:;,"))
        if !prefix.isEmpty {
            result.append(PDFContentBlock(type: .paragraph, content: prefix))
        }

        result.append(diagramBlock(for: detection))

        let suffix = String(content[detection.range.upperBound..<content.endIndex])
            .trimmingCharacters(in: CharacterSet(charactersIn: " \n\t—-–:;,."))
        if !suffix.isEmpty {
            result.append(PDFContentBlock(type: .paragraph, content: suffix))
        }

        return result
    }

    private func diagramBlock(for detection: Detection) -> PDFContentBlock {
        switch detection.kind {
        case .linear:
            return PDFContentBlock(type: .processTimeline, content: "",
                                   listItems: detection.nodes,
                                   metadata: ["title": "Process", "promoted": "linear"])
        case .loop:
            return PDFContentBlock(type: .loopDiagram, content: "",
                                   listItems: detection.nodes,
                                   metadata: ["title": "Feedback Loop",
                                              "promoted": "loop",
                                              "caption": "A self-reinforcing loop: each step makes the next more likely."])
        case .spectrum:
            return PDFContentBlock(type: .spectrum, content: "",
                                   listItems: detection.nodes,
                                   metadata: ["title": "Spectrum", "promoted": "spectrum",
                                              "zone": "healthy range"])
        }
    }

    // MARK: - Detection

    /// Detects the first diagram-worthy arrow region in `content`. Spectrum
    /// (bidirectional) takes precedence over a linear/loop chain.
    private func detect(in rawContent: String) -> Detection? {
        let content = normalizeArrows(rawContent)

        if let spectrum = matchRegion(pattern: #"[^\n.;:↔⟷]+(?:\s*[↔⟷]\s*[^\n.;:↔⟷]+)"#, in: content) {
            let poles = spectrum.text
                .components(separatedBy: CharacterSet(charactersIn: "↔⟷"))
                .map { cleanNode($0) }
                .filter { !$0.isEmpty }
            if poles.count == 2, poles.allSatisfy({ $0.count <= 60 }) {
                return Detection(kind: .spectrum, nodes: poles, range: spectrum.range)
            }
        }

        if let chain = matchRegion(pattern: #"[^\n.;:→]+(?:\s*→\s*[^\n.;:→]+){2,}"#, in: content) {
            var nodes = chain.text
                .components(separatedBy: "→")
                .map { cleanNode($0) }
                .filter { !$0.isEmpty }
            guard nodes.count >= 3, nodes.count <= 8,
                  nodes.allSatisfy({ $0.count <= 48 }) else { return nil }

            let returnsToOrigin = normalizedKey(nodes.first!) == normalizedKey(nodes.last!)
            let lowered = content.lowercased()
            let hasLoopCue = Self.loopKeywords.contains { lowered.contains($0) }

            if returnsToOrigin {
                nodes.removeLast()      // collapse the duplicated origin node
                return Detection(kind: .loop, nodes: nodes, range: chain.range)
            }
            if hasLoopCue {
                return Detection(kind: .loop, nodes: nodes, range: chain.range)
            }
            return Detection(kind: .linear, nodes: nodes, range: chain.range)
        }

        return nil
    }

    // MARK: - Helpers

    /// Normalize ASCII arrow spellings to the unicode glyphs the detector uses.
    /// Bidirectional forms are converted before unidirectional so "<->" does not
    /// partially match the "->" rule.
    func normalizeArrows(_ text: String) -> String {
        var t = text
        for bidir in ["<->", "<-->", "<=>"] { t = t.replacingOccurrences(of: bidir, with: "↔") }
        for uni in ["-->", "->", "⟶", "⇒", "=>"] { t = t.replacingOccurrences(of: uni, with: "→") }
        return t
    }

    private struct RegionMatch { let text: String; let range: Range<String.Index> }

    private func matchRegion(pattern: String, in content: String) -> RegionMatch? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(content.startIndex..<content.endIndex, in: content)
        guard let match = regex.firstMatch(in: content, range: nsRange),
              let range = Range(match.range, in: content) else { return nil }
        return RegionMatch(text: String(content[range]), range: range)
    }

    /// Trim surrounding whitespace, markdown emphasis, and stray punctuation from
    /// a node label while preserving intentional inner quotes.
    private func cleanNode(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "**", with: "")
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: " \t*_—-–,"))
        return s
    }

    private func normalizedKey(_ s: String) -> String {
        s.lowercased().trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    }
}
