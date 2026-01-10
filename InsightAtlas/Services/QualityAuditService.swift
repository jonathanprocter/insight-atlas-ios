//
//  QualityAuditService.swift
//  InsightAtlas
//
//  Quality audit service for evaluating generated guide content.
//  Checks for required sections, formatting quality, and content completeness.
//

import Foundation

struct QualityAuditService {

    // MARK: - Quality Criteria

    struct QualityCriteria {
        let name: String
        let weight: Int
        let check: (String) -> Bool
    }

    // MARK: - Required Sections

    static let requiredSections: [(marker: String, name: String, weight: Int)] = [
        ("[QUICK_GLANCE]", "Quick Glance Summary", 10),
        ("[FOUNDATIONAL_NARRATIVE]", "Foundational Narrative", 8),
        ("[INSIGHT_NOTE]", "Insight Note", 5),
        ("[ACTION_BOX", "Action Box", 8),
        ("[EXERCISE_", "Exercise", 5),
        ("[TAKEAWAYS]", "Key Takeaways", 8),
        ("[STRUCTURE_MAP]", "Structure Map", 4)
    ]

    // MARK: - Quality Checks

    static let qualityChecks: [QualityCriteria] = [
        QualityCriteria(
            name: "Has Executive Summary (## Executive Summary or similar)",
            weight: 8,
            check: { content in
                content.contains("## Executive Summary") ||
                content.contains("## Summary") ||
                content.contains("[QUICK_GLANCE]")
            }
        ),
        QualityCriteria(
            name: "Has Comparative Analysis section",
            weight: 6,
            check: { content in
                content.contains("[SECTION: Comparative Analysis]") ||
                content.contains("[PREMIUM_H2]Comparative Analysis[/PREMIUM_H2]")
            }
        ),
        QualityCriteria(
            name: "Has 1-Page Summary label in Quick Glance",
            weight: 4,
            check: { content in
                content.contains("1-Page Summary") || content.contains("1‑Page Summary")
            }
        ),
        QualityCriteria(
            name: "Has proper premium heading structure",
            weight: 6,
            check: { content in
                let h1Count = content.components(separatedBy: "[PREMIUM_H1]").count - 1
                let h2Count = content.components(separatedBy: "[PREMIUM_H2]").count - 1
                return h1Count >= 2 && h2Count >= 4
            }
        ),
        QualityCriteria(
            name: "Uses cross-book synthesis (no chapter summaries)",
            weight: 6,
            check: { content in
                let lower = content.lowercased()
                let hasSynthesis = lower.contains("cross-book synthesis") || lower.contains("cross book synthesis")
                let hasSummary = lower.contains("chapter summary") || lower.contains("chapter-by-chapter")
                return hasSynthesis && !hasSummary
            }
        ),
        QualityCriteria(
            name: "Has Synthesis Interludes",
            weight: 5,
            check: { content in
                content.contains("[PREMIUM_H2]Synthesis Interlude[/PREMIUM_H2]")
            }
        ),
        QualityCriteria(
            name: "Has Applied Implications section",
            weight: 5,
            check: { content in
                content.contains("[PREMIUM_H2]Applied Implications[/PREMIUM_H2]")
            }
        ),
        QualityCriteria(
            name: "Has sufficient word count (minimum 3000 words)",
            weight: 10,
            check: { content in
                let wordCount = content.split(whereSeparator: { $0.isWhitespace }).count
                return wordCount >= 3000
            }
        ),
        QualityCriteria(
            name: "Has key takeaways section",
            weight: 6,
            check: { content in
                content.contains("[TAKEAWAYS]") ||
                content.contains("## Key Takeaways") ||
                content.contains("## Takeaways")
            }
        ),
        QualityCriteria(
            name: "Has practical exercises",
            weight: 6,
            check: { content in
                content.contains("[EXERCISE_") ||
                content.contains("## Exercise") ||
                content.contains("### Exercise")
            }
        ),
        QualityCriteria(
            name: "Has properly closed block markers",
            weight: 8,
            check: { content in
                let openQuickGlance = content.components(separatedBy: "[QUICK_GLANCE]").count - 1
                let closeQuickGlance = content.components(separatedBy: "[/QUICK_GLANCE]").count - 1
                let openInsight = content.components(separatedBy: "[INSIGHT_NOTE]").count - 1
                let closeInsight = content.components(separatedBy: "[/INSIGHT_NOTE]").count - 1
                return openQuickGlance == closeQuickGlance && openInsight == closeInsight
            }
        ),
        QualityCriteria(
            name: "Has action-oriented content",
            weight: 5,
            check: { content in
                content.contains("[ACTION_BOX") ||
                content.contains("Apply It") ||
                content.contains("Try This")
            }
        ),
        QualityCriteria(
            name: "Has quotes or citations",
            weight: 4,
            check: { content in
                content.contains("[QUOTE]") ||
                content.contains("> ") ||
                content.contains("\"") && content.filter { $0 == "\"" }.count >= 10
            }
        ),
        QualityCriteria(
            name: "Has foundational narrative or context",
            weight: 6,
            check: { content in
                content.contains("[FOUNDATIONAL_NARRATIVE]") ||
                content.contains("## Background") ||
                content.contains("## Context") ||
                content.contains("## The Story")
            }
        ),
        QualityCriteria(
            name: "Uses premium formatting blocks",
            weight: 6,
            check: { content in
                let premiumMarkers = [
                    "[PREMIUM_H1]",
                    "[PREMIUM_H2]",
                    "[PREMIUM_DIVIDER]",
                    "[PREMIUM_QUOTE]",
                    "[AUTHOR_SPOTLIGHT]",
                    "[ALTERNATIVE_PERSPECTIVE]",
                    "[RESEARCH_INSIGHT]"
                ]
                return premiumMarkers.contains { content.contains($0) }
            }
        ),
        QualityCriteria(
            name: "Uses premium headers for parts or chapters",
            weight: 5,
            check: { content in
                content.contains("[PREMIUM_H1]") || content.contains("[PREMIUM_H2]")
            }
        ),
        QualityCriteria(
            name: "Includes perspective/research notes",
            weight: 6,
            check: { content in
                content.contains("[ALTERNATIVE_PERSPECTIVE]") ||
                content.contains("[RESEARCH_INSIGHT]")
            }
        ),
        QualityCriteria(
            name: "Uses diverse premium callouts",
            weight: 6,
            check: { content in
                let markers = [
                    "[PREMIUM_QUOTE]",
                    "[AUTHOR_SPOTLIGHT]",
                    "[ALTERNATIVE_PERSPECTIVE]",
                    "[RESEARCH_INSIGHT]",
                    "[INSIGHT_NOTE]"
                ]
                let used = markers.filter { content.contains($0) }
                return used.count >= 3
            }
        ),
        QualityCriteria(
            name: "Avoids back-to-back identical callouts",
            weight: 4,
            check: { content in
                let markers = [
                    "[PREMIUM_QUOTE]",
                    "[AUTHOR_SPOTLIGHT]",
                    "[ALTERNATIVE_PERSPECTIVE]",
                    "[RESEARCH_INSIGHT]",
                    "[INSIGHT_NOTE]"
                ]
                let lines = content.components(separatedBy: "\n")
                var lastMarker: String?
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { continue }
                    if let marker = markers.first(where: { trimmed.hasPrefix($0) }) {
                        if marker == lastMarker {
                            return false
                        }
                        lastMarker = marker
                    } else {
                        lastMarker = nil
                    }
                }
                return true
            }
        ),
        QualityCriteria(
            name: "Has premium quotes",
            weight: 4,
            check: { content in
                content.components(separatedBy: "[PREMIUM_QUOTE]").count - 1 >= 2
            }
        ),
        QualityCriteria(
            name: "Uses premium dividers between parts",
            weight: 4,
            check: { content in
                content.components(separatedBy: "[PREMIUM_DIVIDER]").count - 1 >= 2
            }
        ),
        QualityCriteria(
            name: "Avoids visual callout language",
            weight: 4,
            check: { content in
                let lowered = content.lowercased()
                let bannedPhrases = [
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
                return !bannedPhrases.contains { lowered.contains($0) }
            }
        ),
        QualityCriteria(
            name: "Cross-disciplinary synthesis signals present",
            weight: 6,
            check: { content in
                let markers = [
                    "Kahneman",
                    "Dweck",
                    "Cialdini",
                    "Rosenberg",
                    "Stoic",
                    "Buddhist",
                    "neuroscience",
                    "neuroplasticity",
                    "behavioral",
                    "systems thinking",
                    "economics"
                ]
                let hits = markers.filter { content.localizedCaseInsensitiveContains($0) }
                return hits.count >= 3
            }
        ),
        QualityCriteria(
            name: "No raw markdown artifacts (unprocessed **bold** or *italic*)",
            weight: 4,
            check: { content in
                // Fail if markdown styling markers are still present in content
                let patterns = [
                    #"\*\*[^*]+\*\*"#,
                    #"(?:^|\s)\*[^*]+\*(?:\s|$)"#,
                    #"__[^_]+__"#,
                    #"(?:^|\s)_[^_]+_(?:\s|$)"#
                ]
                for pattern in patterns {
                    if let regex = try? NSRegularExpression(pattern: pattern),
                       regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) != nil {
                        return false
                    }
                }
                return true
            }
        ),
        QualityCriteria(
            name: "Has numbered or bulleted lists",
            weight: 4,
            check: { content in
                let hasBullets = content.contains("\n- ") || content.contains("\n* ")
                let hasNumbers = content.range(of: "\n\\d+\\.", options: .regularExpression) != nil
                return hasBullets || hasNumbers
            }
        )
    ]

    // MARK: - Calculate Quality Score

    static func calculateQualityScore(content: String) -> Int {
        var totalWeight = 0
        var earnedWeight = 0

        // Check required sections
        for section in requiredSections {
            totalWeight += section.weight
            if content.contains(section.marker) {
                earnedWeight += section.weight
            }
        }

        // Run quality checks
        for check in qualityChecks {
            totalWeight += check.weight
            if check.check(content) {
                earnedWeight += check.weight
            }
        }

        // Calculate percentage
        guard totalWeight > 0 else { return 0 }
        return Int((Double(earnedWeight) / Double(totalWeight)) * 100)
    }

    // MARK: - Detailed Audit Report

    struct AuditReport {
        let overallScore: Int
        let passedChecks: [String]
        let failedChecks: [String]
        let missingSections: [String]
        let suggestions: [String]
        let meetsThreshold: Bool

        static let passingThreshold = 95
    }

    static func generateAuditReport(content: String) -> AuditReport {
        var passedChecks: [String] = []
        var failedChecks: [String] = []
        var missingSections: [String] = []
        var suggestions: [String] = []

        // Check required sections
        for section in requiredSections {
            if content.contains(section.marker) {
                passedChecks.append("✓ Has \(section.name)")
            } else {
                missingSections.append(section.name)
                failedChecks.append("✗ Missing \(section.name)")
                suggestions.append("Add a \(section.name) section using [\(section.marker.dropFirst())] markers")
            }
        }

        // Run quality checks
        for check in qualityChecks {
            if check.check(content) {
                passedChecks.append("✓ \(check.name)")
            } else {
                failedChecks.append("✗ \(check.name)")
            }
        }

        // Additional suggestions based on content analysis
        let wordCount = content.split(whereSeparator: { $0.isWhitespace }).count
        if wordCount < 3000 {
            suggestions.append("Content is \(wordCount) words. Consider expanding to at least 3000 words for comprehensive coverage.")
        }

        let score = calculateQualityScore(content: content)

        return AuditReport(
            overallScore: score,
            passedChecks: passedChecks,
            failedChecks: failedChecks,
            missingSections: missingSections,
            suggestions: suggestions,
            meetsThreshold: score >= AuditReport.passingThreshold
        )
    }
}
