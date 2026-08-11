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
