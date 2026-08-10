# ChatGPT Voice Experimental Design

**Author:** Manus AI  
**Date:** August 10, 2026

## Objective

InsightAtlas will add **ChatGPT Voice (Experimental)** as its primary narration provider whenever a valid ChatGPT OAuth session is present. The app will send sanitized guide narration text to OpenAI’s GPT-Live transport, collect streamed 24 kHz PCM audio, encode the result as an M4A file, and retain the current OpenAI Platform TTS and ElevenLabs services as automatic fallbacks.

The feature is intentionally additive. Existing guide generation, audio playback, saved-library metadata, OpenAI API-key narration, and ElevenLabs narration must continue working without migration or data loss.

## Evaluated Approaches

| Approach | Advantages | Tradeoffs | Decision |
|---|---|---|---|
| Direct GPT-Live WebSocket | Reuses the existing OAuth token and account ID; receives audio frames directly; smallest implementation surface | Experimental protocol; access can vary by account; long-form narration requires chunking and validation | **Selected** |
| GPT-Live WebRTC | Closest to interactive voice clients and supports realtime media negotiation | Requires SDP negotiation, audio tracks, and substantially more lifecycle code than saved-file narration needs | Rejected for initial release |
| ChatGPT web internal synthesis endpoint | Potentially simple HTTP request | Undocumented, session/cookie-dependent, and less stable than the GPT-Live transport | Rejected |

## Architecture

A new `ChatGPTVoiceService` will conform to `AudioServiceProtocol`. It will depend on a small transport abstraction so event parsing, request construction, PCM accumulation, and fallback decisions can be unit tested without live network access. The service will retrieve a refreshed access token through `ChatGPTOAuthService.validAccessToken()` and obtain the existing ChatGPT account ID from Keychain-backed OAuth state.

The transport will connect to the GPT-Live WebSocket endpoint with the selected experimental model, bearer token, ChatGPT account ID, `OpenAI-Alpha: quicksilver=v2`, and unique session identifiers. It will send a narration-focused session configuration and then append bounded text chunks as speakable context. Incoming `output_audio.delta` frames will be base64-decoded and appended in order. Completion will be detected from assistant turn completion; authentication, access, timeout, malformed-event, empty-output, and premature-close conditions will surface as typed errors.

A dedicated encoder will write little-endian PCM into an AVFoundation composition or temporary audio file and export an Apple M4A container. `GeneratedAudio.data` will therefore remain directly writable by the existing coordinator, player, and export paths.

## Provider Selection and Fallback

`VoiceProvider` will gain a `chatgptVoice` case and make it the default for newly created or reset settings. Older settings will continue decoding safely; when no voice provider is stored, they will now resolve to ChatGPT Voice. The provider is configured only when ChatGPT OAuth credentials are present.

When auto-generating narration, the coordinator will build an ordered provider chain rather than selecting a single provider:

1. ChatGPT Voice when OAuth is available.
2. The user’s configured stable provider if different.
3. OpenAI Platform TTS when an API key exists.
4. ElevenLabs when an API key exists.

Each provider is attempted once. A failure is logged without token or content disclosure, then the next configured provider is tried. Guide generation succeeds even if all narration providers fail; audio metadata remains empty, matching current behavior.

## Voice Catalog and User Experience

ChatGPT Voice will expose the GPT-Live voice catalog separately from the legacy OpenAI TTS catalog. The initial supported IDs will be `alloy`, `ash`, `ballad`, `cedar`, `coral`, `echo`, `marin`, `sage`, `shimmer`, and `verse`, with `marin` as the default. Settings and the generation screen will identify the provider as experimental, explain that access depends on the signed-in ChatGPT account, and show fallback status rather than claiming that an API key is missing.

The existing ChatGPT subscription section will add a narration toggle and accurate risk copy. Signing out of ChatGPT will leave the selected provider intact but mark it unavailable; the fallback chain will then use configured stable providers automatically.

## Data Flow

| Stage | Input | Output |
|---|---|---|
| Guide completion | Sanitized guide content | Narration text |
| Provider routing | OAuth and API-key availability | Ordered provider attempts |
| GPT-Live session | Token, account ID, model, voice, text chunks | Ordered PCM frames and transcript events |
| Audio validation | PCM byte count and frame alignment | Valid 24 kHz mono PCM |
| Encoding | PCM samples | M4A audio data |
| Persistence | M4A data and library item ID | Existing `audio_<UUID>.m4a` file and metadata |

## Error Handling and Security

OAuth tokens will remain in Keychain and will never be logged. Request diagnostics will include only HTTP status, stable error category, and request/session identifiers. The implementation will reject non-OpenAI WebSocket redirects, cap event size, cap accumulated audio size, enforce a session timeout, validate base64, validate 16-bit PCM frame alignment, and cancel the socket after completion or failure.

The feature will remain visibly labeled experimental because GPT-Live model names, headers, entitlement rules, and event shapes can change. Stable providers remain available as fallbacks and can still be selected directly.

## Testing Strategy

Tests will be written before production code and will cover provider defaults, configuration predicates, OAuth headers, model and voice validation, text chunking, event decoding, PCM assembly, empty or malformed audio rejection, timeout and close errors, and ordered fallback routing. Network behavior will be exercised through an injected transport double rather than live OAuth credentials.

The Linux development environment cannot run `xcodebuild`, so repository-level verification will combine source-level structural checks with a macOS GitHub Actions build/test workflow or the user’s local Xcode run. No successful iOS build will be claimed without evidence from an Apple toolchain.

## Success Criteria

The feature is complete when ChatGPT Voice is the default narration provider, a signed-in account can produce a playable M4A from guide text, provider failures fall back in the documented order, existing narration services still work, settings and voice pickers handle all three providers, tests cover the new pure logic, and an Apple-toolchain build reports no compile or test failures.
