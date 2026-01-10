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

    /// Modern visual block markers
    static let visualMarkers: Set<String> = [
        "[VISUAL_FLOWCHART",
        "[VISUAL_FLOW_DIAGRAM",
        "[VISUAL_TABLE",
        "[VISUAL_COMPARISON_MATRIX",
        "[VISUAL_CONCEPT_MAP",
        "[VISUAL_TIMELINE",
        "[VISUAL_HIERARCHY",
        "[VISUAL_RADAR",
        "[VISUAL_BAR_CHART",
        "[VISUAL_PIE_CHART"
    ]

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

    /// Required components within INSIGHT_NOTE blocks
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

    /// Phrases indicating proper cross-book synthesis
    static let crossBookSynthesisPhrases: Set<String> = [
        "cross-book synthesis",
        "cross book synthesis"
    ]

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

            // Validate INSIGHT_NOTE components
            for component in ContentMarkers.insightNoteComponents {
                let componentCount = lowercased.markerCount(component)
                if componentCount < insightNoteCount {
                    let componentName = component
                        .replacingOccurrences(of: "**", with: "")
                        .replacingOccurrences(of: ":", with: "")
                        .capitalized
                    issues.append("INSIGHT_NOTEs missing \(componentName) sections")
                }
            }
        }

        // MARK: - Cross-Book Synthesis Validation

        if !lowercased.containsAny(of: ContentMarkers.crossBookSynthesisPhrases) {
            issues.append("Missing Cross-Book Synthesis sections")
        }

        if lowercased.containsAny(of: ContentMarkers.chapterFramingPhrases) {
            issues.append("Chapter-by-chapter framing is not allowed; use thematic synthesis")
        }

        // MARK: - Required Sections Validation

        if !lowercased.contains("[section: comparative analysis]") &&
            !lowercased.contains("[premium_h2]comparative analysis[/premium_h2]") {
            issues.append("Missing Comparative Analysis section")
        }

        if !lowercased.contains("[premium_h2]synthesis interlude[/premium_h2]") {
            issues.append("Missing Synthesis Interlude sections")
        }

        if !lowercased.contains("[premium_h2]applied implications[/premium_h2]") {
            issues.append("Missing Applied Implications section")
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

        // MARK: - Quick Glance Label

        if !lowercased.contains("1-page summary") && !lowercased.contains("1‑page summary") {
            issues.append("Quick Glance missing 1-Page Summary label")
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
