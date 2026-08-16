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

    /// Copied from the "Available visual types" catalogue in
    /// InsightAtlasPrompt.swift. Prompt and parser must move together.
    private static let documentedPayloads: [(tag: String, lines: [String])] = [
        ("VISUAL_SPECTRUM", ["Rigid control → Open willingness", "White-knuckling through fear", "Tolerating discomfort", "Acting alongside fear"]),
        ("VISUAL_TIMELINE", ["1952: Existential therapy emerges — May publishes on anxiety", "1979: Cognitive turn — Beck formalises schema work"]),
        ("VISUAL_TABLE", ["Dimension | Cognitive therapy | Narrative therapy", "Unit of change | Distorted thought | Dominant story", "Therapist stance | Expert guide | Curious collaborator"]),
        ("VISUAL_MATRIX", ["Dimension | Short-term work | Long-term work", "Focus | Symptom relief | Identity revision", "Typical length | 8 sessions | 18 months"]),
        ("VISUAL_COMPARISON", ["Aspect | Acceptance | Avoidance", "Stance toward fear | Makes room for it | Pushes it away", "Long-term cost | Short discomfort | Narrowing life"]),
        ("VISUAL_COMPARISON_TABLE", ["Aspect | Group format | Individual format", "Pace | Set by cohort | Set by client"]),
        ("VISUAL_BEFORE_AFTER", ["Aspect | Before | After", "Response to criticism | Immediate defence | Pause and consider"]),
        ("VISUAL_FLOWCHART", ["Trigger event occurs", "Automatic thought arises", "Thought taken as literal truth", "Behaviour narrows"]),
        ("VISUAL_PROCESS", ["Notice the sensation", "Name what it is", "Allow it to be present"]),
        ("VISUAL_FLOW_DIAGRAM", ["Client reports symptom", "Clinician maps the pattern", "Pattern tested against evidence"]),
        ("VISUAL_BRIDGE", ["Avoiding difficult conversations", "Practising one small disclosure", "Speaking candidly under pressure"]),
        ("VISUAL_CONCEPT_MAP", ["Central: Psychological flexibility", "Contact with the present moment", "Values-guided action", "Cognitive defusion"]),
        ("VISUAL_MINDMAP", ["Central: The inner critic", "Inherited family voices", "Cultural standards", "Protective intent"]),
        ("VISUAL_ORBIT", ["Central: The observing self", "Thoughts passing through", "Emotions rising and falling", "Bodily sensation"]),
        ("VISUAL_BAR_CHART", ["Sessions completed: 42", "Sessions cancelled: 9"]),
        ("VISUAL_BAR_CHART_STACKED", ["Week 1, Week 2, Week 3", "Practice minutes: 30, 55, 80", "Avoidance episodes: 6, 4, 1"]),
        ("VISUAL_BAR_CHART_GROUPED", ["Week 1, Week 2, Week 3", "Practice minutes: 30, 55, 80", "Avoidance episodes: 6, 4, 1"]),
        ("VISUAL_PIE_CHART", ["Therapy alliance: 45", "Client factors: 30", "Technique: 25"]),
        ("VISUAL_LINE_CHART", ["2020: 12", "2021: 19", "2022: 27"]),
        ("VISUAL_AREA_CHART", ["2020: 12", "2021: 19", "2022: 27"]),
        ("VISUAL_FUNNEL", ["Referred: 1000", "Assessed: 400", "Completed treatment: 120"]),
        ("VISUAL_GAUGE", ["Current distress rating: 72", "Target range: 40"]),
        ("VISUAL_TREEMAP", ["Rumination: 40", "Avoidance: 25", "Self-criticism: 18"]),
        ("VISUAL_BUBBLE", ["Perfectionism, 2, 3, 40", "People-pleasing, 5, 1, 15"]),
        ("VISUAL_INFOGRAPHIC", ["Adults reporting impostor feelings: 62", "Who never disclose it: 75"]),
        ("VISUAL_SCATTER_PLOT", ["3.2, 4.5, High practice and high change", "5.1, 2.8, High practice and low change"]),
        ("VISUAL_QUADRANT", ["Quadrant: Urgent and important", "Crisis contact with a client", "Quadrant: Important, not urgent", "Weekly supervision"]),
        ("VISUAL_VENN", ["Shame: hiding, self-attack", "Guilt: repair, apology", "Intersection: painful self-evaluation"]),
        ("VISUAL_GANTT", ["Assessment phase | 0 | 3", "Skills practice | 2 | 8"]),
        ("VISUAL_NETWORK", ["Node: Avoidance | maintaining", "Node: Anxiety | presenting", "Link: Avoidance -> Anxiety"]),
        ("VISUAL_FISHBONE", ["Effect: Treatment dropout", "Practical barriers: cost, travel, scheduling", "Relational barriers: weak alliance, mismatch of goals"]),
        ("VISUAL_SWOT", ["Strengths: strong alliance, client motivation", "Weaknesses: limited session count", "Opportunities: group follow-up", "Threats: relapse without support"]),
        ("VISUAL_SANKEY", ["Referrals -> Assessment: 400", "Assessment -> Treatment: 260"]),
        ("VISUAL_HEATMAP", ["Morning, Afternoon, Evening", "Rumination: 3, 7, 9", "Avoidance: 5, 2, 8"]),
        ("VISUAL_PYRAMID", ["Daily practice", "Weekly reflection", "Values clarification"]),
        ("VISUAL_ICEBERG", ["Snapping at a colleague", "Belief that rest must be earned", "Fear of being seen as lazy"]),
        ("VISUAL_LADDER", ["Naming the feeling", "Sitting with it briefly", "Acting while it is present"]),
        ("VISUAL_CYCLE", ["Worry rises", "Reassurance sought", "Relief is brief", "Worry returns stronger"]),
        ("VISUAL_HIERARCHY", ["Dominant personal narrative", "Societal narratives about productivity", "Family narratives about loyalty", "Individual remembered events"]),
        ("VISUAL_RADAR", ["Emotional awareness", "Distress tolerance", "Values clarity"]),
        ("VISUAL_STORYBOARD", ["Noticing the urge: the moment avoidance begins", "Choosing differently: acting on the value instead"]),
        ("VISUAL_JOURNEY_MAP", ["Stage: First contact | apprehensive", "Intake call", "First session", "Stage: Consolidation | steadier", "Relapse-prevention planning"])
        // VISUAL_GENERIC is excluded: generic IS its payload.
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
