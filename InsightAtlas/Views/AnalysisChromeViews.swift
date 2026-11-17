import SwiftUI

// MARK: - Analysis Header View

struct AnalysisHeaderView: View {
    let title: String
    let author: String
    let subtitle: String?

    init(title: String, author: String, subtitle: String? = nil) {
        self.title = title
        self.author = author
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: AnalysisTheme.Spacing.lg) {
            // Logo
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 100)
                .opacity(0.9)

            // Brand badge
            Text("Insight Atlas")
                .font(.analysisUI())
                .foregroundColor(AnalysisTheme.brandSepia)
                .tracking(2)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AnalysisTheme.primaryGoldSubtle)
                .cornerRadius(AnalysisTheme.Radius.sm)

            // Book title
            Text(title)
                .font(.analysisDisplayTitle())
                .foregroundColor(AnalysisTheme.textHeading)
                .multilineTextAlignment(.center)

            // Subtitle/Description
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.analysisDisplayH4())
                    .foregroundColor(AnalysisTheme.textMuted)
                    .multilineTextAlignment(.center)
            }

            // Author
            Text(parseMarkdownBold("Based on the work of **\(author)**"))
                .font(.analysisBody())
                .foregroundColor(AnalysisTheme.textBody)
                .multilineTextAlignment(.center)

            // Tagline
            Text("Where Understanding Illuminates the World")
                .font(.analysisHandwritten())
                .foregroundColor(AnalysisTheme.accentCoralText)
                .multilineTextAlignment(.center)
                .padding(.top, AnalysisTheme.Spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AnalysisTheme.Spacing.xl2)
    }
}

// MARK: - Premium Quick Glance View

struct PremiumQuickGlanceView: View {
    let coreMessage: String
    let keyPoints: [String]
    let readingTime: Int

    // Box surface is adaptive (PremiumUI.card), so text follows the adaptive theme.
    private let boxTextColor = AnalysisTheme.textBody
    private let boxHeadingColor = AnalysisTheme.textHeading

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            HStack {
                HStack(spacing: 8) {
                    Text("📋")
                        .font(.system(size: 14))
                    Text("QUICK GLANCE")
                        .font(.analysisUIBold())
                        .foregroundColor(AnalysisTheme.primaryGoldDark)
                        .tracking(1)
                }

                Spacer()

                // Reading time badge - fixed layout to prevent text truncation
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                    Text("\(readingTime) min read")
                        .font(.analysisUISmall())
                        .fixedSize(horizontal: true, vertical: false)
                        .lineLimit(1)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                // Solid: both stops resolve to ember, so the gradient was flat.
                .background(AnalysisTheme.primaryGold)
                .cornerRadius(AnalysisTheme.Radius.full)
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.bottom, AnalysisTheme.Spacing.sm)

            // Divider with proper spacing from top border
            Divider()
                .background(AnalysisTheme.borderLight)
                .padding(.top, 4)

            Text(parseMarkdownBold("**Core Message:** \(coreMessage)"))
                .font(.analysisBody())
                .foregroundColor(boxTextColor)
                .padding(.top, AnalysisTheme.Spacing.sm)

            VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.sm) {
                ForEach(keyPoints, id: \.self) { point in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.analysisBody())
                            .foregroundColor(AnalysisTheme.primaryGoldText)
                        Text(parseMarkdownBold(point))
                            .font(.analysisBody())
                            .foregroundColor(boxTextColor)
                    }
                }
            }
        }
        .padding(AnalysisTheme.Spacing.xl)
        .padding(.top, 8) // Extra top padding to prevent overlap with top border
        .background(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.xl)
                .fill(PremiumUI.card)
                .shadow(color: AnalysisTheme.shadowCard, radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.xl)
                // Solid: all three stops resolved to ember.
                .stroke(AnalysisTheme.primaryGold, lineWidth: 2)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Table of Contents View

struct TableOfContentsView: View {
    let sections: [AnalysisSection]
    let onSectionTap: (Int) -> Void

    // Box surface is adaptive (PremiumUI.card), so text follows the adaptive theme.
    private let boxTextColor = AnalysisTheme.textBody
    private let boxHeadingColor = AnalysisTheme.textHeading
    private let tocAccentColor = AnalysisTheme.primaryGold

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            // Header
            HStack(spacing: 8) {
                Text("📑")
                    .font(.system(size: 14))

                Text("TABLE OF CONTENTS")
                    .font(.analysisUIBold())
                    .foregroundColor(tocAccentColor)
                    .tracking(1)

                Spacer()

                Text("\(filteredSections.count) sections")
                    .font(.analysisUISmall())
                    .foregroundColor(AnalysisTheme.textMuted)
            }
            .padding(.bottom, AnalysisTheme.Spacing.xs)

            Divider()
                .background(tocAccentColor.opacity(0.3))

            // TOC Entries
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(filteredSections.enumerated()), id: \.offset) { index, item in
                    Button(action: { onSectionTap(item.originalIndex) }) {
                        HStack(alignment: .top, spacing: 12) {
                            // Section number
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(tocAccentColor)
                                .clipShape(Circle())

                            // Section title
                            Text(item.title)
                                .font(.analysisBody())
                                .foregroundColor(boxTextColor)
                                .multilineTextAlignment(.leading)

                            Spacer()

                            // Arrow indicator
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(tocAccentColor.opacity(0.6))
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < filteredSections.count - 1 {
                        Divider()
                            .background(AnalysisTheme.borderLight)
                    }
                }
            }
            .padding(.top, AnalysisTheme.Spacing.sm)
        }
        .padding(AnalysisTheme.Spacing.xl)
        .background(PremiumUI.card)
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.xl)
                .stroke(tocAccentColor.opacity(0.3), lineWidth: 1.5)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(tocAccentColor)
                .frame(width: 4)
                .clipShape(
                    RoundedCorner(radius: AnalysisTheme.Radius.xl, corners: [.topLeft, .bottomLeft])
                )
        }
        .cornerRadius(AnalysisTheme.Radius.xl)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    /// Filter and transform sections for TOC display
    private var filteredSections: [(title: String, originalIndex: Int)] {
        var result: [(title: String, originalIndex: Int)] = []

        for (index, section) in sections.enumerated() {
            // Only include sections with headings
            if let heading = section.heading, !heading.isEmpty {
                // Skip very short or generic headings
                let trimmed = heading.trimmingCharacters(in: .whitespaces)
                if trimmed.count >= 3 {
                    result.append((title: trimmed, originalIndex: index))
                }
            }
        }

        return result
    }
}

// MARK: - Analysis Footer View

struct AnalysisFooterView: View {
    var body: some View {
        VStack(spacing: AnalysisTheme.Spacing.md) {
            // Logo
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 60)
                .opacity(0.7)

            Text("INSIGHT ATLAS")
                .font(.analysisUIBold())
                .foregroundColor(AnalysisTheme.brandSepia)
                .tracking(2)

            Text("Where Understanding Illuminates the World")
                .font(.analysisHandwritten())
                .foregroundColor(AnalysisTheme.accentCoralText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AnalysisTheme.Spacing.xl3)
        .padding(.bottom, AnalysisTheme.Spacing.xl)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AnalysisTheme.borderLight)
                .frame(height: 1)
        }
    }
}

// MARK: - Section Divider (Premium with Diamond Ornaments)

struct PremiumSectionDivider: View {
    var body: some View {
        HStack(spacing: 0) {
            // Left line
            Rectangle()
                .fill(AnalysisTheme.primaryGold)
                .frame(height: 1)

            // Diamond ornaments
            HStack(spacing: 6) {
                DiamondShape()
                    .fill(AnalysisTheme.primaryGold)
                    .frame(width: 8, height: 8)

                DiamondShape()
                    .stroke(AnalysisTheme.primaryGold, lineWidth: 1.5)
                    .frame(width: 10, height: 10)

                DiamondShape()
                    .fill(AnalysisTheme.primaryGold)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 16)

            // Right line
            Rectangle()
                .fill(AnalysisTheme.primaryGold)
                .frame(height: 1)
        }
        .padding(.vertical, AnalysisTheme.Spacing.xl2)
    }
}

// MARK: - Diamond Shape

struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let halfWidth = rect.width / 2
        let halfHeight = rect.height / 2

        path.move(to: CGPoint(x: center.x, y: center.y - halfHeight))
        path.addLine(to: CGPoint(x: center.x + halfWidth, y: center.y))
        path.addLine(to: CGPoint(x: center.x, y: center.y + halfHeight))
        path.addLine(to: CGPoint(x: center.x - halfWidth, y: center.y))
        path.closeSubpath()

        return path
    }
}

// MARK: - Premium Section Header H1 (Centered with Diamond Ornaments)

/// Premium H1 header matching the mockup: centered, gold, uppercase, with diamond ornaments above and below
struct PremiumSectionHeaderH1: View {
    let title: String

    var body: some View {
        VStack(spacing: AnalysisTheme.Spacing.md) {
            // Top diamond ornaments
            HStack(spacing: 8) {
                DiamondShape()
                    .stroke(AnalysisTheme.primaryGold, lineWidth: 1.5)
                    .frame(width: 8, height: 8)

                DiamondShape()
                    .fill(AnalysisTheme.primaryGold)
                    .frame(width: 10, height: 10)

                DiamondShape()
                    .stroke(AnalysisTheme.primaryGold, lineWidth: 1.5)
                    .frame(width: 8, height: 8)
            }

            // Title text (centered, gold, uppercase)
            Text(title.uppercased())
                .font(.custom("CormorantGaramond-Bold", size: 22))
                .foregroundColor(AnalysisTheme.primaryGoldText)
                .tracking(2)
                .multilineTextAlignment(.center)

            // Bottom diamond ornaments
            HStack(spacing: 8) {
                DiamondShape()
                    .stroke(AnalysisTheme.primaryGold, lineWidth: 1.5)
                    .frame(width: 8, height: 8)

                DiamondShape()
                    .fill(AnalysisTheme.primaryGold)
                    .frame(width: 10, height: 10)

                DiamondShape()
                    .stroke(AnalysisTheme.primaryGold, lineWidth: 1.5)
                    .frame(width: 8, height: 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AnalysisTheme.Spacing.xl2)
    }
}

// MARK: - Premium Section Header H2 (Left-aligned with Gold Gradient Bar)

/// Premium H2 header matching the mockup: left-aligned with gold gradient vertical bar, optional label above
struct PremiumSectionHeaderH2: View {
    let title: String
    let label: String?

    init(title: String, label: String? = nil) {
        self.title = title
        self.label = label
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Gold gradient vertical bar
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AnalysisTheme.primaryGold, AnalysisTheme.primaryGold.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4)

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                // Optional label
                if let label = label {
                    Text(label.uppercased())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AnalysisTheme.textMuted)
                        .tracking(1)
                }

                // Main heading
                Text(title)
                    .font(.custom("CormorantGaramond-Bold", size: 24))
                    .foregroundColor(AnalysisTheme.textHeading)
            }
        }
        .padding(.vertical, AnalysisTheme.Spacing.lg)
    }
}

// MARK: - Premium Book Title View

/// Displays book titles in gold italic serif font (Shortform-inspired)
struct BookTitleView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.custom("CormorantGaramond-Italic", size: 17))
            .foregroundColor(AnalysisTheme.primaryGoldText)
    }
}

// MARK: - Premium Author Name View

/// Displays author names in coral small caps (Shortform-inspired)
struct AuthorNameView: View {
    let name: String

    var body: some View {
        Text(name.uppercased())
            .font(.analysisUI())
            .fontWeight(.semibold)
            .foregroundColor(AnalysisTheme.accentCoralText)
            .tracking(0.5)
    }
}
