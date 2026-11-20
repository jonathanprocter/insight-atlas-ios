import Foundation

/// A guide in the elevation-spec shape, modelled on the reviewed "Nineteen
/// Ways of Looking at Consciousness" export: front matter, numbered sections
/// with descriptors and the six labelled parts, callouts with honesty markers,
/// a spectrum, a flowchart, a five-column table, and the full back matter.
/// Used to render a fixture PDF for visual inspection and page-count checks.
enum ElevationSpecFixture {
    static func paragraph(_ seed: String, _ n: Int = 6) -> String {
        (1...n).map { "\(seed), and sentence \($0) of that paragraph develops the point with a concrete case from the book (ch. \($0 % 7 + 1))." }.joined(separator: " ")
    }

    static func section(_ number: Int, _ title: String, _ descriptor: String, extra: String = "") -> String {
        """
        [PREMIUM_H2]\(number). \(title)[/PREMIUM_H2]
        *\(descriptor)*

        **The claim.** \(paragraph("House asserts the central claim of \(title.lowercased())", 2))

        **The evidence.** \(paragraph("The evidence House gives for \(title.lowercased()) is clinical and anatomical", 7))

        [INSIGHT_NOTE]
        **Rodolfo Llinás** (*I of the Vortex*, 2001) corroborates this claim. *What the source shows:* Llinás argues that mindness evolved as an internalization of movement, first locomotion, then its suppression in the service of prediction. *How it bears on the claim:* this is House's direct intellectual ancestor; where Llinás stays at the level of thalamocortical physiology, House adds the clinical cases.
        **Go Deeper:** Nikolai Bernstein, *The Coordination and Regulation of Movements* (1967) — the original formalization of the degrees-of-freedom problem House leans on
        [/INSIGHT_NOTE]

        **The mechanism.** \(paragraph("The mechanism behind \(title.lowercased()) works through prediction", 5))
        \(extra)
        **Where it strains.** \(paragraph("The strongest objection to \(title.lowercased()) comes from locked-in patients", 4))

        [ALTERNATIVE_PERSPECTIVE]
        **Giulio Tononi** (*Phi*, 2012) objects. *What the source shows:* integrated information theory predicts that a high-neuron, low-integration structure contributes nothing to experience. *How it bears on the claim:* a meaningful limitation rather than a fatal flaw, and House does not answer it directly.
        [/ALTERNATIVE_PERSPECTIVE]

        **Why it matters.** \(paragraph("For clinicians, \(title.lowercased()) changes how deficits are read", 4))

        **Connections.** The confabulation loop (see Section 2, The Confabulation Problem) is what a prediction-for-movement machine does when it has to explain itself.

        """
    }

    static let guide: String = """
    [[AUTHORS: Patrick House]]
    [QUICK_GLANCE]
    **Nineteen Ways of Looking at Consciousness** by Patrick House (2022)

    **Core Message:** Consciousness is not a single phenomenon but a multivalent output of brains whose only function is to coordinate movement, and no single theory yet accounts for all of its observed failures and feats.

    **Key Insights:**
    - Brains evolved for, are dedicated to, and only output movement; consciousness is what falls out of that commitment (ch. 1)
    - The 1998 *Nature* report of a 1996 surgery shows that confabulation is a fundamental feature of conscious brains (ch. 2)
    - Multiple frameworks each explain some conscious phenomena and fail on others (ch. 11)
    - The "hard problem" may be reframed as the gap between what physics describes and what experience contains (ch. 9)
    - Split-brain cases, anosognosia, sleep and anesthesia reveal a patchwork of capacities with many failure modes (ch. 14)

    House compiles nineteen competing scientific and philosophical translations of a one-page neuroscience paper. The book is best for readers who want fluency in several theories rather than allegiance to one.
    [/QUICK_GLANCE]

    [PREMIUM_H2]About the Book and Author[/PREMIUM_H2]
    Patrick House is a neuroscientist with a doctorate from Stanford who writes for general readers; the book was published by St. Martin's Press in 2022 and consists of nineteen short chapters that each re-read the same one-page 1998 *Nature* case report, in homage to Eliot Weinberger's *Nineteen Ways of Looking at Wang Wei*. \(paragraph("The book's form is a deliberate inversion", 3))

    [FOUNDATIONAL_NARRATIVE]
    In 1996, a sixteen-year-old patient referred to throughout this guide as Anna underwent subdural electrode monitoring to localize the focus of her intractable seizures. Current applied to the anterior supplementary motor area produced, reliably, both laughter and the subjective report of mirth, and each time she offered a different explanation.
    [/FOUNDATIONAL_NARRATIVE]

    [PREMIUM_H2]How to Use This Guide[/PREMIUM_H2]
    Corroboration and Expansion notes bring in a named external source and say explicitly what it shows and how it bears on House's claim; Alternative Perspective boxes carry the strongest objection; the Go Deeper line names the next read. \(paragraph("The guide has three layers", 2)) The guide is organised thematically, not by chapter; the Chapter Map at the end maps every chapter to the section that treats it.

    [PREMIUM_H2]Who This Is For[/PREMIUM_H2]
    - **For:** clinicians who take self-report as evidence and want to know how far to trust it
    - **For:** technologists asking whether a system without a body can be conscious
    - **For:** readers who enjoyed Anil Seth or Annaka Harris and want the clinical cases
    - **Skip it if:** you want one theory defended to the end
    - **Skip it if:** you need a textbook treatment of integrated information theory
    - **Skip it if:** you dislike a book that repeats its central case nineteen times on purpose

    [PREMIUM_H2]Executive Summary[/PREMIUM_H2]
    \(paragraph("The book opens from the movement commitment", 8))

    \(paragraph("From there House turns to confabulation", 8))

    [INSIGHT_NOTE]
    **Daniel Dennett** (*From Bacteria to Bach and Back*, 2017) corroborates the project's premise. *What the source shows:* Dennett argues that competences accumulate without a comprehending designer. *How it bears on the claim:* the bridge from gradual competence to House's motor-first view is ours, not Dennett's.
    **Go Deeper:** Daniel Dennett, *From Bacteria to Bach and Back* (2017) — the evolutionary gradient from bacterial chemotaxis to human reflection
    [/INSIGHT_NOTE]

    \(paragraph("The boundary problem and the hard problem follow", 8))

    [PREMIUM_DIVIDER]

    \(section(1, "The Movement Commitment", "Why every theory of consciousness ends up talking about motor control", extra: """
    [VISUAL_SPECTRUM: The movement spectrum, from anchored organisms to fluid conscious movers]
    Rigid fixation (plants, sea squirts) → Fluid, conscious movement (primates, bats)
    Anchored, no nervous system: 0.05
    Sea squirt dissolves its nervous system upon settling: 0.25
    Primate manual dexterity and vocal learning: 0.75
    Echolocating bat: flight plus sensory computation: 0.95
    [/VISUAL_SPECTRUM]
    The spectrum shows why the movement commitment is a baseline against which every theory must be calibrated rather than one theory among many.
    """))
    \(section(2, "The Confabulation Problem", "Why brains must lie to function", extra: """
    [VISUAL_FLOWCHART: The confabulation loop, from an unintegrated state to a revised prediction]
    A stimulus or state arrives
    Brain cannot integrate it into its model
    Confabulation generates a plausible explanation
    Explanation is treated as memory
    Prediction is updated to incorporate the fabricated explanation
    [/VISUAL_FLOWCHART]
    The loop is constitutive of normal experience rather than pathological, which is why the honest position is diagnostic humility.
    """))
    \(section(3, "The Boundary Problem", "Where consciousness begins and ends"))
    \(section(4, "The Hard Problem and Its Discontents", "Why subjective experience resists physical explanation", extra: """
    [VISUAL_TABLE: The five frameworks compared on what they explain and what they miss]
    | Theory | What consciousness is | Where it lives | Explains well | Fails to explain |
    |---|---|---|---|---|
    | Predictive processing | Compression of predictions | Entire cortical hierarchy | Perception as inference | Phenomenal character |
    | IIT | Integrated information (phi) | Posterior cortical hot zone | Anesthesia, sleep | The cerebellum |
    | GNW | Global broadcast | Frontoparietal network | Reportability | Split-brain duplication |
    | Orch OR | Quantum coherence | Microtubules | Non-computability | Decoherence timescales |
    | Movement-first (House) | Internalized motor planning | Sensorimotor loops | Clinical dissociations | Locked-in patients |
    [/VISUAL_TABLE]
    The table makes visible what the Quick Glance promised: each framework explains a slice of the data and fails on another.
    """))
    \(section(5, "The Predictive Frame", "Consciousness as compression, prediction and simulation"))
    \(section(6, "Clinical Windows", "What anesthesia, split brains and resection reveal"))
    \(section(7, "Synthesis: The Privileged Position of Movement", "What the nineteen readings agree on without saying so"))

    [PREMIUM_DIVIDER]

    [PREMIUM_H2]Key Takeaways[/PREMIUM_H2]
    [TAKEAWAYS]
    - When a patient explains their own behaviour, treat the explanation as evidence about their narrative machinery, not as a readout of cause (see Section 2)
    - Read deficits in execution separately from deficits in the conscious plan; the cerebellum case cuts both ways (see Section 1)
    - Before adopting any theory of consciousness, list the stubborn clinical cases it must pass and check which it fails (see Section 6)
    - Treat the unity of the self as a process that anatomy can divide, not as a fact anatomy reports (see Section 3)
    - If you build a system with no body, expect its claim to consciousness to be contested for reasons unrelated to compute (see Section 7)
    [/TAKEAWAYS]

    [PREMIUM_H2]Exercises[/PREMIUM_H2]
    [EXERCISE_REFLECT: Reconstruct a confident explanation]
    Recall a decision you explained confidently afterward. Using the confabulation loop from Section 2, reconstruct which parts of the explanation could have been generated post hoc.
    1. Write the explanation you gave
    2. Mark each clause you could actually have observed
    3. Mark each clause that is a plausible story
    [/EXERCISE_REFLECT]
    [EXERCISE_PRACTICE: Notice the rehearsed movement]
    For one day, each time you "think something through", note whether you are rehearsing a movement you are not making, as Section 1 suggests.
    1. Pick three decisions during the day
    2. Note the bodily rehearsal, if any
    3. Record what you noticed in one line each
    [/EXERCISE_PRACTICE]

    [PREMIUM_H2]Glossary[/PREMIUM_H2]
    - **Anosognosia** — denial of a deficit, classically after right-hemisphere stroke, in which the patient confabulates reasons for failing a task rather than reporting the deficit.
    - **Confabulation** — a plausible but incorrect account the brain generates for the causes of its own states.
    - **Corollary discharge** — a copy of a motor command sent to sensory areas so the brain can predict the sensory consequences of its own movement.
    - **Degrees of freedom problem** — Bernstein's observation that the body's near-infinite configurations require internal models to move at all.
    - **Integrated information (phi)** — the quantity IIT proposes as the measure of consciousness in any physical system.
    - **Posterior hot zone** — the posterior cortical region IIT identifies with the neural correlate of experience.
    - **Supplementary motor area** — the premotor region whose stimulation produced Anna's laughter.

    [PREMIUM_H2]Key Quotations[/PREMIUM_H2]
    [PREMIUM_QUOTE]
    "A briny sac full of trillions of coincidence detectors that are only useful if there are connections between things."
    — ch. 4
    [/PREMIUM_QUOTE]
    [PREMIUM_QUOTE]
    "Anna is all of it, and none of it, and the question of where she ends is the wrong question."
    — ch. 8
    [/PREMIUM_QUOTE]
    [PREMIUM_QUOTE]
    "Consciousness is not something passed on or recycled."
    — ch. 12
    [/PREMIUM_QUOTE]

    [PREMIUM_H2]Chapter Map[/PREMIUM_H2]
    Because the guide is organised thematically, this map shows where each of House's nineteen readings is treated.
    [VISUAL_TABLE: Chapter Map]
    | Chapter | Lens | Guide section |
    |---|---|---|
    | 1. The case | the one-page report | §2, §6 |
    | 2. Movement | motor-first | §1 |
    | 3. The sea squirt | evolution | §1 |
    | 4. Coincidence detectors | prediction | §2, §5 |
    | 5. The cerebellum | subtraction | §1, §6 |
    | 6. Split brains | duplication | §3, §6 |
    | 7. Anesthesia | failure modes | §6 |
    | 8. Boundaries | the AI thought experiment | §3 |
    | 9. The hard problem | philosophy | §4 |
    | 10. Bats | Nagel | §4 |
    | 11. Frameworks | triangulation | §4, §7 |
    | 12. Inheritance | development | §5 |
    | 13. Marco Polo's rhinoceros | expectation | §2 |
    | 14. Schizophrenia | corollary discharge | §6 |
    | 15. The soldier | intuition | §5 |
    | 16. Orch OR | quantum | §7 |
    | 17. Bridging | connectivity | §3, §7 |
    | 18. Conjoined twins | partial sharing | §3 |
    | 19. Homo caecus | modality | §4 |
    [/VISUAL_TABLE]

    [PREMIUM_H2]Further Reading[/PREMIUM_H2]
    **Primary sources the author relies on**
    - Rodolfo Llinás, *I of the Vortex* (2001) — the motor-first ancestor of House's argument
    - Nikolai Bernstein, *The Coordination and Regulation of Movements* (1967) — the degrees-of-freedom problem
    **Corroborating works**
    - Daniel Dennett, *From Bacteria to Bach and Back* (2017) — competence without comprehension
    - V. S. Ramachandran, *Phantoms in the Brain* (1998) — the foundational anosognosia cases
    **Alternative frameworks**
    - Giulio Tononi, *Phi* (2012) — integrated information theory in the author's own voice
    - Anil Seth, *Being You* (2021) — the controlled-hallucination account of perception
    """
}
