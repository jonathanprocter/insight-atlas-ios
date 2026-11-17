# Insight Atlas — Current Status

**Tip:** `cursor/full-app-fixes-9243` (audit PR **#9** + completion pass)  
**Date:** 2026-11-17

## Product tip

| Area | Current state |
|------|----------------|
| **Guide generation** | **MiniMax** (default). Optional MiniMax→OpenRouter fallback only before the first content token. |
| **Narration** | **Pocket / Kokoro** on-device TTS with **Apple system voices** as the only fallback. Hosted Liam / Mega / OpenAI Audio / ChatGPT Voice removed. |
| **Settings** | Single source of truth: `AppEnvironment.shared` (mirrored into `DataManager` for observers). |
| **Audit** | `docs/audits/2026-11-17-full-app-audit.md` backlog completed on this branch. |

## Audit backlog completion

All 40 ranked findings addressed except intentional deferrals:

| Deferred | Why |
|----------|-----|
| Inter → distinctive sans (#34) | Brand-locked across PremiumUI / DesignSystem / HTML export (~46 call sites); keep Inter. |
| Full megaview splits (#37) | `EditorialMarkupCanonicalizer` extracted; full AnalysisDetailView / AnalysisComponents split deferred as multi-PR maintainability work. |
| Full DataManager export module split (#6) | `main.sync` removed from async export path; god-object file split still a follow-on refactor. |

## Done highlights (completion pass)

- Release `print` gated `#if DEBUG` (0 ungated in InsightAtlas/)
- Root sample HTML/PDF + `pnpm-lock.yaml` removed
- `FOLLOWUPS.md` / `todo.md` archived; living `docs/STATUS.md`
- Real PDF export prerender progress; memory pressure purges resident guide bodies
- LLMActionRouter drives Pocket voice selection / provider / preview
- CI `release-stub-guard` job; Kokoro docs match Pocket→Apple only
- Settings SoT tests; OutputContract soft failures logged via `Logger` in Release

## Still open (device / release ops)

- Physical-iPhone smoke: Pocket install, generate, play, delete, airplane mode
- Next unique TestFlight build number, archive/upload, tag + release evidence

See also: `docs/KOKORO_OFFLINE_NARRATION.md`, archived `FOLLOWUPS.md`, `todo.md`.
