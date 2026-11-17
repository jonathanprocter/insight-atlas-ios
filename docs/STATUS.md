# Insight Atlas — Current Status

**Tip:** `cursor/full-app-fixes-9243` (audit PR **#9** + completion + structure)  
**Date:** 2026-11-17

## Product tip

MiniMax generation · Pocket/Kokoro + Apple narration · `AppEnvironment.shared` settings SoT.

## Structure

| Extract | LOC moved |
|---------|----------:|
| `GuideHTMLExporter` | ~3.8k |
| `GuideDOCXExporter` | ~1.3k |
| `ExportBrandAssets` / `ExportMarkdownTable` | shared |
| `EditorialMarkupCanonicalizer` | done |
| `AnalysisDetailModels` / `AnalysisExportOptionsView` | done |

`DataManager.swift` is now ~1.5k LOC (was ~6.7k). PDF generation remains in DataManager for a follow-on extract.

## Deferred

- Inter font swap (brand-locked)
- PDF exporter extract (`GuidePDFExporter`)
- Full `AnalysisComponents` split

## Device / release

Physical-iPhone smoke + next TestFlight build.
