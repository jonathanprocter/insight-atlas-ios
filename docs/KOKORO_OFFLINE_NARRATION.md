# Kokoro Offline Narration

Insight Atlas uses **Kokoro-82M** as its default narration provider. FluidAudio splits Kokoro into seven Core ML stages and places compatible work on Apple's Neural Engine. Narration remains on the iPhone or iPad, requires no speech API key, and has no per-use charge.

## Installation and Storage

Open **Settings → Audio & Narration → On-Device Voice Model**, then select **Download Kokoro Model**. Insight Atlas downloads the compiled Core ML stages, English G2P assets, vocabulary, and the 28 voice packs used by the existing voice picker. A successful full model load is required before the installation is marked ready.

The model is stored under Application Support rather than the purgeable cache directory. Removing it does not delete saved guides or previously generated narration.

## Performance Architecture

- Albert, PostAlbert, Alignment, Prosody, and Vocoder are routed to CPU plus Neural Engine.
- Noise and final iSTFT stages use FluidAudio's OS-appropriate stable placement.
- The model stays resident between narration chunks and is released when the service resets.
- Long guide narration remains losslessly chunked and is assembled into a 24 kHz mono PCM WAV.
- All 28 existing English voice IDs remain available; additional voice packs are preloaded during installation.

FluidAudio reports approximately 3–11× faster-than-real-time synthesis on Apple Silicon, depending on utterance length. Real performance depends on the device, OS, temperature, and narration structure.

## Provider and Fallback Behavior

Kokoro remains the default provider for new and migrated installations. An explicit OpenAI or ElevenLabs selection remains intact. When narration is generated, Insight Atlas tries the selected provider first, then available providers in this order: **Kokoro → OpenAI → ElevenLabs → ChatGPT Voice**.

If no provider can generate audio, guide creation still completes without narration. A voice failure never discards the generated reading guide.

## Troubleshooting

| Symptom | Recommended action |
|---|---|
| Download fails | Confirm a stable connection and sufficient free storage, then retry. |
| Model does not load | Remove the downloaded model, reinstall it, and retry the preview. |
| First generation is slower | The OS may be preparing Core ML assets; later warm generations should be faster. |
| Audio is absent but the guide exists | Check model readiness or configure an optional cloud fallback. |
| Intel simulator link fails | FluidAudio's text-normalization binary is arm64-only; use an Apple Silicon simulator or physical device. |

## Validation

The arm64 iOS Simulator build compiles and links the complete FluidAudio integration. Unit tests cover provider routing, cancellation, the 28-voice registry, completed-installation validation, and lossless narration chunking. A physical-iPhone/iPad smoke test remains required to record real-device latency, peak memory, thermals, interruption behavior, and airplane-mode operation.

## References

- [FluidAudio](https://github.com/FluidInference/FluidAudio)
- [FluidAudio Kokoro ANE documentation](https://github.com/FluidInference/FluidAudio/blob/main/Documentation/TTS/KokoroAne.md)
- [Kokoro-82M model card](https://huggingface.co/hexgrad/Kokoro-82M)
