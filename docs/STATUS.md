# Insight Atlas — Current Status

**Tip:** `cursor/full-app-fixes-9243` (audit PR **#9** + completion + structure pass)  
**Date:** 2026-11-17

## Product tip

| Area | Current state |
|------|----------------|
| **Guide generation** | **MiniMax** (default). MiniMax→OpenRouter fallback only before the first content token. |
| **Narration** | **Pocket / Kokoro** + **Apple** fallback only. |
| **Settings** | `AppEnvironment.shared` sole SoT. |
| **Audit** | Full backlog addressed; structure extracts continue. |

## Structure progress

| Extract | Status |
|---------|--------|
| `GuideDOCXExporter` | Done (~1.3k LOC out of DataManager) |
| `ExportMarkdownTable` | Done (shared PDF/DOCX helpers) |
| `EditorialMarkupCanonicalizer` | Done |
| `AnalysisDetailModels` | Done |
| `AnalysisExportOptionsView` | Done |
| HTML/PDF exporters from DataManager | Next follow-on |
| Full AnalysisComponents split | Deferred |

## Intentionally deferred

- Inter font swap (brand-locked)
- Remaining HTML/PDF module split from DataManager (~4k+ LOC HTML)
- Full AnalysisComponents megaview split

## Device / release ops

- Physical-iPhone smoke + next TestFlight build
