# InsightAtlas Feature Checklist

## ChatGPT Voice (Experimental)

- [x] Confirm direct GPT-Live WebSocket architecture and automatic fallback behavior.
- [x] Create isolated feature worktree and establish repository baseline.
- [x] Write and approve the feature design.
- [x] Write the detailed test-first implementation plan.
- [x] Add failing tests for provider defaults and fallback ordering.
- [x] Implement ChatGPT Voice provider modeling and backward-compatible settings.
- [x] Add failing tests for GPT-Live request/event protocol behavior.
- [x] Implement the pure GPT-Live protocol core.
- [x] Add failing tests for streaming orchestration and audio encoding.
- [x] Implement the OAuth WebSocket transport and PCM-to-M4A encoder.
- [x] Integrate ChatGPT Voice as primary narration with ordered fallbacks.
- [x] Update Settings, Generation, voice picker, and automated UI routing for three providers.
- [x] Add setup, risk, and smoke-testing documentation.
- [x] Run static verification in Linux.
- [x] Run or obtain evidence from an Apple-toolchain build and test run.
- [x] Complete security, reliability, and compatibility review.
- [x] Push the feature branch for installation and device testing.
- [ ] Complete the signed-in GPT-Live and stable-fallback smoke test on a physical iPhone.

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
- [ ] Complete independent code review
- [ ] Integrate and synchronize local and GitHub branches
- [ ] Assign the next unique TestFlight build number
- [ ] Archive, upload, and verify internal TestFlight availability
- [ ] Tag the accepted build and deliver release evidence
