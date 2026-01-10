# Formatting Invariants Contract

**Version:** 1.0
**Last Audit:** 2025-12-12
**Status:** LOCKED - All invariants verified

This document defines the authoritative formatting rules that must never regress. Any change to rendering, export, or parsing logic must be validated against these invariants.

---

## A. Header Semantics

### Invariant A.1: H1–H4 Semantic Hierarchy Must Be Preserved

**Invariant:** Header levels H1 through H4 must maintain their semantic meaning across all code paths: parsing, encoding, decoding, SwiftUI rendering, PDF export, DOCX export, and HTML export.

**Why it matters:** Headers define document structure. If an H1 silently becomes a paragraph during round-trip, the document loses its hierarchical meaning, TOC generation breaks, and export formats become structurally incorrect.

**How to detect regression:**
- Unit test: Encode a document with H1/H2/H3/H4 blocks to JSON, decode it back, verify all types are preserved
- Manual: Export a document with PART headers to PDF; verify TOC shows correct hierarchy

---

### Invariant A.2: PART Headers (H1) Are Distinct From SECTION Headers (H2)

**Invariant:** H1 headers represent major document divisions (PART I, PART II, etc.). H2 headers represent sections within those parts. This distinction must be preserved in:
- SwiftUI: Different visual styling (H1 uses `analysisDisplayH1()`, gold accent)
- PDF: Different rendering path (`renderPartHeader` vs `renderSectionHeading`)
- PDF TOC: H1 entries have `isSubsection: false`, H2+ have `isSubsection: true`
- DOCX: H1 uses `PartHeader` style, H2 uses `PremiumH2` style
- HTML: H1 uses `premium-part-header` class, H2 uses `premium-h2` class

**Why it matters:** PART vs SECTION distinction is the primary structural hierarchy of the document. Flattening this loses navigational meaning.

**How to detect regression:**
- Visual: Open PDF TOC; H1 entries should not be indented, H2 entries should be indented
- Code: In `InsightAtlasPDFRenderer.buildTableOfContents()`, verify `isSubsection: section.headingLevel > 1`

---

### Invariant A.3: Header Type Mapping Table

| Markdown | BlockType | SwiftUI Font | PDF Method | DOCX Style | HTML Tag |
|----------|-----------|--------------|------------|------------|----------|
| `# `     | `.heading1` | `analysisDisplayH1()` | `renderPartHeader()` | `PartHeader` | `<h1>` |
| `## `    | `.heading2` | `analysisDisplayH2()` | `renderSectionHeading()` | `PremiumH2` | `<h2>` |
| `### `   | `.heading3` | `analysisDisplayH3()` | `renderHeading3()` | `Heading2` | `<h3>` |
| `#### `  | `.heading4` | `analysisDisplayH4()` | `renderHeading4()` | `Normal+Bold` | `<h4>` |

**Invariant:** This mapping must remain constant. Any deviation is a regression.

---

## B. Table of Contents

### Invariant B.1: PDF TOC Preserves Hierarchical Distinction

**Invariant:** The PDF Table of Contents must visually distinguish between:
- H1 entries (PART-level): `isSubsection: false` → no indent
- H2+ entries (SECTION-level): `isSubsection: true` → indented

**Why it matters:** A flat TOC makes long documents unnavigable.

**How to detect regression:**
- In `InsightAtlasPDFRenderer.swift`, line ~417: `isSubsection: section.headingLevel > 1`
- Visual: Generate PDF, check TOC indentation

---

### Invariant B.2: HTML TOC Uses Level-Based CSS Classes

**Invariant:** HTML TOC entries must use CSS classes based on heading level:
- H2 entries: class `toc-section`
- H3 entries: class `toc-subsection`

**Why it matters:** CSS-based styling enables visual hierarchy without hardcoded formatting.

**How to detect regression:**
- In `DataManager.generateHTMLTableOfContents()`: verify `entry.level == 3 ? "toc-subsection" : "toc-section"`

---

### Invariant B.3: TOC Entries Include Navigable IDs

**Invariant:** Every TOC entry must link to an `id` attribute on the corresponding heading element. IDs must be stable and deterministic (e.g., `section-1`, `section-2`).

**Why it matters:** Broken links make the TOC useless.

**How to detect regression:**
- In HTML output, verify each `<a href="#section-N">` has a matching `<h2 id="section-N">`

---

## C. Visuals

### Invariant C.1: Visuals Are Attached to Sections

**Invariant:** A `GuideVisual` is always associated with a `GuideSection`. Visuals never float independently.

**Why it matters:** Detached visuals lose narrative context.

**How to detect regression:**
- In `GenerateGuideResponse.swift`: `GuideSection` has `let visual: GuideVisual?`
- In parsing: visuals are added to section blocks, not to a separate array

---

### Invariant C.2: Visuals Render Inline After Section Content

**Invariant:** In all formats (SwiftUI, PDF, DOCX, HTML), a visual must render immediately after the text content of its parent section, before the next section begins.

**Why it matters:** Visual-text adjacency preserves narrative flow.

**How to detect regression:**
- In SwiftUI: `GuideVisualView` appears in block rendering after paragraph content
- In PDF: `renderVisual()` called in section block loop

---

### Invariant C.3: PDF Export Must Not Perform Network I/O

**Invariant:** PDF rendering must use only locally cached images. The `VisualAssetCache` must have all images cached before `InsightAtlasPDFRenderer.render()` is called.

**Why it matters:** Network I/O during PDF generation causes:
- Non-deterministic output (different results on retry)
- Export failures in offline mode
- Unpredictable latency

**How to detect regression:**
- In `AnalysisExportOptionsView.exportAs()`: verify `VisualAssetCache.shared.prefetchAll()` is called before PDF generation
- In `PDFContentBlockRenderer.renderVisual()`: verify it only calls `VisualAssetCache.shared.cachedImage(for:)`, never a network fetch

---

### Invariant C.4: Visual Rendering Parity Across Formats

**Invariant:** The same `GuideVisual` must produce visually equivalent output in SwiftUI and PDF (same aspect ratio, same caption placement, same corner radius styling).

**Why it matters:** Users expect "what you see is what you export."

**How to detect regression:**
- Compare `VisualTheme.cornerRadius` (SwiftUI) with `VisualTheme.pdfCornerRadius` (PDF) — both should be 8pt
- Visual: Compare app display with PDF export of same document

---

## D. Spacing & Block Rules

### Invariant D.1: Paragraph Spacing Is Consistent

**Invariant:** Body paragraphs must have consistent spacing:
- SwiftUI: `lineSpacing(6)` with `AnalysisTheme.Spacing.md` between paragraphs
- PDF: `PDFStyleConfiguration.Spacing.paragraphSpacing` (12pt)

**Why it matters:** Inconsistent spacing creates visual noise and reduces readability.

**How to detect regression:**
- Measure vertical space between consecutive paragraphs in PDF vs SwiftUI

---

### Invariant D.2: Block Spacing After Special Blocks

**Invariant:** Special blocks (insight notes, action boxes, exercises, etc.) must have `PDFStyleConfiguration.Spacing.blockSpacing` (16pt) after them.

**Why it matters:** Special blocks need breathing room to stand out.

**How to detect regression:**
- In `PDFContentBlockRenderer`, verify all `renderX()` methods return heights that include bottom spacing

---

### Invariant D.3: Headers Never Orphaned From Content

**Invariant:** A header must not appear at the bottom of a page with its content starting on the next page. If a header would be within 50pt of the page bottom, start a new page.

**Why it matters:** Orphaned headers confuse readers.

**How to detect regression:**
- In `InsightAtlasPDFRenderer.renderContentPages()`: verify check `currentY + headingHeight > contentRect.maxY - 50`

---

### Invariant D.4: Visuals Never Split Across Pages

**Invariant:** A visual block (image + caption) must render entirely on one page. If it doesn't fit, start a new page.

**Why it matters:** Split visuals are illegible.

**How to detect regression:**
- In `InsightAtlasPDFRenderer`: verify visual block height check before rendering

---

### Invariant D.5: List Items Maintain Grouping

**Invariant:** Bullet lists and numbered lists must not be split mid-list across pages unless the list exceeds one full page.

**Why it matters:** Fragmented lists lose sequential meaning.

**How to detect regression:**
- Generate PDF with multi-item list near page break; verify list stays together or breaks cleanly

---

## E. Codable Round-Trip Safety

### Invariant E.1: All BlockTypes Encode and Decode Symmetrically

**Invariant:** Every case in `PDFContentBlock.BlockType` must have:
1. A corresponding `case "typeName":` in `encode(to:)`
2. A corresponding `case "typeName":` in `init(from:)`

**Why it matters:** Missing decode cases cause silent data loss.

**How to detect regression:**
- Unit test: For each BlockType, encode and decode, assert equality
- Code review: Count cases in `encode(to:)` vs `init(from:)`

---

### Invariant E.2: Unknown Block Types Fail Loudly in DEBUG

**Invariant:** If an unknown `typeString` is encountered during decoding, the code should:
- In DEBUG: Log a warning
- In RELEASE: Fall back to `.paragraph` (current behavior)

**Why it matters:** Silent fallback masks bugs during development.

**How to detect regression:**
- Add `#if DEBUG` warning in the `default:` case of `init(from:)`

---

## F. Layout Score Integrity

### Invariant F.1: Layout Scores Are Versioned

**Invariant:** `LayoutScore` must include a `version` field (e.g., `"layout-rubric-v1.0"`). Scores from different rubric versions are not comparable.

**Why it matters:** Rubric changes invalidate historical scores.

**How to detect regression:**
- In `LayoutScore.swift`: verify `let version: String` exists
- In decoding: verify version is validated

---

### Invariant F.2: Missing Layout Score Version Fails in DEBUG

**Invariant:** If a `LayoutScore` is decoded without a `version` field, DEBUG builds should assert or log loudly.

**Why it matters:** Unversioned scores are uninterpretable.

**How to detect regression:**
- Decode a JSON payload without `version`; verify DEBUG warning/failure

---

## G. Bulk Export Orchestration

### Invariant G.1: Bulk Export Delegates to Single-Item Pipeline

**Invariant:** Bulk export (`BulkExportCoordinator`) must delegate to the existing single-item export pipeline (`DataManager.exportGuide()`). Bulk export is orchestration only, not rendering.

**What bulk export does:**
- Collects selected items
- Iterates and calls `DataManager.exportGuide()` for each
- Copies results to a staging directory
- Creates a ZIP archive

**What bulk export must NOT do:**
- Introduce new export logic
- Bypass layout scoring
- Modify rendering pipelines
- Apply different formatting rules than single-item export

**Why it matters:** Export parity. A guide exported individually must be byte-identical to the same guide in a bulk export ZIP. Any divergence creates user confusion and QA burden.

**How to detect regression:**
- Export a guide individually as PDF
- Export the same guide via bulk export
- Diff the two files — they must be identical

---

### Invariant G.2: Bulk Export Never Regenerates Content

**Invariant:** `BulkExportCoordinator` receives `LibraryItem` objects with existing `summaryContent`. It must never:
- Call AI generation endpoints
- Trigger content regeneration
- Modify the `summaryContent` field

**Why it matters:** Bulk export is a packaging operation. Regeneration during export would cause unpredictable delays and inconsistent output.

**How to detect regression:**
- In `BulkExportCoordinator.export()`: verify no calls to `AIService`, `GuideGenerationService`, or similar
- Assert: `item.summaryContent` is non-nil and used as-is

---

### Invariant G.3: Bulk Export Filters Are Read-Only

**Invariant:** Bulk export respects the current filter/search state in `LibraryView`. It must not:
- Modify filter state
- Clear search text
- Add new filtering logic

**Why it matters:** Users expect bulk export to reflect what they see. Hidden filtering would export unexpected items.

**How to detect regression:**
- Apply a filter in LibraryView
- Enter selection mode
- Verify only filtered items are selectable
- Verify filter state is unchanged after export

---

## Verification Checklist

Before any release, verify:

- [ ] H1 headers survive JSON round-trip (test: `HeaderHierarchyTests`)
- [ ] PDF TOC shows indented H2 entries
- [ ] HTML TOC uses `toc-section` / `toc-subsection` classes
- [ ] Visuals export to PDF without network calls
- [ ] No orphaned headers in PDF
- [ ] Layout scores include version field
- [ ] All BlockTypes have encode AND decode cases
- [ ] Bulk export produces same output as single-item export
- [ ] Bulk export does not trigger content regeneration

---

## Change Log

| Date | Version | Change | Author |
|------|---------|--------|--------|
| 2025-12-12 | 1.0 | Initial invariants locked after audit | System |

---

*This document is authoritative. Any deviation is a bug.*
