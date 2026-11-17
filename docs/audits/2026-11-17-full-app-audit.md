# Insight Atlas iOS — Full-App Audit

**Branch audited:** `cursor/atlas-audio-optim-9243` @ `f492ee2`  
**Date:** 2026-11-17  
**Scope:** All major subsystems (not audio/visuals only)  
**Method:** Static code inspection across `InsightAtlas/` + tests, CI, docs, release scripts

**Implementation status (2026-11-17):** Closed on `cursor/full-app-fixes-9243` (PR **#9**). See `docs/STATUS.md` for executive decisions (Inter kept as brand; support URLs stay hidden until configured; megaview leftovers post-ship).

Findings are ranked by severity (impact × likelihood), with effort awareness in the ranking rationale. Aim: actionable, evidence-backed items — not generic advice.

---

## Severity summary

| Severity | Count | Meaning |
|----------|------:|---------|
| P0 | 3 | Ship-blocker or user-visible correctness failure likely in normal use |
| P1 | 12 | High impact / high likelihood; fix before next TestFlight if possible |
| P2 | 14 | Real defects or debt; schedule soon |
| P3 | 7 | Cleanup, docs drift, low-likelihood hardening |

---

## Ranked findings

### 1. Regenerate re-feeds the guide as the “book”
- **Severity:** P0
- **Category:** Guide generation / reliability
- **Evidence:** `InsightAtlas/Views/RegenerateView.swift` (`generateGuide(bookText: item.summaryContent ?? …)`); `LibraryItem` has no source-book field (`Models/GuideModels.swift`)
- **Why:** Impact is total quality collapse on regenerate (model summarizes a summary, invents provenance). Likelihood is 100% for anyone using Regenerate. Effort is medium (must persist original extract or re-import file).
- **Remediation:** Persist processed book text (or original file) per library item beside `GuideBodyStore`; Regenerate must pass that source, never `summaryContent`. Block Regenerate when source is missing.

### 2. Dual settings owners diverge in memory
- **Severity:** P0
- **Category:** Persistence / settings
- **Evidence:** `AppEnvironment.swift` and `DataManager.swift` both load/save `insight_atlas_settings`; Generation/Settings use `environment.userSettings`; Regenerate seeds from `dataManager.userSettings` and writes via `dataManager.updateSettings`
- **Why:** Two `@Published` copies of the same blob; saving one does not reload the other. Users can regenerate with stale provider/mode while Settings shows something else. High likelihood after any Settings → Regenerate path.
- **Remediation:** Single source of truth (keep `AppEnvironment.userSettings`, make `DataManager` read-through or delete its copy). Sync on save; add a regression test that Settings write is visible to Regenerate without relaunch.

### 3. Hosted Liam TTS client still ships and is tested as live
- **Severity:** P0
- **Category:** Narration / dead-but-dangerous path
- **Evidence:** `KokoroTTSClient.swift` (`https://kokoro-tts.procterai.cc/v1`, voice `am_liam`); `KokoroNarrationService.swift`; production call sites absent, but `InsightAtlasTests/KokoroNarrationTests.swift` still exercises keychain + HTTP client; UX leftovers still name Liam
- **Why:** Documented as removed from fallback, yet binary still contains a private hosted TTS client + keychain account. Any future accidental rewire (or LLMActionRouter/tests) reopens the Cloudflare 530 outage path. High security/reliability surprise surface.
- **Remediation:** Delete `KokoroTTSClient` / `KokoroNarrationService` from app target (move tests to archive or delete); strip Liam fallback enum cases; keep only Pocket + Apple routes.

### 4. Narration rewrite blocks first listen up to 75s
- **Severity:** P1
- **Category:** Narration / performance / UX
- **Evidence:** `NarrationPreparationPolicy.rewritesBeforeInitialSynthesis = true` in `NarrationService.swift`; `NarrationScriptService.rewriteDeadline = .seconds(75)`
- **Why:** Every cold listen with MiniMax/OpenRouter configured waits on network before Pocket speaks. Offline path is good; online-but-slow is a frequent spinner. Impact high on perceived reliability.
- **Remediation:** Default policy to listening-edition first + background cache warm (code path already exists when flag is `false`); or start Apple/Pocket on fallback immediately while rewrite races, then upgrade only if rewrite finishes before synthesis starts.

### 5. Guide bodies stay fully resident despite GuideBodyStore
- **Severity:** P1
- **Category:** Performance / memory
- **Evidence:** `DataManager.loadLibrary()` rehydrates every body into `libraryItems[].summaryContent`; `LibraryView` search scans full `summaryContent`; `MemoryPressureCoordinator` does not drop guide text
- **Why:** GuideBodyStore fixed UserDefaults rewrite cost, but launch still materializes the whole corpus in RAM. Large libraries + Pocket model (~100MB+) → jetsam while backgrounded. Likelihood rises with library size.
- **Remediation:** Keep metadata only in `libraryItems`; lazy-load bodies on open; search title/author (or a separate FTS index); purge body from memory under pressure.

### 6. `DataManager` is a 6.7k-line god object with `main.sync` PDF/HTML paths
- **Severity:** P1
- **Category:** Reliability / concurrency / maintainability
- **Evidence:** `DataManager.swift` (~6694 lines); `DispatchQueue.main.sync` in `getLogoBase64`, `getLogoImage`, `generatePDF`
- **Why:** `@MainActor` class calling `main.sync` from off-main is a classic deadlock if any caller is already on main via a sync bridge. HTML/PDF/DOCX all live here → every export change risks the whole persistence layer. Likelihood medium, impact crash/hang.
- **Remediation:** Split Export / HTML / PDF / DOCX into dedicated types; replace `main.sync` with `MainActor.assumeIsolated` / `await MainActor.run`; keep DataManager to library CRUD + settings facade.

### 7. PDF visual prerender is main-actor, serial, scale-3 ImageRenderer
- **Severity:** P1
- **Category:** Visuals / PDF / performance
- **Evidence:** `InsightVisuals.swift` `VisualRasterizer` / `PDFVisualPrerenderer`; called from `DataManager.exportGuideAsync`, `GuideView`, `AnalysisDetailView`
- **Why:** Each visual rasterized at 3× on MainActor before PDF layout. Guides with many diagrams spike memory and freeze UI during export. High likelihood on Deep Research guides.
- **Remediation:** Cap concurrent renders; lower scale for screen-sized caches; render off main where possible; skip prerender when native PDF diagram path already covers the type; bound total cache bytes per export.

### 8. MiniMax OAuth client_id hardcoded; `clearAllKeys` skips MiniMax
- **Severity:** P1
- **Category:** Security / auth
- **Evidence:** `MiniMaxOAuthService.swift` `MiniMaxOAuthConfig.clientID`; `KeychainService.clearAllKeys()` deletes Claude/OpenAI/OpenRouter only; Settings “Reset All Settings” does not sign out MiniMax (`SettingsView.resetAllSettings`)
- **Why:** Public OAuth client IDs are often OK, but reset/clear claiming to wipe credentials while leaving refresh tokens is a compliance/privacy bug. Likelihood high if users expect Reset = clean slate.
- **Remediation:** `clearAllKeys` → also `clearMiniMaxAuth()`; Reset All Settings calls `MiniMaxOAuthService.shared.signOut()`; document client_id as public PKCE client.

### 9. Interrupted generation UI is stuck; BG resume is best-effort and incomplete
- **Severity:** P1
- **Category:** Guide generation / reliability
- **Evidence:** `BackgroundGenerationCoordinator.checkForInterruptedGeneration` sets progress to `"Interrupted"` but does not resume; `handleBackgroundProcessing` reloads settings and calls `performGeneration` without wiring governor/UI the same as `startGeneration`; failed state kept for retry with no obvious resume API from GenerationView
- **Why:** App kill mid-stream leaves orphan book text in Caches + confusing Interrupted chrome. Likelihood medium on long MiniMax M3 runs.
- **Remediation:** Explicit Resume / Discard UI; on launch auto-resume only when credentials valid; always clear book-text cache on discard; unify resume with `startGeneration` path.

### 10. Three independent `AIService` instances
- **Severity:** P1
- **Category:** Networking / concurrency
- **Evidence:** `AppEnvironment.aiService = AIService()`; `BackgroundGenerationCoordinator` private `AIService()`; `NarrationScriptService` private `AIService()`
- **Why:** Separate URLSessions, retry state, and no shared cancellation. Environment’s instance appears unused by the real generation path. Wastes sockets and confuses debugging.
- **Remediation:** Inject one shared `AIService` (or factory with shared session config) through AppEnvironment into coordinator + script service.

### 11. Governance docs claim `OutputContractValidator` gates export — code uses `ManuscriptGate` instead, validator unused
- **Severity:** P1
- **Category:** Export compliance / contradictory docs
- **Evidence:** `Documentation/GOVERNANCE_LOCKS.md` Lock 1; `OutputContractValidator.swift` (no call sites); `DataManager.exportGuide` → `ManuscriptGate.prepareForExport`
- **Why:** Teams following GOVERNANCE_LOCKS will believe invariants are enforced that are not (visual zone rules, narration-forbidden phrases). Ship risk: “compliant” exports that violate documented locks.
- **Remediation:** Either wire `OutputContractValidator` into ManuscriptGate, or rewrite locks to match ManuscriptGate and delete/archive the unused validator.

### 12. CI does not cover active feature branches; release still needs manual stub stripping
- **Severity:** P1
- **Category:** Testing / CI / release
- **Evidence:** `.github/workflows/ios-ci.yml` push triggers only `main` + `feature/chatgpt-voice-experimental`; `scripts/release-testflight.sh` deletes SPM-embedded `onnxruntime`/`SherpaOnnxC` dynamic stubs or App Store rejects (ITMS-90208)
- **Why:** Audio-optim/visuals branches rely on PR CI only; forgetting the release script = processing failure. High operational likelihood.
- **Remediation:** Add `cursor/**` (or all branches) to push triggers; encode stub-strip as a documented required step in Xcode Cloud / make CI archive smoke on Release.

### 13. Liam / “voice is fixed” copy contradicts live Pocket voice picker
- **Severity:** P1
- **Category:** UX / accessibility / copy leftovers
- **Evidence:** `GenerationView.swift` comment “voice is fixed (Liam)”; `LLMActionRouter` failures “Narration voice is fixed (Liam)…”; `SettingsView.audioStatus` returns `"Liam"` when Pocket not installed; `NarrationSupport.fallingBackToLiam`; `NarrationControlsView` maps `KokoroTTSClient.voice` → `"Liam"`; meanwhile Settings has full Pocket voice UI
- **Why:** Users and automation get told voice isn’t selectable while Settings offers selection. Offline-without-Pocket shows “Liam” instead of “Apple Voice”. Confusing and false.
- **Remediation:** Global rename pass: Liam → Pocket/Apple; fix LLMActionRouter to drive real voice APIs; default status string `"Apple Voice"` when Pocket missing.

### 14. ContentView comment claims light-mode lock; theme picker is live again
- **Severity:** P2
- **Category:** UX / dark mode / contradictory docs
- **Evidence:** `ContentView.swift` comment “Locked to light mode…” but applies `preferredColorScheme` from `PremiumTheme`; `ThemeSettingsView` exposes all themes; `FOLLOWUPS.md` still says Dark/System hidden and light lock retained
- **Why:** FOLLOWUPS and comment are stale; PDF paths correctly pin light, but on-screen adaptive tokens + theme picker can disagree with export atmosphere. Medium confusion, lower crash risk.
- **Remediation:** Delete stale comment/FOLLOWUPS; decide product stance (full dark vs light-only) and align ThemeSettingsView + PDF/HTML export pins.

### 15. Library search forces full-body scans on every keystroke
- **Severity:** P2
- **Category:** Performance / UX
- **Evidence:** `LibraryView.swift` filtered items include `summaryContent?.localizedCaseInsensitiveContains`
- **Why:** With finding #5, each search walks megabytes of guide text on main. Jank on large libraries.
- **Remediation:** Search metadata only, or maintain a lightweight search blob / Spotlight index.

### 16. Verbose `print` diagnostics in Release PDF/narration paths
- **Severity:** P2
- **Category:** Performance / security hygiene
- **Evidence:** Widespread `print("🖼️ [PDF Visual]…")` etc. in `PDFAnalysisDocument`, `InsightAtlasPDFRenderer`, `PDFContentBlockRenderer`, `NarrationScriptService`, `KokoroAudioService`, `BackgroundGenerationCoordinator`
- **Why:** Synchronous stdout on hot paths; can leak titles/content fragments into device logs. Likelihood high during export.
- **Remediation:** Gate with `#if DEBUG` or `Logger` with `.privacy`; keep a single opt-in `IA_PDF_TRACE` flag.

### 17. `InsightAtlasHTMLTemplate` dead; HTML lives inside DataManager instead
- **Severity:** P2
- **Category:** Visuals / HTML export / dead code
- **Evidence:** `InsightAtlasHTMLTemplate.swift` (no references); `DataManager.generatePremiumHTML` (~thousands of lines of CSS/HTML)
- **Why:** Two HTML design systems in repo; only the DataManager one ships. Drift guarantees style bugs when designers edit the wrong file.
- **Remediation:** Delete or wire the template; extract shipping HTML builder out of DataManager.

### 18. `generateAudioIfAvailable` is dead inside the coordinator
- **Severity:** P2
- **Category:** Narration / dead code
- **Evidence:** `BackgroundGenerationCoordinator.generateAudioIfAvailable` — definition only; comments say narration deferred to GenerationView
- **Why:** ~50+ lines of stale audio orchestration including “unavailable Liam route” comments invite reintroduction of blocking narration (# historical 100%-stuck bug).
- **Remediation:** Delete method and helpers only used by it; keep GenerationView’s post-complete narration.

### 19. Placeholder support / App Store URLs ship in Settings
- **Severity:** P2
- **Category:** UX / release readiness
- **Evidence:** `SettingsView` + `LLMActionRouter` → `mailto:support@example.com`, `itms-apps://…/id000000000`
- **Why:** Tap targets look real; fail silently or open junk. Blocks App Store polish.
- **Remediation:** Real support email + App Store ID, or hide rows until configured via Info.plist keys.

### 20. `UIStatusBarHidden = true` globally
- **Severity:** P2
- **Category:** UX / accessibility
- **Evidence:** `InsightAtlas/Info.plist` `UIStatusBarHidden`
- **Why:** Hides time/battery/network during long generation and narration. Accessibility and trust hit.
- **Remediation:** Prefer per-screen control or default visible; hide only for immersive reader if desired.

### 21. MiniMax signed-in detection inconsistent (access vs refresh)
- **Severity:** P2
- **Category:** Networking / auth
- **Evidence:** `MiniMaxOAuthService.hasStoredCredentials` checks access token only; `NarrationScriptService.isMiniMaxAvailable` accepts access **or** refresh
- **Why:** Edge case after partial keychain clear / expiry write failure: script service thinks MiniMax is available, generation gate disagrees (or vice versa).
- **Remediation:** Single helper: signed-in iff refresh present (or access valid OR refresh present); use everywhere.

### 22. Visual cache filenames truncate to 64 chars of base64 URL
- **Severity:** P2
- **Category:** Visuals / reliability
- **Evidence:** `VisualAssetCache.localURL` `.prefix(64)` of base64(url)
- **Why:** Collision risk across long similar CDN URLs; wrong image in PDF. Lower likelihood, nasty when it hits.
- **Remediation:** Use full SHA256 hex of URL string as filename.

### 23. No Privacy Manifest (`.xcprivacy`) in tree
- **Severity:** P2
- **Category:** Security / App Store compliance
- **Evidence:** No `PrivacyInfo.xcprivacy` under repo; `ITSAppUsesNonExemptEncryption = false` only
- **Why:** Required declarations for UserDefaults, file timestamps, network vary by dependency (onnxruntime/sherpa). Missing manifest → App Store warnings/rejection risk.
- **Remediation:** Add privacy manifest covering required reason APIs used by app + SPM deps; verify archive contents.

### 24. Repo carries large sample HTML/PDF binaries + orphan `pnpm-lock.yaml`
- **Severity:** P2
- **Category:** Dead artifacts / repo hygiene
- **Evidence:** Root `*.html`, `Strong Ground…pdf`, `Exceed Expectations…pdf` (~3MB+); `pnpm-lock.yaml` with no Node package
- **Why:** Inflates clone, confuses “source of truth” for HTML design, unrelated lockfile.
- **Remediation:** Move samples to Releases or `docs/fixtures/` with LFS; delete `pnpm-lock.yaml`.

### 25. README / architecture docs describe retired OpenAI + nonexistent services
- **Severity:** P2
- **Category:** Contradictory docs
- **Evidence:** `README.md` (OpenAI keys, `LibraryService`/`SettingsService`/`ExportService`); `docs/KOKORO_OFFLINE_NARRATION.md` fallback order still lists Mega Transcript / OpenAI / Liam; `GOVERNANCE_LOCKS.md` cites `ElevenLabsAudioService`
- **Why:** Onboarding and audits follow fiction. Wastes engineering time; mis-sets security expectations.
- **Remediation:** Rewrite README to MiniMax/Claude/OpenRouter + Pocket/Apple; delete or archive ChatGPT/ElevenLabs plans that are not in tree.

### 26. Test suite skew: strong PDF/Kokoro, weak app shell / persistence / OAuth
- **Severity:** P2
- **Category:** Testing gaps
- **Evidence:** ~38 test files; heavy PDF/Kokoro/governor coverage; thin/no tests for `BackgroundGenerationCoordinator`, `DataManager` dual-settings, MiniMax OAuth refresh, ContentView navigation, export ManuscriptGate integration, Regenerate source-text invariant
- **Why:** Regressions in #1–#3 would not fail CI today.
- **Remediation:** Add focused unit tests for settings single-source, regenerate-requires-source, ManuscriptGate-on-all-formats, OAuth credential helpers; keep live Pocket tests skipped without model.

### 27. `ChatGPTVoiceProviderTests.swift` name/legacy while provider is gone
- **Severity:** P3
- **Category:** Testing / dead naming
- **Evidence:** `InsightAtlasTests/ChatGPTVoiceProviderTests.swift` (asserts Pocket display names / provider enums)
- **Why:** Misleading; hides that ChatGPT voice was removed.
- **Remediation:** Rename to `VoiceProviderTests`.

### 28. Background generation stores book text in Caches without explicit TTL scrub beyond clear
- **Severity:** P2
- **Category:** Persistence / privacy
- **Evidence:** `BackgroundGenerationCoordinator.bookTextStorageURL` under Caches; cleared in `clearPersistedState` but Interrupted/failed paths may leave files until manual clear
- **Why:** Full book plaintext on disk after failed runs. Privacy + storage.
- **Remediation:** Always delete book-text file when leaving processing; periodic orphan scrub on launch.

### 29. AppEnvironment constructs a second world vs singletons
- **Severity:** P2
- **Category:** App entry / architecture
- **Evidence:** `InsightAtlasApp` `@StateObject private var environment = AppEnvironment()` (not `.shared`); many services still `DataManager.shared` / `BackgroundGenerationCoordinator.shared` / `NarrationService.shared`
- **Why:** `AppEnvironment.shared` exists for previews but production uses a different instance; settings live on the StateObject while library ops often hit DataManager.shared’s settings copy (#2).
- **Remediation:** Either fully DI from the StateObject or make AppEnvironment a pure facade over singletons — pick one.

### 30. On-device insight spike UI still reachable from GuideView
- **Severity:** P3
- **Category:** UX / dead-or-spike code
- **Evidence:** `OnDeviceInsightPreviewView.swift` marked “SPIKE / PROTOTYPE”; embedded from `GuideView.swift`
- **Why:** Prototype copy and 4k-token caveats can surface in production reader chrome.
- **Remediation:** Feature-flag or remove from shipping GuideView until productized.

### 31. LLM automation layer blocks real voice controls
- **Severity:** P2
- **Category:** UX / automation
- **Evidence:** `LLMActionRouter` / `LLMUIRegistry` still encode fixed-Liam semantics for voice rows
- **Why:** UI-driver / agent automation cannot change Pocket voice or provider though UI can — automation tests lie.
- **Remediation:** Align router with Settings voice APIs; update registry labels.

### 32. `AudioVisualBridge` / governance Lock 3 not clearly enforced on MiniMax script path
- **Severity:** P2
- **Category:** Narration / editorial integrity
- **Evidence:** `Editorial/AudioVisualBridge.swift` + GOVERNANCE_LOCKS Lock 3; `NarrationScriptService` relies on MiniMax prompt rewrite + `NarrationListeningEdition` sanitizer — no explicit forbidden-phrase gate on spoken script before TTS
- **Why:** Listener may hear “as you can see in the diagram…” defeating audio-visual policy.
- **Remediation:** Run bridge forbidden-pattern scrub (or OutputContract narration checks) on script before cache/speak.

### 33. Default generation settings are Deep Research + auto-audio on
- **Severity:** P3
- **Category:** UX / cost / performance
- **Evidence:** `UserSettings` defaults: `preferredMode = .deepResearch`, `preferredSummaryType = .deepResearch`, `autoGenerateAudio = true`
- **Why:** First-run users burn max tokens + kick narration immediately. High cost/latency surprise.
- **Remediation:** Default to Professional/Standard; opt-in Deep Research and auto-audio.

### 34. Inter + Cormorant font bundle (design debt note)
- **Severity:** P3
- **Category:** UX
- **Evidence:** `Info.plist` `UIAppFonts` lists Inter-* and CormorantGaramond-*
- **Why:** Not a functional bug; Inter is a common “AI default” look. Only relevant if brand refresh is planned.
- **Remediation:** Keep if brand-locked; otherwise swap Inter for a distinctive UI sans already licensed.

### 35. `FOLLOWUPS.md` and `todo.md` claim resolved states that contradict tip
- **Severity:** P3
- **Category:** Contradictory docs
- **Evidence:** `FOLLOWUPS.md` light-mode lock; `todo.md` ChatGPT voice checklist still present; open TestFlight integrate items
- **Why:** Agents/humans follow stale checklists.
- **Remediation:** Archive completed follow-ups; regenerate a single living `STATUS.md` from tip.

### 36. Keychain migration marks complete even when Claude save fails
- **Severity:** P3
- **Category:** Security / persistence
- **Evidence:** `KeychainService.migrateFromUserDefaults` — on partial failure still sets `keychain_migration_completed` after loop; early invalid-format return does **not** set the flag (good), but save failure inside still proceeds to mark complete
- **Why:** Low likelihood now (one-time), but could drop a key once.
- **Remediation:** Only set completed when all non-empty keys saved successfully; otherwise retry next launch.

### 37. AnalysisDetailView / EditorialContentRenderer megaviews
- **Severity:** P3
- **Category:** Maintainability / performance risk
- **Evidence:** `AnalysisDetailView.swift` (~2894), `EditorialContentRenderer.swift` (~1577), `AnalysisComponents.swift` (~3758), `InsightVisuals.swift` (~2401)
- **Why:** Compile times and accidental main-thread work hide in noise; not a user bug yet.
- **Remediation:** Incremental extraction by block type; snapshot tests per block already exist — keep expanding those instead of more monolith.

### 38. Export progress API is cosmetic
- **Severity:** P3
- **Category:** UX
- **Evidence:** `DataManager.exportGuideAsync` jumps preparing → 0.5 → complete with no real percent
- **Why:** Long PDF exports look frozen aside from spinner.
- **Remediation:** Report prerender i/N and page layout progress from PDF renderer.

### 39. `InsightAtlasConfig.defaultModel = .anthropic` vs runtime MiniMax default
- **Severity:** P3
- **Category:** Config / dead contradiction
- **Evidence:** `Config/InsightAtlasConfig.swift`; `UserSettings` / `AIProvider` default `.minimax`
- **Why:** Config enum appears unused/out of sync — footgun for future call sites.
- **Remediation:** Align or delete InsightAtlasConfig defaults.

### 40. No automated check that release stub-strip still matches SPM layout
- **Severity:** P2
- **Category:** Release / reliability
- **Evidence:** `scripts/release-testflight.sh` hard-codes `STUBS=(onnxruntime SherpaOnnxC)`
- **Why:** sherpa-onnx upgrade can rename stubs → script no-ops → App Store rejection returns.
- **Remediation:** Script fails if `Frameworks/*.framework` remains with mismatched MinimumOSVersion; CI Release archive job asserts Frameworks empty or OK.

---

## Coverage map (subsystems → top findings)

| Subsystem | Finding IDs |
|-----------|-------------|
| App entry / nav / ContentView / library / settings | 2, 14, 19, 20, 29, 33 |
| Guide generation pipeline | 1, 9, 10, 28, 33, 39 |
| Narration / Pocket / Apple / MiniMax script | 3, 4, 13, 18, 21, 32 |
| Visuals / PDF / HTML | 7, 16, 17, 22, 38 |
| Persistence (DataManager, GuideBodyStore, Keychain) | 2, 5, 6, 8, 28, 36 |
| Networking / providers / auth | 8, 10, 21 |
| Performance | 4, 5, 7, 15, 16 |
| Reliability / concurrency | 6, 9, 12, 40 |
| UX / a11y / copy | 13, 14, 19, 20, 30, 31 |
| Security / secrets / export compliance | 8, 11, 23, 28 |
| Testing / CI / release | 12, 26, 27, 40 |
| Dead code / contradictory docs | 3, 17, 18, 24, 25, 35, 39 |

---

## Suggested fix order (effort-aware)

1. **Correctness:** #1 Regenerate source, #2 single settings store, #3 delete hosted Liam client  
2. **User-facing pain:** #4 narration fast path, #13 Liam copy purge, #19 support URLs  
3. **Stability:** #6 split DataManager / remove main.sync, #7 PDF prerender budget, #9 interrupted generation UX  
4. **Compliance/docs:** #11 governance vs ManuscriptGate, #23 privacy manifest, #25 README  
5. **Hardening:** #12/#40 CI+release, #26 tests for the P0/P1 invariants  

---

## Out of scope / not claimed

- No simulator/device run in this audit (Linux agent host).
- No measurement of actual jetsam rates or MiniMax production latency — severities for #4/#5/#7 use code structure + prior branch history (`todo.md` audio reliability notes).
