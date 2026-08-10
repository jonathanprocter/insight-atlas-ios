# ChatGPT Voice Experimental Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make ChatGPT Voice (Experimental) the primary InsightAtlas narration provider by streaming GPT-Live PCM audio through the existing ChatGPT OAuth session, while retaining ordered OpenAI and ElevenLabs fallbacks.

**Architecture:** Add a testable GPT-Live protocol layer, a URLSession WebSocket transport, and an AVFoundation PCM-to-M4A encoder behind `AudioServiceProtocol`. Promote the provider through persisted settings and all voice-selection UI, then route narration through an ordered fallback chain. Keep tokens in Keychain and isolate experimental failures from guide completion.

**Tech Stack:** Swift 6, SwiftUI, Foundation `URLSessionWebSocketTask`, AVFoundation, XCTest, Xcode project files, Git.

---

### Task 1: Add Provider and Routing Contract Tests

**Files:**
- Create: `InsightAtlasTests/ChatGPTVoiceProviderTests.swift`
- Modify: `InsightAtlas.xcodeproj/project.pbxproj`

**Step 1: Write failing tests**

Add tests asserting that:

```swift
XCTAssertEqual(VoiceProvider.allCases.first, .chatgptVoice)
XCTAssertEqual(VoiceProvider.chatgptVoice.defaultVoiceID, "marin")
XCTAssertFalse(VoiceProvider.chatgptVoice.requiresSeparateApiKey)
```

Add a dependency-injected provider-availability test asserting that the preferred chain is ChatGPT Voice, OpenAI, ElevenLabs when all credentials exist, and that unavailable providers are omitted without duplication.

**Step 2: Run tests and verify RED**

Run on an Apple toolchain:

```bash
xcodebuild test -project InsightAtlas.xcodeproj -scheme InsightAtlas \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

Expected: compilation fails because `.chatgptVoice`, `defaultVoiceID`, and the fallback planner do not exist.

In this Linux environment, record the expected toolchain limitation and run the structural test manifest check instead.

**Step 3: Commit tests only**

```bash
git add InsightAtlasTests/ChatGPTVoiceProviderTests.swift InsightAtlas.xcodeproj/project.pbxproj
git commit -m "test: specify ChatGPT voice provider routing"
```

### Task 2: Implement the Provider Model and Fallback Planner

**Files:**
- Modify: `InsightAtlas/Services/VoiceProvider.swift`
- Modify: `InsightAtlas/Models/GuideModels.swift`
- Modify: `InsightAtlas/Services/AppEnvironment.swift`
- Test: `InsightAtlasTests/ChatGPTVoiceProviderTests.swift`

**Step 1: Add the minimum provider model**

Introduce `.chatgptVoice = "chatgpt_voice"` as the first `CaseIterable` case. Add `displayName`, experimental description, `isConfigured()` based on `ChatGPTOAuthService.hasStoredCredentials`, provider-specific `defaultVoiceID`, and a shared helper for provider voice defaults.

Create a pure `VoiceProviderFallbackPlanner` that accepts availability booleans and returns a unique ordered provider list. The default order is ChatGPT Voice, the selected stable provider, OpenAI, ElevenLabs.

**Step 2: Change persisted defaults safely**

Default new and legacy-decoded settings to `.chatgptVoice`. Preserve raw values for existing `.openai` and `.elevenlabs` settings.

**Step 3: Run tests and verify GREEN**

Run the same `xcodebuild test` command on an Apple toolchain. Expected: provider tests pass.

**Step 4: Commit**

```bash
git add InsightAtlas/Services/VoiceProvider.swift InsightAtlas/Models/GuideModels.swift \
  InsightAtlas/Services/AppEnvironment.swift InsightAtlasTests/ChatGPTVoiceProviderTests.swift
git commit -m "feat: add ChatGPT voice provider model"
```

### Task 3: Specify GPT-Live Wire Behavior

**Files:**
- Create: `InsightAtlasTests/ChatGPTVoiceProtocolTests.swift`
- Modify: `InsightAtlas.xcodeproj/project.pbxproj`

**Step 1: Write failing protocol tests**

Cover the following wished-for APIs:

```swift
let config = ChatGPTVoiceConfig.default
XCTAssertEqual(config.endpoint.host, "api.openai.com")
XCTAssertEqual(config.model, "gpt-live-1-codex")

let headers = ChatGPTVoiceRequestBuilder.headers(
    token: "secret",
    accountID: "acct_123",
    requestIDs: .fixedForTesting
)
XCTAssertEqual(headers["Authorization"], "Bearer secret")
XCTAssertEqual(headers["chatgpt-account-id"], "acct_123")
XCTAssertEqual(headers["OpenAI-Alpha"], "quicksilver=v2")
```

Test UTF-8-safe 500-byte text chunking, session update payload shape, speakable context payload shape, valid `output_audio.delta` parsing, assistant `turn.done` parsing, provider error parsing, malformed JSON rejection, malformed base64 rejection, and 16-bit PCM alignment validation.

**Step 2: Verify RED**

Expected: compilation fails because the protocol types do not exist.

**Step 3: Commit tests only**

```bash
git add InsightAtlasTests/ChatGPTVoiceProtocolTests.swift InsightAtlas.xcodeproj/project.pbxproj
git commit -m "test: specify GPT-Live protocol behavior"
```

### Task 4: Implement the GPT-Live Protocol Core

**Files:**
- Create: `InsightAtlas/Services/ChatGPTVoiceProtocol.swift`
- Modify: `InsightAtlas.xcodeproj/project.pbxproj`
- Test: `InsightAtlasTests/ChatGPTVoiceProtocolTests.swift`

**Step 1: Implement pure protocol types**

Add:

```swift
struct ChatGPTVoiceConfig
struct ChatGPTVoiceRequestIDs
struct ChatGPTVoiceRequestBuilder
enum ChatGPTVoiceInboundEvent
enum ChatGPTVoiceProtocolError: LocalizedError
```

Use `JSONSerialization` or small `Codable` structs for payloads. Bound inbound text frames, reject non-OpenAI endpoint hosts, never log tokens, and keep model/voice constants centralized.

**Step 2: Implement text chunking**

Split at sentence or whitespace boundaries while enforcing a 500-byte UTF-8 ceiling. Fall back to Unicode-scalar-safe splitting for a single oversized token.

**Step 3: Implement event parsing**

Parse `session.started`, `output_audio.delta`, assistant/user transcript events, assistant `turn.done`, and `error`. Return `.ignored(type:)` for unknown valid events.

**Step 4: Run tests and verify GREEN**

Expected: protocol tests pass on the Apple toolchain.

**Step 5: Commit**

```bash
git add InsightAtlas/Services/ChatGPTVoiceProtocol.swift \
  InsightAtlasTests/ChatGPTVoiceProtocolTests.swift InsightAtlas.xcodeproj/project.pbxproj
git commit -m "feat: implement GPT-Live protocol core"
```

### Task 5: Specify Streaming, Encoding, and Failure Behavior

**Files:**
- Create: `InsightAtlasTests/ChatGPTVoiceServiceTests.swift`
- Modify: `InsightAtlas.xcodeproj/project.pbxproj`

**Step 1: Write failing service tests**

Define an injected transport protocol and test double. Assert that the service:

1. Refreshes and uses OAuth credentials.
2. Sends session configuration before narration chunks.
3. Sends one speakable chunk, waits for assistant completion, then sends the next.
4. Appends audio deltas in order.
5. Rejects empty output, malformed PCM, authentication errors, access errors, timeouts, and premature close.
6. Cancels the transport after success or failure.
7. Returns M4A-compatible `GeneratedAudio` metadata.

Keep AVFoundation export behind an encoder protocol so service orchestration tests can use a deterministic encoder double.

**Step 2: Verify RED**

Expected: compilation fails because the service, transport, and encoder interfaces do not exist.

**Step 3: Commit tests only**

```bash
git add InsightAtlasTests/ChatGPTVoiceServiceTests.swift InsightAtlas.xcodeproj/project.pbxproj
git commit -m "test: specify GPT-Live streaming service"
```

### Task 6: Implement WebSocket Transport and PCM-to-M4A Encoder

**Files:**
- Create: `InsightAtlas/Services/ChatGPTVoiceService.swift`
- Create: `InsightAtlas/Services/ChatGPTVoiceAudioEncoder.swift`
- Modify: `InsightAtlas.xcodeproj/project.pbxproj`
- Test: `InsightAtlasTests/ChatGPTVoiceServiceTests.swift`

**Step 1: Implement the transport seam**

Add a protocol wrapping connect/send/receive/cancel. Implement it with `URLSessionWebSocketTask` and an injected `URLSession` factory. Enforce connection and per-turn timeouts and cap inbound event size.

**Step 2: Implement sequential narration**

After `session.started`, send each UTF-8-safe chunk as `session.context.append` with `channel: "speakable"`; wait for assistant `turn.done` before advancing. Collect output audio frames and transcript diagnostics without retaining the narration text in logs.

**Step 3: Implement streaming audio encoding**

Write 24 kHz mono signed 16-bit little-endian PCM into a temporary audio container using `AVAudioFile`/`AVAudioPCMBuffer`, then export with `AVAssetExportSession` using `AVAssetExportPresetAppleM4A`. Clean temporary files on every exit path.

**Step 4: Implement `AudioServiceProtocol`**

Use `ChatGPTOAuthService.shared.validAccessToken()` and `storedAccountID`. Set `provider = .chatgptVoice`, expose `isConfigured`, validate voice IDs, and return compressed M4A data plus duration and character count.

**Step 5: Run tests and verify GREEN**

Expected: service orchestration tests pass; AVFoundation integration test creates a playable non-empty M4A on an Apple toolchain.

**Step 6: Commit**

```bash
git add InsightAtlas/Services/ChatGPTVoiceService.swift \
  InsightAtlas/Services/ChatGPTVoiceAudioEncoder.swift \
  InsightAtlasTests/ChatGPTVoiceServiceTests.swift InsightAtlas.xcodeproj/project.pbxproj
git commit -m "feat: stream GPT-Live narration to M4A"
```

### Task 7: Integrate Primary Provider and Ordered Fallbacks

**Files:**
- Modify: `InsightAtlas/Services/VoiceProvider.swift`
- Modify: `InsightAtlas/Services/BackgroundGenerationCoordinator.swift`
- Modify: `InsightAtlas/Services/AppEnvironment.swift`
- Test: `InsightAtlasTests/ChatGPTVoiceProviderTests.swift`

**Step 1: Wire the service manager**

Instantiate `ChatGPTVoiceService`, route `.chatgptVoice` calls to it, and expose the ChatGPT voice catalog.

**Step 2: Replace single-provider selection**

Use `VoiceProviderFallbackPlanner` in `generateAudioIfAvailable()`. Resolve a valid voice per attempted provider, try each configured provider once, log a redacted failure category, and persist the actual successful provider’s compatible extension.

**Step 3: Preserve guide completion**

If all providers fail, return `nil` audio exactly as today. Do not throw through guide generation.

**Step 4: Run tests and commit**

```bash
git add InsightAtlas/Services/VoiceProvider.swift \
  InsightAtlas/Services/BackgroundGenerationCoordinator.swift \
  InsightAtlas/Services/AppEnvironment.swift InsightAtlasTests/ChatGPTVoiceProviderTests.swift
git commit -m "feat: make ChatGPT voice primary with fallbacks"
```

### Task 8: Update Settings and Voice Selection UI

**Files:**
- Create: `InsightAtlas/Editorial/ChatGPTVoiceRegistry.swift`
- Modify: `InsightAtlas/Views/SettingsView.swift`
- Modify: `InsightAtlas/Views/GenerationView.swift`
- Modify: `InsightAtlas/Views/LLMActionRouter.swift`
- Modify: `InsightAtlas.xcodeproj/project.pbxproj`

**Step 1: Add the voice registry**

Expose the ten known GPT-Live voice IDs and make `marin` the default.

**Step 2: Update settings copy and controls**

Label the provider **ChatGPT Voice (Experimental)**, show signed-in/readiness status, explain automatic fallback, and replace the obsolete “ChatGPT sign-in does not enable narration” copy.

**Step 3: Update generation controls**

Handle three providers in selected-name lookup and the voice-selection sheet. Replace the segmented picker with a menu if three labels do not fit cleanly. Show “Sign in with ChatGPT” rather than an API-key warning for the experimental provider.

**Step 4: Update hidden router defaults**

Use provider helpers instead of two-way OpenAI/ElevenLabs ternaries and allow parsing “ChatGPT Voice”.

**Step 5: Commit**

```bash
git add InsightAtlas/Editorial/ChatGPTVoiceRegistry.swift \
  InsightAtlas/Views/SettingsView.swift InsightAtlas/Views/GenerationView.swift \
  InsightAtlas/Views/LLMActionRouter.swift InsightAtlas.xcodeproj/project.pbxproj
git commit -m "feat: expose experimental ChatGPT voice controls"
```

### Task 9: Add Build Verification and Documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/plans/2026-08-10-chatgpt-voice-experimental-design.md`
- Create: `docs/chatgpt-voice-testing.md`
- Modify: `todo.md`

**Step 1: Document setup and risks**

Explain sign-in, primary-provider behavior, fallbacks, model/voice settings, experimental access failures, and how to return to stable providers.

**Step 2: Run static verification in Linux**

Run:

```bash
git diff --check
python3 scripts/verify_xcode_references.py   # create only if needed for deterministic PBX checks
grep -R "case \.openai\|case \.elevenlabs" InsightAtlas | review manually
```

Expected: no whitespace errors, every new source/test file appears exactly once in its target, and every `VoiceProvider` switch is exhaustive.

**Step 3: Run Apple-toolchain verification**

On macOS:

```bash
xcodebuild -project InsightAtlas.xcodeproj -scheme InsightAtlas \
  -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO
xcodebuild test -project InsightAtlas.xcodeproj -scheme InsightAtlas \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

Expected: build succeeds and all tests pass.

**Step 4: Manual smoke test**

Sign in with ChatGPT, select ChatGPT Voice, generate a short guide, confirm audio is playable, then simulate an unavailable GPT-Live account and confirm a configured stable provider is used.

**Step 5: Commit documentation**

```bash
git add README.md docs/chatgpt-voice-testing.md \
  docs/plans/2026-08-10-chatgpt-voice-experimental-design.md todo.md
git commit -m "docs: add ChatGPT voice setup and testing guide"
```

### Task 10: Final Review and Branch Packaging

**Files:**
- Review all changed files

**Step 1: Review security and protocol assumptions**

Confirm tokens never appear in logs, endpoint host validation is strict, text/audio/event limits are bounded, temporary files are deleted, cancellation closes sockets, and fallback errors are redacted.

**Step 2: Review compatibility**

Confirm old persisted provider raw values decode, existing OpenAI and ElevenLabs paths remain selectable, saved guide audio still uses supported extensions, and sign-out does not crash provider resolution.

**Step 3: Verify clean state**

```bash
git status --short
git log --oneline --decorate origin/main..HEAD
git diff --stat origin/main...HEAD
```

Expected: only intentional files are changed and all planned commits are present.

**Step 4: Push the feature branch**

```bash
git push -u origin feature/chatgpt-voice-experimental
```

Do not merge to `main` until the Apple-toolchain build and manual OAuth smoke test pass.
