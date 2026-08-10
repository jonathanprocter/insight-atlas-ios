# InsightAtlas Feature Checklist

## ChatGPT Voice (Experimental)

- [x] Confirm direct GPT-Live WebSocket architecture and automatic fallback behavior.
- [x] Create isolated feature worktree and establish repository baseline.
- [x] Write and approve the feature design.
- [x] Write the detailed test-first implementation plan.
- [ ] Add failing tests for provider defaults and fallback ordering.
- [ ] Implement ChatGPT Voice provider modeling and backward-compatible settings.
- [ ] Add failing tests for GPT-Live request/event protocol behavior.
- [ ] Implement the pure GPT-Live protocol core.
- [ ] Add failing tests for streaming orchestration and audio encoding.
- [ ] Implement the OAuth WebSocket transport and PCM-to-M4A encoder.
- [ ] Integrate ChatGPT Voice as primary narration with ordered fallbacks.
- [ ] Update Settings, Generation, voice picker, and automated UI routing for three providers.
- [ ] Add setup, risk, and smoke-testing documentation.
- [ ] Run static verification in Linux.
- [ ] Run or obtain evidence from an Apple-toolchain build and test run.
- [ ] Complete security, reliability, and compatibility review.
- [ ] Push the feature branch for installation and device testing.
