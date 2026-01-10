import SwiftUI

/// View for displaying the Quick Glance Summary section
/// - Important: This is a legacy view. Use `PremiumQuickGlanceView` from AnalysisComponents.swift instead,
///   which follows the AnalysisTheme design system and matches the premium brand colors.
@available(*, deprecated, message: "Use PremiumQuickGlanceView from AnalysisComponents.swift instead")
struct QuickGlanceView: View {

    let summary: QuickGlanceSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "eye")
                    .font(.title3)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick Glance Summary")
                        .font(.headline)
                    Text(summary.readTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Divider()

            // Title and Author
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.title)
                    .font(.title2)
                    .fontWeight(.bold)

                Text("by \(summary.author)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // One-Sentence Premise
            VStack(alignment: .leading, spacing: 8) {
                Text("One-Sentence Premise")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Text(summary.oneSentencePremise)
                    .font(.body)
            }

            // Core Framework Overview
            VStack(alignment: .leading, spacing: 8) {
                Text("Core Framework")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Text(summary.coreFrameworkOverview)
                    .font(.body)
            }

            // Main Concepts
            VStack(alignment: .leading, spacing: 12) {
                Text("Main Concepts")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                ForEach(summary.mainConcepts) { concept in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(concept.number)")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.blue)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(concept.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text(concept.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Bottom Line
            VStack(alignment: .leading, spacing: 8) {
                Text("The Bottom Line")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Text(summary.bottomLine)
                    .font(.body)
                    .fontWeight(.medium)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Who Should Read This
            VStack(alignment: .leading, spacing: 8) {
                Text("Who Should Read This")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Text(summary.whoShouldRead)
                    .font(.body)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

// Preview removed to avoid deprecation warning on legacy view.
// For current implementation, see PremiumQuickGlanceView in AnalysisComponents.swift
