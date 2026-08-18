//
//  ManuscriptIntegrity.swift
//  InsightAtlas
//
//  Track A — the manufacturing-integrity layer that keeps broken guides from
//  shipping. Two cooperating stages, per the release-gate spec:
//
//    A1 · ManuscriptNormalizer  — repairs SAFE defects on the assembled
//         manuscript BEFORE layout: Unicode NFC, corrupted-hyphen glyphs
//         (`self￾constructed` → `self-constructed`), missing sentence spaces
//         (`them.The` → `them. The`), and a canonical-names table
//         (`Irving Yalom` → `Irvin Yalom`).
//
//    A2 · ManuscriptPreflight   — DETECTS unsafe defects and returns a hard
//         pass/fail. It never guesses a repair; a failing manuscript must not
//         be exported. Covers the content-level (pre-render) checks: truncation,
//         prohibited glyphs, missing spaces, non-canonical names, and brand /
//         tagline strings leaking into body prose.
//
//  Post-render checks that require the rendered page map — TOC page-number
//  agreement and "1-Page" label-vs-actual-page-count — are intentionally NOT
//  here; they need renderer instrumentation and live in the post-layout gate.
//

import Foundation

// MARK: - Canonical name corrections

/// One exact wrong→right substitution. Exact strings (not fuzzy surname
/// matching) so we never rewrite a legitimately different person — e.g.
/// "Marilyn Yalom" must survive while "Irving Yalom" is corrected.
struct NameCorrection: Sendable, Equatable {
    let wrong: String
    let right: String
}

enum CanonicalNames {
    /// Default corrections applied to every guide. Extend per-guide by passing a
    /// custom list; this is the general "canonical-names table", seeded with the
    /// misspellings we have actually observed in output.
    static let `default`: [NameCorrection] = [
        NameCorrection(wrong: "Irving D. Yalom", right: "Irvin D. Yalom"),
        NameCorrection(wrong: "Irving Yalom", right: "Irvin Yalom"),
    ]
}

// MARK: - A1 · Normalizer (safe repairs)

enum ManuscriptNormalizer {

    /// Scalars that represent a corrupted hard hyphen when they sit between two
    /// word characters (`self￾constructed`, `here-and￾now`). Replaced with `-`
    /// in that position; removed everywhere else.
    private static let corruptedHyphenScalars: Set<Unicode.Scalar> = [
        "\u{00AD}", // soft hyphen
        "\u{FFFD}", // replacement character
        "\u{FFFE}", // noncharacter
        "\u{FFFF}", // noncharacter
    ]

    /// Zero-width / byte-order scalars that are always removed.
    private static let alwaysStripScalars: Set<Unicode.Scalar> = [
        "\u{FEFF}", // BOM / zero-width no-break space
        "\u{200B}", // zero-width space
    ]

    /// Repair the assembled manuscript in place. Idempotent: running it twice
    /// yields the same result, so it is safe to call anywhere in the pipeline.
    static func normalize(
        _ content: String,
        corrections: [NameCorrection] = CanonicalNames.default
    ) -> String {
        // 1. Canonical composition so accents/compatibility forms are stable.
        var result = content.precomposedStringWithCanonicalMapping

        // 2. Corrupted-hyphen and zero-width glyphs, context-sensitive.
        result = repairCorruptedScalars(result)

        // 3. Missing space after a sentence period: "them.The" → "them. The".
        //    Lowercase-before / uppercase-after only, so initials ("D.Y") and
        //    acronyms ("U.S.") are left untouched.
        result = result.replacingOccurrences(
            of: "([a-z])\\.([A-Z])",
            with: "$1. $2",
            options: .regularExpression
        )

        // 4. Canonical-names table (exact substitutions, longest first).
        for correction in corrections.sorted(by: { $0.wrong.count > $1.wrong.count }) {
            result = result.replacingOccurrences(of: correction.wrong, with: correction.right)
        }

        return result
    }

    /// Walk scalars once: a corrupted-hyphen scalar becomes `-` when flanked by
    /// word characters, otherwise it (and always-strip scalars) is dropped.
    private static func repairCorruptedScalars(_ text: String) -> String {
        // Fast path — nothing to do.
        let needsWork = text.unicodeScalars.contains {
            corruptedHyphenScalars.contains($0) || alwaysStripScalars.contains($0)
        }
        guard needsWork else { return text }

        let scalars = Array(text.unicodeScalars)
        var out = String.UnicodeScalarView()
        out.reserveCapacity(scalars.count)

        for (index, scalar) in scalars.enumerated() {
            if alwaysStripScalars.contains(scalar) {
                continue
            }
            if corruptedHyphenScalars.contains(scalar) {
                let prev = index > 0 ? scalars[index - 1] : nil
                let next = index + 1 < scalars.count ? scalars[index + 1] : nil
                if let prev, let next, isWordScalar(prev), isWordScalar(next) {
                    out.append("-")
                }
                // Otherwise a dangling discretionary hyphen — drop it.
                continue
            }
            out.append(scalar)
        }
        return String(out)
    }

    private static func isWordScalar(_ scalar: Unicode.Scalar) -> Bool {
        CharacterSet.alphanumerics.contains(scalar)
    }
}

// MARK: - A2 · Preflight (hard pass/fail detection)

/// Content-level release gate. Repairs nothing; reports what must block export.
enum ManuscriptPreflight {

    enum Severity: String, Sendable {
        case error   // blocks export
        case warning // surfaced, does not block
    }

    enum Category: String, Sendable {
        case truncation
        case prohibitedGlyph
        case missingSpace
        case nonCanonicalName
        case brandInBody
        case missingClosingElement
    }

    struct Violation: Sendable, CustomStringConvertible {
        let severity: Severity
        let category: Category
        let message: String
        /// A short excerpt showing the offending text, when applicable.
        let sample: String?

        var description: String {
            let base = "[\(severity.rawValue.uppercased())] \(category.rawValue): \(message)"
            guard let sample, !sample.isEmpty else { return base }
            return "\(base) — “\(sample)”"
        }
    }

    struct Report: Sendable {
        let violations: [Violation]
        /// True when nothing would block export (errors == 0).
        var passed: Bool { !violations.contains { $0.severity == .error } }
        var errors: [Violation] { violations.filter { $0.severity == .error } }
        var warnings: [Violation] { violations.filter { $0.severity == .warning } }
    }

    /// Brand / tagline strings that must only ever appear in the renderer's
    /// cover / header / footer frames — never inside generated body prose.
    /// Kept in sync with PDFStyleConfiguration / InsightAtlasPDFRenderer.
    static let brandStrings: [String] = [
        "Where Understanding Illuminates the World",
        "WHERE UNDERSTANDING ILLUMINATES THE WORLD",
        "Where the weight of understanding becomes the clarity to act",
        "Insight Atlas",
        "INSIGHT ATLAS",
    ]

    /// Markers that count as a real closing element for the final section.
    private static let closingMarkers: [String] = [
        "[TAKEAWAYS]", "[ACTION_BOX]", "[STRUCTURE_MAP]",
        "Key Takeaways", "In Summary", "The Residue", "What to Carry",
    ]

    static func inspect(
        content: String,
        corrections: [NameCorrection] = CanonicalNames.default
    ) -> Report {
        var violations: [Violation] = []

        // 1. Truncation — reuse the existing detector (dangling initials,
        //    lead-in colons, missing terminal punctuation).
        if let reason = OutputQualityValidator.detectTruncation(in: content) {
            violations.append(Violation(
                severity: .error, category: .truncation,
                message: reason, sample: lastLine(of: content)
            ))
        }

        // 2. Prohibited glyphs that should never survive normalization.
        let prohibited: Set<Unicode.Scalar> = [
            "\u{00AD}", "\u{FFFD}", "\u{FFFE}", "\u{FFFF}", "\u{FEFF}", "\u{200B}",
        ]
        if let scalar = content.unicodeScalars.first(where: { prohibited.contains($0) }) {
            violations.append(Violation(
                severity: .error, category: .prohibitedGlyph,
                message: "Contains prohibited code point U+\(String(scalar.value, radix: 16, uppercase: true))",
                sample: nil
            ))
        }

        // 3. Missing sentence spaces ("them.The").
        if let match = firstMatch(of: "[a-z]\\.[A-Z]", in: content) {
            violations.append(Violation(
                severity: .error, category: .missingSpace,
                message: "Missing space after sentence period", sample: match
            ))
        }

        // 4. Non-canonical names that normalization should have fixed.
        for correction in corrections where content.contains(correction.wrong) {
            violations.append(Violation(
                severity: .error, category: .nonCanonicalName,
                message: "Non-canonical name; expected “\(correction.right)”",
                sample: correction.wrong
            ))
        }

        // 5. Brand / tagline strings leaking into body prose.
        for brand in brandStrings where content.contains(brand) {
            violations.append(Violation(
                severity: .error, category: .brandInBody,
                message: "Brand/tagline string appears in body content",
                sample: brand
            ))
        }

        // 6. Closing element in the final quartile (warning — the hard
        //    mid-sentence case is already caught by truncation above).
        if !hasClosingElement(content) {
            violations.append(Violation(
                severity: .warning, category: .missingClosingElement,
                message: "Final section has no recognizable closing element (synthesis/takeaway/coda)",
                sample: nil
            ))
        }

        return Report(violations: violations)
    }

    // MARK: Helpers

    /// Whether the manuscript already ends with a recognizable closing element
    /// (synthesis / takeaways / coda). Used to decide whether to run a
    /// conclusion pass before finalizing.

    // MARK: - Truncation repair

    /// Repair a generation that stopped mid-thought.
    ///
    /// Truncation was detected but never repaired: the conclusion pass appended
    /// a closing section onto a body still ending mid-word, so guides shipped
    /// reading "...rather than treat each advers". Three things are cleaned up,
    /// in order:
    ///
    /// 1. A partial editorial tag at the very end (`[INSIGHT_NO`). No parser
    ///    branch matches it and orphan-tag stripping needs a closing bracket, so
    ///    it renders to the reader verbatim.
    /// 2. A trailing incomplete sentence, dropped back to the last terminal
    ///    punctuation.
    /// 3. Any editorial block the cut left open, closed so the structure stays
    ///    balanced for the parser.
    ///
    /// Conservative by design: if the trim would discard more than a quarter of
    /// the content the tail is probably not a fragment, and the content is
    /// returned untouched rather than risk deleting real material.
    static func repairTruncatedTail(_ content: String) -> String {
        var result = content

        // 1. A dangling partial tag: an unmatched "[" after the last "]".
        if let openIndex = result.lastIndex(of: "[") {
            let afterOpen = result[openIndex...]
            if !afterOpen.contains("]") {
                result = String(result[..<openIndex])
            }
        }

        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return content }

        // Already ends deliberately — a closing tag, or terminal punctuation.
        if trimmed.hasSuffix("]") { return trimmed }
        if let last = trimmed.last, ".!?\"'\u{201D}\u{2019}".contains(last) { return trimmed }

        // 2. Cut back to the last sentence terminator.
        let terminators: Set<Character> = [".", "!", "?"]
        guard let cut = trimmed.lastIndex(where: { terminators.contains($0) }) else {
            return trimmed
        }

        var candidate = String(trimmed[...cut])
        // Keep a closing quote or bracket that follows the terminator.
        var after = trimmed.index(after: cut)
        while after < trimmed.endIndex, "\")]\u{201D}\u{2019}".contains(trimmed[after]) {
            candidate.append(trimmed[after])
            after = trimmed.index(after: after)
        }

        // Refuse to discard a large amount of material. A cap on what is thrown
        // away, not a ratio of what is kept: a short passage whose final
        // sentence runs long is still a fragment worth trimming, whereas a very
        // long unpunctuated tail is more likely real prose than a fragment.
        guard trimmed.count - candidate.count <= Self.maximumDiscardedTailCharacters else {
            return trimmed
        }

        // 3. Close any editorial block the cut left open.
        return candidate + closingTagsNeeded(for: candidate)
    }

    /// Closing tags for any editorial block opened but not closed in `content`.
    static func closingTagsNeeded(for content: String) -> String {
        var stack: [String] = []
        let pattern = #"\[(/?)([A-Z][A-Z0-9_]*)(?::[^\]]*)?\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return "" }

        let range = NSRange(content.startIndex..., in: content)
        for match in regex.matches(in: content, range: range) {
            guard let slashRange = Range(match.range(at: 1), in: content),
                  let nameRange = Range(match.range(at: 2), in: content) else { continue }
            let name = String(content[nameRange])
            if content[slashRange] == "/" {
                if stack.last == name { stack.removeLast() }
            } else if Self.closableEditorialTags.contains(name) {
                stack.append(name)
            }
        }

        guard !stack.isEmpty else { return "" }
        return "\n" + stack.reversed().map { "[/\($0)]" }.joined(separator: "\n")
    }

    /// Longest tail `repairTruncatedTail` will drop. Roughly a long paragraph:
    /// beyond this the tail is more plausibly unpunctuated prose than a
    /// generation fragment, and deleting it would be worse than the defect.
    static let maximumDiscardedTailCharacters = 600

    /// Editorial tags that wrap a block and require a closing partner.
    static let closableEditorialTags: Set<String> = [
        "INSIGHT_NOTE", "FOUNDATIONAL_NARRATIVE", "PREMIUM_H1", "PREMIUM_H2",
        "QUICK_GLANCE", "TAKEAWAYS", "PREMIUM_QUOTE", "AUTHOR_SPOTLIGHT",
        "ALTERNATIVE_PERSPECTIVE", "RESEARCH_INSIGHT", "ACTION_BOX",
        "STRUCTURE_MAP"
    ]

    static func hasClosingElement(_ content: String) -> Bool {
        let scalars = content
        let tailStart = scalars.index(
            scalars.endIndex,
            offsetBy: -min(scalars.count, max(400, scalars.count / 4))
        )
        let tail = String(scalars[tailStart...])
        return closingMarkers.contains { tail.localizedCaseInsensitiveContains($0) }
    }

    private static func lastLine(of content: String) -> String? {
        content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last { !$0.isEmpty }
            .map { String($0.suffix(80)) }
    }

    private static func firstMatch(of pattern: String, in content: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(content.startIndex..., in: content)
        guard let match = regex.firstMatch(in: content, range: range),
              let r = Range(match.range, in: content) else { return nil }
        return String(content[r])
    }
}

// MARK: - Shared export gate

/// Single chokepoint every export format must pass through. Repairs the safe
/// defects, then hard-fails if any unshippable defect remains. Both the PDF
/// path (GuideView) and the html/txt/md path (DataManager) call this so no
/// format can ship a defective artifact.
enum ManuscriptGate {

    struct GateError: LocalizedError {
        let violations: [ManuscriptPreflight.Violation]
        var errorDescription: String? {
            let details = violations.map { "• \($0.message)" }.joined(separator: "\n")
            return "Export blocked — this guide has integrity defects:\n\(details)"
        }
    }

    /// Normalize `rawContent`, log warnings, and throw `GateError` if any
    /// blocking violation remains. Returns the cleaned content to render/write.
    static func prepareForExport(_ rawContent: String) throws -> String {
        let content = ManuscriptNormalizer.normalize(rawContent)
        let report = ManuscriptPreflight.inspect(content: content)
        for warning in report.warnings { print("[Preflight] \(warning)") }
        guard report.passed else {
            for violation in report.errors { print("[Preflight] \(violation)") }
            throw GateError(violations: report.errors)
        }
        return content
    }
}
