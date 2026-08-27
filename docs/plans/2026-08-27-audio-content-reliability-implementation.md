# InsightAtlas Audio and Content Reliability Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove avoidable Daniel startup latency, prevent invalid audio from being persisted or played, suppress the known-dead hosted Liam route, and make malformed Reader Edition markup render safely in existing and newly generated guides.

**Architecture:** Keep MiniMax M3 and narration as distinct product responsibilities: M3 generates written guides, while installed Kokoro voices synthesize audio locally. Introduce pure policies for provider availability, narration preparation, audio-session configuration, asset validation, and editorial-tag canonicalization so every observed failure has deterministic tests. Apply editorial canonicalization before persistence and again at renderer entry for backward compatibility.

**Tech Stack:** Swift 6, SwiftUI, AVFoundation, AVAudioSession, AVAsset, sherpa-onnx Kokoro, XCTest, Xcode build/test/analyze, App Store Connect API-key release automation.

---

## Task 1: Canonicalize malformed editorial markup

**Files:**
- Create: `InsightAtlas/Services/EditorialMarkupCanonicalizer.swift`
- Modify: `InsightAtlas/Services/BackgroundGenerationCoordinator.swift`
- Modify: `InsightAtlas/Views/EditorialContentRenderer.swift`
- Modify: `InsightAtlas/Views/EditorialBlockViews.swift`
- Test: `InsightAtlasTests/EditorialParserTests.swift`
- Test: `InsightAtlasTests/MarkdownRenderingTests.swift`

**Step 1: Write failing tests.** Add the exact user-observed fixture with `[/INSIGHT_NOTE][PREMIUM_H1]`, an unclosed premium heading followed by `[FOUNDATIONAL_NARRATIVE]`, and italic phrases such as `*liking*`. Assert that adjacent tags are split, no bracket token is emitted as visible text, the premium heading does not absorb the narrative block, and emphasis markers do not survive the plain-text projection.

**Step 2: Run focused tests and confirm the expected failures.**

```bash
xcodebuild test -project InsightAtlas.xcodeproj -scheme InsightAtlas \
  -destination 'platform=iOS Simulator,id=633642CF-83BA-4CB0-A9A2-99CD7F8668A9' \
  -only-testing:InsightAtlasTests/EditorialParserTests \
  -only-testing:InsightAtlasTests/MarkdownRenderingTests \
  -disableAutomaticPackageResolution
```

**Step 3: Implement the minimal canonicalizer.** Separate every adjacent opening and closing editorial tag onto its own line, normalize tag-boundary whitespace, and preserve prose. At parser entry, terminate a malformed premium header when another recognized editorial tag begins. Do not invent missing prose or reorder blocks.

**Step 4: Apply both boundaries.** Canonicalize generated content before quality checks and persistence. Canonicalize again inside `EditorialContentRenderer` so already-saved malformed guides repair themselves after app update.

**Step 5: Run the focused tests and commit.**

## Task 2: Make MiniMax and narration responsibilities explicit

**Files:**
- Create: `InsightAtlas/Services/NarrationPreparationPolicy.swift`
- Modify: `InsightAtlas/Services/NarrationService.swift`
- Modify: `InsightAtlas/Views/GenerationView.swift`
- Modify: `InsightAtlas/Views/NarrationControlsView.swift`
- Test: `InsightAtlasTests/KokoroNarrationTests.swift`
- Test: `InsightAtlasTests/AIProviderRoutingTests.swift`

**Step 1: Write failing tests.** Assert that MiniMax M3 is classified as a text-only guide provider, optional LLM rewriting is not on the first-time narration critical path, and a configured-but-known-unavailable hosted endpoint is excluded from automatic fallback.

**Step 2: Run the focused tests and confirm they fail for missing policy APIs.**

**Step 3: Implement the minimal preparation policy.** Sanitize the completed guide deterministically and begin Kokoro preparation immediately. Retain `NarrationScriptService` only as an optional future enhancement or cached input source; do not wait up to 75 seconds before first synthesis.

**Step 4: Correct the UI.** Label MiniMax M3 as the written-guide provider, identify Daniel as an on-device Kokoro voice, and replace the obsolete provider-order copy with the active local route. Do not imply MiniMax M3 generates audio.

**Step 5: Run tests and commit.**

## Task 3: Remove the dead hosted fallback and improve actionable recovery

**Files:**
- Modify: `InsightAtlas/Services/NarrationService.swift`
- Modify: `InsightAtlas/Views/NarrationControlsView.swift`
- Test: `InsightAtlasTests/KokoroNarrationTests.swift`

**Step 1: Write failing tests.** Assert that the automatic route list contains installed on-device Kokoro only and never calls Liam while its production endpoint is classified unavailable. Assert that a local failure produces a clean message that offers retry or another installed voice rather than surfacing HTTP 530.

**Step 2: Verify the tests fail against the current `Kokoro → Liam` policy.**

**Step 3: Implement the minimal route and error policy.** Keep the existing hosted client for future restoration, but remove it from the automatic release path. Preserve last known-good audio until a replacement passes validation.

**Step 4: Run tests and commit.**

## Task 4: Validate audio before persistence and configure playback safely

**Files:**
- Create: `InsightAtlas/Services/NarrationAudioValidation.swift`
- Modify: `InsightAtlas/Services/NarrationService.swift`
- Modify: `InsightAtlas/Services/NarrationSupport.swift`
- Test: `InsightAtlasTests/KokoroNarrationTests.swift`
- Test: `InsightAtlasTests/KokoroLiveSynthesisTests.swift`

**Step 1: Write failing tests.** Assert that playback session mode is `.default`, that playback options do not contain `.allowBluetooth` or recording-only routes, that empty/unknown containers cannot be promoted, and that a real Daniel WAV has a playable audio track and positive duration.

**Step 2: Run tests and confirm failures.**

**Step 3: Implement validation.** Stage generated bytes, validate container signature, positive declared duration, AVAsset playability, at least one audio track, and positive loaded duration, then atomically promote. On validation failure, delete only the staged file and retain prior audio.

**Step 4: Implement playback policy.** Configure `AVAudioSession` with `.playback`, `.default`, and no incompatible Bluetooth option. Map AVFoundation/OSStatus failures to a clear regeneration message; never expose `OSStatus error -50` to the user.

**Step 5: Run tests and commit.**

## Task 5: Reduce Daniel synthesis time without unsafe truncation

**Files:**
- Modify: `InsightAtlas/Services/KokoroTextChunker.swift`
- Modify: `InsightAtlas/Services/KokoroAudioService.swift`
- Test: `InsightAtlasTests/KokoroNarrationTests.swift`
- Test: `InsightAtlasTests/KokoroLiveSynthesisTests.swift`

**Step 1: Add benchmark-backed failing tests.** Require a multi-paragraph Daniel fixture to preserve every word, use fewer chunks under the candidate ceiling, generate a valid WAV, initialize an audio player, prepare successfully, and report positive duration.

**Step 2: Benchmark the production model at the current 900-character ceiling and conservative larger candidates.** Select the largest ceiling that improves wall time without reducing playability or sentence-boundary quality. Do not increase memory concurrency or load duplicate models on iPhone.

**Step 3: Implement only the evidence-supported chunk change.** Keep serial inference, progress heartbeat, cancellation, and atomic writing intact.

**Step 4: Run live production-model tests and commit.**

## Task 6: Verify setting combinations and full release health

**Files:**
- Modify: `InsightAtlasTests/GuideGenerationContractTests.swift` or the existing equivalent
- Modify: `InsightAtlasTests/MarkdownRenderingTests.swift`
- Modify: `InsightAtlasTests/PDFOutputHygieneTests.swift`
- Create: `docs/plans/2026-08-27-audio-content-reliability-verification.md`

**Step 1: Add fixtures for MiniMax/Claude/OpenRouter, Standard/Deep Research, both writing styles, all output formats, and every summary length.** Assert that reader-bound content cannot expose editorial tokens or unsupported Markdown regardless of setting combination.

**Step 2: Run targeted tests, then the full signed suite.**

**Step 3: Run the real Kokoro suite with the verified production model, including Daniel multi-chunk playability.**

**Step 4: Run Debug, generic-device Release, static analysis, and strict-concurrency compilation.**

**Step 5: Launch representative malformed and narration fixtures on iPhone and iPad simulators and preserve screenshots.**

**Step 6: Complete independent review and address all Critical or Important findings.**

## Task 7: Integrate and release to TestFlight

**Files:**
- Modify: `InsightAtlas.xcodeproj/project.pbxproj`
- Use: `scripts/release-testflight.sh`

**Step 1: Fast-forward the authoritative branch to the reviewed feature branch and rerun core checks on the exact merged commit.**

**Step 2: Synchronize `main` and the authoritative release branch with GitHub without rewriting history.**

**Step 3: Query App Store Connect and assign the next unused date-based build number.** Preserve `ITSAppUsesNonExemptEncryption = NO` if already configured; otherwise add it to both app configurations.

**Step 4: Archive and upload with the secured App Store Connect API key.**

**Step 5: Wait until Apple reports `VALID`, resolve export compliance if required, assign the build to the internal Testing group, verify the user’s tester relationship, and tag the exact uploaded source commit.

**Step 6: Deliver a before/after release report, screenshots, GitHub revision, immutable tag, TestFlight status, and consolidated evidence archive.
