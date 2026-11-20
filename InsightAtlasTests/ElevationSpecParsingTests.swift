import XCTest
@testable import InsightAtlas

/// Parser-side guarantees from the 2026-10-12 elevation spec: headings the
/// model forgot to mark up are promoted on every surface, section descriptors
/// ride their headings, orphan one-liners never print as prose, spectrum
/// visuals become native figures, Go Deeper lines normalise to one pattern,
/// and the skeleton lint catches a guide that is missing its back matter.
final class ElevationSpecParsingTests: XCTestCase {

    // MARK: - A1: implicit headings

    private let plainHeadingGuide = """
    [QUICK_GLANCE]
    **Core Message:** Consciousness is downstream of movement.
    - Brains only output movement
    - Confabulation is a feature
    [/QUICK_GLANCE]

    This guide reorganizes the book's material around its actual thematic architecture rather than its chapter sequence, consolidating repeated arguments.

    The Movement Commitment

    The single claim House returns to most often is also the most empirically grounded: the brain's only outputs are the muscles it connects to, and consciousness is therefore best understood as what motor coordination feels like from the inside.

    **The Confabulation Problem**

    Anna's case is best known not for her laughter but for her explanations, each a plausible but incorrect account of why she laughed, offered with complete confidence every time.

    A theory that cannot account for any of these has not.

    Synthesis: The Privileged Position of Movement

    Across the nineteen perspectives House assembles, a convergent picture emerges in which the explanatory work is consistently done by the same feature.
    """

    func testPDFParserPromotesPlainAndBoldOnlyTitleLinesToHeadings() {
        let doc = PDFAnalysisDocument.parse(from: plainHeadingGuide, title: "Nineteen Ways", author: "Patrick House")
        let blocks = doc.sections.flatMap(\.blocks)
        let headings = blocks.filter { $0.type == .premiumH2 }.map(\.content)
        XCTAssertEqual(headings, ["The Movement Commitment", "The Confabulation Problem", "Synthesis: The Privileged Position of Movement"])
        // The short sentence with a full stop stays prose.
        XCTAssertTrue(blocks.contains { $0.type == .paragraph && $0.content.hasPrefix("A theory that cannot") })
    }

    func testReaderParserPromotesTheSameLines() {
        let blocks = ContentBlockParser.parse(plainHeadingGuide)
        let headings = blocks.filter { $0.type == .subsectionHeader }.map(\.content)
        XCTAssertEqual(headings, ["The Movement Commitment", "The Confabulation Problem", "Synthesis: The Privileged Position of Movement"])
    }

    func testLegacyExportParserPromotesTheSameLines() {
        let parsed = ParsedAnalysisContent.parse(from: plainHeadingGuide)
        let headings = parsed.sections.flatMap(\.blocks).filter { $0.type == .premiumH2 }.map(\.content)
        XCTAssertEqual(headings, ["The Movement Commitment", "The Confabulation Problem", "Synthesis: The Privileged Position of Movement"])
    }

    func testImplicitHeadingRejectsProseFragmentsAndListItems() {
        let next = "A long enough following paragraph that clearly reads as body prose with more than twelve words in it."
        XCTAssertNil(ContentBlockParser.implicitHeading(line: "Anchored, no nervous system", previousLine: "", nextLine: next))
        XCTAssertNil(ContentBlockParser.implicitHeading(line: "Sea squirt dissolves its nervous system upon settling", previousLine: "", nextLine: next))
        XCTAssertNil(ContentBlockParser.implicitHeading(line: "- The Boundary Problem", previousLine: "", nextLine: next))
        XCTAssertNil(ContentBlockParser.implicitHeading(line: "The Boundary Problem.", previousLine: "", nextLine: next))
        XCTAssertNil(ContentBlockParser.implicitHeading(line: "The Boundary Problem", previousLine: "Some prose line directly above it.", nextLine: next))
        XCTAssertNil(ContentBlockParser.implicitHeading(line: "The Boundary Problem", previousLine: "", nextLine: nil))
        XCTAssertEqual(ContentBlockParser.implicitHeading(line: "The Boundary Problem", previousLine: "", nextLine: next), "The Boundary Problem")
        XCTAssertEqual(ContentBlockParser.implicitHeading(line: "**Clinical Windows**", previousLine: "[/INSIGHT_NOTE]", nextLine: next), "Clinical Windows")
    }

    func testSingleNumberedTitleLineBecomesANumberedHeading() {
        let content = """
        3. The Boundary Problem

        Where does a consciousness end and the rest of the world begin? House poses this through an elaborate thought experiment about an artificial intelligence.
        """
        let blocks = PDFAnalysisDocument.parse(from: content, title: "T", author: "A").sections.flatMap(\.blocks)
        XCTAssertEqual(blocks.first?.type, .premiumH2)
        XCTAssertEqual(blocks.first?.content, "3. The Boundary Problem")
        XCTAssertFalse(blocks.contains { $0.type == .numberedList })
    }

    // MARK: - Descriptors and orphan lines

    func testItalicLineUnderHeadingBecomesItsDescriptor() {
        let content = """
        [PREMIUM_H2]2. The Confabulation Problem[/PREMIUM_H2]
        *Why brains must lie to function*

        Anna's case is best known not for her laughter but for her explanations, which were offered with confidence and were wrong every time.
        """
        let blocks = PDFAnalysisDocument.parse(from: content, title: "T", author: "A").sections.flatMap(\.blocks)
        let heading = blocks.first { $0.type == .premiumH2 }
        XCTAssertEqual(heading?.metadata?["descriptor"], "Why brains must lie to function")
        XCTAssertFalse(blocks.contains { $0.type == .paragraph && $0.content.contains("Why brains must lie") })
    }

    func testMarkdownSectionHeadingCarriesItsDescriptor() {
        let content = """
        ## 2. The Confabulation Problem
        *Why brains must lie to function*

        Anna's case is best known not for her laughter but for her explanations, which were offered with confidence and were wrong every time.
        """
        let doc = PDFAnalysisDocument.parse(from: content, title: "T", author: "A")
        XCTAssertEqual(doc.sections.first?.heading, "2. The Confabulation Problem")
        XCTAssertEqual(doc.sections.first?.descriptor, "Why brains must lie to function")
    }

    func testRunOfOrphanShortLinesBecomesAList() {
        let content = """
        The clinical significance of the movement commitment emerges in cases like Leong's, whose fine motor skills were lost while his sense of self remained intact.

        Anchored, no nervous system
        Sea squirt dissolves its nervous system upon settling
        Primate manual dexterity and vocal learning
        Echolocating bat: flight plus sensory computation

        This spectrum clarifies why the movement commitment is a baseline against which all theories must be calibrated.
        """
        let blocks = PDFAnalysisDocument.parse(from: content, title: "T", author: "A").sections.flatMap(\.blocks)
        let lists = blocks.filter { $0.type == .bulletList }
        XCTAssertEqual(lists.count, 1)
        XCTAssertEqual(lists.first?.listItems?.count, 4)
        XCTAssertEqual(blocks.filter { $0.type == .paragraph }.count, 2)
    }

    // MARK: - A4: spectrum is a native figure

    func testSpectrumVisualBecomesANativeSpectrumBlockWithNodes() {
        let content = """
        [VISUAL_SPECTRUM: The movement spectrum, from anchored organisms to fluid conscious movers]
        Rigid fixation (plants, sea squirts) → Fluid, conscious movement (primates, bats)
        Anchored, no nervous system: 0.05
        Sea squirt dissolves its nervous system: 0.25
        Primate manual dexterity: 0.75
        Echolocating bat: 0.95
        [/VISUAL_SPECTRUM]
        """
        let blocks = PDFAnalysisDocument.parse(from: content, title: "T", author: "A").sections.flatMap(\.blocks)
        guard let spectrum = blocks.first(where: { $0.type == .spectrum }) else {
            return XCTFail("expected a native spectrum block, got \(blocks.map(\.type))")
        }
        XCTAssertEqual(spectrum.listItems?.first, "Rigid fixation (plants, sea squirts)")
        XCTAssertEqual(spectrum.listItems?.last, "Fluid, conscious movement (primates, bats)")
        let nodes = PDFContentBlockRenderer.spectrumNodes(from: spectrum)
        XCTAssertEqual(nodes.map(\.label), ["Anchored, no nervous system", "Sea squirt dissolves its nervous system", "Primate manual dexterity", "Echolocating bat"])
        XCTAssertEqual(nodes.map(\.position), [0.05, 0.25, 0.75, 0.95])
        XCTAssertFalse(blocks.contains { $0.type == .paragraph }, "no loose paragraphs may leak from a spectrum payload")
    }

    func testTableVisualCarriesItsTitleAsCaptionMetadata() {
        let content = """
        [VISUAL_TABLE: The five frameworks compared on what they explain and what they miss]
        | Theory | Explains well | Fails to explain |
        |---|---|---|
        | IIT | Posterior hot zone | The cerebellum |
        | GNW | Broadcast | Split-brain duplication |
        [/VISUAL_TABLE]
        """
        let blocks = PDFAnalysisDocument.parse(from: content, title: "T", author: "A").sections.flatMap(\.blocks)
        let table = blocks.first { $0.type == .table }
        XCTAssertEqual(table?.metadata?["title"], "The five frameworks compared on what they explain and what they miss")
        XCTAssertFalse(blocks.contains { $0.type == .heading4 }, "the title is a caption, not a detached heading")
    }

    // MARK: - A9: Go Deeper normalisation

    func testLegacyGoDeeperShapesNormaliseToAuthorFirstItalicTitle() {
        XCTAssertEqual(
            PDFContentBlockRenderer.normalizedGoDeeper("\"From Bacteria to Bach and Back\" by Daniel Dennett — The evolutionary gradient"),
            "Daniel Dennett, *From Bacteria to Bach and Back* — The evolutionary gradient"
        )
        XCTAssertEqual(
            PDFContentBlockRenderer.normalizedGoDeeper("Michael Gazzaniga, \"Tales from Both Sides of the Brain\" — Decades of split-brain research"),
            "Michael Gazzaniga, *Tales from Both Sides of the Brain* — Decades of split-brain research"
        )
        let already = "Rodolfo Llinás, *I of the Vortex* (2001) — House's direct intellectual ancestor"
        XCTAssertEqual(PDFContentBlockRenderer.normalizedGoDeeper(already), already)
    }

    func testGoDeeperLintAcceptsOnlyTheFixedPattern() {
        XCTAssertTrue(GuideSkeletonLint.matchesGoDeeperFormat("**Go Deeper:** Rodolfo Llinás, *I of the Vortex* (2001) — the origin of the motor-first view"))
        XCTAssertFalse(GuideSkeletonLint.matchesGoDeeperFormat("**Go Deeper:** \"I of the Vortex\" by Rodolfo Llinás — the origin"))
        XCTAssertFalse(GuideSkeletonLint.matchesGoDeeperFormat("**Go Deeper:** Rodolfo Llinás, *I of the Vortex* — no year"))
    }

    func testAuthorFirstReferencesAreLinkable() {
        let refs = parseBookReferences(from: "Go Deeper: Nikolai Bernstein, *The Coordination and Regulation of Movements* (1967) — the original formalization")
        XCTAssertEqual(refs.first?.author, "Nikolai Bernstein")
        XCTAssertEqual(refs.first?.title, "The Coordination and Regulation of Movements")
    }

    /// Go Deeper is scarce: require ≥1 across a guide with enough notes, but
    /// reject a stamped footer on every note (cap 6).
    func testGoDeeperValidationIsScarceNotMandatoryPerNote() {
        func notes(_ n: Int, goDeeper: Int) -> String {
            (0..<n).map { i in
                var body = "[INSIGHT_NOTE]\n**Author \(i)** (*Title \(i)*, 2020) corroborates this claim. Prose triangulation without stamped labels.\n"
                if i < goDeeper {
                    body += "**Go Deeper:** Other Author, *Other Title* (2019) — a chapter the note did not cover\n"
                }
                return body + "[/INSIGHT_NOTE]\n"
            }.joined()
        }

        let missing = OutputQualityValidator.validate(content: notes(3, goDeeper: 0), summaryType: .professional)
        XCTAssertTrue(
            missing.issues.contains { $0.localizedCaseInsensitiveContains("at least one Go Deeper") },
            "expected scarcity floor, got: \(missing.issues)"
        )

        let ok = OutputQualityValidator.validate(content: notes(3, goDeeper: 1), summaryType: .professional)
        XCTAssertFalse(ok.issues.contains { $0.localizedCaseInsensitiveContains("Go Deeper") })

        let tooMany = OutputQualityValidator.validate(content: notes(8, goDeeper: 7), summaryType: .professional)
        XCTAssertTrue(
            tooMany.issues.contains { $0.localizedCaseInsensitiveContains("Too many Go Deeper") },
            "expected cap, got: \(tooMany.issues)"
        )
    }

    // MARK: - Skeleton lint

    func testSkeletonLintFlagsMissingBackMatterAndUnnumberedSections() {
        let guide = """
        [QUICK_GLANCE]
        **Core Message:** X.
        - Brains only output movement and consciousness follows that commitment
        [/QUICK_GLANCE]
        [PREMIUM_H2]The Movement Commitment[/PREMIUM_H2]
        Body.
        [TAKEAWAYS]
        - Brains only output movement and consciousness follows that commitment
        [/TAKEAWAYS]
        """
        let issues = GuideSkeletonLint.issues(in: guide)
        XCTAssertTrue(issues.contains { $0.contains("missing Executive Summary") }, "\(issues)")
        XCTAssertTrue(issues.contains { $0.contains("missing Glossary") }, "\(issues)")
        XCTAssertTrue(issues.contains { $0.contains("missing Chapter Map") }, "\(issues)")
        XCTAssertTrue(issues.contains { $0.contains("numbered body sections") }, "\(issues)")
        XCTAssertTrue(issues.contains { $0.contains("restate the Quick Glance") }, "\(issues)")
        XCTAssertTrue(issues.allSatisfy { $0.hasPrefix("Structure:") })
    }

    func testSkeletonLintPassesAWellFormedGuide() {
        let section = { (n: Int, title: String) -> String in
            let filler = Array(repeating: "House argues that the brain's only outputs are movements and that consciousness is what coordination feels like (ch. 3).", count: 55).joined(separator: " ")
            return "[PREMIUM_H2]\(n). \(title)[/PREMIUM_H2]\n*One line descriptor here*\n\n**The claim.** \(filler)\n"
        }
        var guide = """
        [QUICK_GLANCE]
        **Core Message:** Consciousness is downstream of movement.
        - Brains evolved for, are dedicated to, and only output movement
        - Anna's laughter shows confabulation is a feature, not a bug
        [/QUICK_GLANCE]
        [PREMIUM_H2]About the Book and Author[/PREMIUM_H2]
        Prose.
        [PREMIUM_H2]Executive Summary[/PREMIUM_H2]
        Prose.

        """
        for (i, t) in ["The Movement Commitment", "The Confabulation Problem", "The Boundary Problem", "The Hard Problem", "Clinical Windows"].enumerated() {
            guide += section(i + 1, t)
        }
        guide += section(6, "Synthesis: The Privileged Position of Movement")
        guide += """
        [PREMIUM_H2]Key Takeaways[/PREMIUM_H2]
        [TAKEAWAYS]
        - When a patient explains their own behaviour, treat the explanation as narrative machinery, not cause (see Section 2)
        - Read deficits in execution separately from deficits in the conscious plan (see Section 1)
        [/TAKEAWAYS]
        [PREMIUM_H2]Exercises[/PREMIUM_H2]
        [EXERCISE_REFLECT: Reconstruct a decision]
        Recall a decision you explained confidently afterward.
        [/EXERCISE_REFLECT]
        [PREMIUM_H2]Glossary[/PREMIUM_H2]
        - **Confabulation** — a plausible but false explanation.
        [PREMIUM_H2]Key Quotations[/PREMIUM_H2]
        [PREMIUM_QUOTE]
        "A briny sac full of trillions of coincidence detectors."
        — ch. 4
        [/PREMIUM_QUOTE]
        [PREMIUM_H2]Chapter Map[/PREMIUM_H2]
        [VISUAL_TABLE: Chapter Map]
        | Chapter | Lens | Guide section |
        | 1. Anna | the case | §1 |
        [/VISUAL_TABLE]
        [PREMIUM_H2]Further Reading[/PREMIUM_H2]
        - Rodolfo Llinás, *I of the Vortex* (2001) — the motor-first ancestor
        """
        let issues = GuideSkeletonLint.issues(in: guide)
        XCTAssertEqual(issues, [], "\(issues)")
    }

    // MARK: - C3: verification agent report handling

    func testProvenanceReportIsParsedFromProseWrappedJSONAndAppliedSafely() {
        let raw = """
        Here is the report:
        {"corrections":[{"find":"Daniel Wolman (*Nature*, \\"A Tale of Two Halves\\")","replace":"David Wolman (*Nature*, \\"The split brain: A tale of two halves\\", 2012)","reason":"author's first name"}],
         "consistency":[{"find":"Anna's laughter in 1998","replace":"Anna's laughter, reported in 1998 after her 1996 surgery","reason":"date"}],
         "unverified":[{"text":"Two-thirds of the brain's neurons are devoted to predictive loops","action":"remove","replacement":"Much of the brain's circuitry is devoted to predictive loops","reason":"no source"},
                       {"text":"[INSIGHT_NOTE]","action":"remove","replacement":"","reason":"must be skipped"},
                       {"text":"nineteen billion cerebellar neurons","action":"keep","replacement":null,"reason":"attributed to House"}]}
        Done.
        """
        let report = AIService.parseProvenanceReport(raw)
        XCTAssertEqual(report.corrections.count, 1)
        XCTAssertEqual(report.consistency.count, 1)
        XCTAssertEqual(report.unverified.count, 3)

        let guide = """
        [INSIGHT_NOTE]
        Daniel Wolman (*Nature*, "A Tale of Two Halves") expands on the clinical implications.
        [/INSIGHT_NOTE]
        Anna's laughter in 1998 shows confabulation. Two-thirds of the brain's neurons are devoted to predictive loops, and nineteen billion cerebellar neurons were resected.
        """
        let outcome = AIService.applyProvenanceReport(report, to: guide)
        XCTAssertEqual(outcome.applied, 3)
        XCTAssertEqual(outcome.skipped, 2, "the tag edit and the 'keep' item are skipped")
        XCTAssertTrue(outcome.guide.contains("David Wolman"))
        XCTAssertTrue(outcome.guide.contains("after her 1996 surgery"))
        XCTAssertFalse(outcome.guide.contains("Two-thirds"))
        XCTAssertTrue(outcome.guide.contains("[INSIGHT_NOTE]"), "tags must never be edited away")
        XCTAssertEqual(AIService.parseProvenanceReport("not json at all").corrections.count, 0)
    }

    func testQuickGlanceTakeawayOverlapIsLowForActionableTakeaways() {
        let guide = """
        [QUICK_GLANCE]
        - Brains evolved for, are dedicated to, and only output movement
        - Multiple frameworks each explain some phenomena and fail on others
        [/QUICK_GLANCE]
        [TAKEAWAYS]
        - Treat a patient's self-report as evidence about narrative machinery, not a readout of cause (see Section 2)
        - Before adopting a theory, list the clinical cases it must pass (see Section 6)
        [/TAKEAWAYS]
        """
        let overlap = GuideSkeletonLint.quickGlanceTakeawayOverlap(in: guide) ?? 1
        XCTAssertLessThan(overlap, 0.3)
    }
}
