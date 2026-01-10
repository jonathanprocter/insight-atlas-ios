//
//  LayoutScore.swift
//  InsightAtlas
//
//  Export-aware structural scoring for layout quality across formats.
//
//  ## Versioning Policy
//
//  The `version` field tracks rubric changes. Scores from different rubric versions
//  are NOT directly comparable.
//
//  When to bump the version:
//  - Changing score calculation weights
//  - Adding or removing issue detection rules
//  - Modifying severity thresholds
//  - Changing what constitutes a "passing" score
//
//  Version History:
//  - layout-rubric-v1.0 (2025-12-12): Initial versioned rubric
//

import Foundation

// MARK: - Layout Score Rubric Version

/// Current layout scoring rubric version.
/// Bump this when scoring logic changes to invalidate historical comparisons.
enum LayoutScoreRubric {
    /// Current rubric version identifier
    static let currentVersion = "layout-rubric-v1.0"

    /// Known valid rubric versions for migration/validation
    static let knownVersions: Set<String> = [
        "layout-rubric-v1.0"
    ]

    /// Validates a rubric version string
    static func isKnownVersion(_ version: String) -> Bool {
        knownVersions.contains(version)
    }
}

// MARK: - Layout Score

/// Structural scoring for layout quality across export formats.
///
/// ## Versioning
///
/// The `version` field is mandatory and tracks which rubric was used to calculate scores.
/// Scores from different rubric versions should NOT be compared directly, as the scoring
/// methodology may have changed.
///
/// ## Score Interpretation
///
/// All scores are normalized to 0.0-1.0 range:
/// - 0.9-1.0: Excellent layout quality
/// - 0.7-0.89: Good layout with minor issues
/// - 0.5-0.69: Acceptable but needs improvement
/// - Below 0.5: Poor layout quality, review issues array
///
/// ## Format-Specific Scores
///
/// - `pdf`: Score reflecting PDF export quality (page breaks, typography, visuals)
/// - `docx`: Score reflecting DOCX export quality (styles, structure)
/// - `html`: Score reflecting HTML export quality (semantic markup, accessibility)
struct LayoutScore: Codable {
    /// Rubric version used to calculate this score.
    /// Required. Scores with different versions are not comparable.
    let version: String

    /// Overall layout quality score (0.0-1.0)
    let overall: Double

    /// PDF export quality score (0.0-1.0)
    let pdf: Double

    /// DOCX export quality score (0.0-1.0)
    let docx: Double

    /// HTML export quality score (0.0-1.0)
    let html: Double

    /// Specific layout issues detected
    let issues: [LayoutIssue]

    // MARK: - Initialization

    /// Creates a new LayoutScore with the current rubric version.
    init(overall: Double, pdf: Double, docx: Double, html: Double, issues: [LayoutIssue]) {
        self.version = LayoutScoreRubric.currentVersion
        self.overall = overall
        self.pdf = pdf
        self.docx = docx
        self.html = html
        self.issues = issues
    }

    /// Creates a LayoutScore with an explicit version (for migration/testing).
    init(version: String, overall: Double, pdf: Double, docx: Double, html: Double, issues: [LayoutIssue]) {
        self.version = version
        self.overall = overall
        self.pdf = pdf
        self.docx = docx
        self.html = html
        self.issues = issues
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case version
        case overall
        case pdf
        case docx
        case html
        case issues
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Version is required - fail loudly if missing
        if let version = try container.decodeIfPresent(String.self, forKey: .version) {
            self.version = version

            // Validate version in DEBUG builds
            #if DEBUG
            if !LayoutScoreRubric.isKnownVersion(version) {
                print("⚠️ LayoutScore: Unknown rubric version '\(version)'. Known versions: \(LayoutScoreRubric.knownVersions)")
            }
            #endif
        } else {
            // Version missing - use current version but warn in DEBUG
            #if DEBUG
            assertionFailure("LayoutScore decoded without version field. This indicates legacy data or a bug.")
            #endif
            self.version = LayoutScoreRubric.currentVersion
        }

        self.overall = try container.decode(Double.self, forKey: .overall)
        self.pdf = try container.decode(Double.self, forKey: .pdf)
        self.docx = try container.decode(Double.self, forKey: .docx)
        self.html = try container.decode(Double.self, forKey: .html)
        self.issues = try container.decode([LayoutIssue].self, forKey: .issues)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(overall, forKey: .overall)
        try container.encode(pdf, forKey: .pdf)
        try container.encode(docx, forKey: .docx)
        try container.encode(html, forKey: .html)
        try container.encode(issues, forKey: .issues)
    }
}

// MARK: - Layout Issue

/// A specific layout quality issue detected during scoring.
struct LayoutIssue: Codable, Identifiable {
    let id: UUID
    let type: String
    let section: String
    let severity: String
    let suggestion: String

    init(id: UUID = UUID(), type: String, section: String, severity: String, suggestion: String) {
        self.id = id
        self.type = type
        self.section = section
        self.severity = severity
        self.suggestion = suggestion
    }
}

// MARK: - Documentation

/*
 ## Layout Score Rubric Documentation

 ### What Changing the Rubric Version Means

 When you change `LayoutScoreRubric.currentVersion`, you are declaring that:

 1. The scoring methodology has materially changed
 2. Historical scores calculated with previous versions should not be compared
    to new scores
 3. Any dashboards, reports, or analytics that track scores over time need to
    account for the version boundary

 ### Why Scores From Different Versions Are Not Comparable

 Consider these scenarios:

 **Scenario A: Weight Changes**
 - v1.0 weights PDF issues at 40%, DOCX at 30%, HTML at 30%
 - v1.1 changes to 50%, 25%, 25%
 - A document scoring 0.85 in v1.0 might score 0.75 in v1.1 (or vice versa)
   purely due to weight changes, not actual quality changes

 **Scenario B: New Issue Detection**
 - v1.0 detects 5 categories of issues
 - v1.1 adds detection for "orphaned headers"
 - A "perfect" 1.0 score in v1.0 might become 0.95 in v1.1 because the new
   issue type found problems that were previously invisible

 **Scenario C: Threshold Changes**
 - v1.0 considers < 5pt spacing a "warning"
 - v1.1 considers < 8pt spacing a "warning"
 - Scores decrease not because quality degraded, but because standards improved

 ### Best Practices

 1. Always include version when storing/transmitting scores
 2. Filter/group by version when displaying historical trends
 3. Document what changed in each version in the Version History comment above
 4. Consider migration strategies when old scores need reinterpretation
 */

