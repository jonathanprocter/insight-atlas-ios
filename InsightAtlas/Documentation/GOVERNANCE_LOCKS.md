# Insight Atlas Governance Locks

**Version:** 1.0.0
**Last Updated:** 2024-12-12
**Status:** Active

---

## Purpose

This document defines **architectural invariants** that must be preserved across all future changes to Insight Atlas. These locks exist to protect the editorial integrity, security, and determinism of the system.

**Violation of these locks requires explicit architectural review.**

---

## 🔒 Lock 1: Output Contract Validation

**Location:** `OutputContractValidator.swift`

**Invariant:**
All content must pass `OutputContractValidator.validate()` before export.

**Rationale:**
The validator ensures:
- No markdown artifacts reach users (`**`, `_`, `>`, `→`, etc.)
- All blocks have explicit semantic types
- Format parity across PDF, HTML, and DOCX
- Visual density rules are enforced
- Narration-unsafe text is caught

**Enforcement:**
- Validation runs automatically before any export
- Build fails if validation is bypassed
- Errors halt export; warnings are logged

---

## 🔒 Lock 2: Visual Suppression Rules

**Location:** `VisualSelectionService.swift`

**Invariants:**
1. Visuals are suppressed within 2 blocks of `.premiumQuote` or `.insightNote`
2. Visuals are never the first block in a section
3. Maximum 3 visuals per 1000 words
4. No more than 1 visual per section within 5 blocks

**Rationale:**
Visual selection is meaning-driven, not decorative. These rules maintain cognitive pacing and ensure visuals serve understanding rather than distract.

**Enforcement:**
- `VisualSelectionService` applies these rules at selection time
- `OutputContractValidator` includes `visualZoneViolation` and `visualFirstBlockViolation` checks

---

## 🔒 Lock 3: Audio-Visual Meaning Bridging

**Location:** `AudioVisualBridge.swift`

**Invariant:**
Audio narration must never reference visuals literally.

**Forbidden Patterns:**
- "As you can see..."
- "The diagram shows..."
- "Looking at the chart..."
- "This figure illustrates..."

**Rationale:**
Audio listeners must receive equivalent conceptual understanding without visual dependency. Bridges convey the *meaning* of visuals, not their existence.

**Enforcement:**
- `AudioVisualBridgeGenerator` produces conceptual bridges
- `OutputContractValidator.uncleanNarrationText` catches forbidden patterns
- Review any audio text that references visual elements

---

## 🔒 Lock 4: Keychain-Only API Key Storage

**Location:** `KeychainService.swift`, `ElevenLabsAudioService.swift`

**Invariant:**
All API keys are stored exclusively in iOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.

**Forbidden:**
- API keys in source code
- API keys in config files
- API keys in UserDefaults
- API keys in Info.plist
- API keys logged to console
- API keys cached in memory beyond request scope

**Enforcement:**
- `KeychainService` is the single source of truth
- `ElevenLabsAudioService.generateAudio()` retrieves key at request time
- Security comments enforce no-logging policy

---

## 🔒 Lock 5: Reader Profiles Affect Pacing Only

**Location:** `ReaderProfilePacing.swift`, `AudioNarrationService.swift`

**Invariant:**
Reader profiles modify pacing constants only—never content structure or meaning.

**What Profiles Control:**
- Sentence limits per block
- Prose length thresholds
- Insight density limits
- Framework complexity caps
- Audio pause multipliers
- Audio pace adjustments

**What Profiles Must Not Control:**
- Block types
- Content text
- Visual selection logic
- Export format decisions

**Rationale:**
The same semantic meaning must reach all users regardless of profile. Profiles are ergonomic adjustments, not content gates.

**Enforcement:**
- Profiles are consumed at normalization time only
- Renderers receive identical block structures
- Cache keys include profile but do not change block content

---

## 🔒 Lock 6: Voice Picker Copy Centralization

**Location:** `VoicePickerCopy.swift`, `VoiceSelectionCopy.swift`

**Invariant:**
All voice picker UI strings are defined in centralized copy enums, not scattered across views.

**Covered Copy:**
- Screen titles and subtitles
- Section headers
- Voice descriptions
- Preview script text
- State labels (selected, loading, playing)
- Accessibility labels
- Error messages

**Rationale:**
Centralized copy ensures consistency, prevents drift, and makes localization manageable.

**Enforcement:**
- Voice picker views reference copy enums only
- No inline strings in SwiftUI voice picker components

---

## 🔒 Lock 7: Block Type to Audio Behavior Mapping

**Location:** `AudioNarrationService.behaviorMapping`

**Invariant:**
The mapping of `EditorialBlockType` to `AudioNarrationBehavior` is canonical and deterministic.

**Current Mapping (excerpt):**
| Block Type | Behavior |
|------------|----------|
| `.paragraph` | `.normal` |
| `.insightNote` | `.emphatic` |
| `.premiumQuote` | `.quoted` |
| `.processFlow` | `.stepPaced` |
| `.framework` | `.segmented` |
| `.divider` | `.silent` |

**Rationale:**
Audio narration must be predictable across updates. Users expect consistent pacing and delivery for each block type.

**Enforcement:**
- Mapping defined as static dictionary
- Changes require version bump and explicit documentation
- No runtime modification of mapping

---

## 🔒 Lock 8: Summary Type Governors

**Location:** `SummaryTypeGovernor.swift`, `SummaryGovernorEngine.swift`, `SummaryGovernorPresets.swift`

**Version:** v1.0 (2025-06-13)

**Invariant:**
Summary generation must respect governor budgets for word count, section allocation, visual limits, and cut policies. Governors control **how much** content is allowed, not **how** content is expressed.

**Governor Types:**
| Type | Base Words | Max Words | Max Audio | Max Visuals |
|------|------------|-----------|-----------|-------------|
| Quick Reference | 900 | 1,200 | 6 min | 1 |
| Professional | 3,000 | 4,000 | 18 min | 3 |
| Accessible | 4,500 | 6,000 | 25 min | 4 |
| Deep Research | 7,000 | 12,000 | 50 min | 6 |

**Budget Calculation:**
```
totalBudget = min(
    baseWordCount + scaledAddition,
    maxWordCeiling,
    sourceWordCount * 0.80
)
```

**Cut Policy:**
- Trigger threshold activates cut evaluation (85-92% depending on type)
- Hard limit threshold is always 1.0 (100%)
- Cut order: adjacentDomainComparison → exercise → extendedCommentary → secondaryExample → stylisticElaboration
- `coreArgument` is NEVER cut

**Strict Enforcement:**
When `strictEnforcement == true`:
- Generation halts on budget violation
- Output is discarded
- Error is returned

**Global Constraints:**
- Do NOT weaken semantic normalization
- Do NOT truncate mid-sentence
- Do NOT rely on token limits
- Do NOT modify rendering or export logic
- Do NOT modify visual or audio semantics

**Determinism Guarantee:**
Identical input + governor = identical output. No randomness, no timestamp-based logic.

**Enforcement:**
- `SummaryGovernorEngine.validate()` checks all constraints
- `SummaryGovernorEngine.enforce()` applies strict/non-strict policy
- Cut events and section detection events emitted for observability
- Tests verify budget calculations, detection algorithms, and determinism

---

## Adding New Locks

Before adding a new governance lock:

1. **Verify necessity:** Is this truly an architectural invariant, or just a current implementation choice?
2. **Document rationale:** Why must this be protected?
3. **Define enforcement:** How will violations be detected?
4. **Update version:** Increment this document's version number

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.1.0 | 2025-06-13 | Added Lock 8: Summary Type Governors v1.0 |
| 1.0.0 | 2024-12-12 | Initial governance locks documentation |

---

## Related Documents

- `FormattingInvariants.md` — Detailed formatting rules
- `RubricVersionEvolution.md` — Rubric versioning history
- `OutputContractValidator.swift` — Validation implementation
