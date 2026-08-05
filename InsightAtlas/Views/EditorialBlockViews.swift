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
        let parsed = parseStructuredNoteContent(content)

        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundColor(AnalysisTheme.accentTeal)

                Text(title ?? "INSIGHT ATLAS NOTE")
                    .font(.analysisUIBold())
                    .tracking(1.5)
                    .foregroundColor(AnalysisTheme.accentTeal)
            }

            if !parsed.coreConnection.isEmpty {
                Text(parseMarkdownBold(parsed.coreConnection))
                    .font(.analysisBody())
                    .foregroundColor(AnalysisTheme.textBody)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let keyDistinction = parsed.keyDistinction, !keyDistinction.isEmpty {
                NoteSubsection(
                    label: "KEY DISTINCTION",
                    icon: "arrow.triangle.branch",
                    text: keyDistinction
                )
            }

            if let practical = parsed.practicalImplication, !practical.isEmpty {
                NoteSubsection(
                    label: "PRACTICAL IMPLICATION",
                    icon: "lightbulb",
                    text: practical
                )
            }

            if let goDeeper = parsed.goDeeper, !goDeeper.isEmpty {
                // Inset "Go Deeper" card with gold accent bar, matching the PDF layout
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AnalysisTheme.primaryGold)
                        .frame(width: 3)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("GO DEEPER")
                            .font(.analysisUISmall())
                            .fontWeight(.semibold)
                            .tracking(1.5)
                            .foregroundColor(AnalysisTheme.primaryGoldText)

                        Text(parseMarkdownBold(goDeeper))
                            .font(.analysisBody())
                            .italic()
                            .foregroundColor(AnalysisTheme.textBody)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AnalysisTheme.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AnalysisTheme.Radius.sm))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AnalysisTheme.accentTealSubtle.opacity(0.3))
        .cornerRadius(AnalysisTheme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.md)
                .stroke(AnalysisTheme.accentTeal.opacity(0.3), lineWidth: 1)
        )
    }
}

/// A labeled sub-section within an Insight Atlas Note — the label always
/// starts on its own line above the text.
private struct NoteSubsection: View {
    let label: String
    let icon: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(AnalysisTheme.accentTeal)

                Text(label)
                    .font(.analysisUISmall())
                    .fontWeight(.semibold)
                    .tracking(1.5)
                    .foregroundColor(AnalysisTheme.accentTeal)
            }

            Text(parseMarkdownBold(text))
                .font(.analysisBody())
                .foregroundColor(AnalysisTheme.textBody)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Splits note content into its editorial sections so each labeled part
/// ("Key Distinction:", "Practical Implication:", "Go Deeper:") renders on
/// its own line instead of running together in one paragraph.
func parseStructuredNoteContent(_ content: String) -> (coreConnection: String, keyDistinction: String?, practicalImplication: String?, goDeeper: String?) {
    let normalized = content.replacingOccurrences(of: "\n", with: " ")

    func stripMarkers(_ text: String) -> String {
        text.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func section(after marker: String, endingAt enders: [String]) -> String? {
        guard let start = normalized.range(of: marker, options: .caseInsensitive) else { return nil }
        var text = String(normalized[start.upperBound...])
        for ender in enders {
            if let end = text.range(of: ender, options: .caseInsensitive) {
                text = String(text[..<end.lowerBound])
            }
        }
        return stripMarkers(text)
    }

    let keyDistinction = section(after: "Key Distinction:", endingAt: ["Practical Implication", "Go Deeper"])
    let practicalImplication = section(after: "Practical Implication:", endingAt: ["Go Deeper"])
    let goDeeper = section(after: "Go Deeper:", endingAt: [])

    var coreText = normalized
    for marker in ["Key Distinction", "Practical Implication", "Go Deeper"] {
        if let range = coreText.range(of: marker, options: .caseInsensitive) {
            coreText = String(coreText[..<range.lowerBound])
        }
    }
    // Trim any trailing bold marker left from "**Key Distinction:**"-style labels
    let coreConnection = stripMarkers(coreText)

    return (coreConnection, keyDistinction, practicalImplication, goDeeper)
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

    /// The big quote glyph supplies the quotation marks, so strip any that
    /// came along in the source text.
    private var cleanQuote: String {
        quote.trimmingCharacters(in: CharacterSet(charactersIn: "\"\u{201C}\u{201D} \n"))
    }

    var body: some View {
        VStack(spacing: 18) {
            // Ornamental top rule with quote glyph
            HStack(spacing: 12) {
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, AnalysisTheme.primaryGold], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)

                Image(systemName: "quote.opening")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AnalysisTheme.primaryGold)

                Rectangle()
                    .fill(LinearGradient(colors: [AnalysisTheme.primaryGold, .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
            }

            Text(cleanQuote)
                .font(.analysisDisplayH3())
                .italic()
                .foregroundColor(AnalysisTheme.textHeading)
                .multilineTextAlignment(.center)
                .lineSpacing(8)
                .fixedSize(horizontal: false, vertical: true)

            if let attribution = attribution, !attribution.isEmpty {
                Text("— \(attribution)")
                    .font(.analysisUIBold())
                    .tracking(1)
                    .foregroundColor(AnalysisTheme.primaryGoldText)
            }

            // Ornamental bottom rule
            HStack(spacing: 12) {
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, AnalysisTheme.primaryGold], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)

                Image(systemName: "diamond.fill")
                    .font(.system(size: 7))
                    .foregroundColor(AnalysisTheme.primaryGold)

                Rectangle()
                    .fill(LinearGradient(colors: [AnalysisTheme.primaryGold, .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
            }
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [AnalysisTheme.primaryGoldSubtle, AnalysisTheme.bgCard],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                .stroke(AnalysisTheme.primaryGold.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: - Blockquote Block

struct BlockquoteBlockView: View {
    let content: String
    let cite: String?

    private var cleanContent: String {
        content.trimmingCharacters(in: CharacterSet(charactersIn: "\"\u{201C}\u{201D} \n"))
    }

    var body: some View {
        if cleanContent.isEmpty {
            EmptyView()
        } else {
            HStack(alignment: .top, spacing: 16) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [AnalysisTheme.primaryGold, AnalysisTheme.primaryGoldLight],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AnalysisTheme.primaryGold.opacity(0.7))

                    Text(parseMarkdownBold(cleanContent))
                        .font(.analysisDisplayH4())
                        .italic()
                        .foregroundColor(AnalysisTheme.textHeading)
                        .lineSpacing(7)
                        .fixedSize(horizontal: false, vertical: true)

                    if let cite = cite, !cite.isEmpty {
                        Text("— \(cite)")
                            .font(.analysisUISmall())
                            .foregroundColor(AnalysisTheme.textMuted)
                    }
                }
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [AnalysisTheme.primaryGoldSubtle, AnalysisTheme.bgCard],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: AnalysisTheme.Radius.md))
        }
    }
}

// MARK: - Author Spotlight Block

/// Framed keepsake card for the author biography — a double gold frame,
/// a labeled header band, and the author's name set large in display type.
struct AuthorSpotlightBlockView: View {
    let content: String
    var authorName: String = ""

    // The card keeps its light parchment surface in both color schemes,
    // so text colors are pinned to the light palette.
    private let bodyTextColor = AnalysisTheme.Light.textBody

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header band
            HStack(spacing: 10) {
                Image(systemName: "book.fill")
                    .font(.system(size: 17))
                    .foregroundColor(AnalysisTheme.primaryGoldText)

                Text("AUTHOR SPOTLIGHT")
                    .font(.analysisUIBold())
                    .tracking(2.5)
                    .foregroundColor(AnalysisTheme.primaryGoldText)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(AnalysisTheme.goldFrameCreamMid)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AnalysisTheme.primaryGold.opacity(0.35))
                    .frame(height: 1)
            }

            // Name + biography
            VStack(alignment: .leading, spacing: 14) {
                if !authorName.isEmpty {
                    Text(authorName.uppercased())
                        .font(.analysisDisplayH2())
                        .fontWeight(.bold)
                        .tracking(1)
                        .foregroundColor(AnalysisTheme.accentOrangeText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(parseMarkdownBold(content))
                    .font(.analysisBodyLarge())
                    .foregroundColor(bodyTextColor)
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AnalysisTheme.goldFrameCreamLight, AnalysisTheme.goldFrameCreamMid],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AnalysisTheme.Radius.xl))
        // Inner hairline of the double frame
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.xl - 4)
                .stroke(AnalysisTheme.primaryGold.opacity(0.45), lineWidth: 1)
                .padding(5)
        )
        // Outer gold frame
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.xl)
                .stroke(
                    LinearGradient(
                        colors: [AnalysisTheme.goldFrameInnerMid, AnalysisTheme.goldFrameOuterDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2.5
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
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
        if text.trimmingCharacters(in: .whitespaces).isEmpty {
            // Never render an empty header — the accent bar alone reads as a stray line
            EmptyView()
        } else {
            headerContent
        }
    }

    private var headerContent: some View {
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

/// Hub-and-spoke concept map: a central concept node with a visible spine
/// connecting each branch, so the hierarchy reads at a glance. Branches
/// written as "Label: description" split into a small-caps label over its
/// description; full-width rows keep text from squeezing into hyphenation.
struct ConceptMapBlockView: View {
    let central: String
    let related: [String]
    let title: String?

    var body: some View {
        if central.isEmpty && related.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                if let title = title, !title.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .foregroundColor(AnalysisTheme.primaryGold)
                        Text(title.uppercased())
                            .font(.analysisUISmall())
                            .fontWeight(.semibold)
                            .tracking(1.5)
                            .foregroundColor(AnalysisTheme.textMuted)
                    }
                    .padding(.bottom, 16)
                }

                // Central hub node
                if !central.isEmpty {
                    Text(parseMarkdownBold(central))
                        .font(.analysisUIBold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                                .fill(
                                    LinearGradient(
                                        colors: [AnalysisTheme.primaryGold, AnalysisTheme.primaryGoldDark],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .shadow(color: AnalysisTheme.primaryGold.opacity(0.3), radius: 6, y: 3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Branches connected by a visible spine
                if !related.isEmpty {
                    if !central.isEmpty {
                        Rectangle()
                            .fill(AnalysisTheme.primaryGold.opacity(0.45))
                            .frame(width: 2, height: 18)
                    }

                    ForEach(Array(related.enumerated()), id: \.offset) { index, concept in
                        if index > 0 {
                            Rectangle()
                                .fill(AnalysisTheme.primaryGold.opacity(0.45))
                                .frame(width: 2, height: 14)
                        }
                        ConceptBranchRow(text: concept)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(AnalysisTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                    .stroke(AnalysisTheme.primaryGoldMuted, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }
}

private struct ConceptBranchRow: View {
    let text: String

    /// Split "Label: description" into a heading and detail when the label
    /// is short enough to be a name rather than part of a sentence.
    private var parts: (label: String?, detail: String) {
        if let idx = text.firstIndex(of: ":") {
            let label = String(text[..<idx]).trimmingCharacters(in: .whitespaces)
            let detail = String(text[text.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
            if !label.isEmpty && !detail.isEmpty && label.count <= 40 {
                return (label.replacingOccurrences(of: "**", with: ""), detail)
            }
        }
        return (nil, text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label = parts.label {
                Text(label.uppercased())
                    .font(.analysisUISmall())
                    .fontWeight(.semibold)
                    .tracking(1)
                    .foregroundColor(AnalysisTheme.primaryGoldText)
            }

            Text(parseMarkdownBold(parts.detail))
                .font(.analysisBody())
                .foregroundColor(AnalysisTheme.textBody)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AnalysisTheme.primaryGoldSubtle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AnalysisTheme.primaryGold.opacity(0.25), lineWidth: 1)
        )
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

    private var columnCount: Int {
        data.map(\.count).max() ?? 0
    }

    var body: some View {
        if data.isEmpty || columnCount == 0 {
            EmptyView()
        } else if columnCount > 3 {
            // Wide tables scroll horizontally instead of squeezing every
            // column into the screen width and hyphenating each word.
            ScrollView(.horizontal, showsIndicators: true) {
                tableContent
                    .frame(minWidth: CGFloat(columnCount) * 130)
            }
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
