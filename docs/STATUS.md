# Insight Atlas — Current Status

**Tip:** `main` @ `b522b96` (audit PR **#8**/#**9** + reader PR **#10**, both merged)  
**Date:** 2026-11-20

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

TestFlight **2026112001** uploaded 2026-11-20 from `main` @ `a61e8e5` (includes PR #11 `4da26b0`: indigo
Go Deeper footers, scarce next-reads, honest visual failures) / bump `c589b89`, tag `build-2026112001`.
App Store Connect `processingState=VALID` (Apple accepted; onnxruntime/SherpaOnnxC strip held, no ITMS-90208).
Marketing version stays **1.0**. Previous: **2026111702** from `main` @ `0f2d9f7` / bump `1cc1677`;
**2026111701** from `main` @ `04c18a1` / bump `06061e5`.

**Release mechanics:** `scripts/release-testflight.sh` cannot run over plain SSH. `codesign` fails
`errSecInternalComponent` and `git push` fails on `osxkeychain` because a non-GUI session cannot reach the
unlocked login keychain. Run it inside the console session instead:
`sudo launchctl asuser 501 sudo -u jonathanprocter <script>`. Xcode Accounts upload still fails
“Failed to Use Accounts”, so export with the ASC API key instead: pass `-authenticationKeyPath`,
`-authenticationKeyID` and `-authenticationKeyIssuerID` to `xcodebuild -exportArchive`. The key and issuer
live on the release Mac under `~/.appstoreconnect/` (not in this repo). Since `a61e8e5` the script discovers
them there automatically (override with `ASC_KEY_PATH` / `ASC_KEY_ID` / `ASC_ISSUER_ID`).

### Reader follow-up (PR **#10**, `cursor/reader-visuals-hyphens-9243` — merged)

Device screenshots showed broken charts + mid-word hyphens. Root causes (not OCR chrome):

1. **Generate-time:** `sanitizeGeneratedContent` dropped `[VISUAL_*]` wrappers → raw payloads in reader
2. **Extract-time:** PDF EOL hyphenation not rejoined; soft hyphens were hardened to `-`

**Fix:** preserve `VISUAL_*`, rejoin EOL hyphens, strip soft hyphens, accept `→` network links, normalize on reader load.

**Note:** Guides already saved without `VISUAL_*` tags need **Regenerate** (source is in `SourceTextStore`) to restore charts. Soft-hyphen cleanup applies on open without regenerate.

### Structural variation

Guides felt formulaic because every numbered section was prompt-forced into the same six bold-labelled parts. Prompt now uses a **rotating cadence menu** (claim-led / evidence-led / mechanism-first / strain-first / practitioner), optional single orientation page, and lint no longer implies six labelled parts. Regenerate to feel the change.

### Insight Note / Go Deeper / visuals (branch `cursor/note-go-deeper-visuals-9243`)

- **Color clash:** Go Deeper is an indigo footer (reader, Premium note, HTML, PDF) — not a second ember/coral wash nested inside the note.
- **Substance:** Go Deeper is optional and scarce; must name a *different* next read and a concrete gain. KD/PI no longer half-quota stamped.
- **Visuals:** Malformed JSON no longer shows “Visual content is being prepared”; line-format recovery or honest “Couldn’t render this figure”.
- Existing guides need **Regenerate** for new note shape / next-reads; color fixes apply on open for already-tagged content.
