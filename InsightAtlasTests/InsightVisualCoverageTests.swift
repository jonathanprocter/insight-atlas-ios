import XCTest
@testable import InsightAtlas

/// Every visual tag the prompt can emit must reach a typed renderer, and the
/// loose payload formats the prompt specifies must actually parse. A tag that
/// resolves but whose payload does not parse degrades to `.generic`, which is
/// how raw pole labels ended up spliced into guide prose.
final class InsightVisualCoverageTests: XCTestCase {

    /// Tags that appear in the prompt but are not visual content blocks.
    private let nonVisualTags: Set<String> = [
        "VISUAL_TYPE",
        "VISUAL_FIRST_BLOCK",
        "VISUAL_DENSITY_EXCEEDED",
        "VISUAL_ZONE_VIOLATION"
    ]

    /// The visual vocabulary the generation prompt advertises.
    private let promptTags = [
        "VISUAL_AREA_CHART", "VISUAL_BAR_CHART", "VISUAL_BAR_CHART_GROUPED",
        "VISUAL_BAR_CHART_STACKED", "VISUAL_BEFORE_AFTER", "VISUAL_BRIDGE",
        "VISUAL_BUBBLE", "VISUAL_COMPARISON", "VISUAL_COMPARISON_MATRIX",
        "VISUAL_COMPARISON_TABLE", "VISUAL_CONCEPT_MAP", "VISUAL_CYCLE",
        "VISUAL_FISHBONE", "VISUAL_FLOW_DIAGRAM", "VISUAL_FLOWCHART",
        "VISUAL_FUNNEL", "VISUAL_GANTT", "VISUAL_GAUGE", "VISUAL_GENERIC",
        "VISUAL_HEATMAP", "VISUAL_HIERARCHY", "VISUAL_ICEBERG",
        "VISUAL_INFOGRAPHIC", "VISUAL_JOURNEY_MAP", "VISUAL_LADDER",
        "VISUAL_LINE_CHART", "VISUAL_MATRIX", "VISUAL_MINDMAP",
        "VISUAL_NETWORK", "VISUAL_ORBIT", "VISUAL_PIE_CHART", "VISUAL_PROCESS",
        "VISUAL_PYRAMID", "VISUAL_QUADRANT", "VISUAL_RADAR", "VISUAL_SANKEY",
        "VISUAL_SCATTER_PLOT", "VISUAL_SPECTRUM", "VISUAL_STORYBOARD",
        "VISUAL_SWOT", "VISUAL_TABLE", "VISUAL_TIMELINE", "VISUAL_TREEMAP",
        "VISUAL_VENN"
    ]

    /// No prompt tag may fall through to the raw-text path.
    func testEveryPromptVisualTagResolvesToARenderer() {
        for tag in promptTags where !nonVisualTags.contains(tag) {
            let canonical = InsightVisualParser.tagAliases[tag] ?? tag
            XCTAssertNotNil(
                InsightVisualType(rawValue: canonical),
                "\(tag) resolves to \(canonical), which has no renderer"
            )
        }
    }

    func testAliasesPointAtRealTypes() {
        for (alias, canonical) in InsightVisualParser.tagAliases {
            XCTAssertNotNil(
                InsightVisualType(rawValue: canonical),
                "alias \(alias) points at unknown type \(canonical)"
            )
            XCTAssertNil(
                InsightVisualType(rawValue: alias),
                "\(alias) has its own renderer and should not be aliased"
            )
        }
    }

    // MARK: - Spectrum

    /// The payload shape the prompt asks for: poles on an arrow line, then items.
    func testSpectrumParsesArrowPolesAndItems() {
        let data = InsightVisualParser.parseSpectrum([
            "Full immersion in mineness and anxiety → Tranquilization through generalizations",
            "Sober anxiety",
            "Flight into busy-ness"
        ])

        XCTAssertEqual(data?.leftPole, "Full immersion in mineness and anxiety")
        XCTAssertEqual(data?.rightPole, "Tranquilization through generalizations")
        XCTAssertEqual(data?.items.count, 2)
        XCTAssertEqual(data?.items.first?.label, "Sober anxiety")
    }

    func testSpectrumAcceptsAlternateSeparators() {
        for separator in ["->", "↔", "<->", " vs "] {
            let data = InsightVisualParser.parseSpectrum(["Inauthentic\(separator)Authentic"])
            XCTAssertEqual(data?.leftPole, "Inauthentic", "failed for separator \(separator)")
            XCTAssertEqual(data?.rightPole, "Authentic", "failed for separator \(separator)")
        }
    }

    func testSpectrumDistributesUnpositionedItemsAcrossTheRange() {
        let data = InsightVisualParser.parseSpectrum([
            "Left → Right", "First", "Middle", "Last"
        ])
        XCTAssertEqual(data?.items.map(\.position), [0, 0.5, 1])
    }

    func testSpectrumHonorsExplicitPositions() {
        let percent = InsightVisualParser.parseSpectrum(["Left → Right", "Anxiety: 70%"])
        XCTAssertEqual(percent?.items.first?.label, "Anxiety")
        XCTAssertEqual(percent?.items.first?.position ?? 0, 0.7, accuracy: 0.001)

        let fraction = InsightVisualParser.parseSpectrum(["Left → Right", "Anxiety: 0.25"])
        XCTAssertEqual(fraction?.items.first?.position ?? 0, 0.25, accuracy: 0.001)
    }

    func testSpectrumStripsBulletMarkers() {
        let data = InsightVisualParser.parseSpectrum(["Left → Right", "- Bulleted item"])
        XCTAssertEqual(data?.items.first?.label, "Bulleted item")
    }

    func testSpectrumSingleItemSitsInTheMiddle() {
        let data = InsightVisualParser.parseSpectrum(["Left → Right", "Only one"])
        XCTAssertEqual(data?.items.first?.position, 0.5)
    }

    /// A colon that is part of the prose must not be mistaken for a position.
    func testSpectrumKeepsNonNumericColonSuffixes() {
        let data = InsightVisualParser.parseSpectrum([
            "Left → Right",
            "Heidegger: the they-self"
        ])
        XCTAssertEqual(data?.items.first?.label, "Heidegger: the they-self")
    }

    func testSpectrumWithoutPolesIsRejected() {
        XCTAssertNil(InsightVisualParser.parseSpectrum(["Just one line", "And another"]))
        XCTAssertNil(InsightVisualParser.parseSpectrum([]))
    }

    /// End to end: the tag plus a prompt-shaped payload must produce a spectrum
    /// payload, not the generic text dump.
    func testSpectrumTagProducesSpectrumPayloadNotGeneric() {
        let visual = InsightVisualParser.parse(
            tag: "VISUAL_SPECTRUM",
            title: "Modes of Being",
            lines: ["Inauthentic → Authentic", "Flight into busy-ness", "Sober anxiety"]
        )
        guard case .spectrum(let data)? = visual?.payload else {
            return XCTFail("expected a spectrum payload, got \(String(describing: visual?.payload))")
        }
        XCTAssertEqual(data.leftPole, "Inauthentic")
        XCTAssertEqual(data.items.count, 2)
    }
}
