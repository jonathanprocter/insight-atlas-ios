# Insight Atlas — Current Status

**Tip:** `cursor/full-app-fixes-9243` (audit PR **#9**)  
**Date:** 2026-11-17

## Product tip

MiniMax generation · Pocket/Kokoro + Apple narration · `AppEnvironment.shared` settings SoT.

## Structure

| Was | Now |
|-----|-----|
| `DataManager` ~6.7k | ~680 + HTML/DOCX/PDF exporters |
| `AnalysisComponents` ~3.7k | BookReferences / Chrome / PremiumBlocks / ShapeHelpers |

Also: `EditorialMarkupCanonicalizer`, `AnalysisDetailModels`, `AnalysisExportOptionsView`.

## Latest Bugbot fixes (PR #9)

- Resume persists `LibraryItem` + `SourceTextStore`; failed resume stays retryable
- Narration script scrub on every path; cache/skip compares scrubbed fallback
- Memory purge flushes to `GuideBodyStore` before nilling inline bodies
- `voice_preview_` plays via `AudioPlaybackManager`
- DOCX special blocks keep newlines for quote/author splits

## Deferred

- Inter font swap (brand-locked)

## Device / release

Physical-iPhone smoke + next TestFlight build.
