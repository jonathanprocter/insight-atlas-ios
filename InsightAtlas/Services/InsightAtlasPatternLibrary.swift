//
//  InsightAtlasPatternLibrary.swift
//  InsightAtlas
//
//  Pattern Library for the Replicator System.
//  These templates serve as benchmarks for style matching and output quality.
//

import Foundation

// MARK: - Pattern Library

/// Comprehensive pattern library for Insight Atlas guide generation.
/// These patterns ensure consistent, high-quality output that matches the brand voice.
struct InsightAtlasPatternLibrary {

    // MARK: - Hook Question Patterns

    static let hookPatterns = """
    ## HOOK QUESTION PATTERNS

    Use these patterns to open sections with engaging questions:

    **Pattern A: Two-Question Hook (Pain Point + Intensifier)**
    "Is there someone in your life who always pushes your buttons? Someone who makes the simplest interaction feel like pulling teeth?"

    **Pattern B: Universal Experience Hook**
    "Have you ever felt stuck in a career that no longer excites you? Wondered if there's a way to make a living doing what you love?"

    **Pattern C: Fear/Aspiration Hook**
    "Are you worried that your current habits are holding you back from the person you want to become? Do you wish you could build systems that make success automatic?"
    """

    // MARK: - Author Credential Templates

    static let credentialTemplates = """
    ## AUTHOR CREDENTIAL BLOCK TEMPLATES

    **Template A: Corporate-to-Consultant**
    "[Author] is a [job title] specializing in [specialty 1] and [specialty 2]. Before becoming a [current role], [he/she/they] worked for [X] years at [Company Name], where [he/she/they] [specific accomplishment] and [specific accomplishment]. [Author] has written a number of other books, including *[Book Title]* and *[Book Title]*, both of which extend [Author's] principles of [connecting theme] to [new domain]."

    **Template B: Academic/Research**
    "[Author] is a [academic title] at [Institution], where [he/she/they] studies [research area]. [His/Her/Their] research has been published in [journals/venues] and has influenced [field impact]. [Author] previously served as [notable position] and [another notable position]."

    **Template C: Practitioner**
    "[Author] has spent [X+] years [practicing/working in] [field], including [notable clients/projects]. [He/She/They] [is/are] a [credential] and [credential], and has trained [audience] at organizations including [notable org] and [notable org]."
    """

    // MARK: - Extended Commentary Box Examples

    static let commentaryBoxTemplates = """
    ## EXTENDED COMMENTARY BOX PATTERNS

    Use [INSIGHT_NOTE] tags for these. Each must include Key Distinction, Practical Implication, and Go Deeper.

    **Type: Framework Comparison**
    [INSIGHT_NOTE]
    **An Alternative Process Centered Around Needs**

    [Author's] method isn't the only effective approach. For example, in *[Related Book]*, [Other Author] describes a [X]-step process based on [framework name]:

    * Step #1: [Action]
    * Step #2: [Action]
    * Step #3: [Action]

    While both processes involve [similarity], the [alternative] places more emphasis on [difference] than [Author's] method.

    **Key Distinction:** [Author's] method focuses on [X] while [Other Author's] centers on [Y].

    **Practical Implication:** Choose [Author's] approach when [situation]; use [Other Author's] when [different situation].

    **Go Deeper:** *[Specific Book Title]* by [Author] for [what the reader will learn]
    [/INSIGHT_NOTE]

    **Type: Relationship to Adjacent Domain**
    [INSIGHT_NOTE]
    **[Concept] in [Adjacent Domain]**

    [Author] argues that [concept] is particularly common in [context]. However, in *[Related Book]*, [Other Author] contends that [concept] is inevitable in [different context] too. After [situation], [outcome]. [People/practitioners] must [action] for [goal].

    Instead of seeing [challenges] as purely negative, [Other Author] (like [Author]) frames them as [opportunity]. Specifically, [he/she/they] claims that by [action], [people] can foster [positive outcome].

    **Key Distinction:** [Author] focuses on [context A] while [Other Author] extends to [context B].

    **Practical Implication:** Apply these principles across [multiple domains] for [benefit].

    **Go Deeper:** *[Specific Book Title]* by [Author] for [what the reader will learn]
    [/INSIGHT_NOTE]

    **Type: Counterpoint/Caution**
    [INSIGHT_NOTE]
    **Don't [Common Mistake]**

    Although [recommended action] can help [benefit], don't [overdo it]. Studies show that [excessive behavior] makes you appear [negative outcome]. Additionally, even if [clarification], research shows that it still [consequence].

    Some experts contend that there are certain things you just shouldn't [do]. For instance, never [specific don't] or [another don't]—these are integral parts of [positive quality].

    **Key Distinction:** [Nuance that prevents misapplication]

    **Practical Implication:** [How to calibrate the advice properly]

    **Go Deeper:** *[Specific Book Title]* by [Author] for [what the reader will learn]
    [/INSIGHT_NOTE]

    **Type: Technique Enhancement**
    [INSIGHT_NOTE]
    **[Enhanced Technique Name]**

    In *[Related Book]*, [Other Author] also recommends [similar technique]. However, unlike [Author], [he/she/they] contends that during this stage, you can also [additional capability].

    First, [step 1]. They'll appreciate this and be more likely to [positive response]. Next, [step 2]. Then, [step 3]. By the end, [outcome].

    **Key Distinction:** [Author] stops at [point] while [Other Author] extends to [further point].

    **Practical Implication:** [When to use the enhanced version]

    **Go Deeper:** *[Specific Book Title]* by [Author] for [what the reader will learn]
    [/INSIGHT_NOTE]
    """

    // MARK: - Inline Atlas Insight Examples

    static let inlineInsightPatterns = """
    ## INLINE ATLAS INSIGHT PATTERNS

    Use parenthetical notes for brief cross-references within flowing text:

    **Simple Extension**
    (Insight Atlas: In *[Book Title]*, [Author] contends that you can [related technique] by [method]. This skill is called *[term]*.)

    **Broader Context**
    (Insight Atlas: Other experts agree that [broader claim]. That said, they contend that [specific skill] is just one aspect of the broader skill of *[umbrella concept]*, which also includes [related skills]. Such skills will help you succeed by [benefit].)

    **Counterpoint**
    (Insight Atlas: In *[Book Title]*, [Author] argues the opposite: You should [contrary advice]. If [condition], they [negative consequence]. Instead, [alternative approach].)

    **Practical Extension**
    (Insight Atlas: If you [action], you might be tempted to [common mistake]. This is a common error and will only [negative consequence].)

    **Supporting Citation**
    (Insight Atlas: A common piece of advice in [field] is that if you want [outcome], you should [technique]. This approach may be helpful for [application] too.)
    """

    // MARK: - Exercise Patterns

    static let exercisePatterns = """
    ## EXERCISE PATTERNS

    **Pattern A: Reflection + Perspective-Taking + Application**
    [EXERCISE_REFLECTION]
    ## Exercise: Reflect on a [Topic] Relationship

    Identify a challenging [situation] in your life and brainstorm ways to improve using [Author's] strategies.

    **Part 1:** Think of [specific prompt]. Briefly describe [what to describe].

    **Part 2:** Pick a specific [instance] and consider it from [alternative perspective]. How might they describe this? What valid reasons might they have for [their behavior]?

    **Part 3:** Imagine [applying the technique]. Write [specific output]. How do you think they'd respond? What could you say back?

    *Estimated time: 15-20 minutes*
    [/EXERCISE_REFLECTION]

    **Pattern B: Self-Assessment + Planning**
    [EXERCISE_ASSESSMENT]
    ## Exercise: Audit Your [Domain] Habits

    Take inventory of your current approach and identify specific changes based on [Author's] advice.

    **Step 1:** List three [behaviors] you regularly engage in. For each, note whether it aligns with [Author's] principles or contradicts them.

    **Step 2:** For the [behavior] that most contradicts the recommendations, what specific trigger causes you to act this way? What alternative response could you adopt?

    **Step 3:** Create a simple plan to implement this change over the next week. What reminder or accountability measure will you use?

    *Estimated time: 10-15 minutes*
    [/EXERCISE_ASSESSMENT]
    """

    // MARK: - Visual Type Templates

    static let visualTemplates = """
    ## VISUAL FRAMEWORK TEMPLATES

    CRITICAL: Never use the same visual type twice in a row. Distribute across:
    - 2-3 Flowcharts (processes, escalation patterns)
    - 2-3 Comparison Tables (before/after, problem/solution)
    - 1-2 Concept Maps (idea relationships)
    - 1-2 Process Timelines (phased approaches)
    - 1-2 Hierarchy Diagrams (nested concepts)

    **Flowchart Template:**
    [VISUAL_FLOWCHART: The [Process Name] Cycle]
    [Trigger/Starting Point]
        ↓
    [First Response/Action]
        ↓
    [Consequence/Effect]
        ↓
    [Escalation/Development]
        ↓
    [Outcome/Resolution]
    [/VISUAL_FLOWCHART]

    **Comparison Table Template:**
    [VISUAL_TABLE: [Before State] vs. [After State]]
    | [Before/Problem/Without] | [After/Solution/With] |
    |--------------------------|----------------------|
    | [Negative pattern 1]     | [Positive pattern 1] |
    | [Negative pattern 2]     | [Positive pattern 2] |
    | [Negative pattern 3]     | [Positive pattern 3] |
    | [Negative pattern 4]     | [Positive pattern 4] |
    [/VISUAL_TABLE]

    **Concept Map Template:**
    [CONCEPT_MAP: [Central Concept]]
    Central: [Core Concept]
    → [Related Concept 1]: [relationship verb] (e.g., "enables")
    → [Related Concept 2]: [relationship verb] (e.g., "requires")
    → [Related Concept 3]: [relationship verb] (e.g., "contrasts with")
    → [Related Concept 4]: [relationship verb] (e.g., "builds upon")
    [/CONCEPT_MAP]

    **Process Timeline Template:**
    [PROCESS_TIMELINE: The [X]-Phase [Process Name]]
    Phase 1: [Name] — [Brief description of what happens and why]
    Phase 2: [Name] — [Brief description of what happens and why]
    Phase 3: [Name] — [Brief description of what happens and why]
    Phase 4: [Name] — [Brief description of what happens and why]
    [/PROCESS_TIMELINE]

    **Hierarchy Diagram Template:**
    [HIERARCHY_DIAGRAM: [Umbrella Concept]]
    [Top-Level Concept]
    ├── [Category A]
    │   ├── [Subcategory A1]
    │   └── [Subcategory A2]
    ├── [Category B]
    │   ├── [Subcategory B1]
    │   └── [Subcategory B2]
    └── [Category C]
        ├── [Subcategory C1]
        └── [Subcategory C2]
    [/HIERARCHY_DIAGRAM]
    """

    // MARK: - Action Box Template

    static let actionBoxTemplate = """
    ## ACTION BOX TEMPLATE

    [ACTION_BOX: [Concept Name]]
    1. [Specific, observable action with time-bound element if applicable]
    2. [Specific, observable action that can be done immediately]
    3. [Specific, observable action with measurable outcome]
    4. [Specific, observable action involving others or environment]
    5. [Specific, observable action for ongoing practice]
    [/ACTION_BOX]

    REQUIREMENTS:
    - 3-5 specific action steps per box
    - Imperative voice ("Do this," not "You should do this")
    - Immediately implementable (no prerequisites)
    - Time-bounded where applicable ("For one week...", "Today...")
    - One Action Box per major concept/chapter

    AVOID:
    - Vague instructions ("be more mindful")
    - Non-observable actions ("think about...")
    - Actions requiring special equipment or access
    """

    // MARK: - Bold Emphasis Rules

    static let emphasisRules = """
    ## BOLD EMPHASIS RULES

    **USE BOLD FOR:**
    1. Key terms on first introduction: "[Author] asserts that **mature conflict resolution** is necessary..."
    2. Core arguments/thesis: "**you can reform your relationships** with the right skills"
    3. Imperative guidance: "**Think through the points** you want to make"
    4. Contrast emphasis: "In contrast, when most people start, they **instinctively resort to** 'you' messages"

    **DO NOT USE BOLD FOR:**
    - Book titles (use *italics*)
    - Author names
    - General emphasis within prose
    - Every concept mentioned
    """

    // MARK: - Transition Language

    static let transitionLanguage = """
    ## TRANSITION LANGUAGE

    **Between Major Sections:**
    - "We've established that [summary]. [Author] divides the process into [X] stages:"
    - "In the remaining sections, we'll discuss each stage in turn."
    - "Let's discuss [specific subtopics]: [Topic 1] and [Topic 2]. Additionally, we'll discuss [Topic 3]."

    **Within Sections:**
    - "Furthermore, [Author] asserts that..."
    - "According to [Author], ..."
    - "[Author] notes that..."
    - "[Author] recommends..."
    - "[Author] explains that..."
    - "[Author] warns that..."

    **Before Commentary:**
    - "Other experts agree..." / "Other experts disagree..."
    - "That said, ..."
    - "However, ..."
    - "In contrast, ..."
    """

    // MARK: - Attribution Verb Variety

    static let attributionVerbs = """
    ## ATTRIBUTION VERB VARIETY

    **Neutral/Factual:**
    - argues, contends, explains, describes, notes, states, asserts

    **Prescriptive:**
    - recommends, advises, suggests, warns

    **Analytical:**
    - points out, observes, illustrates, demonstrates

    **Use Sparingly (implies skepticism):**
    - claims, insists, maintains
    """

    // MARK: - Cross-Discipline Connections

    static let crossDisciplineLibrary = """
    ## CROSS-DISCIPLINE CONNECTION LIBRARY

    When connecting ideas, draw from these domains to show universal applicability:

    **Psychology & Behavior:**
    - Cognitive biases (Kahneman's System 1/2)
    - Habit formation (Duhigg's cue-routine-reward, Clear's identity-based change)
    - Growth mindset (Dweck)
    - Vulnerability and shame (Brown)

    **Neuroscience:**
    - Neuroplasticity and learning
    - Stress response (fight/flight/freeze)
    - Mirror neurons and empathy
    - Default mode network and rumination

    **Philosophy:**
    - Stoicism (Aurelius, Epictetus, Seneca)
    - Existentialism (choice and responsibility)
    - Buddhist concepts (attachment, impermanence, mindfulness)
    - Virtue ethics (Aristotle)

    **Business & Leadership:**
    - Systems thinking (Senge)
    - Servant leadership (Greenleaf)
    - Psychological safety (Edmondson)
    - First principles thinking (Musk methodology)

    **Communication:**
    - Nonviolent Communication (Rosenberg)
    - Crucial Conversations (Patterson et al.)
    - Influence principles (Cialdini)
    - Negotiation (Voss, Fisher/Ury)

    **Health & Wellness:**
    - Mind-body connection
    - Circadian rhythms and sleep science
    - Nutrition and cognitive function
    - Exercise and mental health

    When making cross-discipline connections:
    1. Be specific (cite author + book title)
    2. Explain the connection clearly
    3. Show practical implication
    4. Offer "Go Deeper" recommendation
    """

    // MARK: - Complete Pattern Library

    /// Returns the complete pattern library for inclusion in prompts
    static var completeLibrary: String {
        return """
        ═══════════════════════════════════════════════════════════════════
        INSIGHT ATLAS PATTERN LIBRARY
        Use these templates as benchmarks for style matching.
        ═══════════════════════════════════════════════════════════════════

        \(hookPatterns)

        ───────────────────────────────────────────────────────────────────

        \(credentialTemplates)

        ───────────────────────────────────────────────────────────────────

        \(commentaryBoxTemplates)

        ───────────────────────────────────────────────────────────────────

        \(inlineInsightPatterns)

        ───────────────────────────────────────────────────────────────────

        \(exercisePatterns)

        ───────────────────────────────────────────────────────────────────

        \(visualTemplates)

        ───────────────────────────────────────────────────────────────────

        \(actionBoxTemplate)

        ───────────────────────────────────────────────────────────────────

        \(emphasisRules)

        ───────────────────────────────────────────────────────────────────

        \(transitionLanguage)

        ───────────────────────────────────────────────────────────────────

        \(attributionVerbs)

        ───────────────────────────────────────────────────────────────────

        \(crossDisciplineLibrary)

        ═══════════════════════════════════════════════════════════════════
        """
    }

    /// Returns a condensed version for token-limited contexts
    static var condensedLibrary: String {
        return """
        PATTERN LIBRARY ESSENTIALS:

        \(visualTemplates)

        \(commentaryBoxTemplates)

        \(actionBoxTemplate)

        \(emphasisRules)
        """
    }
}
