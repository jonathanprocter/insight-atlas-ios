# InsightAtlas Feature Checklist

## ChatGPT Voice / GPT-Live / Liam (REMOVED — historical)

> **Status: REMOVED / historical.** ChatGPT Voice, GPT-Live WebSocket narration, and hosted Liam TTS are no longer part of the product. Checklist items below are retained only as an archive of past work; do not resume them. Remaining live work is tracked in `docs/STATUS.md`.

- [x] Confirm direct GPT-Live WebSocket architecture and automatic fallback behavior. *(historical)*
- [x] Create isolated feature worktree and establish repository baseline. *(historical)*
- [x] Write and approve the feature design. *(historical)*
- [x] Write the detailed test-first implementation plan. *(historical)*
- [x] Add failing tests for provider defaults and fallback ordering. *(historical)*
- [x] Implement ChatGPT Voice provider modeling and backward-compatible settings. *(historical)*
- [x] Add failing tests for GPT-Live request/event protocol behavior. *(historical)*
- [x] Implement the pure GPT-Live protocol core. *(historical)*
- [x] Add failing tests for streaming orchestration and audio encoding. *(historical)*
- [x] Implement the OAuth WebSocket transport and PCM-to-M4A encoder. *(historical)*
- [x] Integrate ChatGPT Voice as primary narration with ordered fallbacks. *(historical)*
- [x] Update Settings, Generation, voice picker, and automated UI routing for three providers. *(historical)*
- [x] Add setup, risk, and smoke-testing documentation. *(historical)*
- [x] Run static verification in Linux. *(historical)*
- [x] Run or obtain evidence from an Apple-toolchain build and test run. *(historical)*
- [x] Complete security, reliability, and compatibility review. *(historical)*
- [x] Push the feature branch for installation and device testing. *(historical)*
- [x] ~~Complete the signed-in GPT-Live and stable-fallback smoke test on a physical iPhone.~~ **REMOVED — not applicable**

## Kokoro Offline Narration

- [x] Audit the current provider, generation, settings, and Xcode dependency architecture.
- [x] Verify the approved Kokoro voice, official model package, checksum, size, and native Swift runtime.
- [x] Create the isolated feature worktree and implementation plan.
- [x] Add failing tests for Kokoro provider defaults, registry, fallbacks, and legacy settings.
- [x] Add failing tests for model manifest, installation validation, and archive path safety.
- [x] Add failing tests for narration chunking and voice-to-speaker resolution.
- [x] Add and pin sherpa-onnx and SWCompression Swift packages.
- [x] Implement the Kokoro voice registry and provider routing.
- [x] Implement the secure model download, verification, extraction, deletion, and progress manager.
- [x] Implement actor-isolated Kokoro synthesis and WAV output.
- [x] Add the model-install and Kokoro voice-selection user interface.
- [x] Wire Kokoro into background narration, caching, and stable fallbacks.
- [x] Add third-party notices, setup documentation, and troubleshooting guidance.
- [x] Run static checks, independent review, and the full macOS CI build/test suite (201 tests, 0 failures).
- [ ] Validate install, generation, playback, deletion, and airplane-mode use on a physical iPhone.

## Audio and Content Reliability Release

- [x] Reconcile local, GitHub, archive, and TestFlight baseline
- [x] Preserve the user-reported screenshot evidence without reopening attachments
- [x] Verify MiniMax M3 is text-only and MiniMax Speech is a separate product
- [x] Reproduce the hosted Liam HTTP 530 / Cloudflare 1033 outage
- [x] Trace Daniel startup latency, Kokoro synthesis, persistence, and OSStatus -50 playback
- [x] Trace adjacent editorial tags and malformed header absorption in the reader
- [x] Document the release design and implementation plan
- [x] Add and verify failing editorial canonicalization and legacy-reader tests
- [x] Add and verify failing narration critical-path and provider-route tests
- [x] Add and verify failing audio-session, staged-asset, and error-mapping tests
- [x] Implement canonical editorial normalization before persistence and at render time
- [x] Remove optional full-guide LLM rewriting from first-time narration startup
- [x] Remove the unavailable hosted Liam route from automatic fallback
- [x] Validate staged audio before replacing a prior asset
- [x] Configure playback without incompatible Bluetooth options and map raw OSStatus errors
- [x] Benchmark and implement an evidence-supported Kokoro chunk-size improvement
- [x] Verify every guide-generation setting family against reader syntax leakage
- [x] Run targeted, full-suite, live-production-model, Release, analyzer, and strict-concurrency checks
- [x] Complete iPhone and iPad visual verification
- [x] Complete independent code review
- [x] Restore audio fast-path after MiniMax rewrite regression (policy gate + background cache warm)
- [x] Cache rewrite failures so retries do not re-pay the 75s deadline
- [x] Fix INFOGRAPHIC/GAUGE prompt payload parsing and stop empty typed cards
- [x] Route tagged SPECTRUM / HIERARCHY / LINE/AREA to native PDF diagram blocks
- [x] Unify visual tag canonicalize across reader, PDF, and HTML
- [ ] Integrate and synchronize local and GitHub branches
- [ ] Assign the next unique TestFlight build number
- [ ] Archive, upload, and verify internal TestFlight availability
- [ ] Tag the accepted build and deliver release evidence

> For current tip status (MiniMax generation + Pocket/Apple narration, audit PR #9 follow-ups), see **`docs/STATUS.md`**.
