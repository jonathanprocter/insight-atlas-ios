# Audio and Markdown Release Hardening Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Consolidate InsightAtlas onto one reliable narration experience, prove the production Kokoro model produces playable audio, and prevent Markdown/editorial syntax from appearing in any in-app or exported presentation.

**Architecture:** Keep raw generated guide content as the canonical structured source, but normalize it at every presentation boundary. The existing `NarrationControlsView` and `NarrationPlaybackController` become the only user-facing narration path. A shared presentation sanitizer defines syntax-free plain text for narration and text-like exports, while HTML, DOCX, PDF, and SwiftUI renderers convert supported syntax into native formatting and remove residual editorial markers.

**Tech Stack:** Swift 5.9+, SwiftUI, AVFoundation, PDFKit, ZIPFoundation, XCTest, Xcode 26.6.

---

## Audit Baseline

The local `minimax-primary-generator` branch and GitHub branch were identical at commit `f072fd9`; `origin/main` is an ancestor by 21 commits. The signed targeted baseline passed 61 tests with zero failures. The exact production Kokoro archive was downloaded, byte-count and SHA-256 verified, and exercised by `KokoroLiveSynthesisTests`: all 28 voices synthesized, and the default voice produced 4.9 seconds of audio in 3.3 seconds on the simulator host.

Two release risks remain. First, `GuideView` and `AnalysisDetailView` expose the new shared narration panel while retaining legacy `AudioPlaybackManager` controls and independent generation tasks. This can produce contradictory playback state and overlapping synthesis. Second, the reader, narration, plain-text export, Markdown export, HTML export, DOCX export, and PDF export use separate Markdown parsers with different syntax coverage.

## Task 1: Add Failing Presentation-Hygiene Tests

**Files:**

- Modify: `InsightAtlasTests/MarkdownRenderingTests.swift`
- Modify: `InsightAtlasTests/KokoroNarrationTests.swift`
- Modify: `InsightAtlasTests/KokoroLiveSynthesisTests.swift`

**Step 1:** Add reader tests proving links, images, inline code, strikethrough, emphasis, orphan editorial tags, and heading markers never appear as literal syntax.

**Step 2:** Add narration sanitizer tests proving spoken text contains semantic words but not Markdown/editorial delimiters.

**Step 3:** Add live-audio assertions that the bytes returned by the real production Kokoro model initialize an `AVAudioPlayer`, have a positive playable duration, and prepare successfully.

**Step 4:** Run only the new tests and confirm they fail for the missing syntax cases while the existing live-synthesis assertions continue to pass.

## Task 2: Add Failing End-to-End Export Tests

**Files:**

- Modify: `InsightAtlasTests/MarkdownRenderingTests.swift`

**Step 1:** Create a valid markup-heavy `LibraryItem` fixture containing headings, bold, asterisk and underscore italics, inline code, strikethrough, links, image alt text, lists, a Markdown table, and inline editorial tags.

**Step 2:** Export through the real `DataManager.exportGuide` path as Markdown, plain text, HTML, DOCX, and PDF.

**Step 3:** Inspect text outputs directly, extract DOCX `word/document.xml` with ZIPFoundation, and extract PDF text with PDFKit.

**Step 4:** Assert semantic content survives while Markdown/editorial delimiters do not appear in the reader-visible payload. Run the tests and record the expected failures for Markdown, HTML, and DOCX before implementation.

## Task 3: Implement Shared Presentation Sanitization

**Files:**

- Create: `InsightAtlas/Services/PresentationTextSanitizer.swift`
- Modify: `InsightAtlas.xcodeproj/project.pbxproj`
- Modify: `InsightAtlas/Views/AnalysisComponents.swift`
- Modify: `InsightAtlas/Views/EditorialContentRenderer.swift`
- Modify: `InsightAtlas/Services/NarrationSupport.swift`

**Step 1:** Implement a pure, deterministic sanitizer for editorial tags, links, image alt text, inline code, strikethrough, headings, blockquotes, list markers, table separators, table pipes, and emphasis delimiters while preserving semantic prose.

**Step 2:** Use the shared inline normalization before the SwiftUI attributed-text formatter so valid formatting remains styled and unsupported syntax becomes syntax-free text.

**Step 3:** Make the narration sanitizer delegate to the shared presentation sanitizer so narration never speaks Markdown or editorial control tags.

**Step 4:** Run the focused reader and narration tests until green, then run all related parser tests to prevent regressions.

## Task 4: Harden Every Export Boundary

**Files:**

- Modify: `InsightAtlas/Services/DataManager.swift`
- Modify: `InsightAtlas/Services/PDFRenderer/PDFContentBlockRenderer.swift` only if the end-to-end PDF test reveals a gap

**Step 1:** Change the legacy `.markdown` export option to emit syntax-free readable text while retaining its existing filename for backward compatibility; use the same canonical plain-text output for `.plainText`.

**Step 2:** Normalize inline editorial residue and add complete image, link, code, strikethrough, bold, and italic conversion in HTML without leaving literal Markdown delimiters.

**Step 3:** Extend DOCX run generation to consume the same inline syntax forms into native Word runs or syntax-free text.

**Step 4:** Keep PDF’s existing rich formatting, but route any uncovered residue through the shared sanitizer at the final text boundary.

**Step 5:** Run the end-to-end export hygiene tests and confirm all formats retain semantic content with no presentation-level Markdown residue.

## Task 5: Consolidate the Audio Interface

**Files:**

- Modify: `InsightAtlas/Views/NarrationControlsView.swift`
- Modify: `InsightAtlas/Views/GuideView.swift`
- Modify: `InsightAtlas/Views/AnalysisDetailView.swift`

**Step 1:** Add regeneration to the shared narration panel, stopping current playback before atomic replacement.

**Step 2:** Remove the duplicate legacy audio toolbar/menu controls from both readers so users cannot operate two playback engines or launch parallel generation paths.

**Step 3:** Keep `NarrationPlaybackController` as the sole user-facing player and preserve background playback, interruption recovery, route-change handling, remote commands, progress, speed, retry, delete, and fallback messaging.

**Step 4:** Build and run targeted narration tests after each change.

## Task 6: Full Verification and Release

**Files:**

- Modify: version/build settings only if required for a new App Store Connect upload
- Use: `scripts/release-testflight.sh` after reviewing its commands and credentials handling

**Step 1:** Run the full signed XCTest suite on the iPhone 17 Pro simulator.

**Step 2:** Re-run `KokoroLiveSynthesisTests` using the checksum-verified production model.

**Step 3:** Build the Release configuration for a generic iOS device, archive with automatic signing, validate the archive, and export/upload through the repository’s established TestFlight process.

**Step 4:** Review the final diff, commit in coherent units, fast-forward the latest branch, push the branch and tags to GitHub, and confirm local/remote commit identity.

**Step 5:** Confirm the uploaded build appears in App Store Connect/TestFlight processing and report the build number, commit, test counts, verification evidence, and any Apple processing status.
