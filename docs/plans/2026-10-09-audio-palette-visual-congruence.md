# Audio, palette, and visual-contract congruence — 2026-10-09

Build `2026100901`. Three workstreams over the uncommitted theming/audio pass
that was sitting in the tree since 2026-09-21.

## 1. Audio generation — root cause and fix

**Narration could never work on any device.** `KokoroModelManifest.production`
declared `archiveByteCount: 131_839_838` and
`sha256: 75654a84…aa5a3`. The live GitHub release asset is **132,303,094 bytes
/ `4c3052abaa60943a341f193888cf6abd68787dae6ab8ae5c925a706caa247e4e`**
(measured 2026-10-09 with `curl` + `shasum -a 256`). `verifyArchive` gates on
exact size equality before hashing, so every install downloaded 126 MiB and
then threw `unexpectedArchiveSize` — `KokoroModelStore.isInstalled` was
permanently `false`, and because Kokoro was the only engine, every narration
attempt failed with "Download the Kokoro voice model in Settings", which could
never succeed.

The manifest values had never been edited since the feature landed, and
`KokoroModelManagerTests.testProductionManifestMatchesVerifiedOfficialArchive`
asserted the *same* wrong pair — test and code agreed with each other while
production failed. Both are corrected, and the test now carries the
re-measurement command so the next change is verified rather than copied.

Verified against the real archive: all seven `requiredRelativePaths` exist
(including `espeak-ng-data/phondata`), extraction is 186 MB, so peak need
(~312 MB with the archive) stays under the 450 MB capacity gate. There is no
second install blocker.

Also fixed:

- **A real fallback.** `VoiceProviderFallbackPlanner.orderedProviders` returned
  `[preferred]` or `[]` — it could not fall back despite backing a method named
  `generateAudioWithFallback`, which also tried only `providers[0]`. Both now
  walk every available provider in order.
- **Auto-narration gates.** `GenerationView` and
  `BackgroundGenerationCoordinator` hard-gated on `KokoroModelStore.isInstalled`,
  so background and post-generation narration stayed dead even with the Apple
  engine available. Both now test `VoiceProviderAvailability`.
- **Retry gates.** `NarrationControlViewModel.canRetry` was
  `KokoroModelStore.isInstalled`, so an Apple-engine failure offered no Retry.
- **Attempt-cap amnesty.** `maxAudioGenerationAttempts` is 3; guides that
  exhausted their retries against the broken install would have stayed
  un-narratable forever. `LibraryItem.init(from:)` resets the counter for items
  with no audio that had hit the cap.
- **Apple-voice render reliability.** `AVSpeechSynthesizer.write` emits no
  buffers for some premium voices, and the only continuation-resume path was the
  zero-length end-of-utterance buffer — so a silent voice hung the render until
  the 120 s outer stall timeout. `AppleVoiceCatalog.defaultVoice()` now prefers
  enhanced → standard → premium, and `AppleSpeechAudioService` has a 30 s
  per-chunk idle watchdog (`RenderWatchdogGate`) that fails with
  `noAudioProduced` instead of hanging.
- **Download integrity.** The download delegate moved whatever arrived into
  place, so a CDN error page became "the model" and surfaced as a checksum
  failure. It now rejects non-2xx responses with `invalidResponse` (previously
  declared but never thrown).
- Stale "Download Kokoro" copy replaced across Generation, Listen, Settings,
  and the stall error; Apple voice identifiers now resolve to display names;
  the Apple Voice picker materializes its effective default instead of
  rendering with nothing selected.

### Vois

Vois 2.4.1 is installed, licensed (`ltd_t2`, subscriber), and its CLI works —
`vois-cli tts generate` produced 24 kHz audio on the Pocket/Metal engine. It is
a **macOS desktop app driven by a local CLI**, with no iOS SDK and no hosted
API, so it cannot be the in-app narration engine. Not needed either: the
on-device path now works. It remains a viable route for Mac-rendered
studio-quality narration sideloaded into the library, which would be a new
feature rather than a fix.

## 2. Palette congruence

`PremiumUI.Hex` is the single source of values; `AnalysisTheme`,
`InsightAtlasColors`, `PDFStyleConfiguration`, and the export CSS all derive
from it.

- `UIColor.ia*` was made trait-adaptive by the earlier pass, and the legacy PDF
  path draws with it at 35 sites — a PDF generated in dark mode could print
  dark surfaces. Those are now pinned to light hexes; `PremiumUI.UI.*` stays
  adaptive for on-screen UIKit.
- `AccentColor` asset was still the two-generations-old `#E85D2D`; now
  `#C2431F` light / `#F07A55` dark.
- All 75 off-palette `rgba()` literals in the export CSS became
  `rgba(var(--…-rgb), α)` from new `PremiumUI.Hex.RGB` triplets, overridden in
  the dark block. Those tints were light-only, so dark-mode guides had
  ember-era headers on terracotta-era grounds inside one callout.
- Three different page grounds (`#FFFFFF` HTML, `#F5F4F1` app/PDF, `#FAFAFA`
  PDF zebra) aligned.
- HTML export discarded every visual title (`parse(title: nil)`); titles now
  pass through, matching reader and PDF.
- `emberMark` (3.17:1, fails AA) was backing text tokens; text aliases moved to
  `ember` (4.64:1 / 5.10:1 on card), which also fixes white-on-CTA contrast.
  Degenerate gradients left by the aliasing collapsed to solid fills.
- `PremiumAccent` offered four swatches that aliased to three identical colors;
  now Ember / Indigo / Celadon with backward-compatible decoding.
- Collapsed semantics re-separated: a real `dividerStrong` step for
  `borderMedium`, caution → `emberDeep`, notes/premium → `indigoDeep`,
  crimson/burgundy → `destructive`, Exercise distinguished from Takeaways.
- Library rows no longer pick an accent from `title.hashValue % 4`, which could
  tint a row with the destructive red.
- 11 stale colorsets deleted. New `PaletteCongruenceTests` pins print-pinning
  and RGB↔hex agreement — nothing pinned palette values before.

## 3. Making every renderable component known to the LLM

The prompt and the renderer had drifted apart in both directions.

- **Four payload contracts were broken**: the prompt's own examples for
  `VISUAL_INFOGRAPHIC`, `VISUAL_GAUGE`, `VISUAL_STORYBOARD`, and
  `VISUAL_NETWORK` could not parse — infographic/gauge rendered an empty grid,
  storyboard discarded the scene title, network swapped node id and label. All
  four now match the parser.
- **JSON payloads are now offered.** `parseJSON` already covered all 31 types
  and is tried first, but the prompt never mentioned it. It is now documented as
  preferred for data-rich visuals, with schema-accurate examples — this is the
  only way to reach quadrant/scatter axis labels, network edge type and
  strength, gantt status, and timeline descriptions.
- **Retired tags removed from the offer**: `VISUAL_RADAR` had no value channel
  (every bar drew at a fixed 60 pt) and `VISUAL_HIERARCHY` degraded to a bullet
  list in PDF. Parser support is kept for existing guides, recorded in
  `InsightVisualCoverageTests.retiredButStillParsedTags`.
- **Previously invisible capability documented**: `[PREMIUM_DIVIDER]` (which the
  validator *required* while the prompt never named it), `[CONCEPT_MAP: Title]`,
  `[PROCESS_TIMELINE: Title]`, and the fact that prose arrow chains
  `A → B → C` are auto-promoted to drawn steppers and `A ↔ B` to a spectrum.
- **Validator reconciled with the prompt.** `visualMarkers` was an 8-element
  whitelist, so 35 of the 43 accepted spellings counted nothing toward the
  ≥8-variety check — a perfectly compliant guide could fail. It is now derived
  from `InsightVisualType.allCases` + `tagAliases`. Checks the prompt never
  instructed (three named `[PREMIUM_H2]` sections, a literal "cross-book
  synthesis" phrase) were dropped; the quote and divider minimums were added to
  the prompt instead.
- **Contradictions resolved**: "max 1 visual per section" × 4–8 sections could
  not reach the "12–18 visuals" target; the absolute ban on bare markdown
  tables contradicted all three renderers parsing them fine.
- The narration prompt's per-type semantic taxonomy — the best one in the
  codebase — was ported into the generation prompt's selection heuristics.
- **Table column shift fixed.** Both table parsers filtered empty cells out of
  each row, left-shifting every cell after a blank one so values landed under
  the wrong header. Cells now keep their position (edge-pipe artifacts only are
  dropped), alignment rows like `|:---|---:|` are recognized, and
  `ComparisonTableView` keys cells by column index — `ForEach(row, id: \.self)`
  would have collapsed two blank (or two repeated) cells and dropped a column.

## Verification

- `xcodebuild build` clean, 0 errors.
- `xcodebuild test`: **433 tests, 0 failures**, 5 skipped.
- Kokoro manifest verified against the live asset over the network.

## Still open

- The optional MiniMax rewrite still runs before first synthesis
  (`NarrationPreparationPolicy.rewritesBeforeInitialSynthesis = true`), bounded
  at 75 s and reported in the UI, but outside `withStallDetection`. Left as-is:
  the most recent commit deliberately made MiniMax write bounded audio
  summaries. Revisit if a cold Listen tap feels slow on device.
- Physical-device validation of Kokoro install → generate → play → airplane
  mode remains outstanding (carried over from the Kokoro checklist).
- Dead code with zero call sites, left in place deliberately:
  `Theme/DesignSystem.swift`, `Services/InsightAtlasHTMLTemplate.swift`,
  `SemanticNormalizationService`, `OutputContractValidator`,
  `VisualSelectionService`, `VoicePickerSheet`, and the four duplicate block
  views. The thematic-synthesis prompt still has no visual vocabulary at all.
