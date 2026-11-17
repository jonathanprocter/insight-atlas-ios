# Elevation spec: Shortform-class summaries — 2026-10-12 (build 2026101205)

Reviewer input: a page-referenced critique of the 29-page export of
*Nineteen Ways of Looking at Consciousness* (Patrick House), generated on
2026-10-12. Verdict: prose and triangulation above baseline; skeleton,
pagination, missing reader components and provenance discipline below it.

## Root cause of the headline defect (A1)

Every section title in the export is set in 17 pt *regular* body type and
absent from the Contents page. So they reached `PDFAnalysisDocument.parse`
as plain lines: no `[PREMIUM_H2]`, no `##`, not even `**bold**` (which would
have rendered bold). The parser had no notion of an unmarked heading.

Fix: `ContentBlockParser.implicitHeading(line:previousLine:nextLine:)`
(`Views/EditorialContentRenderer.swift`) promotes a standalone Title-Case
line (2–12 words, no terminal punctuation, followed by prose or a block) to a
heading. All three parsers — reader, legacy export, PDF — call it, so the
three surfaces agree. The generator is also now told that headings are only
ever `[PREMIUM_H2]…[/PREMIUM_H2]`.

## What changed, by spec item

| Item | Where | Change |
|---|---|---|
| A1 headings | parsers, `PDFContentBlockRenderer.renderHeading` | implicit promotion; numbered openers draw a hanging accent numeral + italic descriptor; headings never start in the bottom 15 % of the text block; keep-with-next keeps ~100 pt of a fragmentable block instead of all of it |
| A2 TOC | `InsightAtlasPDFRenderer` | layout-verified: the content is laid out, heading pages recorded, then re-rendered with those numbers (up to 3 passes); rows carry the descriptor and per-section minutes; flush-left when the guide has no level-1 headings |
| A3 pagination | `InsightAtlasPDFRenderer`, `PDFContentBlockRenderer` | paragraph fragmentation (CoreText line ranges, 2-line widow/orphan), list fragmentation (numbering continues), Key Takeaways fragmentation ("continued" card), float-ahead of up to three paragraphs around an atomic block, page-tall diagrams scaled to the page |
| A4 spectrum | `PDFAnalysisDocument.pdfBlocks`, `PDFDiagramRenderer.renderSpectrum` | native figure: poles, numbered markers at the payload positions, legend; unknown component types log loudly and are recovered as structure; ≥3 consecutive ≤8-word orphan lines become a list |
| A5 figure text | `PDFDiagramRenderer` | flowchart nodes measured at their real inner width (they were measured 40 pt wider, hence the cut-off last words); word-wrap draw |
| A6 tables | `PDFContentBlockRenderer.tableLayout` | proportional columns floored at each column's longest word, 13 pt table face (11.5 pt fallback), 36 pt overhang into the margins, word wrapping |
| A7 captions | block renderer wrappers | "Figure N: title" / "Table N: title" under every numbered figure and table; the visual's title is the descriptive caption |
| A8 callouts | `Typography.calloutLabel()` | one label face (Inter-SemiBold 11, kern 1.2) for every card header, figure caption and takeaways header; identical padding/header height |
| A9 Go Deeper | prompt + `normalizedGoDeeper` | `Author, *Title* (Year) — reason`; legacy forms normalised at render; footer in roman, title italic; `parseBookReferences` links the new form |
| A10 header | `drawPageHeader/Footer` | book title left, section right (fitted with …); brand + page number in the footer |
| B1–B6 structure | `InsightAtlasPrompt.swift` | fixed skeleton: Quick Glance → About the Book and Author → How to Use → Who This Is For → Executive Summary → numbered sections with six labelled parts (≥900 words) → Synthesis → Key Takeaways (actionable, section refs) → Exercises → Glossary → Key Quotations → Chapter Map table → Further Reading; comparison tables of theories must carry a "Fails to explain" column |
| B7 honesty markers | prompt | every note/perspective has "*What the source shows:*" and "*How it bears on the claim:*" |
| C1–C4 provenance | prompt + `AIService.verifyProvenance` | chapter refs, sourced numbers, consistency pass, "the book does not say"; a verification agent (JSON report, exact-substring edits, tags protected, 60-edit cap, 180 s deadline, never fatal) runs after the conclusion pass |
| D typography | `PDFStyleConfiguration` | 16 pt body on 1" side margins (≈11–13 words/line), MediumItalic for italics, cover reading-time badge, TOC minutes |
| F lint | `GuideSkeletonLint` (`ContentValidation.swift`) | required headings, ≥5 numbered sections with Synthesis last, ≥900 words each, Go Deeper regex, Chapter Map table, Quick Glance vs Takeaways Jaccard < 0.3; "Structure:" issues trigger the improvement pass |
| Length | `SummaryGovernorPresets` | professional 9,500/12,000 (was 3,000/4,000 — the reason the export was ~4,000 words), accessible 9,000/11,500, deep research 11,000/15,000; MiniMax legacy + OpenRouter output budgets 24k tokens |
| Audio | narration prompt | skips Glossary, Chapter Map, Further Reading, How to Use, Who For; always narrates Key Takeaways; numerals not read aloud |

Not done as specified, and why:
- A7(b)/(c) in-text "Table 1 compares…" lead-ins: the generator is still forbidden from numbering or pointing at visuals (that rule exists because it hallucinated references). The sentence before a visual must introduce its subject by name; the caption carries the title.
- The renderer logs an unknown component loudly but does not block the export: a reader waiting on a file must not get a hard failure.

## Verification

- `ElevationSpecParsingTests` (16) and `ElevationSpecRenderingTests` (8): heading promotion on all three parsers, descriptors, orphan coalescing, spectrum nodes, Go Deeper normalisation, skeleton lint, verification-report parsing/application; and on real PDF bytes: TOC numbers equal the pages headings land on, no intra-word table breaks, a long paragraph spans two consecutive pages, paragraphs float ahead of a diagram, running header/footer present, spectrum/flowchart text intact.
- Fixture (`ElevationSpecFixture.swift`, a spec-shaped guide of ~10k words) renders to 40 pages with 87 % mean text-block fill; the only pages under 80 % are the Contents spill, two section tails at 72–77 %, and the last page. The reviewed export had ten pages 40–70 % blank.
- Full simulator suite: 484 tests, 0 failures, 3 skipped (live Pocket synthesis without the model).
