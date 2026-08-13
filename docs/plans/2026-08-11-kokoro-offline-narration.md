# Kokoro Offline Narration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Kokoro-82M the default, premium-sounding offline narrator in Insight Atlas while preserving explicit user choice, cloud fallbacks, and safe recovery when the model is unavailable.

**Architecture:** The app will add a `.kokoro` provider backed by the native `sherpa-onnx` Swift package. A model manager will download the official quantized Kokoro v1.0 archive only after user consent, verify its SHA-256 checksum, extract required assets into Application Support, and publish install progress to Settings. A dedicated synthesis actor will lazily load the model, generate speech off the main actor, stream chunks into one WAV file, and return the existing `GeneratedAudio` contract.

**Tech Stack:** Swift 5.9, SwiftUI, AVFoundation, CryptoKit, `sherpa-onnx` 1.13.4, `SWCompression` 4.9.1, XCTest, GitHub Actions on macOS 15.

---

## Confirmed Design Decisions

| Decision | Selection | Reason |
|---|---|---|
| Model | `kokoro-int8-multi-lang-v1_0` | It contains the approved `af_heart` voice and 28 English voices while using a smaller quantized model. |
| Model delivery | Explicit one-time download in Settings | A 126 MiB cellular download must not occur without user consent. |
| Default provider | Kokoro | New and migrated ChatGPT-default installations point to the free local provider. Explicit OpenAI or ElevenLabs selections remain respected. |
| Default voice | `af_heart`, speaker ID 3 | This is the exact voice the user approved in the audition sample. |
| Output format | WAV | It is natively writable from 24 kHz mono samples, universally playable by AVFoundation, and avoids a fragile transcode step in the first release. |
| Fallback order | Preferred provider, then Kokoro, OpenAI, ElevenLabs, ChatGPT Voice | The chosen provider is respected; Kokoro is the default and first stable fallback; the private ChatGPT route becomes last and experimental. |
| Runtime isolation | Actor-owned `SherpaOnnxOfflineTtsWrapper` | The native wrapper remains serialized and off the main actor. |
| Download integrity | Size check plus SHA-256 | Corrupt or substituted model archives are rejected before extraction. |
| Extraction safety | Required-file allowlist plus normalized relative-path policy | Prevents path traversal and avoids retaining unused Chinese dictionaries and FST files. |

## Model Manifest

| Field | Value |
|---|---|
| URL | `https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-int8-multi-lang-v1_0.tar.bz2` |
| Archive bytes | `131839838` |
| SHA-256 | `75654a84864be26f345f020f4070c2c019e96dd1b7f9bf6e2ffd59efac6aa5a3` |
| Expanded footprint | Approximately 182 MiB |
| Required assets | `model.int8.onnx`, `voices.bin`, `tokens.txt`, `lexicon-us-en.txt`, `lexicon-gb-en.txt`, `espeak-ng-data/**`, `LICENSE` |
| Install directory | `Application Support/Models/Kokoro/kokoro-int8-multi-lang-v1_0/` |

## Task 1: Add Provider and Registry Tests

**Files:**

- Modify: `InsightAtlasTests/ChatGPTVoiceProviderTests.swift`
- Create: `InsightAtlasTests/KokoroVoiceRegistryTests.swift`
- Later modify: `InsightAtlas/Services/VoiceProvider.swift`
- Later create: `InsightAtlas/Editorial/KokoroVoiceRegistry.swift`

**Step 1:** Replace the old ChatGPT-primary expectations with failing assertions that `.kokoro` is the first case, has display name `Kokoro (On-Device)`, does not require an API key, defaults to `af_heart`, and uses `wav`.

**Step 2:** Add failing tests showing that new settings and settings decoded without `voiceProvider` default to `.kokoro`.

**Step 3:** Add fallback tests for these behaviors: preferred and available provider remains first; unavailable preferred provider is omitted; Kokoro follows a selected cloud provider; ChatGPT Voice is last; duplicates are removed.

**Step 4:** Add registry tests proving that `af_heart` maps to speaker ID 3, all voice IDs and speaker IDs are unique, exactly 28 English voices are exposed, and every returned voice reports provider `.kokoro`.

**Step 5:** Run the macOS test workflow before production changes and confirm the new tests fail because `.kokoro` and the registry do not exist.

## Task 2: Add Model-Lifecycle Tests

**Files:**

- Create: `InsightAtlasTests/KokoroModelManagerTests.swift`
- Later create: `InsightAtlas/Services/KokoroModelManager.swift`

**Step 1:** Add tests using a temporary directory to prove an empty directory is not installed, a directory containing every required asset is installed, and any missing required asset makes installation invalid.

**Step 2:** Add pure path-policy tests that accept required files below the expected archive root and reject absolute paths, `..` traversal, unrelated roots, symlinks, and non-allowlisted files.

**Step 3:** Add manifest tests for the canonical URL, byte count, checksum, version, and minimum free-space requirement.

**Step 4:** Run the macOS test workflow and confirm these tests fail because model lifecycle types do not exist.

## Task 3: Add Text and WAV Pipeline Tests

**Files:**

- Create: `InsightAtlasTests/KokoroTextChunkerTests.swift`
- Later create: `InsightAtlas/Services/KokoroAudioService.swift`

**Step 1:** Test that short narration remains one chunk, long narration splits near sentence boundaries, no chunk exceeds the configured limit, whitespace-only input produces no chunks, and concatenating chunks preserves every non-whitespace word.

**Step 2:** Test the pure voice-ID-to-speaker-ID resolver and invalid-voice rejection.

**Step 3:** Keep native inference and AVFoundation file writing behind small interfaces so unit tests exercise pure decisions while CI compilation validates the Apple implementation.

## Task 4: Add Stable Swift Package Dependencies

**Files:**

- Modify: `InsightAtlas.xcodeproj/project.pbxproj`
- Modify: `InsightAtlas.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

**Step 1:** Add exact SwiftPM dependency `https://github.com/k2-fsa/sherpa-onnx` version `1.13.4` and product `sherpa-onnx` to the app target.

**Step 2:** Add exact SwiftPM dependency `https://github.com/tsolomko/SWCompression.git` version `4.9.1` and product `SWCompression` to the app target.

**Step 3:** Add new production and test source files to the corresponding Xcode build phases.

**Step 4:** Resolve packages in macOS CI and commit the resulting deterministic `Package.resolved` revisions.

## Task 5: Implement the Kokoro Voice Registry

**Files:**

- Create: `InsightAtlas/Editorial/KokoroVoiceRegistry.swift`
- Modify: `InsightAtlas/Services/VoiceProvider.swift`
- Modify: `InsightAtlas/Models/GuideModels.swift`

**Step 1:** Define `KokoroVoice: UnifiedVoice` with `voiceID`, display name, description, accent, presentation, and integer `speakerID`.

**Step 2:** Register all 28 English voices from the official v1.0 speaker map. Set Heart (`af_heart`, speaker 3) as the default and provide profile recommendations without inventing undocumented voice capabilities.

**Step 3:** Add `.kokoro` to `VoiceProvider` first, including display copy, `requiresSeparateApiKey = false`, WAV extension, default voice, and configuration check through the model store.

**Step 4:** Change `UserSettings` initializer and backward-compatible decoder defaults to `.kokoro`.

**Step 5:** Run tests and confirm provider and registry tests pass.

## Task 6: Implement the Secure Model Manager

**Files:**

- Create: `InsightAtlas/Services/KokoroModelManager.swift`
- Modify: `InsightAtlas/Services/AppEnvironment.swift`

**Step 1:** Define `KokoroModelManifest`, `KokoroModelPaths`, `KokoroModelInstallState`, and a pure installation validator.

**Step 2:** Implement `@MainActor KokoroModelManager: ObservableObject` with `install()`, `cancelInstall()`, `deleteModel()`, `refreshState()`, and published progress/state.

**Step 3:** Download with `URLSession.download(from:delegate:)` or an equivalent progress-reporting session into a temporary file. Require at least 450 MiB available capacity before starting.

**Step 4:** Stream the archive file through CryptoKit SHA-256 in bounded chunks, verify exact expected size and digest, then load/decompress only after integrity passes.

**Step 5:** Use `BZip2.decompress(data:)` and `TarContainer.open(container:)`. Normalize every entry path, apply the required-file allowlist, reject links and unsafe paths, write to a temporary install directory, validate all required assets, and atomically replace the active directory.

**Step 6:** Always remove temporary archive and install directories after success, cancellation, or error. Keep the previous valid model until the replacement is validated.

**Step 7:** Inject the shared manager through `AppEnvironment` and add one-time migration that changes only the former ChatGPT-default selection to Kokoro while preserving explicit OpenAI or ElevenLabs choices.

**Step 8:** Run model-lifecycle tests and confirm they pass.

## Task 7: Implement Offline Synthesis

**Files:**

- Create: `InsightAtlas/Services/KokoroAudioService.swift`
- Modify: `InsightAtlas/Services/VoiceProvider.swift`
- Modify: `InsightAtlas/Services/AppEnvironment.swift`

**Step 1:** Define `KokoroAudioError` for model missing, invalid voice, invalid model, empty text, generation failure, and file-writing failure.

**Step 2:** Define an actor-owned synthesis engine that lazily creates `SherpaOnnxOfflineTtsWrapper` from the installed model, voices, token, data-directory, and English lexicon paths. Configure CPU inference, one or two threads, no debug logging, and verify the reported speaker count.

**Step 3:** Split narration into bounded sentence-aware chunks. Generate each chunk using `SherpaOnnxGenerationConfigSwift(silenceScale: 0.2, speed: 0.96, sid: speakerID)`.

**Step 4:** Write generated 24 kHz mono float samples incrementally to a temporary WAV file using AVFoundation. Close the file, load its data, compute duration from written frame count, and remove the temporary file.

**Step 5:** Conform `KokoroAudioService` to `AudioServiceProtocol`, make `validateApiKey()` return model readiness for compatibility, and route `.kokoro` through `VoiceServiceManager`.

**Step 6:** Update availability, voice resolution, voice lists, defaults, and fallback routing. Replace the credential-only error copy with configuration-neutral narration guidance.

**Step 7:** Run all tests and confirm text, registry, model, and routing tests pass.

## Task 8: Add Model Installation and Voice UI

**Files:**

- Modify: `InsightAtlas/Views/SettingsView.swift`
- Modify: `InsightAtlas/Views/GenerationView.swift`
- Modify: `InsightAtlas/Views/VoicePickerSheet.swift`

**Step 1:** Add Kokoro voice-name branches everywhere provider switches are exhaustive.

**Step 2:** Add an On-Device Voice Model section to Audio Settings. Show not-installed, download progress, installing, ready, and failed states; provide Download, Retry, Cancel, and Remove actions with clear approximate storage disclosure.

**Step 3:** Disable Kokoro previews until the model is ready and route previews through `VoiceServiceManager` rather than constructing a provider-specific service inside the view.

**Step 4:** Add Kokoro voice sections to the Settings picker, generation picker, and regeneration picker. Select Heart by default and retain the current selection when valid.

**Step 5:** Rewrite provider guidance so Kokoro is presented as offline and free, cloud providers are optional, and ChatGPT Voice is explicitly experimental and last-resort.

## Task 9: Wire Background Narration and Persistence

**Files:**

- Modify: `InsightAtlas/Services/BackgroundGenerationCoordinator.swift`

**Step 1:** Add Kokoro voice resolution to the production generation loop.

**Step 2:** Store generated narration with `.wav`, retain the existing atomic write and duration verification, and log only provider/voice metadata—not user text.

**Step 3:** Preserve graceful behavior: when the model is not installed or local generation fails, try configured cloud providers in order; when no provider is available, complete the guide without audio rather than failing guide generation.

## Task 10: Documentation, CI, and Device Validation

**Files:**

- Modify: `README.md`
- Create: `docs/KOKORO_OFFLINE_NARRATION.md`
- Create: `docs/THIRD_PARTY_NOTICES.md`
- Modify: `todo.md`

**Step 1:** Document model size, download flow, privacy, deletion, supported voices, fallback behavior, and troubleshooting.

**Step 2:** Credit Kokoro, sherpa-onnx, ONNX Runtime, and SWCompression with licenses and source links.

**Step 3:** Run static repository checks for exhaustive provider switches, malformed project references, accidental model binaries, secrets, and untracked generated files.

**Step 4:** Commit the feature branch, push it, and manually dispatch `.github/workflows/ios-ci.yml` on the branch. Require package resolution, app compilation, and all XCTest cases to pass.

**Step 5:** On a physical iPhone, validate the one-time download, progress UI, cancellation, checksum failure recovery, model deletion, all three curated preview paths, a full guide narration, playback after relaunch, airplane-mode generation, storage pressure, and thermal behavior. Physical-device validation remains explicit because the Linux sandbox and iOS Simulator cannot prove real-device inference speed or memory pressure.

## Rollback Plan

The change is isolated on `feature/kokoro-offline-narration`. Reverting the feature commits restores the existing providers without touching saved guide data. The model lives under a versioned Application Support directory and can be removed independently; no model binary is committed to Git. The app must continue decoding legacy provider values even after rollback.

## Success Criteria

The implementation is complete only when Kokoro is the default provider, Heart is the default voice, model installation is integrity-checked and recoverable, local preview and full narration compile through the native runtime, cloud fallbacks still work, no model binary enters source control, and the macOS GitHub Actions build and XCTest suite pass. A final handoff must clearly distinguish CI-verified behavior from physical-device validation still required.

## References

[1]: https://github.com/k2-fsa/sherpa-onnx "sherpa-onnx"
[2]: https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models "Official sherpa-onnx TTS model assets"
[3]: https://huggingface.co/hexgrad/Kokoro-82M "Kokoro-82M model card"
[4]: https://github.com/tsolomko/SWCompression "SWCompression"
