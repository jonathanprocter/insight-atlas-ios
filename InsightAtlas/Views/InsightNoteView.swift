import SwiftUI

/// View for displaying enhanced Insight Atlas Notes with cross-references
/// - Important: This is a legacy view. Use `PremiumInsightNoteView` from AnalysisComponents.swift instead,
///   which follows the AnalysisTheme design system and matches the premium brand colors.
@available(*, deprecated, message: "Use PremiumInsightNoteView from AnalysisComponents.swift instead")
struct InsightNoteView: View {

    let note: InsightNote?
    let content: String?

    init(note: InsightNote) {
        self.note = note
        self.content = nil
    }

    init(content: String) {
        self.note = nil
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "book.closed.fill")
                    .font(.title3)
                    .foregroundStyle(.purple)

                Text("INSIGHT ATLAS NOTE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(1)
                    .foregroundStyle(.purple)

                Spacer()
            }

            Divider()

            if let note = note {
                structuredNoteContent(note)
            } else if let content = content {
                parsedContentView(content)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func structuredNoteContent(_ note: InsightNote) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Core Connection
            Text(note.coreConnection)
                .font(.body)

            // Key Distinction
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(.purple)
                    Text("Key Distinction")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                Text(note.keyDistinction)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            // Practical Implication
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.orange)
                    Text("Practical Implication")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                Text(note.practicalImplication)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            // Go Deeper
            goDeepSection(note.goDeeper)
        }
    }

    /// Parse raw content string into structured view with Key Distinction, Practical Implication, Go Deeper
    @ViewBuilder
    private func parsedContentView(_ content: String) -> some View {
        let parsed = parseInsightNoteContent(content)

        VStack(alignment: .leading, spacing: 16) {
            // Core Connection
            if !parsed.coreConnection.isEmpty {
                Text(parsed.coreConnection)
                    .font(.body)
            }

            // Key Distinction
            if let keyDistinction = parsed.keyDistinction, !keyDistinction.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundStyle(.purple)
                        Text("Key Distinction")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    Text(keyDistinction)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            // Practical Implication
            if let practical = parsed.practicalImplication, !practical.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.orange)
                        Text("Practical Implication")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    Text(practical)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            // Go Deeper
            if let goDeeper = parsed.goDeeper, !goDeeper.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Go Deeper")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "book")
                            .foregroundStyle(.secondary)

                        Text(goDeeper)
                            .font(.body)
                            .italic()
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    /// Parse insight note content into structured components
    private func parseInsightNoteContent(_ content: String) -> (coreConnection: String, keyDistinction: String?, practicalImplication: String?, goDeeper: String?) {
        var coreConnection = ""
        var keyDistinction: String?
        var practicalImplication: String?
        var goDeeper: String?

        // Normalize content - replace newlines with spaces for simpler matching
        let normalizedContent = content.replacingOccurrences(of: "\n", with: " ")

        // Simple string-based parsing for each section
        // Look for "Key Distinction:" marker
        if let keyStart = normalizedContent.range(of: "Key Distinction:", options: .caseInsensitive) {
            var keyText = String(normalizedContent[keyStart.upperBound...])
            // Find end at next section marker or end
            if let practicalStart = keyText.range(of: "Practical Implication:", options: .caseInsensitive) {
                keyText = String(keyText[..<practicalStart.lowerBound])
            } else if let goStart = keyText.range(of: "Go Deeper:", options: .caseInsensitive) {
                keyText = String(keyText[..<goStart.lowerBound])
            }
            keyDistinction = keyText.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Look for "Practical Implication:" marker
        if let practStart = normalizedContent.range(of: "Practical Implication:", options: .caseInsensitive) {
            var practText = String(normalizedContent[practStart.upperBound...])
            // Find end at next section marker or end
            if let goStart = practText.range(of: "Go Deeper:", options: .caseInsensitive) {
                practText = String(practText[..<goStart.lowerBound])
            }
            practicalImplication = practText.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Look for "Go Deeper:" marker
        if let goStart = normalizedContent.range(of: "Go Deeper:", options: .caseInsensitive) {
            let goText = String(normalizedContent[goStart.upperBound...])
            goDeeper = goText.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Extract core connection (everything before the first structured section)
        var coreText = normalizedContent
        if let keyRange = normalizedContent.range(of: "Key Distinction:", options: .caseInsensitive) {
            coreText = String(normalizedContent[..<keyRange.lowerBound])
        } else if let keyRange = normalizedContent.range(of: "**Key Distinction", options: .caseInsensitive) {
            coreText = String(normalizedContent[..<keyRange.lowerBound])
        }
        coreConnection = coreText.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)

        return (coreConnection, keyDistinction, practicalImplication, goDeeper)
    }

    private func goDeepSection(_ goDeeper: GoDeeper) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(.blue)
                Text("Go Deeper")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "book")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(goDeeper.bookTitle)
                        .font(.body)
                        .fontWeight(.medium)
                        .italic()

                    Text("by \(goDeeper.author)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(goDeeper.whatYoullLearn)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// Preview commented out to avoid deprecation warnings
// Use PremiumInsightNoteView from AnalysisComponents.swift instead
/*
#Preview("Legacy InsightNoteView - Deprecated") {
    ScrollView {
        VStack(spacing: 20) {
            InsightNoteView(note: InsightNote(
                coreConnection: "The Judge-Victim dynamic closely resembles what psychoanalyst Melanie Klein called \"internal objects\"—internalized versions of external relationships that continue operating within the psyche. Brené Brown identifies similar patterns in her work on shame resilience.",
                keyDistinction: "The Toltec framework is more optimistic than traditional psychoanalysis—these voices are learned agreements that can be changed, not fundamental psychological structures.",
                practicalImplication: "You don't need years of therapy to understand where your inner critic came from. You can start changing the agreement today by catching the Judge's voice and choosing not to comply.",
                goDeeper: GoDeeper(
                    bookTitle: "Daring Greatly",
                    author: "Brené Brown",
                    whatYoullLearn: "Research-backed strategies on shame resilience and vulnerability"
                )
            ))

            InsightNoteView(note: InsightNote(
                coreConnection: "The concept of \"domestication\" parallels what cognitive behavioral therapy calls \"core beliefs\"—fundamental assumptions about ourselves and the world formed in childhood.",
                keyDistinction: "While CBT focuses on rational examination of beliefs, the Toltec approach emphasizes the emotional and spiritual dimension of liberation.",
                practicalImplication: "Both approaches can work together: use CBT techniques to identify distorted thinking, then apply the Four Agreements as guiding principles for new behavior.",
                goDeeper: GoDeeper(
                    bookTitle: "Feeling Good",
                    author: "David D. Burns",
                    whatYoullLearn: "The foundational text on cognitive behavioral therapy techniques"
                )
            ))
        }
        .padding()
    }
}
*/
