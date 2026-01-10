# Layout Scoring Rubric Version Evolution Plan

**Version:** 1.0
**Created:** 2025-12-12
**Status:** Active

This document formalizes how layout scoring evolves over time, preventing silent scoring drift and ensuring intentional, traceable changes.

---

## Core Principle

> **Layout scoring changes must be intentional, documented, and versioned.**

The layout scoring rubric is a contract between the system and its users. Changes to how quality is measured affect:

- Regeneration decisions
- Quality thresholds
- Historical comparisons
- User expectations

---

## When to Bump Rubric Versions

### MUST Bump Version (Breaking Changes)

These changes **require** a version bump because they make historical scores incomparable:

| Change Type | Example | Impact |
|-------------|---------|--------|
| **Weight changes** | PDF score weight: 40% → 50% | Same document gets different overall score |
| **New issue detection** | Add "orphaned header" detection | Previously "perfect" documents may now have issues |
| **Threshold changes** | Paragraph "too long" threshold: 150 → 120 words | More documents flagged |
| **Score range changes** | Normalize to 0-100 instead of 0-1 | All scores numerically different |
| **Issue severity changes** | Visual density: info → warning | Affects regeneration triggers |
| **Formula changes** | Linear → logarithmic penalty scaling | Score distribution changes |

### MAY Bump Version (Significant Changes)

These changes may warrant a version bump depending on impact:

| Change Type | Bump If... |
|-------------|------------|
| **Bug fixes** | Fix changes scores by > 5% on average |
| **Performance improvements** | Scoring becomes more accurate (not just faster) |
| **New metrics (additive)** | New metric affects overall score calculation |
| **Documentation updates** | N/A - never requires bump |

### NEVER Bump Version

These changes do **not** require a version bump:

- Documentation clarifications
- Code refactoring (same behavior)
- Performance optimizations (same scores)
- Adding debug logging
- Test additions

---

## What Constitutes a Breaking Scoring Change

A change is "breaking" if it causes:

```
ScoreV1(document) ≠ ScoreV2(document)
```

For the **same document** with the **same content**.

### Detection Method

Before releasing rubric changes:

1. Score a reference corpus with current version
2. Score same corpus with proposed changes
3. Compare distributions
4. If mean difference > 2% OR any document differs > 5%, it's breaking

### Reference Corpus

Maintain a versioned reference corpus:

```
/Tests/RubricReferenceCorpus/
  ├── executive_guide_1.json
  ├── academic_guide_1.json
  ├── practitioner_guide_1.json
  ├── edge_case_dense_visuals.json
  ├── edge_case_long_paragraphs.json
  └── expected_scores_v1.0.json
```

---

## How to Compare Documents Scored Under Different Versions

### Rule 1: Don't Compare Raw Scores

```swift
// ❌ WRONG - scores from different versions are not comparable
if documentA.layoutScore.overall > documentB.layoutScore.overall { ... }

// ✅ CORRECT - check versions first
guard documentA.layoutScore.version == documentB.layoutScore.version else {
    // Cannot directly compare
    return .incomparable
}
```

### Rule 2: Use Percentile Ranks for Cross-Version Comparison

If you must compare documents from different rubric versions:

1. Determine each document's percentile rank within its version's score distribution
2. Compare percentile ranks, not raw scores

```swift
// Pseudocode for cross-version comparison
let percentileA = scoreDistribution(version: "v1.0").percentile(of: scoreA)
let percentileB = scoreDistribution(version: "v1.1").percentile(of: scoreB)
// Compare percentileA vs percentileB
```

### Rule 3: Re-Score for True Comparison

The most accurate comparison method:

1. Re-score document A with current rubric version
2. Re-score document B with current rubric version
3. Compare the new scores

This requires storing the raw document structure, not just the score.

---

## Version Naming Convention

```
layout-rubric-v{MAJOR}.{MINOR}
```

- **MAJOR**: Breaking changes (score formula, weights)
- **MINOR**: Non-breaking additions (new optional metrics)

Examples:
- `layout-rubric-v1.0` - Initial release
- `layout-rubric-v1.1` - Added visual density metrics (additive)
- `layout-rubric-v2.0` - Changed PDF weight from 40% to 50%

---

## Version Migration Guide

When releasing a new rubric version:

### 1. Document Changes

Add to version history in `LayoutScore.swift`:

```swift
//  Version History:
//  - layout-rubric-v1.0 (2025-12-12): Initial versioned rubric
//  - layout-rubric-v1.1 (2025-XX-XX): Added visual density penalties, stricter PDF page-break rules
```

### 2. Update Known Versions

```swift
static let knownVersions: Set<String> = [
    "layout-rubric-v1.0",
    "layout-rubric-v1.1"  // ← Add new version
]
```

### 3. Update Current Version

```swift
static let currentVersion = "layout-rubric-v1.1"  // ← Update
```

### 4. Create Migration Notes

Document in this file under "Version History" section below.

### 5. Update Reference Corpus Expectations

Create new expected scores file:
```
expected_scores_v1.1.json
```

---

## Version History

### layout-rubric-v1.0 (2025-12-12)

**Initial Release**

- Established versioning framework
- Base scoring for PDF, DOCX, HTML
- Issue detection for:
  - Paragraph length
  - Orphaned headers
  - Page breaks
  - Spacing
- No visual density scoring (added in v1.1)

### layout-rubric-v1.1 (Planned)

**Visual Density Integration**

Changes from v1.0:
- Added visual density penalties:
  - Consecutive visuals without text: -0.05 per occurrence
  - Oversized visuals for PDF: -0.20 × ratio
  - Insufficient text before visual: -0.05 per occurrence
  - Excessive visual density (> 3/1000 words): up to -0.20
- Added visual density rewards:
  - Well-placed visuals (≥ 80 words before): +0.10 × ratio
- Stricter PDF page-break rules (TBD)
- No change to header semantics (invariants preserved)

Migration notes:
- Documents with many consecutive visuals will score lower
- Documents with well-placed visuals may score higher
- Net effect: ~5% score change on average

---

## Preventing Silent Scoring Drift

### Automated Checks

1. **Version Presence Check**: Decode failures if version missing (DEBUG)
2. **Version Validity Check**: Warnings for unknown versions
3. **Regression Tests**: Reference corpus scored on every build

### Manual Checks

1. **Code Review**: Any scoring logic change requires rubric version discussion
2. **Release Checklist**: Version bump confirmation for scoring changes
3. **Changelog**: Public changelog includes rubric version changes

### Monitoring

Track these metrics:
- Mean score by rubric version
- Score distribution percentiles by version
- Regeneration rate by version

---

## Example: Proposed v1.1 Change Summary

```
layout-rubric-v1.1
==================

CHANGES FROM v1.0:

[PENALTY] Visual Density - Consecutive Visuals
  - Trigger: 2+ visuals in a row without text
  - Impact: -0.05 per occurrence (capped at -0.30)
  - Rationale: Readers need context between visuals

[PENALTY] Visual Density - Oversized Visuals
  - Trigger: Visual > 90% of page width
  - Impact: -0.20 × (oversized count / total visuals)
  - Rationale: Causes PDF page break issues

[REWARD] Visual Density - Well-Placed Visuals
  - Trigger: ≥ 80 words before visual
  - Impact: +0.10 × (well-placed count / total visuals)
  - Rationale: Encourages proper contextual placement

[NO CHANGE] Header Semantics
  - H1-H4 handling unchanged
  - TOC generation unchanged
  - Formatting invariants preserved

EXPECTED IMPACT:
  - Average score change: ±5%
  - Documents with visual issues: -3% to -15%
  - Documents with good visual placement: +2% to +8%

BACKWARD COMPATIBILITY:
  - Old scores remain valid under v1.0 interpretation
  - Cannot directly compare v1.0 and v1.1 scores
  - Re-scoring recommended for trend analysis
```

---

## Governance

### Approval Required For

- Any rubric version bump: Tech Lead + Product Owner
- Breaking changes: Architecture Review Board
- Removal of issue types: Migration plan required

### Documentation Required For

- All version bumps: This document + inline code comments
- Breaking changes: Migration guide
- New issue types: Detection criteria + severity rationale

---

*This document is authoritative for rubric evolution. Follow it to prevent silent scoring drift.*
