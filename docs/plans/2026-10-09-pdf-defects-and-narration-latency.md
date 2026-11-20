# PDF duplication defects and narration latency — 2026-10-09 (build 2026100902)

Reported against build 2026100901 with a real export
(`Persuasion Skills.pdf`, 58 pages).

## 1. PDF: heading rendered three times — FIXED

The text layer confirmed it literally:

```
'...in the long run."\nThe One-Page Summary\nThe One-Page Summary\nThe One-Page Summary\n'
```

`PDFAnalysisDocument.parse` has three sites that append a `.premiumH2`
block: the `flushOpenBlock()` helper, the inline `[PREMIUM_H2]x[/PREMIUM_H2]`
handler, and the multi-line `[/PREMIUM_H2]` handler.

A diagnostic test (`PDFHeadingDuplicationTests.testReportHeadingShapes`) fed
each plausible authoring shape through the real parser rather than guessing:

| shape | before | after |
|---|---|---|
| `[PREMIUM_H2]Title[/PREMIUM_H2]` | 1 | 1 |
| `[PREMIUM_H2]\nTitle\n[/PREMIUM_H2]` | **2** | 1 |
| unterminated `[PREMIUM_H2]Title` | 1 | 1 |

**Cause:** the `[/PREMIUM_H2]` handler emitted the block but never emptied
`premiumH2Content`, unlike every other block handler in the function. The
stale buffer was then re-emitted by a later flush. One line fixes it.

The shipped guide showed three rather than two because the LLM also emits the
heading in more than one shape across a 58-page document; with the buffer
cleared, each shape now yields exactly one heading.

## 2. PDF: bare `[` and `]` rendered as body paragraphs — FIXED

Page 5 contained `'[\n]\n'` as two paragraphs — debris from a tag whose name
was stripped (most likely the `[[AUTHORS: …]]` removal at the top of `parse`).
The paragraph branch accepted any non-empty line. It now skips lines composed
only of brackets and whitespace. `[...]` (an elided quotation) contains dots
and is still kept.

## 3. PDF: duplicated table-of-contents entries — FIXED

Nearly every theme appeared twice, one page apart. `.heading3` was the only
TOC case lacking the `!tableOfContents.contains(where:)` guard that
`.foundationalNarrative`, `.keyTakeaways`, `.heading2`, and `.premiumH1` all
carry, so a repeated subheading listed itself once per occurrence.

## 4. Narration latency — diagnosed, not yet fixed

**Inference is not the bottleneck, and CoreML is a dead end.**

Benchmarked the shipped `model.int8.onnx` directly with onnxruntime 1.31:

| provider | threads | tokens | wall | audio | RTF |
|---|---|---|---|---|---|
| CPU | 1 | 300 | 2.33 s | 12.97 s | 0.180 |
| CPU | 4 | 300 | 1.31 s | 14.47 s | 0.090 |
| CPU | 5 | 500 | 2.13 s | 21.73 s | 0.098 |
| CoreML | — | — | — | — | **fails** |

CoreML EP *is* compiled into the iOS onnxruntime build
(`CoreMLExecutionProvider` present in the framework), but it rejects this
model at run time:

```
Input (/text_encoder/TopK_output_1) has a dynamic shape ({-1}) but the
runtime shape ({0}) has zero elements. This is not supported by the CoreML EP.
```

So `provider: "cpu"` in `KokoroAudioService.loadModelIfNeeded` is correct and
must not be changed to `"coreml"` — it would break synthesis outright. Thread
count (`min(6, cores - 1)`) is already past the point of meaningful return:
1 → 4 threads doubled throughput, 4 → 5 gained nothing.

**The real cause is volume plus all-or-nothing delivery.** A professional
guide narrates up to 2,400 words ≈ 16 minutes of audio
(`NarrationListeningEdition.maximumWords`), and nothing plays until every
chunk is rendered. Scaling the measured Mac RTF by 2–4× for A-series:

| narration length | audio | synthesis at 2× | at 3× | at 4× |
|---|---|---|---|---|
| 2,400 words (current) | 16.0 min | 3.1 min | 4.7 min | 6.3 min |
| 1,200 words | 8.0 min | 1.6 min | 2.4 min | 3.1 min |
| 900 words | 6.0 min | 1.2 min | 1.8 min | 2.4 min |

Add up to 75 s for the MiniMax rewrite, which still runs *before* synthesis
(`NarrationPreparationPolicy.rewritesBeforeInitialSynthesis = true`) despite
the 2026-08-27 design decision not to block first play on it. Total before any
sound: roughly 4–7.5 minutes.

### Options, in order of value

1. **Progressive playback** — play chunk 1 while the rest renders.
   Time-to-first-audio drops to a few seconds with no change to content or
   length. This is the only option with no product trade-off. Playback is
   already `AVPlayer` (`NarrationSupport.swift:316`), so the shape is an
   `AVQueuePlayer` over per-chunk files, concatenated at the end for the
   cached asset. Needs aggregated duration/seek and on-device testing — not
   shipped blind.
2. **Shorten the listening edition** (2,400 → ~1,200 words). Halves the wait
   immediately; one constant. Product decision: shorter narration.
3. **Take the MiniMax rewrite off the first-play path.** Saves up to 75 s and
   matches the original design decision, but first play would use the
   deterministic bounded edition instead of the audio-native MiniMax script.

Options 2 and 3 are product trade-offs and are left for the owner to choose.

## Verification

- `PDFHeadingDuplicationTests`: 3 tests, all passing (2 were failing before the
  fixes, reproducing the shipped defects).
- Full suite re-run after the changes.
