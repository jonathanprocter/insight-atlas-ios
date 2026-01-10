//
//  InsightAtlasThematicPrompt.swift
//  InsightAtlas
//
//  Canonical prompt for generating comprehensive thematic book syntheses.
//  This is the authoritative Insight Atlas Synthesis Engine prompt.
//

import Foundation

/// Generates the canonical Insight Atlas thematic synthesis prompt.
/// This is the primary prompt for generating comprehensive book analyses.
struct InsightAtlasThematicPromptGenerator {

    // MARK: - Public Interface

    /// Generate the complete system prompt for thematic synthesis generation.
    /// - Parameters:
    ///   - title: The book title (optional, extracted from document if not provided)
    ///   - author: The book author (optional, extracted from document if not provided)
    /// - Returns: The complete system prompt string
    static func generateSystemPrompt(
        title: String? = nil,
        author: String? = nil
    ) -> String {
        return buildCanonicalPrompt(title: title, author: author)
    }

    /// Generate the user message for the AI.
    /// - Parameters:
    ///   - documentText: The complete book/document text
    ///   - title: The book title
    ///   - author: The book author
    /// - Returns: The user message string
    static func generateUserMessage(
        documentText: String,
        title: String,
        author: String
    ) -> String {
        return """
        Here is the complete text of "\(title)" by \(author) to synthesize:

        \(documentText)

        Generate the complete Insight Atlas synthesis now. Deliver the full JSON output with all sections populated with rigorous, proprietary analysis. Do not abbreviate or provide surface-level content.
        """
    }

    // MARK: - Private Implementation

    private static func buildCanonicalPrompt(title: String?, author: String?) -> String {
        let titlePlaceholder = title ?? "{book title}"
        let authorPlaceholder = author ?? "{book author}"

        return """
        You are the Insight Atlas Synthesis Engine—a world-class system for transmuting books into strategic intelligence. You do not merely summarize; you synthesize, critique, and contextualize, creating a new asset that makes your user smarter than the book itself. Your output is a proprietary analysis that services like Shortform, Blinkist, and getAbstract cannot replicate.

        DOCUMENT TO SYNTHESIZE:
        [Complete uploaded document - synthesize the ENTIRE work, not a truncated portion]

        [BOOK TITLE: \(titlePlaceholder)]
        [BOOK AUTHOR: \(authorPlaceholder)]

        ═══════════════════════════════════════════════════════════════════════════════
        CORE PHILOSOPHY: BEYOND SUMMARY, TOWARD SYNTHESIS
        ═══════════════════════════════════════════════════════════════════════════════

        Insight Atlas is an intellectual partner. We operate on these principles:

        • **FROM COMPRESSION TO SYNTHESIS**: We don't just shrink knowledge; we connect it. We build bridges between the book's ideas and the broader intellectual landscape.
        • **DUAL-HORIZON ANALYSIS**: Every concept receives both granular explanation (the trees) and strategic synthesis (the forest), revealing patterns the author may not have explicitly stated.
        • **ACTIVE INTELLECTUAL ENGAGEMENT**: We are not passive scribes. We provide commentary, critique, and multi-disciplinary connections that create new value.
        • **STRATEGIC APPLICATION**: We frame all insights around "What strategic choices does this enable?" moving beyond mere tactical tips.
        • **INTELLECTUAL HONESTY & RIGOR**: We surface limitations, contradictions, unresolved debates, and the author's potential blindspots as a core feature.
        • **ADAPTIVE DEPTH**: We provide multiple, curated pathways for engagement, from a 90-second strategic overview to a 60-minute deep dive into the intellectual foundations.

        ═══════════════════════════════════════════════════════════════════════════════
        OUTPUT ARCHITECTURE: THE INSIGHT ATLAS SYNTHESIS
        ═══════════════════════════════════════════════════════════════════════════════

        Generate your guide in the following mandatory structure. Each section is a layer of analysis, designed for a specific cognitive purpose.

        ───────────────────────────────────────────────────────────────────────────────
        SECTION 1: STRATEGIC BRIEFING (The "I Have 90 Seconds" Tier)
        ───────────────────────────────────────────────────────────────────────────────

        ## 1.1 The Guide's Thesis
        Your unique thesis about the book's core importance. What is the single most critical insight this guide offers that isn't obvious from the book's cover?
        *Format: "This book is ostensibly about [Topic], but its true significance lies in [Your Deeper Insight], making it essential for [Target Audience] who need to [Strategic Goal]."*

        ## 1.2 The One-Paragraph Executive Briefing (150-200 words)
        The core intelligence. Include:
        - The central problem & its strategic importance.
        - The author's core solution/framework.
        - The most powerful piece of evidence.
        - The primary strategic implication for a sophisticated reader.

        ## 1.3 The 3 Actionable Insights
        Three non-obvious, high-leverage takeaways that can be immediately applied.
        *Format each as: "Strategic Lever: [Insight] | Unlocks: [New Capability/Advantage]"*

        ## 1.4 Premium Metadata
        - **Intellectual Pedigree**: e.g., "Builds on 40 years of research in behavioral economics, challenging the rational actor model."
        - **Controversy Level**: [Mainstream Consensus | Actively Debated | Contrarian View | Frontier Science]
        - **Applicability Score**: [High for Individuals | High for Teams | High for Organizations]
        - **Difficulty**: e.g., "Conceptually accessible, but requires significant discipline to implement."

        ───────────────────────────────────────────────────────────────────────────────
        SECTION 2: THE INTELLECTUAL LANDSCAPE (The "Where This Fits" Layer)
        ───────────────────────────────────────────────────────────────────────────────

        ## 2.1 The Intellectual Ecosystem (The Knowledge Graph)
        Visually describe a concept map that places this book within the broader world of ideas. Identify 10-15 related concepts from other fields (e.g., complexity theory, behavioral economics, systems thinking, neuroscience) and describe the connections.

        ## 2.2 The Knowledge Lineage
        Show the evolution of ideas. This is NOT a simple reading list.
        *Format:*
        - **FOUNDATIONAL LAYER (Read First)**: [Book A], which established the core paradigm.
        - **DEVELOPMENT LAYER (Builds On)**: [Book B], which extended it; [Book C], which challenged it.
        - **FRONTIER LAYER (Cutting Edge)**: [Book D], which represents the current state of the debate.

        ## 2.3 The Author's Lens
        - **Credibility & Expertise**: What gives the author the right to speak on this?
        - **Potential Blindspots**: What in the author's background (e.g., industry, ideology, training) might limit their perspective? What do they likely fail to see?

        ───────────────────────────────────────────────────────────────────────────────
        SECTION 3: THE CORE SYNTHESIS (The Big Ideas, Reimagined)
        ───────────────────────────────────────────────────────────────────────────────

        Identify 4-6 MAJOR THEMES. For each theme:

        ## Theme [X]: [Theme Title]

        ### The Core Insight (The "What")
        2-3 paragraphs explaining the idea with clarity and precision. Use the book's best examples.

        ### Insight Atlas Synthesis & Analysis (The "So What")
        [Bracketed analysis that creates proprietary value. This is the core of your work.]

        Types of Synthesis to include:
        - **[Synthesis: Cross-Disciplinary Connection]**: "This parallels the concept of 'emergence' in complexity theory, suggesting that..."
        - **[Synthesis: Second-Order Implication]**: "If this is true, the unstated consequence is that traditional performance reviews are not just ineffective, but actively harmful because..."
        - **[Synthesis: Pattern Recognition]**: "This is the third book in the last five years to converge on this idea from different starting points (see [Book X], [Book Y]), which indicates a major paradigm shift is underway."
        - **[Critique: Flawed Assumption]**: "The author's entire argument rests on the assumption that [X] is true. However, recent research from [Source] suggests this assumption is weak, meaning the framework may only apply under [Specific Conditions]."
        - **[Critique: Alternative Explanation]**: "An alternative explanation for this phenomenon, proposed by [Expert], is that [Alternative Theory], which accounts for the data without requiring us to accept the author's more radical claim."

        ### The Scholarly Deep Dive (For the Intellectually Curious)
        A 300-word exploration of the academic context.
        - What are the methodological underpinnings of the key studies?
        - What is the statistical significance or effect size of the findings?
        - Where is the academic field genuinely uncertain?

        ### The Insight Atlas Synthesis Framework (Proprietary Value)
        Create a NEW, original framework (e.g., 2x2 matrix, decision tree, flow model) that synthesizes the book's ideas with other concepts to create a practical tool.
        *Example: For a book on habits, create a 2x2 matrix with axes of "Effort to Start" and "Impact on Goals" and plot the book's strategies within it, providing a new diagnostic tool.*

        ### Perspectives from the Field
        Brief (100-word) opposing or complementary viewpoints from:
        - **A Researcher**: What does the latest data say?
        - **A Practitioner**: How does this play out in the real world?
        - **A Critic**: What is the strongest counterargument?

        ───────────────────────────────────────────────────────────────────────────────
        SECTION 4: ADAPTIVE IMPLEMENTATION (The "How To" Layer, Personalized)
        ───────────────────────────────────────────────────────────────────────────────

        ## 4.1 The Insight Atlas Diagnostic
        Create a 5-7 question assessment to help the reader diagnose their current state and identify which parts of the guide are most relevant to them.

        ## 4.2 Adaptive Implementation Pathways
        Provide 2-3 distinct pathways based on reader context. This replaces a generic 30-day plan.
        *Format:*
        **Pathway 1: The Corporate Leader (5 hours/week)**
        - **Week 1 Focus**: Diagnosing team dynamics using the [Book's Framework].
        - **Key Action**: Run the [Specific Exercise] in your next team meeting.
        - **Success Metric**: Reduction in meeting time spent on status updates by 20%.

        **Pathway 2: The Startup Founder (10 hours/week)**
        - **Week 1 Focus**: Applying the [Book's Framework] to customer discovery.
        - **Key Action**: Re-write 3 customer interview questions using the [Insight].
        - **Success Metric**: Uncovering 2 new, non-obvious customer pain points.

        ## 4.3 Resistance & Obstacles
        Go beyond "common mistakes." Analyze the barriers.
        - **Psychological Barriers**: (e.g., Confirmation Bias, Imposter Syndrome)
        - **Organizational Barriers**: (e.g., Legacy Systems, Misaligned Incentives)
        - **Systemic Barriers**: (e.g., Market Pressures, Regulatory Hurdles)
        For each, provide diagnostic questions and specific interventions.

        ───────────────────────────────────────────────────────────────────────────────
        SECTION 5: CRITICAL ANALYSIS & VERDICT (The "Think For Yourself" Layer)
        ───────────────────────────────────────────────────────────────────────────────

        ## 5.1 Strengths & Novel Contributions
        What does this book get uniquely right? What is its single most important contribution to the conversation?

        ## 5.2 Limitations & Unquestioned Assumptions
        What are the 2-3 core assumptions the author makes that might be flawed? In what specific contexts would this book's advice be dangerous or counterproductive?

        ## 5.3 The Unresolved Debates
        What major questions remain unanswered? Where does this book fall short of providing a complete picture?

        ## 5.4 The Verdict with Nuance
        - **Read this book if...** [you are in X situation and need to achieve Y].
        - **The most valuable takeaway is...** [the single most important insight].
        - **Pair this with...** [a specific book that provides a counterpoint or complementary view] to get a complete picture.
        - **Final Assessment**: A definitive, nuanced judgment on the book's strategic value.

        ───────────────────────────────────────────────────────────────────────────────
        SECTION 6: EXTENDED INTELLIGENCE (The "Go Deeper" Layer)
        ───────────────────────────────────────────────────────────────────────────────

        ## 6.1 Real-World Case Studies
        Provide 2 detailed case studies (positive or negative) of the book's ideas in action. Include metrics and specific outcomes.

        ## 6.2 The 5-Year Forecast
        Based on the book's logic, what are 3 plausible, non-obvious predictions for the next 5 years in the relevant field?

        ## 6.3 Glossary of Key Concepts
        A glossary of terms, but with added synthesis on why each term matters strategically.

        ## 6.4 Strategic Conversation Prompts
        Questions designed to spark high-level discussion.
        - "How might this framework change our 3-year strategy?"
        - "What is the biggest threat to our business if our competitors master this before we do?"
        - "If we accept the author's premise, what is one thing we must STOP doing immediately?"

        ═══════════════════════════════════════════════════════════════════════════════
        TONE & VOICE CALIBRATION
        ═══════════════════════════════════════════════════════════════════════════════

        Your voice is that of an **authoritative yet accessible intellectual partner**. You understand both the academic rigor and the pragmatic realities of application. You are confident, clear, and unafraid to challenge the author, but you do so with respect for the work. You are not a cheerleader; you are a strategist.

        ═══════════════════════════════════════════════════════════════════════════════
        QUALITY STANDARDS & LENGTH
        ═══════════════════════════════════════════════════════════════════════════════

        - **ACCURACY**: Flawless representation of the author's arguments, even when you critique them.
        - **SYNTHESIS**: Your primary goal is to create new connections and insights.
        - **RIGOR**: All claims, especially critiques, are well-reasoned and evidence-based.
        - **ACTIONABILITY**: Every insight is tied to a strategic choice or action.
        - **PROPRIETARY VALUE**: The guide must contain frameworks and analysis not found anywhere else.
        - **TARGET LENGTH**: 15,000-25,000 words. Let the need for intellectual rigor, not the word count, drive the final length.

        ═══════════════════════════════════════════════════════════════════════════════
        OUTPUT FORMAT: JSON SCHEMA v3.0
        ═══════════════════════════════════════════════════════════════════════════════

        Return the complete guide as a single, structured JSON object matching the following schema:

        \(jsonSchema)
        """
    }

    // MARK: - JSON Schema

    private static let jsonSchema = """
    {
      "metadata": {
        "bookTitle": "string",
        "author": "string",
        "publicationYear": "number (optional)",
        "guidesThesis": "string",
        "premiumMetadata": {
          "intellectualPedigree": "string",
          "controversyLevel": "string (Mainstream Consensus | Actively Debated | Contrarian View | Frontier Science)",
          "applicabilityScore": "string (High for Individuals | High for Teams | High for Organizations)",
          "difficulty": "string"
        }
      },
      "strategicBriefing": {
        "executiveBriefing": "string (150-200 words)",
        "actionableInsights": [
          {
            "strategicLever": "string",
            "unlocks": "string"
          }
        ]
      },
      "intellectualLandscape": {
        "knowledgeGraphDescription": "string",
        "knowledgeLineage": {
          "foundational": [{"book": "string", "contribution": "string"}],
          "development": [{"book": "string", "contribution": "string"}],
          "frontier": [{"book": "string", "contribution": "string"}]
        },
        "authorsLens": {
          "credibility": "string",
          "potentialBlindspots": "string"
        }
      },
      "coreSynthesis": [
        {
          "themeNumber": "number",
          "themeTitle": "string",
          "coreInsight": "string (2-3 paragraphs)",
          "insightAtlasAnalysis": [
            {
              "type": "string (Synthesis: Cross-Disciplinary Connection | Synthesis: Second-Order Implication | Synthesis: Pattern Recognition | Critique: Flawed Assumption | Critique: Alternative Explanation)",
              "content": "string"
            }
          ],
          "scholarlyDeepDive": "string (300 words)",
          "insightAtlasFramework": {
            "type": "string (2x2 Matrix | Decision Tree | Flow Model | Spectrum | Hierarchy)",
            "description": "string",
            "elements": "object (flexible structure based on framework type)",
            "howToUse": "string"
          },
          "perspectivesFromTheField": [
            {
              "perspective": "string (Researcher | Practitioner | Critic)",
              "viewpoint": "string (100 words)"
            }
          ]
        }
      ],
      "adaptiveImplementation": {
        "diagnosticAssessment": [
          {
            "question": "string",
            "options": ["string"]
          }
        ],
        "implementationPathways": [
          {
            "pathwayTitle": "string",
            "weeklyPlan": [
              {
                "week": "number",
                "focus": "string",
                "keyAction": "string",
                "successMetric": "string"
              }
            ]
          }
        ],
        "resistanceAndObstacles": [
          {
            "barrierType": "string (Psychological | Organizational | Systemic)",
            "description": "string",
            "intervention": "string"
          }
        ]
      },
      "criticalAnalysisAndVerdict": {
        "strengthsAndContributions": "string",
        "limitationsAndAssumptions": "string",
        "unresolvedDebates": "string",
        "nuancedVerdict": {
          "readThisIf": "string",
          "mostValuableTakeaway": "string",
          "pairWith": "string",
          "finalAssessment": "string"
        }
      },
      "extendedIntelligence": {
        "caseStudies": [
          {
            "title": "string",
            "situation": "string",
            "application": "string",
            "outcome": "string"
          }
        ],
        "fiveYearForecast": ["string"],
        "strategicGlossary": [
          {
            "term": "string",
            "definition": "string",
            "strategicRelevance": "string"
          }
        ],
        "strategicConversationPrompts": ["string"]
      }
    }
    """
}

// MARK: - Thematic Synthesis Response Models v3.0

/// Root response model for the Insight Atlas Synthesis Engine JSON output
struct ThematicSynthesisResponse: Codable {
    let metadata: SynthesisMetadata
    let strategicBriefing: StrategicBriefing
    let intellectualLandscape: IntellectualLandscape
    let coreSynthesis: [CoreSynthesisTheme]
    let adaptiveImplementation: AdaptiveImplementation
    let criticalAnalysisAndVerdict: CriticalAnalysisAndVerdict
    let extendedIntelligence: ExtendedIntelligence

    // Legacy compatibility properties
    var bookTitle: String { metadata.bookTitle }
    var bookAuthor: String { metadata.author }
}

/// Metadata about the book and guide
struct SynthesisMetadata: Codable {
    let bookTitle: String
    let author: String
    let publicationYear: Int?
    let guidesThesis: String
    let premiumMetadata: PremiumMetadata
}

/// Premium metadata for the guide
struct PremiumMetadata: Codable {
    let intellectualPedigree: String
    let controversyLevel: String
    let applicabilityScore: String
    let difficulty: String
}

/// Strategic briefing section (90-second tier)
struct StrategicBriefing: Codable {
    let executiveBriefing: String
    let actionableInsights: [ActionableInsight]
}

/// An actionable insight with strategic lever
struct ActionableInsight: Codable {
    let strategicLever: String
    let unlocks: String
}

/// Intellectual landscape section
struct IntellectualLandscape: Codable {
    let knowledgeGraphDescription: String
    let knowledgeLineage: KnowledgeLineage
    let authorsLens: AuthorsLens
}

/// Knowledge lineage showing evolution of ideas
struct KnowledgeLineage: Codable {
    let foundational: [BookContribution]
    let development: [BookContribution]
    let frontier: [BookContribution]
}

/// A book and its contribution to the field
struct BookContribution: Codable {
    let book: String
    let contribution: String
}

/// Author's lens including credibility and blindspots
struct AuthorsLens: Codable {
    let credibility: String
    let potentialBlindspots: String
}

/// A core synthesis theme
struct CoreSynthesisTheme: Codable {
    let themeNumber: Int
    let themeTitle: String
    let coreInsight: String
    let insightAtlasAnalysis: [InsightAtlasAnalysis]
    let scholarlyDeepDive: String
    let insightAtlasFramework: InsightAtlasFramework
    let perspectivesFromTheField: [FieldPerspective]
}

/// An Insight Atlas analysis item
struct InsightAtlasAnalysis: Codable {
    let type: String
    let content: String
}

/// A proprietary Insight Atlas framework
struct InsightAtlasFramework: Codable {
    let type: String
    let description: String
    let elements: AnyCodable?
    let howToUse: String
}

/// A perspective from the field
struct FieldPerspective: Codable {
    let perspective: String
    let viewpoint: String
}

/// Adaptive implementation section
struct AdaptiveImplementation: Codable {
    let diagnosticAssessment: [DiagnosticQuestion]
    let implementationPathways: [ImplementationPathway]
    let resistanceAndObstacles: [ResistanceObstacle]
}

/// A diagnostic assessment question
struct DiagnosticQuestion: Codable {
    let question: String
    let options: [String]
}

/// An implementation pathway
struct ImplementationPathway: Codable {
    let pathwayTitle: String
    let weeklyPlan: [WeeklyPlanItem]
}

/// A weekly plan item
struct WeeklyPlanItem: Codable {
    let week: Int
    let focus: String
    let keyAction: String
    let successMetric: String
}

/// A resistance or obstacle
struct ResistanceObstacle: Codable {
    let barrierType: String
    let description: String
    let intervention: String
}

/// Critical analysis and verdict section
struct CriticalAnalysisAndVerdict: Codable {
    let strengthsAndContributions: String
    let limitationsAndAssumptions: String
    let unresolvedDebates: String
    let nuancedVerdict: NuancedVerdict
}

/// Nuanced verdict with specific recommendations
struct NuancedVerdict: Codable {
    let readThisIf: String
    let mostValuableTakeaway: String
    let pairWith: String
    let finalAssessment: String
}

/// Extended intelligence section
struct ExtendedIntelligence: Codable {
    let caseStudies: [CaseStudy]
    let fiveYearForecast: [String]
    let strategicGlossary: [GlossaryEntry]
    let strategicConversationPrompts: [String]
}

/// A case study
struct CaseStudy: Codable {
    let title: String
    let situation: String
    let application: String
    let outcome: String
}

/// A glossary entry
struct GlossaryEntry: Codable {
    let term: String
    let definition: String
    let strategicRelevance: String
}

// MARK: - AnyCodable for flexible JSON elements

/// A type-erased Codable value for flexible JSON structures
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode AnyCodable")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unable to encode AnyCodable"))
        }
    }
}

// MARK: - PDF Document Conversion

extension ThematicSynthesisResponse {

    /// Convert the thematic synthesis response to a PDFAnalysisDocument for PDF rendering
    /// This transforms the JSON-structured thematic analysis into the block-based format
    /// that the PDF renderer expects.
    func toPDFAnalysisDocument() -> PDFAnalysisDocument {
        var sections: [PDFAnalysisDocument.PDFSection] = []

        // 1. Strategic Briefing Section
        var briefingBlocks: [PDFContentBlock] = []

        // Guide's Thesis
        if !metadata.guidesThesis.isEmpty {
            briefingBlocks.append(PDFContentBlock(
                type: .foundationalNarrative,
                content: metadata.guidesThesis,
                metadata: ["title": "Guide's Thesis"]
            ))
        }

        // Executive Briefing
        if !strategicBriefing.executiveBriefing.isEmpty {
            briefingBlocks.append(PDFContentBlock(
                type: .paragraph,
                content: strategicBriefing.executiveBriefing
            ))
        }

        // Actionable Insights
        if !strategicBriefing.actionableInsights.isEmpty {
            briefingBlocks.append(PDFContentBlock(
                type: .heading3,
                content: "3 Actionable Insights"
            ))
            for (index, insight) in strategicBriefing.actionableInsights.enumerated() {
                briefingBlocks.append(PDFContentBlock(
                    type: .actionBox,
                    content: "**Strategic Lever:** \(insight.strategicLever)\n\n**Unlocks:** \(insight.unlocks)",
                    listItems: [insight.strategicLever, insight.unlocks],
                    metadata: ["title": "Insight \(index + 1)"]
                ))
            }
        }

        // Premium Metadata
        let metadataContent = """
        **Intellectual Pedigree:** \(metadata.premiumMetadata.intellectualPedigree)

        **Controversy Level:** \(metadata.premiumMetadata.controversyLevel)

        **Applicability:** \(metadata.premiumMetadata.applicabilityScore)

        **Difficulty:** \(metadata.premiumMetadata.difficulty)
        """
        briefingBlocks.append(PDFContentBlock(
            type: .insightNote,
            content: metadataContent,
            metadata: ["title": "Premium Metadata"]
        ))

        sections.append(PDFAnalysisDocument.PDFSection(
            heading: "Strategic Briefing",
            headingLevel: 1,
            blocks: briefingBlocks
        ))

        // 2. Intellectual Landscape Section
        var landscapeBlocks: [PDFContentBlock] = []

        // Knowledge Graph
        if !intellectualLandscape.knowledgeGraphDescription.isEmpty {
            landscapeBlocks.append(PDFContentBlock(
                type: .heading3,
                content: "The Intellectual Ecosystem"
            ))
            landscapeBlocks.append(PDFContentBlock(
                type: .paragraph,
                content: intellectualLandscape.knowledgeGraphDescription
            ))
        }

        // Knowledge Lineage
        landscapeBlocks.append(PDFContentBlock(
            type: .heading3,
            content: "Knowledge Lineage"
        ))

        // Foundational
        if !intellectualLandscape.knowledgeLineage.foundational.isEmpty {
            var foundationalItems: [String] = []
            for book in intellectualLandscape.knowledgeLineage.foundational {
                foundationalItems.append("**\(book.book)**: \(book.contribution)")
            }
            landscapeBlocks.append(PDFContentBlock(
                type: .bulletList,
                content: "Foundational Layer (Read First)",
                listItems: foundationalItems
            ))
        }

        // Development
        if !intellectualLandscape.knowledgeLineage.development.isEmpty {
            var developmentItems: [String] = []
            for book in intellectualLandscape.knowledgeLineage.development {
                developmentItems.append("**\(book.book)**: \(book.contribution)")
            }
            landscapeBlocks.append(PDFContentBlock(
                type: .bulletList,
                content: "Development Layer (Builds On)",
                listItems: developmentItems
            ))
        }

        // Frontier
        if !intellectualLandscape.knowledgeLineage.frontier.isEmpty {
            var frontierItems: [String] = []
            for book in intellectualLandscape.knowledgeLineage.frontier {
                frontierItems.append("**\(book.book)**: \(book.contribution)")
            }
            landscapeBlocks.append(PDFContentBlock(
                type: .bulletList,
                content: "Frontier Layer (Cutting Edge)",
                listItems: frontierItems
            ))
        }

        // Author's Lens
        landscapeBlocks.append(PDFContentBlock(
            type: .heading3,
            content: "The Author's Lens"
        ))
        landscapeBlocks.append(PDFContentBlock(
            type: .authorSpotlight,
            content: "**Credibility & Expertise:** \(intellectualLandscape.authorsLens.credibility)\n\n**Potential Blindspots:** \(intellectualLandscape.authorsLens.potentialBlindspots)"
        ))

        sections.append(PDFAnalysisDocument.PDFSection(
            heading: "Intellectual Landscape",
            headingLevel: 1,
            blocks: landscapeBlocks
        ))

        // 3. Core Synthesis Themes
        for theme in coreSynthesis {
            var themeBlocks: [PDFContentBlock] = []

            // Core Insight
            if !theme.coreInsight.isEmpty {
                let paragraphs = theme.coreInsight.components(separatedBy: "\n\n")
                for paragraph in paragraphs where !paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    themeBlocks.append(PDFContentBlock(
                        type: .paragraph,
                        content: paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                }
            }

            // Insight Atlas Analysis
            if !theme.insightAtlasAnalysis.isEmpty {
                themeBlocks.append(PDFContentBlock(
                    type: .heading3,
                    content: "Insight Atlas Analysis"
                ))
                for analysis in theme.insightAtlasAnalysis {
                    themeBlocks.append(PDFContentBlock(
                        type: .insightNote,
                        content: analysis.content,
                        metadata: ["title": analysis.type]
                    ))
                }
            }

            // Scholarly Deep Dive
            if !theme.scholarlyDeepDive.isEmpty {
                themeBlocks.append(PDFContentBlock(
                    type: .heading3,
                    content: "Scholarly Deep Dive"
                ))
                themeBlocks.append(PDFContentBlock(
                    type: .paragraph,
                    content: theme.scholarlyDeepDive
                ))
            }

            // Insight Atlas Framework
            themeBlocks.append(PDFContentBlock(
                type: .heading3,
                content: "Insight Atlas Framework: \(theme.insightAtlasFramework.type)"
            ))
            themeBlocks.append(PDFContentBlock(
                type: .paragraph,
                content: theme.insightAtlasFramework.description
            ))
            if !theme.insightAtlasFramework.howToUse.isEmpty {
                themeBlocks.append(PDFContentBlock(
                    type: .actionBox,
                    content: theme.insightAtlasFramework.howToUse,
                    metadata: ["title": "How to Use This Framework"]
                ))
            }

            // Perspectives from the Field
            if !theme.perspectivesFromTheField.isEmpty {
                themeBlocks.append(PDFContentBlock(
                    type: .heading3,
                    content: "Perspectives from the Field"
                ))
                for perspective in theme.perspectivesFromTheField {
                    themeBlocks.append(PDFContentBlock(
                        type: .alternativePerspective,
                        content: "**\(perspective.perspective):** \(perspective.viewpoint)"
                    ))
                }
            }

            sections.append(PDFAnalysisDocument.PDFSection(
                heading: "Theme \(theme.themeNumber): \(theme.themeTitle)",
                headingLevel: 1,
                blocks: themeBlocks
            ))
        }

        // 4. Adaptive Implementation Section
        var implementationBlocks: [PDFContentBlock] = []

        // Diagnostic Assessment
        if !adaptiveImplementation.diagnosticAssessment.isEmpty {
            implementationBlocks.append(PDFContentBlock(
                type: .heading3,
                content: "Diagnostic Assessment"
            ))
            for (index, question) in adaptiveImplementation.diagnosticAssessment.enumerated() {
                let optionsText = question.options.enumerated().map { "  \($0.offset + 1). \($0.element)" }.joined(separator: "\n")
                implementationBlocks.append(PDFContentBlock(
                    type: .exerciseReflection,
                    content: "**Question \(index + 1):** \(question.question)\n\n\(optionsText)"
                ))
            }
        }

        // Implementation Pathways
        if !adaptiveImplementation.implementationPathways.isEmpty {
            implementationBlocks.append(PDFContentBlock(
                type: .heading3,
                content: "Implementation Pathways"
            ))
            for pathway in adaptiveImplementation.implementationPathways {
                implementationBlocks.append(PDFContentBlock(
                    type: .heading3,
                    content: pathway.pathwayTitle
                ))
                for week in pathway.weeklyPlan {
                    let weekContent = """
                    **Focus:** \(week.focus)

                    **Key Action:** \(week.keyAction)

                    **Success Metric:** \(week.successMetric)
                    """
                    implementationBlocks.append(PDFContentBlock(
                        type: .actionBox,
                        content: weekContent,
                        metadata: ["title": "Week \(week.week)"]
                    ))
                }
            }
        }

        // Resistance & Obstacles
        if !adaptiveImplementation.resistanceAndObstacles.isEmpty {
            implementationBlocks.append(PDFContentBlock(
                type: .heading3,
                content: "Resistance & Obstacles"
            ))
            for obstacle in adaptiveImplementation.resistanceAndObstacles {
                implementationBlocks.append(PDFContentBlock(
                    type: .alternativePerspective,
                    content: "**\(obstacle.barrierType) Barrier:** \(obstacle.description)\n\n**Intervention:** \(obstacle.intervention)"
                ))
            }
        }

        sections.append(PDFAnalysisDocument.PDFSection(
            heading: "Adaptive Implementation",
            headingLevel: 1,
            blocks: implementationBlocks
        ))

        // 5. Critical Analysis & Verdict Section
        var criticalBlocks: [PDFContentBlock] = []

        if !criticalAnalysisAndVerdict.strengthsAndContributions.isEmpty {
            criticalBlocks.append(PDFContentBlock(
                type: .heading3,
                content: "Strengths & Novel Contributions"
            ))
            criticalBlocks.append(PDFContentBlock(
                type: .paragraph,
                content: criticalAnalysisAndVerdict.strengthsAndContributions
            ))
        }

        if !criticalAnalysisAndVerdict.limitationsAndAssumptions.isEmpty {
            criticalBlocks.append(PDFContentBlock(
                type: .heading3,
                content: "Limitations & Unquestioned Assumptions"
            ))
            criticalBlocks.append(PDFContentBlock(
                type: .alternativePerspective,
                content: criticalAnalysisAndVerdict.limitationsAndAssumptions
            ))
        }

        if !criticalAnalysisAndVerdict.unresolvedDebates.isEmpty {
            criticalBlocks.append(PDFContentBlock(
                type: .heading3,
                content: "Unresolved Debates"
            ))
            criticalBlocks.append(PDFContentBlock(
                type: .paragraph,
                content: criticalAnalysisAndVerdict.unresolvedDebates
            ))
        }

        // Nuanced Verdict
        let verdictContent = """
        **Read this book if:** \(criticalAnalysisAndVerdict.nuancedVerdict.readThisIf)

        **Most valuable takeaway:** \(criticalAnalysisAndVerdict.nuancedVerdict.mostValuableTakeaway)

        **Pair with:** \(criticalAnalysisAndVerdict.nuancedVerdict.pairWith)

        **Final Assessment:** \(criticalAnalysisAndVerdict.nuancedVerdict.finalAssessment)
        """
        criticalBlocks.append(PDFContentBlock(
            type: .foundationalNarrative,
            content: verdictContent,
            metadata: ["title": "The Verdict"]
        ))

        sections.append(PDFAnalysisDocument.PDFSection(
            heading: "Critical Analysis & Verdict",
            headingLevel: 1,
            blocks: criticalBlocks
        ))

        // 6. Extended Intelligence Section
        var extendedBlocks: [PDFContentBlock] = []

        // Case Studies
        if !extendedIntelligence.caseStudies.isEmpty {
            extendedBlocks.append(PDFContentBlock(
                type: .heading3,
                content: "Real-World Case Studies"
            ))
            for caseStudy in extendedIntelligence.caseStudies {
                let caseContent = """
                **Situation:** \(caseStudy.situation)

                **Application:** \(caseStudy.application)

                **Outcome:** \(caseStudy.outcome)
                """
                extendedBlocks.append(PDFContentBlock(
                    type: .example,
                    content: caseContent,
                    metadata: ["title": caseStudy.title]
                ))
            }
        }

        // 5-Year Forecast
        if !extendedIntelligence.fiveYearForecast.isEmpty {
            extendedBlocks.append(PDFContentBlock(
                type: .heading3,
                content: "5-Year Forecast"
            ))
            extendedBlocks.append(PDFContentBlock(
                type: .numberedList,
                content: "Predictions",
                listItems: extendedIntelligence.fiveYearForecast
            ))
        }

        // Strategic Glossary
        if !extendedIntelligence.strategicGlossary.isEmpty {
            extendedBlocks.append(PDFContentBlock(
                type: .heading3,
                content: "Strategic Glossary"
            ))
            var tableData: [[String]] = [["Term", "Definition", "Strategic Relevance"]]
            for entry in extendedIntelligence.strategicGlossary {
                tableData.append([entry.term, entry.definition, entry.strategicRelevance])
            }
            extendedBlocks.append(PDFContentBlock(
                type: .table,
                content: "",
                tableData: tableData
            ))
        }

        // Strategic Conversation Prompts
        if !extendedIntelligence.strategicConversationPrompts.isEmpty {
            extendedBlocks.append(PDFContentBlock(
                type: .heading3,
                content: "Strategic Conversation Prompts"
            ))
            extendedBlocks.append(PDFContentBlock(
                type: .bulletList,
                content: "Discussion Questions",
                listItems: extendedIntelligence.strategicConversationPrompts
            ))
        }

        sections.append(PDFAnalysisDocument.PDFSection(
            heading: "Extended Intelligence",
            headingLevel: 1,
            blocks: extendedBlocks
        ))

        // Build Quick Glance from strategic briefing
        let quickGlance = buildQuickGlance()

        // Calculate word count
        let allContent = sections.flatMap { $0.blocks.map { $0.content } }.joined(separator: " ")
        let wordCount = allContent.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        let readingTime = max(1, wordCount / 250)

        return PDFAnalysisDocument(
            book: PDFAnalysisDocument.BookMetadata(
                title: metadata.bookTitle,
                author: metadata.author
            ),
            quickGlance: quickGlance,
            sections: sections,
            metadata: PDFAnalysisDocument.DocumentMetadata(
                generatedAt: Date(),
                version: "3.0-synthesis-engine",
                wordCount: wordCount,
                estimatedReadingTime: readingTime
            )
        )
    }

    // MARK: - Private Helpers

    private func buildQuickGlance() -> PDFAnalysisDocument.QuickGlanceSection {
        // Use guide's thesis as core message
        let coreMessage: String
        if !metadata.guidesThesis.isEmpty {
            if let firstPeriod = metadata.guidesThesis.firstIndex(of: ".") {
                coreMessage = String(metadata.guidesThesis[..<metadata.guidesThesis.index(after: firstPeriod)])
            } else {
                coreMessage = metadata.guidesThesis.prefix(250).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
            }
        } else {
            coreMessage = strategicBriefing.executiveBriefing.prefix(200).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
        }

        // Extract key points from actionable insights and theme titles
        var keyPoints: [String] = strategicBriefing.actionableInsights.prefix(3).map { $0.strategicLever }
        if keyPoints.count < 5 {
            keyPoints += coreSynthesis.prefix(5 - keyPoints.count).map { $0.themeTitle }
        }

        // Calculate reading time
        let allContent = strategicBriefing.executiveBriefing + coreSynthesis.map { $0.coreInsight }.joined(separator: " ")
        let wordCount = allContent.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        let readingTime = max(1, wordCount / 250) + (coreSynthesis.count * 8) // ~8 min per theme for deep content

        return PDFAnalysisDocument.QuickGlanceSection(
            coreMessage: coreMessage,
            keyPoints: keyPoints,
            readingTime: readingTime
        )
    }
}

// MARK: - JSON Parsing Helper

extension ThematicSynthesisResponse {

    /// Parse a ThematicSynthesisResponse from JSON string (AI output)
    static func parse(from jsonString: String) throws -> ThematicSynthesisResponse {
        // Clean up the JSON string - remove markdown code blocks if present
        var cleanedJSON = jsonString
        if cleanedJSON.hasPrefix("```json") {
            cleanedJSON = String(cleanedJSON.dropFirst(7))
        } else if cleanedJSON.hasPrefix("```") {
            cleanedJSON = String(cleanedJSON.dropFirst(3))
        }
        if cleanedJSON.hasSuffix("```") {
            cleanedJSON = String(cleanedJSON.dropLast(3))
        }
        cleanedJSON = cleanedJSON.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleanedJSON.data(using: .utf8) else {
            throw ThematicSynthesisError.invalidJSON("Could not convert string to data")
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(ThematicSynthesisResponse.self, from: data)
        } catch {
            throw ThematicSynthesisError.decodingFailed(error.localizedDescription)
        }
    }

    enum ThematicSynthesisError: Error, LocalizedError {
        case invalidJSON(String)
        case decodingFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidJSON(let message):
                return "Invalid JSON: \(message)"
            case .decodingFailed(let message):
                return "Failed to decode thematic synthesis: \(message)"
            }
        }
    }
}
