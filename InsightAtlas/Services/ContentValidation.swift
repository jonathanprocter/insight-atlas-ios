//
//  ContentValidation.swift
//  InsightAtlas
//
//  Centralized content validation constants, markers, and utilities.
//  Extracted from BackgroundGenerationCoordinator for maintainability.
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.insightatlas", category: "ContentValidation")

// MARK: - Content Markers

/// Centralized constants for all content markers used in validation and parsing
enum ContentMarkers {

    // MARK: - Premium Formatting Blocks

    /// Premium block markers for formatting validation
    static let premiumBlocks: Set<String> = [
        "[PREMIUM_H1]",
        "[PREMIUM_H2]",
        "[PREMIUM_DIVIDER]",
        "[PREMIUM_QUOTE]",
        "[AUTHOR_SPOTLIGHT]",
        "[ALTERNATIVE_PERSPECTIVE]",
        "[RESEARCH_INSIGHT]"
    ]

    /// Premium callout types for diversity validation
    static let premiumCallouts: Set<String> = [
        "[PREMIUM_QUOTE]",
        "[AUTHOR_SPOTLIGHT]",
        "[ALTERNATIVE_PERSPECTIVE]",
        "[RESEARCH_INSIGHT]",
        "[INSIGHT_NOTE]"
    ]

    // MARK: - Visual Markers

    /// Modern visual block markers — every spelling the renderer accepts
    /// (canonical `InsightVisualType` raw values plus parser aliases), so the
    /// variety check counts the whole catalog the prompt offers, not a subset.
    static let visualMarkers: Set<String> = Set(
        (InsightVisualType.allCases.map(\.rawValue)
            + InsightVisualParser.tagAliases.keys)
            .map { "[" + $0 }
    )

    /// Legacy visual markers (for backwards compatibility)
    static let legacyVisualMarkers: Set<String> = [
        "[CONCEPT_MAP",
        "[PROCESS_TIMELINE",
        "[HIERARCHY_DIAGRAM"
    ]

    /// Flowchart-specific markers
    static let flowchartMarkers: Set<String> = [
        "[VISUAL_FLOWCHART",
        "[VISUAL_FLOW_DIAGRAM"
    ]

    // MARK: - Insight Note Components

    /// Optional Insight Note section markers (scarce; not required on every note)
    static let insightNoteComponents: [String] = [
        "**key distinction:**",
        "**practical implication:**",
        "**go deeper:**"
    ]

    // MARK: - Required Sections

    /// Section markers that must be present in comprehensive guides
    static let requiredSections: Set<String> = [
        "[section: comparative analysis]",
        "[premium_h2]comparative analysis[/premium_h2]",
        "[premium_h2]synthesis interlude[/premium_h2]",
        "[premium_h2]applied implications[/premium_h2]"
    ]

    // MARK: - Banned Phrases

    /// Phrases that indicate poor narrative style
    static let bannedNarrativePhrases: Set<String> = [
        "in this guide",
        "in this summary",
        "this guide will",
        "this summary covers",
        "we will explore",
        "let's explore",
        "let's dive",
        "without further ado",
        "in conclusion",
        "to sum up",
        "in summary",
        "as mentioned earlier",
        "as we discussed",
        "buckle up",
        "get ready to",
        "spoiler alert"
    ]

    /// Phrases that reference visuals incorrectly
    static let visualReferencePhrases: Set<String> = [
        "see the diagram",
        "see the chart",
        "see the table",
        "as shown in",
        "diagram below",
        "chart below",
        "table below",
        "flowchart above",
        "the flowchart",
        "the diagram"
    ]

    /// Chapter-by-chapter framing indicators (not allowed)
    static let chapterFramingPhrases: Set<String> = [
        "chapter summary",
        "chapter-by-chapter",
        "chapter by chapter"
    ]

    // MARK: - Cross-Book Synthesis

    /// Cross-disciplinary synthesis signals
    static let synthesisSignals: Set<String> = [
        "kahneman",
        "dweck",
        "cialdini",
        "rosenberg",
        "stoic",
        "buddhist",
        "neuroscience",
        "neuroplasticity",
        "behavioral",
        "systems thinking",
        "economics"
    ]

    // MARK: - Prompt Leakage Detection

    /// Markers that indicate prompt/system instruction leakage
    static let promptLeakageMarkers: Set<String> = [
        "EXACT PROMPTS USED",
        "SYSTEM MESSAGE",
        "USER PROMPT",
        "MODEL CONFIGURATION",
        "HOW THE PROMPTS WORK",
        "KEY DIFFERENCES",
        "STAGE 1",
        "STAGE 2",
        "PROMPT (COMPLETE)"
    ]
}

// MARK: - String Extension for Content Validation

extension String {

    /// Count occurrences of a marker in the content
    func markerCount(_ marker: String) -> Int {
        components(separatedBy: marker).count - 1
    }

    /// Check if content contains any of the given phrases (case-insensitive)
    func containsAny(of phrases: Set<String>) -> Bool {
        let lowercased = self.lowercased()
        return phrases.contains { lowercased.contains($0.lowercased()) }
    }

    /// Check if content contains all of the given phrases (case-insensitive)
    func containsAll(of phrases: Set<String>) -> Bool {
        let lowercased = self.lowercased()
        return phrases.allSatisfy { lowercased.contains($0.lowercased()) }
    }

    /// Count how many unique phrases from the set are present
    func countUnique(from phrases: Set<String>) -> Int {
        let lowercased = self.lowercased()
        return phrases.filter { lowercased.contains($0.lowercased()) }.count
    }

    /// Check for back-to-back callout patterns
    func hasBackToBackCallouts(markers: Set<String>) -> Bool {
        let lines = components(separatedBy: .newlines)
        var lastCalloutIndex: Int?

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let isCallout = markers.contains { trimmed.hasPrefix($0) }

            if isCallout {
                if let last = lastCalloutIndex, index - last <= 2 {
                    return true
                }
                lastCalloutIndex = index
            }
        }
        return false
    }
}

// MARK: - Output Quality Validator

/// Validates generated content quality and returns improvement suggestions
struct OutputQualityValidator {

    /// Validation result containing issues and suggestions
    struct ValidationResult {
        let issues: [String]
        let warnings: [String]
        let score: Double // 0.0 to 1.0

        var isAcceptable: Bool {
            issues.isEmpty && score >= 0.7
        }

        var needsImprovement: Bool {
            !issues.isEmpty
        }
    }

    // MARK: - Truncation Detection

    /// Detects content that was cut off mid-generation. Returns a short reason
    /// string when the output appears truncated, or `nil` when it ends cleanly.
    ///
    /// Trailing structural tags (e.g. `[PREMIUM_DIVIDER]`, `[/AUTHOR_SPOTLIGHT]`)
    /// and blank lines are ignored so the real last line of prose is evaluated.
    static func detectTruncation(in content: String) -> String? {
        // Find the last meaningful line, skipping blanks and pure-tag lines.
        var lastProse: String?
        for raw in content.components(separatedBy: .newlines).reversed() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || isPureTagLine(line) { continue }
            lastProse = line
            break
        }

        guard let line = lastProse else { return nil }

        // A trailing list item is a complete thought, not a truncation.
        if isListItem(line) { return nil }

        // A lead-in that promises content but delivers none.
        if line.hasSuffix(":") {
            return "Ends on a lead-in colon with no following content"
        }

        // A dangling author initial (e.g. "… by Steven C.") — checked before the
        // sentence-punctuation rule since it also ends in a period.
        if endsWithDanglingInitial(line) {
            return "Ends on a dangling author initial"
        }

        // Proper sentence terminator (allowing trailing quotes/brackets) = clean.
        if endsWithSentencePunctuation(line) { return nil }

        // Otherwise the prose stops mid-sentence.
        return "Ends mid-sentence without terminal punctuation"
    }

    /// A line consisting solely of a bracketed tag, e.g. `[X]` or `[/X]`.
    private static func isPureTagLine(_ line: String) -> Bool {
        line.range(of: "^\\[/?[A-Za-z0-9_]+\\]$", options: .regularExpression) != nil
    }

    /// A bullet or numbered list item.
    private static func isListItem(_ line: String) -> Bool {
        line.range(of: "^([-*•]\\s+|\\d+[.)]\\s+)", options: .regularExpression) != nil
    }

    /// Whether the final whitespace-delimited token is a lone capital initial
    /// followed by a period (e.g. "C."), which signals a cut-off name.
    private static func endsWithDanglingInitial(_ line: String) -> Bool {
        guard let token = line.split(whereSeparator: { $0.isWhitespace }).last else { return false }
        return token.range(of: "^[A-Z]\\.$", options: .regularExpression) != nil
    }

    /// Whether the line ends with `.`, `!`, or `?`, tolerating trailing closing
    /// quotes or brackets (e.g. `anyway."`).
    private static func endsWithSentencePunctuation(_ line: String) -> Bool {
        var scalars = Substring(line)
        while let last = scalars.last, "\"'”’)]}".contains(last) {
            scalars = scalars.dropLast()
        }
        guard let last = scalars.last else { return false }
        return ".!?".contains(last)
    }

    /// Validate content quality for a given summary type
    static func validate(
        content: String,
        summaryType: SummaryType
    ) -> ValidationResult {
        var issues: [String] = []
        let warnings: [String] = []
        let lowercased = content.lowercased()
        let uppercased = content.uppercased()

        // Skip extensive validation for quick reference guides
        let isQuickReference = summaryType == .quickReference
        let isDeepResearch = summaryType == .deepResearch

        // MARK: - INSIGHT_NOTE Validation

        let insightNoteCount = content.markerCount("[INSIGHT_NOTE]")

        if !isQuickReference {
            if insightNoteCount < 3 {
                issues.append("Insufficient cross-discipline connections: found \(insightNoteCount) INSIGHT_NOTEs, need at least 3")
            }

            // Go Deeper is optional and scarce — at most one per note, not required
            // on every note. Require at least one genuine next-read across the guide
            // (non–quick-reference), but never force a shallow citation footer.
            let goDeeperCount = lowercased.markerCount("**go deeper:**")
            if insightNoteCount >= 3, goDeeperCount < 1 {
                issues.append("Guide needs at least one Go Deeper next-read across its Insight Notes")
            }
            if goDeeperCount > 6 {
                issues.append("Too many Go Deeper lines (\(goDeeperCount)); keep at most 6 and only when they name a new work")
            }

            // KD / PI remain useful but optional. Soften the half-quota so notes
            // can stay prose-led when labels would feel stamped.
            let structureFloor = max(1, insightNoteCount / 3)
            let keyDistCount = lowercased.markerCount("**key distinction:**")
            let practicalCount = lowercased.markerCount("**practical implication:**")

            if insightNoteCount >= 3, keyDistCount + practicalCount < structureFloor {
                issues.append("Too few Insight Notes carry a Key Distinction or Practical Implication when one would earn its place")
            }
        }

        // MARK: - Chapter Framing Validation

        if lowercased.containsAny(of: ContentMarkers.chapterFramingPhrases) {
            issues.append("Chapter-by-chapter framing is not allowed; use thematic synthesis")
        }

        // MARK: - Premium Formatting Validation

        if !isQuickReference {
            let premiumCount = ContentMarkers.premiumBlocks.reduce(0) { count, marker in
                count + content.markerCount(marker)
            }

            if premiumCount < 4 {
                issues.append("Insufficient premium formatting blocks: found \(premiumCount), need at least 4")
            }

            // Callout diversity
            let premiumTypesUsed = content.countUnique(from: ContentMarkers.premiumCallouts)
            if premiumTypesUsed < 3 {
                issues.append("Insufficient premium callout diversity")
            }

            // Premium quotes
            let premiumQuoteCount = content.markerCount("[PREMIUM_QUOTE]")
            if premiumQuoteCount < 2 {
                issues.append("Insufficient premium quotes")
            }

            // Premium dividers
            let premiumDividerCount = content.markerCount("[PREMIUM_DIVIDER]")
            if premiumDividerCount < 2 {
                issues.append("Insufficient premium dividers between parts")
            }

            // Premium headers
            if !lowercased.contains("[premium_h1]") && !lowercased.contains("[premium_h2]") {
                issues.append("Missing premium headers for parts/chapters")
            }
        }

        // MARK: - Visual Content Validation

        let modernVisualCount = content.markerCount("[VISUAL_")
        let legacyVisualCount = ContentMarkers.legacyVisualMarkers.reduce(0) { count, marker in
            count + content.markerCount(marker)
        }
        let totalVisuals = modernVisualCount + legacyVisualCount
        let uniqueVisualTypes = content.countUnique(from: ContentMarkers.visualMarkers)

        let flowchartCount = ContentMarkers.flowchartMarkers.reduce(0) { count, marker in
            count + content.markerCount(marker)
        }

        // Warn about excessive flowcharts
        if totalVisuals >= 3 && flowchartCount > 1 {
            issues.append("Overuse of flowcharts; limit to 1 unless indispensable")
        } else if totalVisuals >= 4 && flowchartCount > max(2, totalVisuals / 2) {
            issues.append("Overuse of flowcharts; increase visual variety")
        }

        // Visual reference phrases
        if lowercased.containsAny(of: ContentMarkers.visualReferencePhrases) {
            issues.append("Visuals described as visuals; integrate them into narrative")
        }

        // Encourage richer visual variety for full guides
        if !isQuickReference {
            if totalVisuals < 6 {
                issues.append("Insufficient visuals; add more varied diagrams to clarify key concepts")
            }
            if uniqueVisualTypes < 5 && totalVisuals >= 8 {
                issues.append("Insufficient visual variety; use more distinct visual types")
            }
        }

        // MARK: - Narrative Style Validation

        if lowercased.containsAny(of: ContentMarkers.bannedNarrativePhrases) {
            issues.append("Contains banned narrative phrases (meta-commentary or cliches)")
        }

        // MARK: - Prompt Leakage Detection

        if uppercased.containsAny(of: ContentMarkers.promptLeakageMarkers) {
            issues.append("Prompt or system instructions leaked into output")
        }

        // MARK: - Author Spotlight Validation

        let authorSpotlightCount = content.markerCount("[AUTHOR_SPOTLIGHT]")
        if !isQuickReference && authorSpotlightCount < 1 {
            issues.append("Missing Author Spotlight block")
        } else if authorSpotlightCount > 1 {
            issues.append("Too many author spotlights (max 1)")
        }

        // MARK: - Paragraph Count Validation

        let paragraphs = content
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { block in
                let upper = block.uppercased()
                return !upper.hasPrefix("[") &&
                    !upper.hasPrefix("##") &&
                    !upper.hasPrefix("#") &&
                    !upper.hasPrefix("- ") &&
                    !upper.hasPrefix("* ") &&
                    !upper.hasPrefix("• ")
            }
        if !isQuickReference && paragraphs.count < 6 {
            issues.append("Insufficient narrative paragraphs; expand prose between callouts")
        }

        // MARK: - Back-to-Back Callout Check

        let lines = content.components(separatedBy: "\n")
        var lastCallout: String?
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if let marker = ContentMarkers.premiumCallouts.first(where: { trimmed.hasPrefix($0) }) {
                if marker == lastCallout {
                    issues.append("Repeated callout type in adjacent sections")
                    break
                }
                lastCallout = marker
            } else {
                lastCallout = nil
            }
        }

        // MARK: - Perspective/Research Notes

        let perspectiveCount = content.markerCount("[ALTERNATIVE_PERSPECTIVE]")
        let researchCount = content.markerCount("[RESEARCH_INSIGHT]")
        if !isQuickReference && (perspectiveCount + researchCount) < 4 {
            issues.append("Insufficient perspective/research notes")
        }

        // MARK: - Shortform-class skeleton (elevation spec, 2026-10-12)
        //
        // Prefixed "Structure:" so the coordinator treats them as structural
        // defects worth an improvement pass (see isStructuralIssue).
        if !isQuickReference {
            issues.append(contentsOf: GuideSkeletonLint.issues(in: content))
        }

        // MARK: - Cross-Disciplinary Synthesis Signals

        let synthesisHits = lowercased.countUnique(from: ContentMarkers.synthesisSignals)
        if !isQuickReference && synthesisHits < 4 {
            issues.append("Insufficient cross-disciplinary synthesis signals")
        }

        // MARK: - Action Box Validation

        let actionBoxCount = content.markerCount("[ACTION_BOX")
        if !isQuickReference && actionBoxCount < 2 {
            issues.append("Insufficient action boxes: found \(actionBoxCount), need at least 2")
        }

        // MARK: - Exercise Validation (Deep Research only)

        let exerciseCount = content.markerCount("[EXERCISE_")
        if isDeepResearch && exerciseCount < 2 {
            issues.append("Insufficient exercises for Deep Research mode: found \(exerciseCount), need at least 2")
        }

        // MARK: - Required Block Validation

        if !lowercased.contains("[quick_glance]") {
            issues.append("Missing Quick Glance Summary section")
        }

        if !lowercased.contains("[foundational_narrative]") && !isQuickReference {
            issues.append("Missing Foundational Narrative section")
        }

        // MARK: - Calculate Score

        let maxIssues = 20.0
        let issueWeight = Double(issues.count) / maxIssues
        let warningWeight = Double(warnings.count) * 0.05
        let score = max(0.0, min(1.0, 1.0 - issueWeight - warningWeight))

        logger.debug("Quality validation complete: \(issues.count) issues, score: \(score)")

        return ValidationResult(
            issues: issues,
            warnings: warnings,
            score: score
        )
    }
}

// MARK: - Content Sanitizer

/// Sanitizes generated content by fixing common formatting issues
struct ContentSanitizer {

    /// Sanitization options
    struct Options {
        var fixOrphanedTags: Bool = true
        var normalizeWhitespace: Bool = true
        var removeEmptyBlocks: Bool = true
        var fixMarkdownHeaders: Bool = true

        static let `default` = Options()
    }

    /// Sanitize content with the given options
    static func sanitize(_ content: String, options: Options = .default) -> String {
        var result = content

        if options.normalizeWhitespace {
            result = normalizeWhitespace(result)
        }

        if options.fixOrphanedTags {
            result = fixOrphanedTags(result)
        }

        if options.removeEmptyBlocks {
            result = removeEmptyBlocks(result)
        }

        if options.fixMarkdownHeaders {
            result = fixMarkdownHeaders(result)
        }

        return result
    }

    // MARK: - Private Sanitization Methods

    private static func normalizeWhitespace(_ content: String) -> String {
        var result = content

        // Normalize line endings
        result = result.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.replacingOccurrences(of: "\r", with: "\n")

        // Remove excessive blank lines (more than 2)
        while result.contains("\n\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n\n", with: "\n\n\n")
        }

        // Trim trailing whitespace from lines
        let lines = result.components(separatedBy: "\n")
        result = lines.map { $0.trimmingCharacters(in: .whitespaces.subtracting(.newlines)) }
            .joined(separator: "\n")

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func fixOrphanedTags(_ content: String) -> String {
        var result = content

        // List of paired tags to check
        let pairedTags = [
            ("[INSIGHT_NOTE]", "[/INSIGHT_NOTE]"),
            ("[KEY_TAKEAWAYS]", "[/KEY_TAKEAWAYS]"),
            ("[ACTION_BOX]", "[/ACTION_BOX]"),
            ("[QUICK_GLANCE]", "[/QUICK_GLANCE]"),
            ("[QUOTE]", "[/QUOTE]"),
            ("[EXERCISE]", "[/EXERCISE]"),
            ("[PREMIUM_H1]", "[/PREMIUM_H1]"),
            ("[PREMIUM_H2]", "[/PREMIUM_H2]"),
            ("[FOUNDATIONAL_NARRATIVE]", "[/FOUNDATIONAL_NARRATIVE]"),
            ("[ALTERNATIVE_PERSPECTIVE]", "[/ALTERNATIVE_PERSPECTIVE]"),
            ("[RESEARCH_INSIGHT]", "[/RESEARCH_INSIGHT]"),
            ("[AUTHOR_SPOTLIGHT]", "[/AUTHOR_SPOTLIGHT]")
        ]

        for (openTag, closeTag) in pairedTags {
            let openCount = result.markerCount(openTag)
            let closeCount = result.markerCount(closeTag)

            // If we have more opens than closes, add closing tags
            if openCount > closeCount {
                let missing = openCount - closeCount
                logger.debug("Adding \(missing) missing \(closeTag) tags")
                for _ in 0..<missing {
                    // Find last occurrence of open tag and add close after its content
                    if let range = result.range(of: openTag, options: .backwards) {
                        let afterOpen = result.index(range.upperBound, offsetBy: 0)
                        // Find next blank line or end
                        if let nextBlank = result[afterOpen...].range(of: "\n\n") {
                            result.insert(contentsOf: "\n\(closeTag)", at: nextBlank.lowerBound)
                        } else {
                            result.append("\n\(closeTag)")
                        }
                    }
                }
            }
        }

        return result
    }

    private static func removeEmptyBlocks(_ content: String) -> String {
        var result = content

        // Remove empty insight notes
        let emptyBlockPatterns = [
            #"\[INSIGHT_NOTE\]\s*\[/INSIGHT_NOTE\]"#,
            #"\[KEY_TAKEAWAYS\]\s*\[/KEY_TAKEAWAYS\]"#,
            #"\[ACTION_BOX\]\s*\[/ACTION_BOX\]"#,
            #"\[QUOTE\]\s*\[/QUOTE\]"#
        ]

        for pattern in emptyBlockPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: ""
                )
            }
        }

        return result
    }

    private static func fixMarkdownHeaders(_ content: String) -> String {
        var lines = content.components(separatedBy: "\n")

        for i in 0..<lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Fix headers that don't have space after #
            if trimmed.hasPrefix("#") && !trimmed.hasPrefix("# ") && !trimmed.hasPrefix("##") {
                if let hashEnd = trimmed.firstIndex(where: { $0 != "#" }) {
                    let hashCount = trimmed.distance(from: trimmed.startIndex, to: hashEnd)
                    let rest = String(trimmed[hashEnd...])
                    lines[i] = String(repeating: "#", count: hashCount) + " " + rest.trimmingCharacters(in: .whitespaces)
                }
            }
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Tag Parser Utilities

/// Utilities for parsing content tags
enum TagParser {

    /// Extract tag name from an opening tag line
    static func parseOpenTagName(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("[") else { return nil }

        // Find the closing bracket or space
        if let endIndex = trimmed.firstIndex(where: { $0 == "]" || $0 == " " }) {
            let tagName = String(trimmed[trimmed.index(after: trimmed.startIndex)..<endIndex])
            // Exclude closing tags
            if tagName.hasPrefix("/") { return nil }
            return tagName.uppercased()
        }
        return nil
    }

    /// Extract tag name from a closing tag line
    static func parseCloseTagName(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("[/") else { return nil }

        if let endIndex = trimmed.firstIndex(of: "]") {
            let start = trimmed.index(trimmed.startIndex, offsetBy: 2)
            return String(trimmed[start..<endIndex]).uppercased()
        }
        return nil
    }

    /// Check if a line is purely a tag (no content)
    static func isBareTagLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("[") && trimmed.hasSuffix("]") && !trimmed.contains(" ")
    }

    /// Check if a line starts a new content block
    static func isNewBlockStart(_ line: String) -> Bool {
        let blockStarters: Set<String> = [
            "[INSIGHT_NOTE]",
            "[KEY_TAKEAWAYS]",
            "[ACTION_BOX]",
            "[QUICK_GLANCE]",
            "[EXERCISE]",
            "[QUOTE]",
            "[PREMIUM_QUOTE]",
            "[AUTHOR_SPOTLIGHT]",
            "[ALTERNATIVE_PERSPECTIVE]",
            "[RESEARCH_INSIGHT]",
            "[FOUNDATIONAL_NARRATIVE]"
        ]

        let trimmed = line.trimmingCharacters(in: .whitespaces).uppercased()
        return blockStarters.contains { trimmed.hasPrefix($0) }
    }

    /// Convert a markdown header to premium format
    static func convertMarkdownHeader(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("## ") {
            let content = String(trimmed.dropFirst(3))
            return "[PREMIUM_H2]\(content)[/PREMIUM_H2]"
        } else if trimmed.hasPrefix("# ") {
            let content = String(trimmed.dropFirst(2))
            return "[PREMIUM_H1]\(content)[/PREMIUM_H1]"
        }

        return nil
    }
}


// MARK: - Guide Skeleton Lint (elevation spec, Parts B, C and F)

/// Pre-emit checks for the Shortform-class layer contract: required headings,
/// numbered sections, back matter, Go Deeper format, and the Quick Glance vs
/// Key Takeaways overlap rule. Does not require identical per-section labelled
/// parts — section shape may rotate. Pure functions over the raw tagged guide
/// text so they can run before any parser and be unit-tested without a renderer.
enum GuideSkeletonLint {

    /// Required back/front-matter headings, matched case-insensitively against
    /// `[PREMIUM_H2]…[/PREMIUM_H2]` (any shape) or `## …` headings.
    static let requiredHeadings = [
        "Executive Summary", "Key Takeaways", "Glossary", "Chapter Map", "Further Reading"
    ]

    /// Fixed Go Deeper pattern: `Author, *Title* (Year) — reason`.
    static let goDeeperPattern = #"^\*{0,2}Go Deeper:\*{0,2}\s*[^,\n]{2,80},\s*\*[^*\n]{2,160}\*\s*\((?:c\.\s*)?\d{4}[a-z]?\)\s*[—–-]\s*\S"#

    static func issues(in content: String) -> [String] {
        var issues: [String] = []
        let headings = headingTexts(in: content)
        let folded = headings.map { fold($0) }

        for required in requiredHeadings where !folded.contains(where: { $0.hasPrefix(fold(required)) }) {
            issues.append("Structure: missing \(required) heading")
        }

        let numbered = headings.filter { $0.range(of: #"^\d{1,2}\.\s+\S"#, options: .regularExpression) != nil }
        if numbered.count < 5 {
            issues.append("Structure: only \(numbered.count) numbered body sections (need 5–8, numbered \"1. Title\" … with the Synthesis last)")
        }
        if let last = numbered.last, !fold(last).contains("synthesis") {
            issues.append("Structure: the last numbered section must be the Synthesis")
        }

        for (title, words) in numberedSectionWordCounts(in: content) where words < 900 {
            issues.append("Structure: section \"\(title)\" has \(words) words (each numbered section needs ≥ 900 words of real depth)")
        }

        let badGoDeeper = goDeeperLines(in: content).filter { !matchesGoDeeperFormat($0) }
        if !badGoDeeper.isEmpty {
            issues.append("Structure: \(badGoDeeper.count) Go Deeper line(s) do not match \"Author, *Title* (Year) — reason\"")
        }

        if !lowercasedContains(content, "[VISUAL_TABLE: Chapter Map") && folded.contains(where: { $0.hasPrefix("chaptermap") }) {
            issues.append("Structure: Chapter Map section has no [VISUAL_TABLE: Chapter Map] table")
        }

        if let overlap = quickGlanceTakeawayOverlap(in: content), overlap >= 0.3 {
            issues.append(String(format: "Structure: Key Takeaways restate the Quick Glance (content-word overlap %.2f, must be < 0.30) — rewrite takeaways as actions with section references", overlap))
        }
        return issues
    }

    // MARK: Helpers

    static func headingTexts(in content: String) -> [String] {
        var out: [String] = []
        let tagged = try? NSRegularExpression(pattern: #"\[PREMIUM_H[12]\]\s*([^\[\n]+?)\s*(?:\n\s*)?\[/PREMIUM_H[12]\]"#, options: [.caseInsensitive, .dotMatchesLineSeparators])
        let ns = content as NSString
        tagged?.matches(in: content, range: NSRange(location: 0, length: ns.length)).forEach {
            out.append(ns.substring(with: $0.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        for line in content.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("## ") || t.hasPrefix("# ") {
                out.append(t.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces))
            }
        }
        return out.map { $0.replacingOccurrences(of: "**", with: "") }
    }

    static func fold(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func lowercasedContains(_ content: String, _ needle: String) -> Bool {
        content.lowercased().contains(needle.lowercased())
    }

    static func goDeeperLines(in content: String) -> [String] {
        content.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.range(of: #"^\*{0,2}Go Deeper:"#, options: [.regularExpression, .caseInsensitive]) != nil }
    }

    static func matchesGoDeeperFormat(_ line: String) -> Bool {
        line.range(of: goDeeperPattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Word count of each numbered section's body (from its heading to the
    /// next `[PREMIUM_H2]`/`## ` heading), with tags and payloads counted as
    /// they stand — a cheap, stable proxy for prose length.
    static func numberedSectionWordCounts(in content: String) -> [(String, Int)] {
        let lines = content.components(separatedBy: "\n")
        var result: [(String, Int)] = []
        var currentTitle: String?
        var buffer: [String] = []
        func flush() {
            if let t = currentTitle {
                let words = buffer.joined(separator: " ")
                    .split(whereSeparator: { $0.isWhitespace }).count
                result.append((t, words))
            }
            buffer = []
        }
        var i = 0
        while i < lines.count {
            let t = lines[i].trimmingCharacters(in: .whitespaces)
            if let title = headingOnLine(t, following: i + 1 < lines.count ? lines[i + 1] : nil) {
                flush()
                currentTitle = title.range(of: #"^\d{1,2}\.\s+\S"#, options: .regularExpression) != nil ? title : nil
                if t.uppercased() == "[PREMIUM_H2]" || t.uppercased() == "[PREMIUM_H1]" { i += 2 } // multi-line heading
                i += 1
                continue
            }
            if currentTitle != nil { buffer.append(t) }
            i += 1
        }
        flush()
        return result
    }

    private static func headingOnLine(_ line: String, following next: String?) -> String? {
        let upper = line.uppercased()
        if upper.hasPrefix("[PREMIUM_H2]") || upper.hasPrefix("[PREMIUM_H1]") {
            let body = line.dropFirst("[PREMIUM_H2]".count)
            if let close = body.range(of: "[/", options: .caseInsensitive) {
                return String(body[..<close.lowerBound]).replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
            }
            if body.trimmingCharacters(in: .whitespaces).isEmpty, let next {
                return next.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "**", with: "")
            }
            return body.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
        }
        if line.hasPrefix("## ") { return String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces) }
        return nil
    }

    /// Jaccard overlap of content words between the Quick Glance bullets and
    /// the [TAKEAWAYS] items. `nil` when either block is absent.
    static func quickGlanceTakeawayOverlap(in content: String) -> Double? {
        guard let glance = block("QUICK_GLANCE", in: content),
              let takeaways = block("TAKEAWAYS", in: content) else { return nil }
        let a = contentWords(bulletLines(in: glance))
        let b = contentWords(bulletLines(in: takeaways))
        guard !a.isEmpty, !b.isEmpty else { return nil }
        let union = a.union(b).count
        return union == 0 ? 0 : Double(a.intersection(b).count) / Double(union)
    }

    private static func block(_ tag: String, in content: String) -> String? {
        guard let open = content.range(of: "[\(tag)]", options: .caseInsensitive),
              let close = content.range(of: "[/\(tag)]", options: .caseInsensitive, range: open.upperBound..<content.endIndex) else { return nil }
        return String(content[open.upperBound..<close.lowerBound])
    }

    private static func bulletLines(in block: String) -> [String] {
        block.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.range(of: #"^([-*•]|\d+[.)])\s+"#, options: .regularExpression) != nil }
    }

    static let stopWords: Set<String> = [
        "the","a","an","and","or","but","of","to","in","on","for","with","as","by","at","from","that","this","these","those",
        "is","are","was","were","be","been","being","it","its","not","no","than","then","so","if","into","about","over",
        "we","you","your","our","they","their","he","she","his","her","which","who","what","when","where","how","why",
        "can","may","might","should","would","could","will","do","does","did","has","have","had","more","most","one",
        "see","section","sections","each","every","all","any","some","such","also","only","very","just","between","own"
    ]

    static func contentWords(_ lines: [String]) -> Set<String> {
        var words: Set<String> = []
        for line in lines {
            let cleaned = line.replacingOccurrences(of: #"\(see Section \d+[^)]*\)"#, with: "", options: [.regularExpression, .caseInsensitive])
            for raw in cleaned.lowercased().split(whereSeparator: { !$0.isLetter && $0 != "-" }) {
                let w = String(raw)
                if w.count >= 4, !stopWords.contains(w) { words.insert(stem(w)) }
            }
        }
        return words
    }

    /// Crude suffix stemmer so "theories"/"theory" and "explains"/"explain" count as one word.
    private static func stem(_ w: String) -> String {
        for suffix in ["ies", "ing", "ed", "es", "s"] where w.hasSuffix(suffix) && w.count - suffix.count >= 4 {
            let base = String(w.dropLast(suffix.count))
            return suffix == "ies" ? base + "y" : base
        }
        return w
    }
}
