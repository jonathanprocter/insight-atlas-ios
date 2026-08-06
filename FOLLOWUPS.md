# InsightAtlas — Follow-ups to review & complete

**Target date:** 2026-08-06 (tomorrow)
**Logged:** 2026-08-05
**Branch:** `claude/author-spotlight-ios-ui-ggkops` (PR #1)
**Status:** open — not blocking; app builds green on `8d30582`

---

## 1. Reconcile unwired visual tags (prompt ↔ renderer)

The generation prompt (`InsightAtlas/Services/InsightAtlasPrompt.swift`) instructs ~30
`[VISUAL_*]` tags, but **8 are not among the 32 wired `InsightVisualType` cases**, so they
currently degrade to a **generic box** instead of a tailored diagram:

- `VISUAL_SPECTRUM`
- `VISUAL_MINDMAP`
- `VISUAL_GAUGE`
- `VISUAL_BEFORE_AFTER`
- `VISUAL_ICEBERG`
- `VISUAL_BRIDGE`
- `VISUAL_ORBIT`
- `VISUAL_LADDER`

**Decide one:**

- **(a) Map each to the closest wired type** in `InsightVisualParser.canonicalizeVisualTag`
  (`InsightAtlas/Views/InsightVisuals.swift`). Candidate mappings:
  SPECTRUM→quadrant/comparison, MINDMAP→conceptMap, GAUGE→radar or infographic,
  BEFORE_AFTER→comparisonMatrix, ICEBERG→hierarchy/pyramid, BRIDGE→process,
  ORBIT→conceptMap, LADDER→pyramid/hierarchy. *(Preferred — keeps prompt richness.)*
- **(b) Trim the prompt's visual list** to only the 32 wired tags.

**Verify:** generate a guide exercising these tags; confirm no generic fallback in the
on-screen reader and the PDF export (both parsers share `InsightVisualParser`).

---

## 2. Hide the now-inert Dark / System theme options

The app is **locked to light mode** (`ContentView.swift`: `.preferredColorScheme(.light)`),
so the Theme picker's **Dark** and **System** choices are no-ops and mislead the user.

**Options:**

- Hide the Dark/System rows in `ThemeSettingsView` (`InsightAtlas/Views/SettingsView.swift`)
  — leave only Light; OR
- Reduce `PremiumTheme` to `.light` only (`ContentView.swift`) and drop the picker; OR
- If dark mode may return, instead remove the `.preferredColorScheme(.light)` lock and
  restore `preferredColorScheme` (the adaptive dark support is already built).

Pick based on whether dark mode is coming back.
