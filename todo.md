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
- [ ] Add failing tests for Kokoro provider defaults, registry, fallbacks, and legacy settings.
- [ ] Add failing tests for model manifest, installation validation, and archive path safety.
- [ ] Add failing tests for narration chunking and voice-to-speaker resolution.
- [ ] Add and pin sherpa-onnx and SWCompression Swift packages.
- [ ] Implement the Kokoro voice registry and provider routing.
- [ ] Implement the secure model download, verification, extraction, deletion, and progress manager.
- [ ] Implement actor-isolated Kokoro synthesis and WAV output.
- [ ] Add the model-install and Kokoro voice-selection user interface.
- [ ] Wire Kokoro into background narration, caching, and stable fallbacks.
- [ ] Add third-party notices, setup documentation, and troubleshooting guidance.
- [ ] Run static checks and the full macOS CI build/test suite.
- [ ] Validate install, generation, playback, deletion, and airplane-mode use on a physical iPhone.
