# Kokoro Offline Narration

Insight Atlas uses **Kokoro-82M** as its default narration provider. Speech is generated on the iPhone through the native `sherpa-onnx` runtime, so narration requires no voice API key, creates no per-use bill, and does not transmit narration text to a speech provider.[1] [2]

## Installation and Storage

Open **Settings → Audio & Narration → On-Device Voice Model**, then select **Download Kokoro Model**. The app downloads the official quantized Kokoro v1.0 package, verifies its exact byte count and SHA-256 digest, safely extracts only required English assets, and atomically installs the result under Application Support.

| Property | Value |
|---|---|
| Download | Approximately 126 MiB |
| Installed footprint | Approximately 182 MiB |
| Default voice | Heart (`af_heart`, speaker 3) |
| English voices | 28 American and British voices |
| Output | 24 kHz, mono, 16-bit PCM WAV |
| Network after installation | Not required for narration |
| Per-use charge | None |

The model can be removed at any time from the same settings screen. Removing it does not delete saved guides or previously generated narration files.

## Integrity and Extraction Safety

The production manifest permits only this model archive:

| Field | Verified Value |
|---|---|
| Version | `kokoro-int8-multi-lang-v1_0` |
| Archive bytes | `131839838` |
| SHA-256 | `75654a84864be26f345f020f4070c2c019e96dd1b7f9bf6e2ffd59efac6aa5a3` |
| Source | Official `sherpa-onnx` TTS model release |

The installer requires at least 450 MiB of available capacity before downloading. It rejects files with absolute paths, traversal components, unexpected archive roots, non-regular entry types, and paths outside the English asset allowlist. A previous valid installation remains in place until a replacement has passed all validation.

## Provider and Fallback Behavior

Kokoro is the default provider for new and migrated installations. An explicit OpenAI or ElevenLabs selection remains intact. When narration is generated, Insight Atlas tries the selected provider first, then available providers in this order: **Kokoro → OpenAI → ElevenLabs → ChatGPT Voice**. ChatGPT Voice remains available only as an experimental last fallback.

If no provider can generate audio, guide creation still completes without narration. A voice failure never discards the generated reading guide.

## Voice Selection

The full Kokoro v1.0 English catalog is available in Settings, the guide-generation screen, and the regeneration voice picker. Heart is the default because it was selected after a real local audition. Reader profiles influence only the suggested first voice; they do not alter or misrepresent the official model metadata.

## Troubleshooting

| Symptom | Recommended Action |
|---|---|
| Download fails | Confirm a stable connection and at least 450 MiB free, then select **Try Download Again**. |
| Integrity check fails | Retry. The rejected archive is deleted automatically and is never installed. |
| Preview is disabled | Complete the model download under Audio & Narration. |
| Model does not load | Remove the downloaded model, reinstall it, and retry the preview. |
| Device becomes warm during a long guide | Let generation finish in the foreground and avoid other compute-heavy tasks. |
| Audio is absent but the guide exists | Check model readiness or configure an optional cloud fallback. |

## Validation Status

The feature is compiled and tested by the project’s macOS GitHub Actions workflow. Unit tests cover provider ordering, legacy settings defaults, the 28-voice registry, manifest values, required installation assets, archive-path safety, and lossless narration chunking. A physical-iPhone smoke test is still required to measure real-device synthesis speed, peak memory, thermals, interruption behavior, and airplane-mode operation.

## References

[1]: https://huggingface.co/hexgrad/Kokoro-82M "Kokoro-82M model card"
[2]: https://github.com/k2-fsa/sherpa-onnx "sherpa-onnx"
[3]: https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models "Official sherpa-onnx TTS model assets"
