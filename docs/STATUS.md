# Insight Atlas — Current Status

**Tip:** `cursor/full-app-fixes-9243` (audit PR **#9**)  
**Date:** 2026-11-17

## Product tip

| Area | State |
|------|--------|
| Generation | MiniMax default; OpenRouter fallback only before first token |
| Narration | Pocket/Kokoro + Apple only |
| Settings | `AppEnvironment.shared` sole SoT |

## Structure (DataManager god-object resolved)

| File | Role |
|------|------|
| `DataManager.swift` | ~680 LOC — library CRUD + export orchestration |
| `GuideHTMLExporter.swift` | ~3.8k — HTML export |
| `GuideDOCXExporter.swift` | ~1.3k — DOCX export |
| `GuidePDFExporter.swift` | ~0.8k — PDF export |
| `ExportBrandAssets` / `ExportMarkdownTable` | shared helpers |

Also extracted: `EditorialMarkupCanonicalizer`, `AnalysisDetailModels`, `AnalysisExportOptionsView`.

## Deferred

- Inter font swap (brand-locked)
- Full `AnalysisComponents.swift` (~3.7k) split

## Device / release

Physical-iPhone smoke + next TestFlight build.
