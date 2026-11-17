# Insight Atlas — Current Status

**Tip:** `cursor/full-app-fixes-9243` (audit PR **#9**)  
**Date:** 2026-11-17

## Product tip

MiniMax generation · Pocket/Kokoro + Apple narration · `AppEnvironment.shared` settings SoT.

## Audit completion

Full ranked audit (`docs/audits/2026-11-17-full-app-audit.md`, 40 findings) is implemented on this tip.

### Executive decisions (closed)

| Topic | Decision |
|-------|----------|
| **Inter + Cormorant (#34)** | **Keep.** Established product brand pairing (Inter UI + Cormorant display + Caveat accent). Not “AI default drift” to fix mid-release; swap only in a dedicated brand refresh with licensed assets. |
| **Support / App Store URLs (#19)** | Keep rows **hidden** until `InsightAtlasSupportEmail` / `InsightAtlasAppStoreID` Info.plist keys are set. Do not ship `example.com` placeholders. |
| **Theme (#14)** | Full theme picker stays live; PDF/HTML export remains light-pinned. |
| **Megaview splits (#37)** | AnalysisComponents + DataManager exporters done. Further `AnalysisDetailView` / `InsightVisuals` / HTML CSS splits are post-ship maintainability, not TestFlight blockers. |

### Latest polish on this tip

- PDF export is MainActor-only (no `main.sync`); bulk/library/guide use `exportGuideAsync`
- PDF prerender skips native-strong types + soft 24 MB byte budget
- `generation_voice_provider_picker` aliases Settings voice APIs
- ManuscriptGate + MiniMax credential unit tests
- README architecture matches shipping services
- Bugbot: resume persist, narration scrub/cache, safe body purge, voice preview play, DOCX newlines

## Structure

| Was | Now |
|-----|-----|
| `DataManager` ~6.7k | ~680 + HTML/DOCX/PDF exporters |
| `AnalysisComponents` ~3.7k | BookReferences / Chrome / PremiumBlocks / ShapeHelpers |

## Device / release

Ready for TestFlight handoff: bump build → `scripts/release-testflight.sh` → physical-iPhone smoke after processing.
