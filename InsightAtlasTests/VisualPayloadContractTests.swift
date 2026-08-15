import XCTest
@testable import InsightAtlas

/// The generation prompt documents an exact payload format for every visual
/// type. If a renderer cannot parse its own documented format, the visual
/// degrades to `.generic` and its payload is drawn as a plain text box -- which
/// is what made generated guides look broken.
///
/// These cases are copied from the "Available visual types" catalogue in
/// InsightAtlasPrompt.swift. Prompt and parser must move together: change one
/// without the other and this fails.
final class VisualPayloadContractTests: XCTestCase {

    private static let documentedPayloads: [(tag: String, lines: [String])] = [
        ("VISUAL_SPECTRUM", ["Left pole → Right pole", "Item nearer the left", "Item in the middle", "Item nearer the right"]),
        ("VISUAL_TIMELINE", ["1945: Event name — what happened", "1962: Event name — what happened"]),
        ("VISUAL_TABLE", ["Column A | Column B | Column C", "Row 1 cell | Row 1 cell | Row 1 cell"]),
        ("VISUAL_MATRIX", ["Dimension | Option A | Option B", "Cost | Low | High"]),
        ("VISUAL_COMPARISON", ["Aspect | First concept | Second concept", "Focus | Present moment | Past causes"]),
        ("VISUAL_COMPARISON_TABLE", ["Aspect | Option A | Option B", "Duration | 8 weeks | 12 weeks"]),
        ("VISUAL_BEFORE_AFTER", ["Aspect | Before | After", "Response to anxiety | Avoidance | Willingness"]),
        ("VISUAL_FLOWCHART", ["First step", "Second step", "Third step"]),
        ("VISUAL_PROCESS", ["First step", "Second step"]),
        ("VISUAL_FLOW_DIAGRAM", ["First step", "Second step"]),
        ("VISUAL_BRIDGE", ["Current state", "Intervening move", "Desired state"]),
        ("VISUAL_CONCEPT_MAP", ["Central: The core idea", "First related concept", "Second related concept"]),
        ("VISUAL_MINDMAP", ["Central: The core idea", "First branch", "Second branch"]),
        ("VISUAL_ORBIT", ["Central: The core idea", "First orbiting element", "Second orbiting element"]),
        ("VISUAL_BAR_CHART", ["First label: 42", "Second label: 71"]),
        ("VISUAL_BAR_CHART_STACKED", ["Week 1, Week 2, Week 3", "Practice: 3, 5, 8", "Avoidance: 6, 4, 1"]),
        ("VISUAL_BAR_CHART_GROUPED", ["Week 1, Week 2, Week 3", "Practice: 3, 5, 8", "Avoidance: 6, 4, 1"]),
        ("VISUAL_PIE_CHART", ["First segment: 45", "Second segment: 30", "Third segment: 25"]),
        ("VISUAL_LINE_CHART", ["2020: 12", "2021: 19"]),
        ("VISUAL_AREA_CHART", ["2020: 12", "2021: 19"]),
        ("VISUAL_FUNNEL", ["Awareness: 1000", "Consideration: 400", "Commitment: 120"]),
        ("VISUAL_GAUGE", ["Current reading: 72", "Healthy range: 60"]),
        ("VISUAL_TREEMAP", ["First item: 40", "Second item: 25"]),
        ("VISUAL_BUBBLE", ["First bubble, 2, 3, 40", "Second bubble, 5, 1, 15"]),
        ("VISUAL_INFOGRAPHIC", ["First statistic: 62", "Second statistic: 75"]),
        ("VISUAL_SCATTER_PLOT", ["3.2, 4.5, First point label", "5.1, 2.8, Second point label"]),
        ("VISUAL_QUADRANT", ["Quadrant: High urgency, high importance", "Do it now",
                             "Quadrant: Low urgency, high importance", "Schedule it"]),
        ("VISUAL_VENN", ["First set: item one, item two", "Second set: item three, item four", "Intersection: shared item"]),
        ("VISUAL_GANTT", ["Task name | 0 | 3", "Second task | 2 | 4"]),
        ("VISUAL_NETWORK", ["Node: First concept | group A", "Node: Second concept | group B",
                            "Link: First concept -> Second concept"]),
        ("VISUAL_FISHBONE", ["Effect: The outcome being explained", "Category one: cause A, cause B",
                             "Category two: cause C, cause D"]),
        ("VISUAL_SWOT", ["Strengths: first strength, second strength", "Weaknesses: first weakness",
                         "Opportunities: first opportunity", "Threats: first threat"]),
        ("VISUAL_SANKEY", ["Source -> Destination: 40", "Source -> Other destination: 60"]),
        ("VISUAL_HEATMAP", ["Column A, Column B, Column C", "Row label: 3, 7, 1", "Second row: 5, 2, 8"]),
        ("VISUAL_PYRAMID", ["Base layer", "Middle layer", "Top layer"]),
        ("VISUAL_ICEBERG", ["Visible behaviour", "Underlying belief", "Core assumption"]),
        ("VISUAL_LADDER", ["First level", "Second level", "Third level"]),
        ("VISUAL_CYCLE", ["First stage", "Second stage", "Third stage"]),
        ("VISUAL_HIERARCHY", ["Root concept", "First child", "Second child"]),
        ("VISUAL_RADAR", ["First dimension", "Second dimension", "Third dimension"]),
        ("VISUAL_STORYBOARD", ["First scene: what happens", "Second scene: what happens next"]),
        ("VISUAL_JOURNEY_MAP", ["Stage: Awareness | curious", "First touchpoint", "Second touchpoint", "Stage: Commitment | resolved", "Third touchpoint"])
        // VISUAL_GENERIC is deliberately excluded: generic IS its payload.
    ]

    private func isGeneric(_ payload: InsightVisualPayload?) -> Bool {
        if case .generic = payload { return true }
        return false
    }

    /// The load-bearing test. A failure here names a visual type whose
    /// documented payload the renderer cannot read -- exactly the condition that
    /// makes a visual render as a raw text box in the app.
    func testEveryDocumentedPayloadParsesToATypedVisual() {
        var unparsed: [String] = []

        for (tag, lines) in Self.documentedPayloads {
            let visual = InsightVisualParser.parse(tag: tag, title: "Title", lines: lines)
            if visual == nil || isGeneric(visual?.payload) {
                unparsed.append(tag)
            }
        }

        XCTAssertTrue(
            unparsed.isEmpty,
            "These types degrade to a raw text box on their own documented payload: \(unparsed.joined(separator: ", "))"
        )
    }

    /// Every documented tag must resolve to a renderer, directly or by alias.
    func testEveryDocumentedTagResolves() {
        for (tag, _) in Self.documentedPayloads {
            let canonical = InsightVisualParser.tagAliases[tag] ?? tag
            XCTAssertNotNil(
                InsightVisualType(rawValue: canonical),
                "\(tag) resolves to \(canonical), which has no renderer"
            )
        }
    }

    /// A prose payload -- the shape the prompt used to ask for -- is exactly what
    /// produced unreadable output. It must still degrade safely rather than crash.
    func testProsePayloadDegradesWithoutCrashing() {
        for (tag, _) in Self.documentedPayloads {
            _ = InsightVisualParser.parse(
                tag: tag,
                title: "Title",
                lines: ["A descriptive sentence that carries no structure at all."]
            )
        }
    }
}
