//
//  EditorialBlockViews.swift
//  InsightAtlas
//
//  SwiftUI view components for rendering editorial content blocks.
//  These match the premium styling from the PDF renderer.
//

import SwiftUI

// MARK: - Quick Glance Block

struct QuickGlanceBlockView: View {
    let content: String
    let metadata: [String: String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "eye.fill")
                    .font(.title3)
                    .foregroundColor(AnalysisTheme.primaryGold)

                Text("QUICK GLANCE")
                    .font(.analysisUIBold())
                    .tracking(2)
                    .foregroundColor(AnalysisTheme.primaryGold)

                Spacer()

                if let readTime = metadata["readTime"] {
                    Text(readTime)
                        .font(.analysisUISmall())
                        .foregroundColor(AnalysisTheme.textMuted)
                }
            }

            Divider()
                .background(AnalysisTheme.primaryGoldSubtle)

            // Content
            Text(parseMarkdownBold(content))
                .font(.analysisBody())
                .foregroundColor(AnalysisTheme.textBody)
                .lineSpacing(6)
        }
        .padding(20)
        .background(AnalysisTheme.bgCard)
        .cornerRadius(AnalysisTheme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                .stroke(AnalysisTheme.primaryGoldSubtle, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: - Insight Note Block

struct InsightNoteBlockView: View {
    let content: String
    let title: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundColor(AnalysisTheme.accentTeal)

                Text(title ?? "INSIGHT ATLAS NOTE")
                    .font(.analysisUIBold())
                    .tracking(1.5)
                    .foregroundColor(AnalysisTheme.accentTeal)
            }

            Text(parseMarkdownBold(content))
                .font(.analysisBody())
                .foregroundColor(AnalysisTheme.textBody)
                .lineSpacing(6)
        }
        .padding(20)
        .background(AnalysisTheme.accentTealSubtle.opacity(0.3))
        .cornerRadius(AnalysisTheme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.md)
                .stroke(AnalysisTheme.accentTeal.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Action Box Block

struct ActionBoxBlockView: View {
    let items: [String]
    let title: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(AnalysisTheme.accentGreen)

                Text("APPLY IT")
                    .font(.analysisUIBold())
                    .tracking(1.5)
                    .foregroundColor(AnalysisTheme.accentGreen)

                if let title = title, title != "Apply It" {
                    Text(": \(title)")
                        .font(.analysisDisplayH4())
                        .foregroundColor(AnalysisTheme.textHeading)
                }
            }

            Divider()
                .background(AnalysisTheme.accentGreen.opacity(0.3))

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(AnalysisTheme.accentGreen)
                            .clipShape(Circle())

                        Text(parseMarkdownBold(item))
                            .font(.analysisBody())
                            .foregroundColor(AnalysisTheme.textBody)
                    }
                }
            }
        }
        .padding(20)
        .background(AnalysisTheme.accentGreen.opacity(0.05))
        .cornerRadius(AnalysisTheme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.md)
                .stroke(AnalysisTheme.accentGreen.opacity(0.3), lineWidth: 2)
        )
    }
}

// MARK: - Key Takeaways Block

struct KeyTakeawaysBlockView: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.title3)
                    .foregroundColor(AnalysisTheme.primaryGold)

                Text("KEY TAKEAWAYS")
                    .font(.analysisUIBold())
                    .tracking(1.5)
                    .foregroundColor(AnalysisTheme.primaryGold)
            }

            Divider()
                .background(AnalysisTheme.primaryGoldSubtle)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(AnalysisTheme.primaryGold)
                            .clipShape(Circle())

                        Text(parseMarkdownBold(item))
                            .font(.analysisBody())
                            .foregroundColor(AnalysisTheme.textBody)
                            .lineSpacing(4)
                    }
                }
            }
        }
        .padding(20)
        .background(AnalysisTheme.primaryGoldSubtle.opacity(0.2))
        .cornerRadius(AnalysisTheme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                .stroke(AnalysisTheme.primaryGoldSubtle, lineWidth: 1)
        )
    }
}

// MARK: - Foundational Narrative Block

struct FoundationalNarrativeBlockView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "book.fill")
                    .font(.title3)
                    .foregroundColor(AnalysisTheme.brandSepia)

                Text("THE STORY BEHIND THE IDEAS")
                    .font(.analysisUIBold())
                    .tracking(1.5)
                    .foregroundColor(AnalysisTheme.brandSepia)
            }

            Text(parseMarkdownBold(content))
                .font(.analysisBody())
                .foregroundColor(AnalysisTheme.textBody)
                .lineSpacing(6)
                .italic()
        }
        .padding(20)
        .background(AnalysisTheme.parchmentBase.opacity(0.5))
        .cornerRadius(AnalysisTheme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.md)
                .stroke(AnalysisTheme.brandSepia.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Exercise Block

struct ExerciseBlockView: View {
    let content: String
    let steps: [String]
    let title: String?
    let time: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "figure.walk")
                        .font(.title3)
                        .foregroundColor(AnalysisTheme.accentCoral)

                    Text(title ?? "EXERCISE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .tracking(1.5)
                        .foregroundColor(AnalysisTheme.accentCoral)
                }

                Spacer()

                if let time = time {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(time)
                            .font(.caption)
                    }
                    .foregroundColor(AnalysisTheme.textMuted)
                }
            }

            if !content.isEmpty {
                Text(parseMarkdownBold(content))
                    .font(.analysisBody())
                    .foregroundColor(AnalysisTheme.textBody)
            }

            if !steps.isEmpty {
                Divider()
                    .background(AnalysisTheme.accentCoral.opacity(0.3))

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                                .background(AnalysisTheme.accentCoral)
                                .clipShape(Circle())

                            Text(parseMarkdownBold(step))
                                .font(.analysisBody())
                                .foregroundColor(AnalysisTheme.textBody)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(AnalysisTheme.accentCoral.opacity(0.05))
        .cornerRadius(AnalysisTheme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.md)
                .stroke(AnalysisTheme.accentCoral.opacity(0.3), lineWidth: 2)
        )
    }
}

// MARK: - Premium Quote Block

struct PremiumQuoteBlockView: View {
    let quote: String
    let attribution: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "quote.opening")
                    .font(.title)
                    .foregroundColor(AnalysisTheme.primaryGold)

                Text(quote)
                    .font(.analysisDisplayH4())
                    .foregroundColor(AnalysisTheme.textHeading)
                    .italic()
                    .lineSpacing(8)
            }

            if let attribution = attribution, !attribution.isEmpty {
                HStack {
                    Spacer()
                    Text("— \(attribution)")
                        .font(.analysisUISmall())
                        .foregroundColor(AnalysisTheme.textMuted)
                }
            }
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [AnalysisTheme.primaryGoldSubtle.opacity(0.3), AnalysisTheme.parchmentBase.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(AnalysisTheme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                .stroke(AnalysisTheme.primaryGold.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Blockquote Block

struct BlockquoteBlockView: View {
    let content: String
    let cite: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(AnalysisTheme.primaryGold)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 8) {
                Text(parseMarkdownBold(content))
                    .font(.analysisBodyLarge())
                    .foregroundColor(AnalysisTheme.textBody)
                    .italic()
                    .lineSpacing(4)

                if let cite = cite, !cite.isEmpty {
                    Text("— \(cite)")
                        .font(.analysisUISmall())
                        .foregroundColor(AnalysisTheme.textMuted)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(AnalysisTheme.parchmentBase.opacity(0.3))
        .cornerRadius(AnalysisTheme.Radius.sm)
    }
}

// MARK: - Author Spotlight Block

struct AuthorSpotlightBlockView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .font(.title3)
                    .foregroundColor(AnalysisTheme.brandSepia)

                Text("ABOUT THE AUTHOR")
                    .font(.analysisUIBold())
                    .tracking(1.5)
                    .foregroundColor(AnalysisTheme.brandSepia)
            }

            Text(parseMarkdownBold(content))
                .font(.analysisBody())
                .foregroundColor(AnalysisTheme.textBody)
                .lineSpacing(6)
        }
        .padding(20)
        .background(AnalysisTheme.parchmentBase.opacity(0.5))
        .cornerRadius(AnalysisTheme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.md)
                .stroke(AnalysisTheme.brandSepia.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Alternative Perspective Block

struct AlternativePerspectiveBlockView: View {
    let content: String
    let title: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title3)
                    .foregroundColor(AnalysisTheme.accentPurple)

                Text(title ?? "ALTERNATIVE PERSPECTIVE")
                    .font(.analysisUIBold())
                    .tracking(1.5)
                    .foregroundColor(AnalysisTheme.accentPurple)
            }

            Text(parseMarkdownBold(content))
                .font(.analysisBody())
                .foregroundColor(AnalysisTheme.textBody)
                .lineSpacing(6)
        }
        .padding(20)
        .background(AnalysisTheme.accentPurple.opacity(0.05))
        .cornerRadius(AnalysisTheme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.md)
                .stroke(AnalysisTheme.accentPurple.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Research Insight Block

struct ResearchInsightBlockView: View {
    let content: String
    let title: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.title3)
                    .foregroundColor(AnalysisTheme.accentBlue)

                Text(title ?? "RESEARCH INSIGHT")
                    .font(.analysisUIBold())
                    .tracking(1.5)
                    .foregroundColor(AnalysisTheme.accentBlue)
            }

            Text(parseMarkdownBold(content))
                .font(.analysisBody())
                .foregroundColor(AnalysisTheme.textBody)
                .lineSpacing(6)
        }
        .padding(20)
        .background(AnalysisTheme.accentBlue.opacity(0.05))
        .cornerRadius(AnalysisTheme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.md)
                .stroke(AnalysisTheme.accentBlue.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Section Header Block

struct SectionHeaderBlockView: View {
    let text: String
    let level: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if level == 1 {
                Text(text)
                    .font(.analysisDisplayH2())
                    .foregroundColor(AnalysisTheme.textHeading)
                    .padding(.top, 16)

                Rectangle()
                    .fill(AnalysisTheme.primaryGold)
                    .frame(width: 60, height: 3)
            } else if level == 2 {
                Text(text)
                    .font(.analysisDisplayH3())
                    .foregroundColor(AnalysisTheme.textHeading)
                    .padding(.top, 12)
            } else {
                Text(text)
                    .font(.analysisDisplayH4())
                    .foregroundColor(AnalysisTheme.textHeading)
                    .padding(.top, 8)
            }
        }
    }
}

// MARK: - Part Header Block

struct PartHeaderBlockView: View {
    let text: String

    var body: some View {
        VStack(spacing: 12) {
            // Ornamental line
            HStack(spacing: 8) {
                Rectangle()
                    .fill(AnalysisTheme.primaryGold)
                    .frame(height: 1)
                Image(systemName: "diamond.fill")
                    .font(.caption2)
                    .foregroundColor(AnalysisTheme.primaryGold)
                Rectangle()
                    .fill(AnalysisTheme.primaryGold)
                    .frame(height: 1)
            }

            Text(text.uppercased())
                .font(.analysisDisplayH1())
                .foregroundColor(AnalysisTheme.textHeading)
                .tracking(3)
                .multilineTextAlignment(.center)

            // Ornamental line
            HStack(spacing: 8) {
                Rectangle()
                    .fill(AnalysisTheme.primaryGold)
                    .frame(height: 1)
                Image(systemName: "diamond.fill")
                    .font(.caption2)
                    .foregroundColor(AnalysisTheme.primaryGold)
                Rectangle()
                    .fill(AnalysisTheme.primaryGold)
                    .frame(height: 1)
            }
        }
        .padding(.vertical, 24)
    }
}

// MARK: - Premium Divider

struct PremiumDividerView: View {
    var body: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(LinearGradient(colors: [.clear, AnalysisTheme.primaryGold], startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)

            Image(systemName: "diamond.fill")
                .font(.caption2)
                .foregroundColor(AnalysisTheme.primaryGold)

            Rectangle()
                .fill(LinearGradient(colors: [AnalysisTheme.primaryGold, .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
        }
        .padding(.vertical, 16)
    }
}

// MARK: - List Blocks

struct BulletListBlockView: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(AnalysisTheme.primaryGold)
                        .frame(width: 6, height: 6)
                        .padding(.top, 8)

                    Text(parseMarkdownBold(item))
                        .font(.analysisBody())
                        .foregroundColor(AnalysisTheme.textBody)
                }
            }
        }
    }
}

struct NumberedListBlockView: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1).")
                        .font(.analysisBody())
                        .fontWeight(.semibold)
                        .foregroundColor(AnalysisTheme.primaryGold)
                        .frame(width: 24, alignment: .trailing)

                    Text(parseMarkdownBold(item))
                        .font(.analysisBody())
                        .foregroundColor(AnalysisTheme.textBody)
                }
            }
        }
    }
}

// MARK: - Paragraph Block

struct ParagraphBlockView: View {
    let content: String
    let searchQuery: String

    var body: some View {
        if searchQuery.isEmpty {
            Text(parseMarkdownBold(content))
                .font(.analysisBody())
                .foregroundColor(AnalysisTheme.textBody)
                .lineSpacing(6)
        } else {
            HighlightedText(text: content, highlight: searchQuery)
                .font(.analysisBody())
                .foregroundColor(AnalysisTheme.textBody)
                .lineSpacing(6)
        }
    }
}

// MARK: - Visual Block

struct VisualBlockView: View {
    let url: String?
    let caption: String?
    let visualType: String?

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            if let urlString = url, let imageURL = URL(string: urlString) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(AnalysisTheme.Radius.md)
                    case .failure:
                        visualPlaceholder
                    case .empty:
                        ProgressView()
                            .frame(height: 200)
                    @unknown default:
                        visualPlaceholder
                    }
                }
            } else {
                visualPlaceholder
            }

            if let caption = caption, !caption.isEmpty {
                Text(caption)
                    .font(.analysisUISmall())
                    .foregroundColor(AnalysisTheme.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var visualPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundColor(AnalysisTheme.textMuted)
            if let type = visualType {
                Text(type)
                    .font(.caption)
                    .foregroundColor(AnalysisTheme.textMuted)
            }
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .background(AnalysisTheme.parchmentBase.opacity(0.3))
        .cornerRadius(AnalysisTheme.Radius.md)
    }
}

// MARK: - Flowchart Block

struct FlowchartBlockView: View {
    let steps: [String]
    let title: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = title {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.square.fill")
                        .font(.title3)
                        .foregroundColor(AnalysisTheme.accentBlue)

                    Text(title)
                        .font(.headline)
                        .foregroundColor(AnalysisTheme.textHeading)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 12) {
                        // Step number
                        Text("\(index + 1)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(AnalysisTheme.accentBlue)
                            .clipShape(Circle())

                        // Step content
                        Text(parseMarkdownBold(step))
                            .font(.analysisBody())
                            .foregroundColor(AnalysisTheme.textBody)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AnalysisTheme.accentBlue.opacity(0.1))
                            .cornerRadius(AnalysisTheme.Radius.sm)
                    }

                    // Arrow between steps
                    if index < steps.count - 1 {
                        HStack {
                            Spacer().frame(width: 14)
                            Image(systemName: "arrow.down")
                                .font(.caption)
                                .foregroundColor(AnalysisTheme.accentBlue)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(AnalysisTheme.Radius.lg)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: - Concept Map Block

struct ConceptMapBlockView: View {
    let central: String
    let related: [String]
    let title: String?

    var body: some View {
        VStack(spacing: 16) {
            if let title = title {
                Text(title)
                    .font(.headline)
                    .foregroundColor(AnalysisTheme.textHeading)
            }

            // Central concept
            Text(parseMarkdownBold(central))
                .font(.headline)
                .foregroundColor(.white)
                .padding(16)
                .background(AnalysisTheme.primaryGold)
                .cornerRadius(AnalysisTheme.Radius.md)

            // Related concepts
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(related.enumerated()), id: \.offset) { _, concept in
                    Text(parseMarkdownBold(concept))
                        .font(.subheadline)
                        .foregroundColor(AnalysisTheme.textBody)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(AnalysisTheme.primaryGoldSubtle.opacity(0.3))
                        .cornerRadius(AnalysisTheme.Radius.sm)
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(AnalysisTheme.Radius.lg)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: - Process Timeline Block

struct ProcessTimelineBlockView: View {
    let phases: [String]
    let title: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = title {
                HStack(spacing: 8) {
                    Image(systemName: "timeline.selection")
                        .font(.title3)
                        .foregroundColor(AnalysisTheme.accentTeal)

                    Text(title)
                        .font(.headline)
                        .foregroundColor(AnalysisTheme.textHeading)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                    HStack(alignment: .top, spacing: 16) {
                        // Timeline indicator
                        VStack(spacing: 0) {
                            Circle()
                                .fill(AnalysisTheme.accentTeal)
                                .frame(width: 12, height: 12)

                            if index < phases.count - 1 {
                                Rectangle()
                                    .fill(AnalysisTheme.accentTeal.opacity(0.3))
                                    .frame(width: 2)
                                    .frame(minHeight: 40)
                            }
                        }

                        // Phase content
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Phase \(index + 1)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AnalysisTheme.accentTeal)

                            Text(parseMarkdownBold(phase))
                                .font(.analysisBody())
                                .foregroundColor(AnalysisTheme.textBody)
                        }
                        .padding(.bottom, index < phases.count - 1 ? 16 : 0)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(AnalysisTheme.Radius.lg)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: - Table Block

struct TableBlockView: View {
    let data: [[String]]

    var body: some View {
        if data.isEmpty {
            EmptyView()
        } else {
            tableContent
        }
    }

    private var tableContent: some View {
        VStack(spacing: 0) {
            ForEach(Array(data.enumerated()), id: \.offset) { rowIndex, row in
                TableRowView(row: row, rowIndex: rowIndex)

                if rowIndex < data.count - 1 {
                    Divider()
                }
            }
        }
        .cornerRadius(AnalysisTheme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.md)
                .stroke(AnalysisTheme.borderLight, lineWidth: 1)
        )
    }
}

private struct TableRowView: View {
    let row: [String]
    let rowIndex: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cell in
                TableCellView(cell: cell, isHeader: rowIndex == 0, isAlternate: rowIndex % 2 == 1)

                if colIndex < row.count - 1 {
                    Divider()
                }
            }
        }
    }
}

private struct TableCellView: View {
    let cell: String
    let isHeader: Bool
    let isAlternate: Bool

    var body: some View {
        Text(cell)
            .font(isHeader ? .headline : .body)
            .foregroundColor(isHeader ? AnalysisTheme.textHeading : AnalysisTheme.textBody)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cellBackground)
    }

    private var cellBackground: Color {
        if isHeader {
            return AnalysisTheme.primaryGoldSubtle.opacity(0.3)
        } else if isAlternate {
            return AnalysisTheme.parchmentBase.opacity(0.3)
        } else {
            return Color.clear
        }
    }
}

// MARK: - Highlighted Text View

struct HighlightedText: View {
    let text: String
    let highlight: String

    var body: some View {
        if highlight.isEmpty {
            Text(parseMarkdownBold(text))
        } else {
            highlightedAttributedString
        }
    }

    private var highlightedAttributedString: Text {
        let lowercaseText = text.lowercased()
        let lowercaseHighlight = highlight.lowercased()

        guard lowercaseText.contains(lowercaseHighlight) else {
            return Text(parseMarkdownBold(text))
        }

        var result = Text("")
        var searchRange = text.startIndex..<text.endIndex

        while let range = text.range(of: highlight, options: .caseInsensitive, range: searchRange) {
            // Add text before match
            let beforeMatch = String(text[searchRange.lowerBound..<range.lowerBound])
            result = result + Text(beforeMatch)

            // Add highlighted match
            let match = String(text[range])
            result = result + Text(match).bold().foregroundColor(AnalysisTheme.primaryGold)

            searchRange = range.upperBound..<text.endIndex
        }

        // Add remaining text
        let remaining = String(text[searchRange])
        result = result + Text(remaining)

        return result
    }
}

// MARK: - Text Diagram Block

struct TextDiagramBlockView: View {
    let content: String
    let title: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = title {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.title3)
                        .foregroundColor(AnalysisTheme.accentBlue)

                    Text(title)
                        .font(.headline)
                        .foregroundColor(AnalysisTheme.textHeading)
                }
            }

            // Render the diagram with styled lines
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(content.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                    TextDiagramLineView(line: line)
                }
            }
            .padding(16)
            .background(AnalysisTheme.bgCard)
            .cornerRadius(AnalysisTheme.Radius.md)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(AnalysisTheme.Radius.lg)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

private struct TextDiagramLineView: View {
    let line: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(parseLineSegments(line).enumerated()), id: \.offset) { _, segment in
                segmentView(segment)
            }
        }
    }

    private func parseLineSegments(_ text: String) -> [DiagramSegment] {
        var segments: [DiagramSegment] = []
        var currentText = ""

        for char in text {
            if char == "→" || char == "↓" || char == "←" || char == "↑" {
                if !currentText.isEmpty {
                    segments.append(.text(currentText))
                    currentText = ""
                }
                segments.append(.arrow(String(char)))
            } else if char == "│" || char == "─" || char == "┌" || char == "└" || char == "┐" || char == "┘" || char == "├" || char == "┤" || char == "┬" || char == "┴" || char == "┼" {
                if !currentText.isEmpty {
                    segments.append(.text(currentText))
                    currentText = ""
                }
                segments.append(.box(String(char)))
            } else {
                currentText.append(char)
            }
        }

        if !currentText.isEmpty {
            segments.append(.text(currentText))
        }

        return segments
    }

    @ViewBuilder
    private func segmentView(_ segment: DiagramSegment) -> some View {
        switch segment {
        case .text(let text):
            Text(text)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(AnalysisTheme.textBody)
        case .arrow(let arrow):
            Text(arrow)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(AnalysisTheme.accentBlue)
        case .box(let char):
            Text(char)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(AnalysisTheme.accentTeal)
        }
    }
}

private enum DiagramSegment {
    case text(String)
    case arrow(String)
    case box(String)
}
