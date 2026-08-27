# InsightAtlas Audio and Content Reliability Design

**Date:** 2026-08-27  
**Author:** Manus AI

## Purpose

This release addresses four user-observed failures in the current TestFlight build: Daniel narration waits too long before synthesis begins, long narration can reach playback as an `OSStatus -50` failure, the hosted Liam fallback returns Cloudflare HTTP 530, and Reader Edition output can display literal Markdown and adjacent editorial control tags.

## Verified diagnosis

MiniMax M3 is a text and reasoning model used by InsightAtlas to generate written guides and optional spoken-word scripts. It does not synthesize audio. MiniMax Speech is a separate product and API. The app’s current MiniMax OAuth scope is `group_id profile model.completion`, and its inference endpoint is the Anthropic-compatible Messages endpoint, so the existing M3 authorization must not be presented as an audio provider.

Daniel is an on-device Kokoro voice (`am_adam`, speaker 0), not a MiniMax voice. Current narration preparation waits as long as 75 seconds for MiniMax M3 to rewrite the full guide before Kokoro starts. The rewrite prompt explicitly preserves roughly the full source length, so it adds startup time without reducing Daniel synthesis work. The current Kokoro engine then generates every chunk serially and withholds playback until the complete WAV is finished.

The hosted Liam endpoint `kokoro-tts.procterai.cc` returns Cloudflare error 1033 as HTTP 530 because its `icloud-proxy` tunnel is normally disconnected. Briefly connecting that tunnel changes the endpoint from 530 to the tunnel’s default HTTP 404 route, proving the remote configuration has no healthy TTS origin. The app must not route users to this unavailable fallback or label its failure as Kokoro.

`OSStatus -50` is `paramErr`. The production playback session requests `.playback` mode together with `.allowBluetooth`, an invalid or device-sensitive option combination. Persisted audio is also accepted after asset metadata loading without requiring a playable audio track and without converting raw AVFoundation failures into a recovery action.

The malformed Reader Edition screenshot contains adjacent tags such as `[/INSIGHT_NOTE][PREMIUM_H1]` and a header opening tag followed by a new editorial block before a matching header close. The sanitizer removes trailing spaces but does not canonicalize tag boundaries. The parser is line-oriented, so adjacent tags become prose and an unclosed header absorbs later blocks. Existing guides need a renderer-side compatibility repair as well as a persistence boundary.

## Release decisions

| Area | Decision |
|---|---|
| MiniMax M3 | Keep it as the primary written-guide generator and optional script transformer; explicitly label it as text-only. |
| Daniel startup | Do not block first-time narration on the optional full-guide MiniMax rewrite. Start from deterministic sanitized guide prose immediately. |
| Narration length | Use the user’s selected summary governor as the audio ceiling. If content exceeds the ceiling, create a deterministic listening edition from complete editorial sections rather than truncating mid-sentence. |
| Local voice path | Keep on-device Kokoro first and preserve Daniel as speaker 0. Increase safe chunk size only after live-model benchmarks and playability tests prove an improvement. |
| Fallback | Remove the unavailable Liam route from automatic fallback. If local Kokoro cannot complete, show an actionable local error and offer retry with a different installed Kokoro voice; do not make a known-dead network request. |
| Playback | Configure `.playback` mode without incompatible Bluetooth options, require a playable audio track and positive duration before persistence, and replace raw OSStatus messages with a clean regeneration action. |
| Editorial output | Add one pure canonicalizer that separates adjacent editorial tags, closes or terminates malformed header blocks conservatively, and preserves semantic prose. Apply it before persistence and at renderer entry for legacy guides. |
| Inline Markdown | Keep supported rich emphasis, but ensure malformed or unpaired delimiters degrade to clean semantic text. |
| TestFlight | Release only after targeted regressions, full signed tests, real production-model Daniel synthesis, audio-file playability, multi-setting reader fixtures, Release build, strict concurrency, and independent review pass. |

## Compatibility and privacy

The release does not change existing LibraryItem encoding or delete stored narration. Existing malformed guides are repaired at presentation time, while newly generated guides are canonicalized before persistence. No source book text, guide content, audio, API token, or private key is written to logs or release evidence.

## External references

[1]: https://www.minimax.io/models/text/m3 "MiniMax M3"
[2]: https://www.minimax.io/news/minimax-speech-28 "MiniMax Speech 2.8"
[3]: https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/troubleshooting/ "Cloudflare Tunnel troubleshooting"
