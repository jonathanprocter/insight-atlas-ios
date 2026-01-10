import SwiftUI

// MARK: - Book Reference Utilities

/// Represents a parsed book reference with title and author
struct BookReference: Identifiable {
    let id = UUID()
    let title: String
    let author: String

    /// Generate an Amazon search URL for this book
    var amazonSearchURL: URL? {
        let searchQuery = "\(title) \(author)"
        guard let encoded = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              !encoded.isEmpty else {
            return nil
        }
        return URL(string: "https://www.amazon.com/s?k=\(encoded)&i=stripbooks")
    }

    /// Generate a Goodreads search URL for this book
    var goodreadsSearchURL: URL? {
        let searchQuery = "\(title) \(author)"
        guard let encoded = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              !encoded.isEmpty else {
            return nil
        }
        return URL(string: "https://www.goodreads.com/search?q=\(encoded)")
    }
}

/// Parse book references from text in the format: "Book Title" by Author Name
func parseBookReferences(from text: String) -> [BookReference] {
    var references: [BookReference] = []

    // Pattern 1: "Book Title" by Author Name (supports both straight and curly quotes)
    let quotedPattern = #"["""]([^"""]+)["""]\s+by\s+([A-Z][a-zA-Z\s\.]+?)(?:\s*[-–—]|\s*$|\s*\.|,)"#
    if let regex = try? NSRegularExpression(pattern: quotedPattern, options: []) {
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            if let titleRange = Range(match.range(at: 1), in: text),
               let authorRange = Range(match.range(at: 2), in: text) {
                let title = String(text[titleRange]).trimmingCharacters(in: .whitespaces)
                let author = String(text[authorRange]).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty && !author.isEmpty {
                    references.append(BookReference(title: title, author: author))
                }
            }
        }
    }

    // Pattern 2: *Book Title* by Author Name (italicized)
    let italicPattern = #"\*([^*]+)\*\s+by\s+([A-Z][a-zA-Z\s\.]+?)(?:\s*[-–—]|\s*$|\s*\.|,)"#
    if let regex = try? NSRegularExpression(pattern: italicPattern, options: []) {
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            if let titleRange = Range(match.range(at: 1), in: text),
               let authorRange = Range(match.range(at: 2), in: text) {
                let title = String(text[titleRange]).trimmingCharacters(in: .whitespaces)
                let author = String(text[authorRange]).trimmingCharacters(in: .whitespaces)
                // Avoid duplicates
                if !title.isEmpty && !author.isEmpty && !references.contains(where: { $0.title == title }) {
                    references.append(BookReference(title: title, author: author))
                }
            }
        }
    }

    return references
}

// MARK: - Clickable Book Reference View

struct BookReferenceLink: View {
    let reference: BookReference
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button(action: {
            if let url = reference.amazonSearchURL {
                openURL(url)
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "book.fill")
                    .font(.system(size: 12))
                    .foregroundColor(AnalysisTheme.accentTeal)

                VStack(alignment: .leading, spacing: 2) {
                    Text(reference.title)
                        .font(.analysisBody())
                        .fontWeight(.medium)
                        .italic()
                        .foregroundColor(AnalysisTheme.accentTeal)

                    Text("by \(reference.author)")
                        .font(.analysisUISmall())
                        .foregroundColor(AnalysisTheme.Light.textMuted)
                }

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 12))
                    .foregroundColor(AnalysisTheme.accentTeal.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AnalysisTheme.accentTealSubtle.opacity(0.3))
            .cornerRadius(AnalysisTheme.Radius.md)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Markdown Parsing Helper

/// Parses markdown bold syntax (**text**) into AttributedString
func parseMarkdownBold(_ text: String) -> AttributedString {
    var result = AttributedString(text)

    let boldPattern = #"\*\*([^*]+)\*\*"#
    guard let boldRegex = try? NSRegularExpression(pattern: boldPattern) else {
        return result
    }

    let matches = boldRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))

    // Process matches in reverse to preserve indices
    for match in matches.reversed() {
        guard Range(match.range, in: text) != nil,
              let captureRange = Range(match.range(at: 1), in: text) else {
            continue
        }

        let boldText = String(text[captureRange])

        // Find and replace in AttributedString
        if let attrRange = result.range(of: "**\(boldText)**") {
            var boldString = AttributedString(boldText)
            boldString.font = .system(size: 17, weight: .bold)
            result.replaceSubrange(attrRange, with: boldString)
        }
    }

    return result
}

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
                .foregroundColor(AnalysisTheme.textHandwritten)
                .multilineTextAlignment(.center)
                .padding(.top, AnalysisTheme.Spacing.sm)
        }
        .padding(.vertical, AnalysisTheme.Spacing.xl2)
    }
}

// MARK: - Premium Quick Glance View

struct PremiumQuickGlanceView: View {
    let coreMessage: String
    let keyPoints: [String]
    let readingTime: Int

    // CRITICAL FIX: Use explicit light-mode colors for text inside light background boxes
    // This ensures readability when the box has a light background in dark mode
    private let boxTextColor = AnalysisTheme.Light.textBody
    private let boxHeadingColor = AnalysisTheme.Light.textHeading

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
                .background(
                    LinearGradient(
                        colors: [AnalysisTheme.primaryGold, AnalysisTheme.accentOrange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(AnalysisTheme.Radius.full)
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.bottom, AnalysisTheme.Spacing.sm)

            // Divider with proper spacing from top border
            Divider()
                .background(AnalysisTheme.Light.borderLight)
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
                .fill(Color.white) // Always white background for light box appearance
                .shadow(color: AnalysisTheme.shadowCard, radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.xl)
                .stroke(
                    LinearGradient(
                        colors: [AnalysisTheme.primaryGold, AnalysisTheme.accentOrange, AnalysisTheme.primaryGold],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2
                )
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AnalysisTheme.primaryGold, AnalysisTheme.accentOrange, AnalysisTheme.primaryGold],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 3)
                .clipShape(
                    RoundedCorner(radius: AnalysisTheme.Radius.xl, corners: [.topLeft, .topRight])
                )
        }
    }
}

// MARK: - Table of Contents View

struct TableOfContentsView: View {
    let sections: [AnalysisSection]
    let onSectionTap: (Int) -> Void

    // Use explicit dark text for light background
    private let boxTextColor = AnalysisTheme.Light.textBody
    private let boxHeadingColor = AnalysisTheme.Light.textHeading
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
                    .foregroundColor(AnalysisTheme.Light.textMuted)
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
                            .background(AnalysisTheme.Light.borderLight)
                    }
                }
            }
            .padding(.top, AnalysisTheme.Spacing.sm)
        }
        .padding(AnalysisTheme.Spacing.xl)
        .background(Color.white)
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

// MARK: - Blockquote View

struct PremiumBlockquoteView: View {
    let text: String
    let cite: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.sm) {
            HStack(alignment: .top, spacing: 0) {
                Text("\u{201C}")
                    .font(.system(size: 48))
                    .foregroundColor(AnalysisTheme.primaryGoldMuted)
                    .offset(y: -8)

                Text(text)
                    .font(.analysisBodyLarge())
                    .italic()
                    .foregroundColor(AnalysisTheme.textMuted)
                    .padding(.leading, 4)
            }

            if let cite = cite {
                Text("— \(cite)")
                    .font(.analysisHandwritten())
                    .foregroundColor(AnalysisTheme.accentCoralText)
                    .padding(.leading, AnalysisTheme.Spacing.xl2)
            }
        }
        .padding(AnalysisTheme.Spacing.xl)
        .padding(.leading, AnalysisTheme.Spacing.lg)
        .background(AnalysisTheme.bgCard)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(AnalysisTheme.primaryGold)
                .frame(width: 3)
        }
        .cornerRadius(AnalysisTheme.Radius.xl)
        .shadow(color: AnalysisTheme.shadowCard, radius: 4, x: 0, y: 2)
    }
}

// MARK: - Premium Insight Note View

struct PremiumInsightNoteView: View {
    let title: String
    let content: String

    // Use explicit dark text color for light background box (fixes dark mode visibility)
    private let boxTextColor = AnalysisTheme.Light.textBody
    private let boxMutedColor = AnalysisTheme.Light.textMuted

    private var parsed: (coreConnection: String, keyDistinction: String?, practicalImplication: String?, goDeeper: String?) {
        parseInsightNoteContent(content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            // Header
            HStack(spacing: 8) {
                Text("💡")
                    .font(.system(size: 14))

                Text(title.uppercased())
                    .font(.analysisUIBold())
                    .foregroundColor(AnalysisTheme.accentCoralText)
                    .tracking(1)
            }

            // Core Connection
            if !parsed.coreConnection.isEmpty {
                Text(parseMarkdownInline(parsed.coreConnection, foregroundColor: boxTextColor))
                    .font(.analysisBody())
            }

            // Key Distinction
            if let keyDistinction = parsed.keyDistinction, !keyDistinction.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 11))
                            .foregroundColor(AnalysisTheme.accentCoralText)
                        Text("Key Distinction")
                            .font(.analysisUIBold())
                            .foregroundColor(AnalysisTheme.accentCoralText)
                    }
                    Text(parseMarkdownInline(keyDistinction, foregroundColor: boxMutedColor))
                        .font(.analysisBody())
                }
                .padding(AnalysisTheme.Spacing.md)
                .background(
                    ZStack {
                        Color.white
                        AnalysisTheme.accentCoralSubtle.opacity(0.5)
                    }
                )
                .cornerRadius(AnalysisTheme.Radius.md)
            }

            // Practical Implication
            if let practical = parsed.practicalImplication, !practical.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 11))
                            .foregroundColor(AnalysisTheme.accentOrange)
                        Text("Practical Implication")
                            .font(.analysisUIBold())
                            .foregroundColor(AnalysisTheme.accentOrange)
                    }
                    Text(parseMarkdownInline(practical, foregroundColor: boxMutedColor))
                        .font(.analysisBody())
                }
                .padding(AnalysisTheme.Spacing.md)
                .background(
                    ZStack {
                        Color.white
                        AnalysisTheme.accentOrangeSubtle.opacity(0.5)
                    }
                )
                .cornerRadius(AnalysisTheme.Radius.md)
            }

            // Go Deeper - with clickable book links
            if let goDeeper = parsed.goDeeper, !goDeeper.isEmpty {
                let bookRefs = parseBookReferences(from: goDeeper)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 11))
                            .foregroundColor(AnalysisTheme.accentTeal)
                        Text("Go Deeper")
                            .font(.analysisUIBold())
                            .foregroundColor(AnalysisTheme.accentTeal)
                    }

                    // Show parsed book references as clickable links
                    if !bookRefs.isEmpty {
                        ForEach(bookRefs) { ref in
                            BookReferenceLink(reference: ref)
                        }

                        // Show any remaining description text
                        let descriptionText = extractDescriptionFromGoDeeper(goDeeper, excluding: bookRefs)
                        if !descriptionText.isEmpty {
                            Text(parseMarkdownInline(descriptionText, foregroundColor: boxMutedColor))
                                .font(.analysisBody())
                        }
                    } else {
                        // Fallback: show as plain text if no book references found
                        Text(parseMarkdownInline(goDeeper, foregroundColor: boxMutedColor))
                            .font(.analysisBody())
                            .italic()
                    }
                }
                .padding(AnalysisTheme.Spacing.md)
                .background(
                    ZStack {
                        Color.white
                        AnalysisTheme.accentTealSubtle.opacity(0.5)
                    }
                )
                .cornerRadius(AnalysisTheme.Radius.md)
            }
        }
        .padding(AnalysisTheme.Spacing.lg)
        .padding(.leading, AnalysisTheme.Spacing.sm)
        .background(
            ZStack {
                // Solid white base ensures readability in dark mode
                Color.white
                // Subtle gradient overlay for visual interest
                LinearGradient(
                    colors: [AnalysisTheme.accentCoralSubtle, AnalysisTheme.accentOrangeSubtle],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(AnalysisTheme.accentCoral)
                .frame(width: 4)
                .clipShape(
                    RoundedCorner(radius: AnalysisTheme.Radius.lg, corners: [.topLeft, .bottomLeft])
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                .stroke(AnalysisTheme.accentCoralMuted, lineWidth: 1)
        )
        .cornerRadius(AnalysisTheme.Radius.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Insight Note: \(title)")
        .accessibilityHint(content)
    }

    private func parseInsightNoteContent(_ content: String) -> (coreConnection: String, keyDistinction: String?, practicalImplication: String?, goDeeper: String?) {
        var coreConnection = ""
        var keyDistinction: String?
        var practicalImplication: String?
        var goDeeper: String?

        let normalizedContent = content.replacingOccurrences(of: "\n", with: " ")

        if let keyStart = normalizedContent.range(of: "Key Distinction:", options: .caseInsensitive) {
            var keyText = String(normalizedContent[keyStart.upperBound...])
            if let practicalStart = keyText.range(of: "Practical Implication:", options: .caseInsensitive) {
                keyText = String(keyText[..<practicalStart.lowerBound])
            } else if let goStart = keyText.range(of: "Go Deeper:", options: .caseInsensitive) {
                keyText = String(keyText[..<goStart.lowerBound])
            }
            keyDistinction = keyText.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let practStart = normalizedContent.range(of: "Practical Implication:", options: .caseInsensitive) {
            var practText = String(normalizedContent[practStart.upperBound...])
            if let goStart = practText.range(of: "Go Deeper:", options: .caseInsensitive) {
                practText = String(practText[..<goStart.lowerBound])
            }
            practicalImplication = practText.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let goStart = normalizedContent.range(of: "Go Deeper:", options: .caseInsensitive) {
            let goText = String(normalizedContent[goStart.upperBound...])
            goDeeper = goText.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var coreText = normalizedContent
        if let keyRange = normalizedContent.range(of: "Key Distinction:", options: .caseInsensitive) {
            coreText = String(normalizedContent[..<keyRange.lowerBound])
        } else if let keyRange = normalizedContent.range(of: "**Key Distinction", options: .caseInsensitive) {
            coreText = String(normalizedContent[..<keyRange.lowerBound])
        }
        coreConnection = coreText.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)

        return (coreConnection, keyDistinction, practicalImplication, goDeeper)
    }

    /// Extract description text from Go Deeper section, excluding book references
    private func extractDescriptionFromGoDeeper(_ text: String, excluding refs: [BookReference]) -> String {
        var result = text

        // Remove book reference patterns from the text
        for ref in refs {
            // Remove "Book Title" by Author patterns
            let patterns = [
                "\"\(ref.title)\" by \(ref.author)",
                "*\(ref.title)* by \(ref.author)",
                "\(ref.title) by \(ref.author)"
            ]
            for pattern in patterns {
                result = result.replacingOccurrences(of: pattern, with: "")
            }
        }

        // Clean up remaining punctuation and whitespace
        result = result.replacingOccurrences(of: "  ", with: " ")
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: " -–—:"))

        // Remove leading dashes/bullets
        while result.hasPrefix("-") || result.hasPrefix("–") || result.hasPrefix("—") {
            result = String(result.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Premium Action Box View

struct PremiumActionBoxView: View {
    let title: String
    let steps: [String]

    // CTX-04 Fix: Apply It section uses #4A7C59 green with white text at 18px/medium weight
    // This makes it "Large Text" by WCAG standards, and the 3.03:1 ratio becomes acceptable
    private let applyItGreen = InsightAtlasColors.applyItGreen

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(applyItGreen)
                        .frame(width: 24, height: 24)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }

                Text(title.uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(applyItGreen)
                    .tracking(1)
            }
            .padding(.bottom, AnalysisTheme.Spacing.xs)

            Divider()
                .background(applyItGreen.opacity(0.3))

            VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(applyItGreen)
                                .frame(width: 28, height: 28)
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }

                        // CTX-04: Body text uses textSecondaryWCAG (#333333) for 10.97:1 contrast
                        Text(parseMarkdownInline(step, foregroundColor: InsightAtlasColors.textSecondaryWCAG))
                            .font(.system(size: 16))
                            .lineSpacing(4)
                    }
                }
            }
            .padding(.top, AnalysisTheme.Spacing.sm)
        }
        .padding(AnalysisTheme.Spacing.lg)
        .background(
            ZStack {
                Color.white
                applyItGreen.opacity(0.08)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.xl)
                .stroke(applyItGreen.opacity(0.25), lineWidth: 1.5)
        )
        .cornerRadius(AnalysisTheme.Radius.xl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Action Box: \(title)")
        .accessibilityHint("Contains \(steps.count) action steps: \(steps.joined(separator: ". "))")
    }
}

// MARK: - Premium Key Takeaways View

struct PremiumKeyTakeawaysView: View {
    let takeaways: [String]

    // CRITICAL FIX: Use explicit light-mode dark text color for visibility on light background
    // The box has a light green/white background, so text must be dark even in dark mode
    private let boxTextColor = AnalysisTheme.Light.textBody
    private let takeawayGreen = Color(hex: "#2D6A4F") // Darker green for better contrast

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            HStack(spacing: 8) {
                Text("🎯")
                    .font(.system(size: 14))

                Text("KEY TAKEAWAYS")
                    .font(.analysisUIBold())
                    .foregroundColor(takeawayGreen) // Darker green for header
                    .tracking(1)
            }
            .padding(.bottom, AnalysisTheme.Spacing.xs)

            Divider()
                .background(takeawayGreen.opacity(0.3))

            VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.sm) {
                ForEach(takeaways, id: \.self) { takeaway in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(takeawayGreen)

                        // Use parseMarkdownInline with explicit color to ensure visibility
                        Text(parseMarkdownInline(takeaway, foregroundColor: boxTextColor))
                            .font(.analysisBody())
                    }
                }
            }
            .padding(.top, AnalysisTheme.Spacing.sm)
        }
        .padding(AnalysisTheme.Spacing.xl)
        .background(
            // Use solid light background for consistent appearance
            Color.white
        )
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.xl)
                .stroke(takeawayGreen.opacity(0.4), lineWidth: 2)
        )
        .overlay(alignment: .leading) {
            // Add green left accent bar like other premium boxes
            Rectangle()
                .fill(takeawayGreen)
                .frame(width: 4)
                .clipShape(
                    RoundedCorner(radius: AnalysisTheme.Radius.xl, corners: [.topLeft, .bottomLeft])
                )
        }
        .cornerRadius(AnalysisTheme.Radius.xl)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Key Takeaways")
        .accessibilityHint("\(takeaways.count) takeaways: \(takeaways.joined(separator: ". "))")
    }
}

// MARK: - Foundational Narrative View (Atlas Philosophy Box)

struct PremiumFoundationalNarrativeView: View {
    let title: String
    let content: String

    // CRITICAL FIX: Use explicit dark text for light background
    private let boxTextColor = AnalysisTheme.Light.textBody
    private let boxHeaderColor = Color(hex: "#4B5563") // Gray 600 - visible on light bg

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            HStack(spacing: 8) {
                Text("📖")
                    .font(.system(size: 14))

                Text(title.uppercased())
                    .font(.analysisUIBold())
                    .foregroundColor(boxHeaderColor) // Dark header on light background
                    .tracking(1)
            }
            .padding(.bottom, AnalysisTheme.Spacing.xs)

            Divider()
                .background(Color(hex: "#D1D5DB")) // Light gray divider

            Text(parseMarkdownInline(content, foregroundColor: boxTextColor))
                .font(.analysisBody())
                .padding(.top, AnalysisTheme.Spacing.sm)
        }
        .padding(AnalysisTheme.Spacing.lg)
        .padding(.leading, AnalysisTheme.Spacing.sm)
        .background(
            // Use solid light background
            Color.white
        )
        .overlay(alignment: .leading) {
            // Accent bar clipped to match container's rounded corners
            Rectangle()
                .fill(AnalysisTheme.primaryGold)
                .frame(width: 4)
                .clipShape(
                    RoundedCorner(radius: AnalysisTheme.Radius.xl, corners: [.topLeft, .bottomLeft])
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.xl)
                .stroke(Color(hex: "#E5E7EB"), lineWidth: 1)
        )
        .cornerRadius(AnalysisTheme.Radius.xl)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Premium Exercise View

struct PremiumExerciseView: View {
    let title: String
    let content: String
    let steps: [String]
    let estimatedTime: String?

    // CRITICAL FIX: Use explicit dark text for light background
    private let boxTextColor = AnalysisTheme.Light.textBody
    private let exerciseTeal = Color(hex: "#0D6E6E") // Darker teal for better contrast

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            HStack(spacing: 8) {
                Text("✏️")
                    .font(.system(size: 14))

                Text(title.uppercased())
                    .font(.analysisUIBold())
                    .foregroundColor(exerciseTeal)
                    .tracking(1)
            }
            .padding(.bottom, AnalysisTheme.Spacing.xs)

            Divider()
                .background(exerciseTeal.opacity(0.3))

            Text(parseMarkdownInline(content, foregroundColor: boxTextColor))
                .font(.analysisBody())
                .padding(.top, AnalysisTheme.Spacing.sm)

            if !steps.isEmpty {
                VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.sm) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1).")
                                .font(.analysisUIBold())
                                .foregroundColor(exerciseTeal)
                                .frame(width: 20, alignment: .leading)
                            Text(parseMarkdownInline(step, foregroundColor: boxTextColor))
                                .font(.analysisBody())
                        }
                    }
                }
            }

            if let time = estimatedTime {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                    Text(time)
                        .font(.analysisUISmall())
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(exerciseTeal)
                .cornerRadius(AnalysisTheme.Radius.full)
                .padding(.top, AnalysisTheme.Spacing.sm)
            }
        }
        .padding(AnalysisTheme.Spacing.xl)
        .background(
            // Use solid white background
            Color.white
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(exerciseTeal)
                .frame(width: 4)
                .clipShape(
                    RoundedCorner(radius: AnalysisTheme.Radius.xl, corners: [.topLeft, .bottomLeft])
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.xl)
                .stroke(exerciseTeal.opacity(0.4), lineWidth: 2)
        )
        .cornerRadius(AnalysisTheme.Radius.xl)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Visual Flowchart View

struct PremiumFlowchartView: View {
    let title: String
    let steps: [String]

    // CRITICAL FIX: Use explicit dark text for light background boxes
    private let boxTextColor = AnalysisTheme.Light.textHeading

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            HStack(spacing: 8) {
                Text("📊")
                    .font(.system(size: 14))

                Text(title.uppercased())
                    .font(.analysisUIBold())
                    .foregroundColor(AnalysisTheme.primaryGoldDark)
                    .tracking(1)
            }
            .padding(.bottom, AnalysisTheme.Spacing.xs)

            Divider()
                .background(AnalysisTheme.primaryGold.opacity(0.3))

            VStack(spacing: AnalysisTheme.Spacing.sm) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    VStack(spacing: AnalysisTheme.Spacing.sm) {
                        Text(step)
                            .font(.analysisUI())
                            .foregroundColor(boxTextColor) // Dark text on light background
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AnalysisTheme.Spacing.lg)
                            .padding(.vertical, AnalysisTheme.Spacing.md)
                            .frame(maxWidth: .infinity)
                            .background(Color.white) // Explicit white background
                            .overlay(
                                RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                                    .stroke(AnalysisTheme.primaryGold.opacity(0.4), lineWidth: 2)
                            )
                            .cornerRadius(AnalysisTheme.Radius.lg)
                            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)

                        if index < steps.count - 1 {
                            Text("↓")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(AnalysisTheme.primaryGold)
                        }
                    }
                }
            }
            .padding(.top, AnalysisTheme.Spacing.md)
        }
        .padding(AnalysisTheme.Spacing.xl)
        .background(
            // Use solid white background for consistent light appearance
            Color.white
        )
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.xl)
                .stroke(AnalysisTheme.primaryGold.opacity(0.4), lineWidth: 2)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(AnalysisTheme.primaryGold)
                .frame(width: 4)
                .clipShape(
                    RoundedCorner(radius: AnalysisTheme.Radius.xl, corners: [.topLeft, .bottomLeft])
                )
        }
        .cornerRadius(AnalysisTheme.Radius.xl)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
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
                .foregroundColor(AnalysisTheme.textMuted)
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

// MARK: - Premium Quote View (Matching Mockup)

/// Premium quote block with coral/terracotta left border, decorative quotation marks, and attribution
struct PremiumQuoteView: View {
    let quote: String
    let author: String?
    let source: String?

    // Use explicit dark text color for light background box (fixes dark mode visibility)
    private let boxTextColor = AnalysisTheme.Light.textBody
    private let boxMutedColor = AnalysisTheme.Light.textMuted

    init(quote: String, author: String? = nil, source: String? = nil) {
        self.quote = quote
        self.author = author
        self.source = source
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background card
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                .fill(Color(hex: "#F5F3ED"))

            // Coral/terracotta left border
            HStack(spacing: 0) {
                UnevenRoundedRectangle(
                    topLeadingRadius: AnalysisTheme.Radius.lg,
                    bottomLeadingRadius: AnalysisTheme.Radius.lg,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
                .fill(AnalysisTheme.accentCoral)
                .frame(width: 4)
                Spacer()
            }

            // Large decorative quotation mark
            Text("\u{201C}")
                .font(.custom("CormorantGaramond-Bold", size: 100))
                .foregroundColor(AnalysisTheme.primaryGold.opacity(0.2))
                .offset(x: 12, y: -16)

            // Content
            VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
                // Quote text
                Text(quote)
                    .font(.custom("CormorantGaramond-Italic", size: 20))
                    .foregroundColor(boxTextColor)
                    .lineSpacing(6)
                    .padding(.top, AnalysisTheme.Spacing.xl)

                // Attribution (right-aligned)
                if author != nil || source != nil {
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            if let author = author {
                                Text(author.uppercased())
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(AnalysisTheme.accentCoralText)
                                    .tracking(1.5)
                            }
                            if let source = source {
                                Text(source)
                                    .font(.custom("CormorantGaramond-Italic", size: 13))
                                    .foregroundColor(boxMutedColor)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AnalysisTheme.Spacing.xl)
            .padding(.vertical, AnalysisTheme.Spacing.lg)
            .padding(.leading, 8) // Extra space for left border
        }
    }
}

// MARK: - Premium Author Spotlight View (Matching Mockup)

/// Author spotlight with double gold border, book icon header, and coral author name
struct PremiumAuthorSpotlightView: View {
    let authorName: String
    let bio: String
    let bookTitles: [String]

    init(authorName: String, bio: String, bookTitles: [String] = []) {
        self.authorName = authorName
        self.bio = bio
        self.bookTitles = bookTitles
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with book icon
            HStack(spacing: 8) {
                Text("📖")
                    .font(.system(size: 14))

                Text("AUTHOR SPOTLIGHT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AnalysisTheme.primaryGoldText)
                    .tracking(1.5)
            }
            .padding(.horizontal, AnalysisTheme.Spacing.lg)
            .padding(.vertical, AnalysisTheme.Spacing.md)

            // Main content with gold left accent bar
            HStack(alignment: .top, spacing: 0) {
                // Gold accent bar
                Rectangle()
                    .fill(AnalysisTheme.primaryGold)
                    .frame(width: 4)

                // Content
                VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
                    // Author name in coral
                    Text(authorName)
                        .font(.custom("CormorantGaramond-Bold", size: 26))
                        .foregroundColor(AnalysisTheme.accentCoralText)

                    // Bio text with book titles highlighted
                    highlightedBioText()
                }
                .padding(.horizontal, AnalysisTheme.Spacing.lg)
                .padding(.vertical, AnalysisTheme.Spacing.md)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg))
        // Inner border
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg - 2)
                .stroke(AnalysisTheme.primaryGold.opacity(0.6), lineWidth: 1)
                .padding(4)
        )
        // Outer border
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                .stroke(AnalysisTheme.primaryGold, lineWidth: 2)
        )
    }

    @ViewBuilder
    private func highlightedBioText() -> some View {
        // Use Text concatenation for reliable mixed font/color styling
        StyledSpotlightBioText(
            bio: bio,
            bookTitles: bookTitles
        )
        .lineSpacing(4)
    }
}

// MARK: - Styled Spotlight Bio Text Helper

/// Builds a combined Text view with highlighted book titles for PremiumAuthorSpotlightView
private struct StyledSpotlightBioText: View {
    let bio: String
    let bookTitles: [String]

    private var bodyFont: Font {
        if UIFont(name: "CormorantGaramond-Regular", size: 14) != nil {
            return .custom("CormorantGaramond-Regular", size: 14)
        }
        return .system(size: 14, design: .serif)
    }

    private var bookTitleFont: Font {
        if UIFont(name: "CormorantGaramond-Italic", size: 14) != nil {
            return .custom("CormorantGaramond-Italic", size: 14)
        }
        return .system(size: 14, design: .serif).italic()
    }

    var body: some View {
        buildStyledText()
    }

    @ViewBuilder
    private func buildStyledText() -> some View {
        let segments = parseSegments()
        segments.reduce(Text("")) { result, segment in
            result + segment
        }
    }

    private func parseSegments() -> [Text] {
        var segments: [Text] = []

        // Find all book title positions
        var highlights: [Range<String.Index>] = []
        for title in bookTitles {
            if let range = bio.range(of: title) {
                highlights.append(range)
            }
        }
        highlights.sort { $0.lowerBound < $1.lowerBound }

        var currentIndex = bio.startIndex

        for highlightRange in highlights {
            // Add text before this highlight
            if currentIndex < highlightRange.lowerBound {
                let beforeText = String(bio[currentIndex..<highlightRange.lowerBound])
                segments.append(
                    Text(beforeText)
                        .font(bodyFont)
                        .foregroundColor(AnalysisTheme.textBody)
                )
            }

            // Add the highlighted book title
            let highlightedText = String(bio[highlightRange])
            segments.append(
                Text(highlightedText)
                    .font(bookTitleFont)
                    .foregroundColor(AnalysisTheme.accentCoral)
            )

            currentIndex = highlightRange.upperBound
        }

        // Add remaining text after last highlight
        if currentIndex < bio.endIndex {
            let afterText = String(bio[currentIndex...])
            segments.append(
                Text(afterText)
                    .font(bodyFont)
                    .foregroundColor(AnalysisTheme.textBody)
            )
        }

        // If no highlights were found, return the entire bio as body text
        if segments.isEmpty {
            segments.append(
                Text(bio)
                    .font(bodyFont)
                    .foregroundColor(AnalysisTheme.textBody)
            )
        }

        return segments
    }
}

// MARK: - Helper for rounded corners

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Accent Color for Coral (muted)

private let accentCoralMuted = Color(hex: "#D4735C").opacity(0.25)

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

// MARK: - Author Spotlight Box (First Mention)

struct AuthorSpotlightView: View {
    let authorName: String
    let bookTitle: String
    let description: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            HStack(spacing: 8) {
                Text("📖")
                    .font(.system(size: 14))

                Text("ABOUT THE AUTHOR")
                    .font(.analysisUIBold())
                    .foregroundColor(AnalysisTheme.primaryGoldText)
                    .tracking(1)
            }

            VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.sm) {
                AuthorNameView(name: authorName)
                BookTitleView(title: bookTitle)

                if let description = description {
                    Text(parseMarkdownInline(description, foregroundColor: AnalysisTheme.Light.textBody))
                        .font(.analysisBody())
                        .padding(.top, AnalysisTheme.Spacing.xs)
                }
            }
        }
        .padding(AnalysisTheme.Spacing.lg)
        .padding(.leading, AnalysisTheme.Spacing.sm)
        .background(
            ZStack {
                Color.white
                LinearGradient(
                    colors: [Color(hex: "#FDF8F3").opacity(0.8), Color(hex: "#FBF7E9").opacity(0.6)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(AnalysisTheme.primaryGold)
                .frame(width: 4)
        }
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                .stroke(AnalysisTheme.primaryGoldMuted, lineWidth: 2)
        )
        .cornerRadius(AnalysisTheme.Radius.lg)
    }
}

// MARK: - Alternative Perspective Box

struct AlternativePerspectiveView: View {
    let content: String

    // Use explicit dark text color for light background box (fixes dark mode visibility)
    private let boxTextColor = AnalysisTheme.Light.textBody
    private let boxMutedColor = AnalysisTheme.Light.textMuted

    private var bookRefs: [BookReference] {
        parseBookReferences(from: content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            HStack(spacing: 8) {
                Text("⚖️")
                    .font(.system(size: 14))

                Text("ALTERNATIVE PERSPECTIVE")
                    .font(.analysisUIBold())
                    .foregroundColor(AnalysisTheme.accentTeal)
                    .tracking(1)
            }

            Text(parseMarkdownInline(content, foregroundColor: boxTextColor))
                .font(.analysisBody())

            // Show clickable book links if references found
            if !bookRefs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Related Reading:")
                        .font(.analysisUISmall())
                        .foregroundColor(boxMutedColor)
                        .padding(.top, 4)

                    ForEach(bookRefs) { ref in
                        BookReferenceLink(reference: ref)
                    }
                }
            }
        }
        .padding(AnalysisTheme.Spacing.lg)
        .padding(.leading, AnalysisTheme.Spacing.sm)
        .background(
            ZStack {
                Color.white
                LinearGradient(
                    colors: [Color(hex: "#F5FAFA"), Color(hex: "#F0FAF8").opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(AnalysisTheme.accentTeal)
                .frame(width: 4)
        }
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                .stroke(AnalysisTheme.accentTealMuted, lineWidth: 1)
        )
        .cornerRadius(AnalysisTheme.Radius.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Alternative Perspective")
        .accessibilityHint(content)
    }
}

// MARK: - Research Insight Box

struct ResearchInsightView: View {
    let content: String
    let source: String?

    // Use explicit dark text color for light background box (fixes dark mode visibility)
    private let boxTextColor = AnalysisTheme.Light.textBody
    private let boxMutedColor = AnalysisTheme.Light.textMuted

    private var bookRefs: [BookReference] {
        parseBookReferences(from: content)
    }

    var body: some View {
        let sourceLabel = source.map { " from \($0)" } ?? ""
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            HStack(spacing: 8) {
                Text("🔬")
                    .font(.system(size: 14))

                Text("RESEARCH INSIGHT")
                    .font(.analysisUIBold())
                    .foregroundColor(AnalysisTheme.primaryGoldText)
                    .tracking(1)
            }

            Text(parseMarkdownInline(content, foregroundColor: boxTextColor))
                .font(.analysisBody())

            // Show clickable book links if references found
            if !bookRefs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Referenced Works:")
                        .font(.analysisUISmall())
                        .foregroundColor(boxMutedColor)
                        .padding(.top, 4)

                    ForEach(bookRefs) { ref in
                        BookReferenceLink(reference: ref)
                    }
                }
            }

            if let source = source {
                HStack(spacing: 4) {
                    Text("Source:")
                        .font(.analysisUISmall())
                        .foregroundColor(boxMutedColor)
                    Text(source)
                        .font(.custom("CormorantGaramond-Italic", size: 13))
                        .foregroundColor(AnalysisTheme.primaryGoldText)
                }
                .padding(.top, AnalysisTheme.Spacing.xs)
            }
        }
        .padding(AnalysisTheme.Spacing.lg)
        .padding(.leading, AnalysisTheme.Spacing.sm)
        .background(
            ZStack {
                Color.white
                LinearGradient(
                    colors: [Color(hex: "#FBF7E9"), Color(hex: "#FDFAF0").opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(AnalysisTheme.primaryGold)
                .frame(width: 4)
        }
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                .stroke(AnalysisTheme.primaryGoldMuted, lineWidth: 1)
        )
        .cornerRadius(AnalysisTheme.Radius.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Research Insight\(sourceLabel)")
        .accessibilityHint(content)
    }
}

// MARK: - Enhanced Quote with Attribution

struct PremiumQuoteWithAttributionView: View {
    let quote: String
    let author: String?
    let source: String?

    var body: some View {
        let authorHint: String = {
            guard let author = author, !author.isEmpty else { return "" }
            if let source = source, !source.isEmpty {
                return "By \(author), from \(source)"
            }
            return "By \(author)"
        }()
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            ZStack(alignment: .topLeading) {
                Text("\u{201C}")
                    .font(.system(size: 64))
                    .foregroundColor(AnalysisTheme.primaryGoldMuted.opacity(0.3))
                    .offset(x: -8, y: -16)

                Text(quote)
                    .font(.analysisBodyLarge())
                    .italic()
                    .foregroundColor(AnalysisTheme.textHeading)
                    .padding(.leading, AnalysisTheme.Spacing.xl)
                    .padding(.top, AnalysisTheme.Spacing.md)
            }

            if author != nil || source != nil {
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        if let author = author {
                            Text(author.uppercased())
                                .font(.analysisUI())
                                .fontWeight(.semibold)
                                .foregroundColor(AnalysisTheme.accentCoralText)
                                .tracking(0.5)
                        }
                        if let source = source {
                            Text(source)
                                .font(.custom("CormorantGaramond-Italic", size: 14))
                                .foregroundColor(AnalysisTheme.primaryGoldText)
                        }
                    }
                }
            }
        }
        .padding(AnalysisTheme.Spacing.xl)
        .padding(.leading, AnalysisTheme.Spacing.lg)
        .background(
            LinearGradient(
                colors: [Color(hex: "#FAF9F7").opacity(0.6), Color(hex: "#FDF8F3").opacity(0.4)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(AnalysisTheme.accentCoral)
                .frame(width: 3)
        }
        .cornerRadius(AnalysisTheme.Radius.xl)
        .shadow(color: AnalysisTheme.shadowCard, radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Quote: \(quote)")
        .accessibilityHint(authorHint)
    }
}

// MARK: - Cross-Reference Link

struct CrossReferenceView: View {
    let text: String
    let destination: String?

    var body: some View {
        HStack(spacing: 8) {
            Text("→")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(AnalysisTheme.primaryGoldText)

            Text(text)
                .font(.custom("CormorantGaramond-Italic", size: 15))
                .foregroundColor(AnalysisTheme.primaryGoldText)
        }
        .padding(.vertical, AnalysisTheme.Spacing.xs)
    }
}

// MARK: - Author Bio Box

struct AuthorBioView: View {
    let name: String
    let bio: String
    let otherWorks: [String]?

    var body: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.md) {
            AuthorNameView(name: name)

            Text(parseMarkdownInline(bio, foregroundColor: AnalysisTheme.Light.textBody))
                .font(.analysisBody())

            if let works = otherWorks, !works.isEmpty {
                VStack(alignment: .leading, spacing: AnalysisTheme.Spacing.sm) {
                    Text("OTHER WORKS")
                        .font(.analysisUISmall())
                        .fontWeight(.semibold)
                        .foregroundColor(AnalysisTheme.primaryGoldText)
                        .tracking(0.5)

                    ForEach(works, id: \.self) { work in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(AnalysisTheme.primaryGoldText)
                            BookTitleView(title: work)
                        }
                    }
                }
            }
        }
        .padding(AnalysisTheme.Spacing.lg)
        .background(
            ZStack {
                Color.white
                LinearGradient(
                    colors: [Color(hex: "#FAF9F7"), Color(hex: "#FDF8F3").opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.md)
                .stroke(AnalysisTheme.primaryGoldMuted, lineWidth: 1)
        )
        .cornerRadius(AnalysisTheme.Radius.md)
    }
}

// MARK: - Comparison Table

struct ComparisonTableView: View {
    let headers: [String]
    let rows: [[String]]

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                ForEach(headers, id: \.self) { header in
                    Text(header.uppercased())
                        .font(.analysisUIBold())
                        .foregroundColor(.white)
                        .tracking(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AnalysisTheme.Spacing.md)
                        .padding(.horizontal, AnalysisTheme.Spacing.sm)
                }
            }
            .background(
                LinearGradient(
                    colors: [AnalysisTheme.primaryGold, AnalysisTheme.primaryGoldLight],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

            // Data rows
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 0) {
                    ForEach(row, id: \.self) { cell in
                        Text(cell)
                            .font(.analysisBody())
                            .foregroundColor(AnalysisTheme.textBody)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, AnalysisTheme.Spacing.md)
                            .padding(.horizontal, AnalysisTheme.Spacing.sm)
                    }
                }
                .background(index % 2 == 0 ? Color(hex: "#FDF8F3").opacity(0.5) : AnalysisTheme.bgCard)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AnalysisTheme.Radius.lg)
                .stroke(AnalysisTheme.primaryGoldMuted, lineWidth: 1)
        )
        .shadow(color: AnalysisTheme.shadowCard, radius: 4, x: 0, y: 2)
    }
}

// MARK: - Process Timeline

struct ProcessTimelineView: View {
    let steps: [String]

    // CRITICAL FIX: Use explicit dark text for light background
    private let boxTextColor = AnalysisTheme.Light.textHeading

    var body: some View {
        VStack(spacing: AnalysisTheme.Spacing.lg) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: AnalysisTheme.Spacing.md) {
                    // Number circle
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AnalysisTheme.primaryGold, AnalysisTheme.primaryGoldLight],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                            .shadow(color: AnalysisTheme.primaryGold.opacity(0.25), radius: 4, x: 0, y: 2)

                        Text("\(index + 1)")
                            .font(.analysisUIBold())
                            .foregroundColor(.white)
                    }

                    // Step text - dark text for light background
                    Text(step)
                        .font(.analysisUI())
                        .fontWeight(.medium)
                        .foregroundColor(boxTextColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Connecting line (except for last item)
                if index < steps.count - 1 {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [AnalysisTheme.primaryGold, AnalysisTheme.primaryGoldLight],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2, height: 24)
                        .padding(.leading, 19) // Center under the circle
                }
            }
        }
        .padding(AnalysisTheme.Spacing.xl)
        .background(Color.white)
        .cornerRadius(AnalysisTheme.Radius.xl)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Concept Map View

struct ConceptMapView: View {
    let centralConcept: String
    let connections: [(concept: String, relationship: String)]

    // CRITICAL FIX: Use explicit dark text for light background
    private let boxTextColor = AnalysisTheme.Light.textHeading
    private let boxMutedColor = AnalysisTheme.Light.textMuted

    var body: some View {
        VStack(spacing: AnalysisTheme.Spacing.lg) {
            // Central concept node
            Text(centralConcept)
                .font(.analysisUIBold())
                .foregroundColor(.white)
                .padding(.horizontal, AnalysisTheme.Spacing.xl)
                .padding(.vertical, AnalysisTheme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [AnalysisTheme.primaryGold, AnalysisTheme.primaryGoldLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: AnalysisTheme.primaryGold.opacity(0.3), radius: 8, x: 0, y: 4)
                )

            // Connections
            ForEach(Array(connections.enumerated()), id: \.offset) { index, connection in
                VStack(spacing: AnalysisTheme.Spacing.xs) {
                    // Connection line with relationship label
                    HStack(spacing: AnalysisTheme.Spacing.sm) {
                        Rectangle()
                            .fill(AnalysisTheme.primaryGold.opacity(0.4))
                            .frame(height: 1)
                            .frame(maxWidth: 40)

                        Text(connection.relationship)
                            .font(.analysisUISmall())
                            .foregroundColor(boxMutedColor) // Dark muted text
                            .italic()

                        Rectangle()
                            .fill(AnalysisTheme.primaryGold.opacity(0.4))
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                    }

                    // Related concept node
                    HStack {
                        Spacer()
                        Text(connection.concept)
                            .font(.analysisUI())
                            .fontWeight(.medium)
                            .foregroundColor(boxTextColor) // Dark text for light background
                            .padding(.horizontal, AnalysisTheme.Spacing.lg)
                            .padding(.vertical, AnalysisTheme.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(AnalysisTheme.primaryGold.opacity(0.5), lineWidth: 1.5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.white) // Explicit white background
                                    )
                            )
                        Spacer()
                    }
                }
            }
        }
        .padding(AnalysisTheme.Spacing.xl)
        .background(Color.white)
        .cornerRadius(AnalysisTheme.Radius.xl)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Ornamental Section Header

struct OrnamentalSectionHeader: View {
    let title: String

    var body: some View {
        VStack(spacing: AnalysisTheme.Spacing.md) {
            // Top ornament
            Text("◆ ◇ ◆")
                .font(.system(size: 14))
                .foregroundColor(AnalysisTheme.primaryGoldText)
                .tracking(8)

            // Title
            Text(title.uppercased())
                .font(.analysisUIBold())
                .foregroundColor(AnalysisTheme.primaryGoldText)
                .tracking(2)
                .multilineTextAlignment(.center)

            // Bottom ornament
            Text("◆ ◇ ◆")
                .font(.system(size: 14))
                .foregroundColor(AnalysisTheme.primaryGoldText)
                .tracking(8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AnalysisTheme.Spacing.xl2)
    }
}

// MARK: - Previews

#Preview("Header") {
    ScrollView {
        AnalysisHeaderView(
            title: "The Extended Mind",
            author: "Annie Murphy Paul",
            subtitle: "The Power of Thinking Outside the Brain"
        )
        .padding()
    }
}

#Preview("Quick Glance") {
    ScrollView {
        PremiumQuickGlanceView(
            coreMessage: "This demonstrates the premium design system adapted from the HTML template.",
            keyPoints: [
                "**Design Philosophy:** Renaissance-inspired aesthetics meet modern iOS",
                "**Accessibility:** Native SwiftUI with full accessibility support",
                "**Performance:** Optimized for smooth scrolling and animations"
            ],
            readingTime: 12
        )
        .padding()
    }
}

#Preview("Insight Note") {
    ScrollView {
        PremiumInsightNoteView(
            title: "Insight Atlas Note",
            content: "This component draws inspiration from Shortform's excellent editorial commentary boxes. Use it to add your own analysis, draw connections to other works, or provide context that enhances the reader's understanding."
        )
        .padding()
    }
}

#Preview("Action Box") {
    ScrollView {
        PremiumActionBoxView(
            title: "Apply It",
            steps: [
                "**Engage actively:** Read with pen in hand, annotating key insights as they arise",
                "**Question deeply:** Ask not just \"what\" but \"why\" and \"how might this apply\"",
                "**Connect broadly:** Link new information to existing knowledge structures"
            ]
        )
        .padding()
    }
}

#Preview("Premium Citations") {
    ScrollView {
        VStack(spacing: 24) {
            // Book Title and Author
            HStack {
                Text("Read")
                    .font(.analysisBody())
                BookTitleView(title: "The Four Agreements")
                Text("by")
                    .font(.analysisBody())
                AuthorNameView(name: "Don Miguel Ruiz")
            }

            // Author Spotlight
            AuthorSpotlightView(
                authorName: "Don Miguel Ruiz",
                bookTitle: "The Four Agreements",
                description: "A Toltec wisdom teacher who has dedicated his life to sharing the ancient knowledge of his ancestors."
            )

            // Alternative Perspective
            AlternativePerspectiveView(
                content: "While Ruiz emphasizes the personal responsibility inherent in agreements, some critics argue this approach can overlook systemic factors that shape our beliefs."
            )

            // Research Insight
            ResearchInsightView(
                content: "Neuroscience research has shown that the beliefs we form in childhood create neural pathways that become increasingly difficult to modify as we age.",
                source: "Journal of Cognitive Neuroscience, 2023"
            )

            // Premium Quote
            PremiumQuoteWithAttributionView(
                quote: "Be impeccable with your word. Speak with integrity. Say only what you mean.",
                author: "Don Miguel Ruiz",
                source: "The Four Agreements"
            )

            // Author Bio
            AuthorBioView(
                name: "Don Miguel Ruiz",
                bio: "Don Miguel Ruiz is a Mexican author of Toltec spiritualist texts, born in 1952 in rural Mexico.",
                otherWorks: ["The Mastery of Love", "The Voice of Knowledge", "The Fifth Agreement"]
            )

            // Ornamental Section Header
            OrnamentalSectionHeader(title: "Key Takeaways")

            // Cross Reference
            CrossReferenceView(text: "See also: The Mastery of Love, Chapter 3", destination: nil)

            // Comparison Table
            ComparisonTableView(
                headers: ["Approach", "Focus", "Outcome"],
                rows: [
                    ["Traditional", "External rules", "Compliance"],
                    ["Toltec", "Inner agreements", "Liberation"]
                ]
            )

            // Process Timeline
            ProcessTimelineView(steps: [
                "Awareness of current agreements",
                "Challenge limiting beliefs",
                "Adopt new agreements",
                "Practice consistently"
            ])
        }
        .padding()
    }
    .background(AnalysisTheme.bgPrimary)
}

#Preview("Premium Section Headers") {
    ScrollView {
        VStack(spacing: 32) {
            // Premium H1 Header
            PremiumSectionHeaderH1(title: "Stage #1: Plan How You'll Resolve the Conflict")

            // Premium Divider
            PremiumSectionDivider()

            // Premium H2 Header with label
            PremiumSectionHeaderH2(
                title: "Conflict Is Inevitable in Romantic Relationships",
                label: "Bottom"
            )

            // Premium H2 Header without label
            PremiumSectionHeaderH2(title: "Understanding the Core Principles")
        }
        .padding()
    }
    .background(AnalysisTheme.bgPrimary)
}

#Preview("Premium Quote") {
    ScrollView {
        VStack(spacing: 24) {
            PremiumQuoteView(
                quote: "Mature conflict resolution is necessary to maintain collaborative relationships...",
                author: "Renée Evenson",
                source: "Powerful Phrases for Dealing with Difficult People"
            )
        }
        .padding()
    }
    .background(AnalysisTheme.bgPrimary)
}

#Preview("Premium Author Spotlight") {
    ScrollView {
        VStack(spacing: 24) {
            PremiumAuthorSpotlightView(
                authorName: "Renée Evenson",
                bio: "Renée Evenson is a recognized expert in customer service, leadership, and communication. With decades of experience, she has dedicated her career to helping professionals refine their interpersonal skills and build stronger relationships in the workplace. Her insightful guidebooks provide actionable strategies and practical advice for achieving excellence in service and management. Among her acclaimed works are the essential resources, Powerful Phrases for Effective Customer Service and the comprehensive Customer Service Training 101, both of which have become staples in corporate training programs worldwide. Renée's commitment to fostering positive interactions and empowering individuals shines through in every word, making her a trusted voice in the field.",
                bookTitles: ["Powerful Phrases for Effective Customer Service", "Customer Service Training 101"]
            )
        }
        .padding()
    }
    .background(AnalysisTheme.bgPrimary)
}

// MARK: - Premium Quote Card (Exportable Artifact)

/// A premium styled quote card with aged parchment background, decorative flourishes,
/// and elegant typography. Designed to be exported as an image for sharing.
/// Matches the "After" design from the reference mockup.
struct PremiumQuoteCardView: View {
    let bookTitle: String
    let author: String
    let tagline: String

    // Card dimensions for export (640x490 as per HTML reference)
    static let exportWidth: CGFloat = 640
    static let exportHeight: CGFloat = 490

    var body: some View {
        ZStack {
            // Aged parchment background with vignette
            parchmentBackground

            // Content
            VStack(spacing: 0) {
                // Top flourish
                topFlourish
                    .padding(.bottom, 16)

                // Text content
                textContent

                // Bottom flourish with book icon
                bottomFlourish
                    .padding(.top, 20)
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 40)
        }
        .frame(width: Self.exportWidth, height: Self.exportHeight)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 8)
    }

    // MARK: - Parchment Background

    private var parchmentBackground: some View {
        ZStack {
            // Base parchment gradient using theme colors
            RadialGradient(
                colors: [
                    AnalysisTheme.parchmentBase,           // #F8F3E8
                    AnalysisTheme.parchmentBase.opacity(0.95),
                    AnalysisTheme.bgSecondary,             // #F5F3ED
                    AnalysisTheme.parchmentMid,            // #E8DFCD
                    AnalysisTheme.brandParchmentDark,      // #E8E4DC
                    AnalysisTheme.parchmentDark.opacity(0.8),
                    AnalysisTheme.parchmentDark            // #CBBFA5
                ],
                center: UnitPoint(x: 0.45, y: 0.4),
                startRadius: 0,
                endRadius: 500
            )

            // Corner vignette overlay using theme vignette color
            RadialGradient(
                colors: [
                    Color.clear,
                    AnalysisTheme.parchmentVignette.opacity(0.08),
                    AnalysisTheme.parchmentVignette.opacity(0.18),
                    AnalysisTheme.parchmentVignette.opacity(0.28)
                ],
                center: .center,
                startRadius: 150,
                endRadius: 400
            )
        }
    }

    // MARK: - Top Flourish

    private var topFlourish: some View {
        HStack(spacing: 10) {
            // Left line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, AnalysisTheme.goldOrnament],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .opacity(0.5)

            // Fleur ornament
            FleurOrnament()
                .fill(AnalysisTheme.goldOrnament)
                .frame(width: 14, height: 12)
                .opacity(0.6)

            // Right line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AnalysisTheme.goldOrnament, Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .opacity(0.5)
        }
        .frame(width: 220)
    }

    // MARK: - Text Content

    private var textContent: some View {
        VStack(spacing: 0) {
            // Line 1: "In How to Be an"
            HStack(spacing: 0) {
                Text("In ")
                    .font(Self.titleFont)
                    .italic()
                    .foregroundColor(AnalysisTheme.inkMuted)

                Text("How to Be an")
                    .font(Self.titleFont)
                    .italic()
                    .foregroundColor(AnalysisTheme.goldTitle)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            // Line 2: Book title with underline
            Text(bookTitle)
                .font(Self.titleFont)
                .italic()
                .foregroundColor(AnalysisTheme.goldTitle)
                .underline(color: AnalysisTheme.goldTitle)
                .padding(.top, -2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // Author name - use CormorantGaramond-SemiBold as Cinzel alternative
            Text(author.uppercased())
                .font(Self.authorFont)
                .foregroundColor(AnalysisTheme.coralAuthor)
                .tracking(5.5)
                .padding(.top, 6)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // Tagline
            Text(tagline)
                .font(Self.taglineFont)
                .italic()
                .foregroundColor(AnalysisTheme.goldTitle)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    // MARK: - Font Helpers with Fallbacks

    private static var titleFont: Font {
        if UIFont(name: "CormorantGaramond-Medium", size: 47) != nil {
            return .custom("CormorantGaramond-Medium", size: 47)
        }
        return .system(size: 47, weight: .medium, design: .serif)
    }

    private static var authorFont: Font {
        // Cinzel not available, use CormorantGaramond-SemiBold as elegant alternative
        if UIFont(name: "CormorantGaramond-SemiBold", size: 26) != nil {
            return .custom("CormorantGaramond-SemiBold", size: 26)
        }
        return .system(size: 26, weight: .semibold, design: .serif)
    }

    private static var taglineFont: Font {
        if UIFont(name: "CormorantGaramond-Regular", size: 43) != nil {
            return .custom("CormorantGaramond-Regular", size: 43)
        }
        return .system(size: 43, design: .serif)
    }

    // MARK: - Bottom Flourish

    private var bottomFlourish: some View {
        VStack(spacing: 12) {
            // Scroll ornament with lines
            HStack(spacing: 12) {
                // Left line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, AnalysisTheme.goldOrnament],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1.5)
                    .opacity(0.65)

                // Scroll ornament
                ScrollOrnament()
                    .stroke(AnalysisTheme.goldOrnament, lineWidth: 1.3)
                    .frame(width: 36, height: 18)
                    .opacity(0.75)

                // Right line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [AnalysisTheme.goldOrnament, Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1.5)
                    .opacity(0.65)
            }
            .frame(width: 300)

            // Book icon
            BookIcon()
                .fill(AnalysisTheme.goldOrnament.opacity(0.6))
                .frame(width: 48, height: 36)
        }
    }
}

// MARK: - Custom Shapes for Quote Card

/// Fleur de lis style ornament
struct FleurOrnament: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Center petal
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.54),
            control: CGPoint(x: w * 0.65, y: h * 0.35)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.5, y: 0),
            control: CGPoint(x: w * 0.35, y: h * 0.35)
        )

        // Left petal
        path.move(to: CGPoint(x: w * 0.5, y: h * 0.54))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.18, y: h * 0.67),
            control: CGPoint(x: w * 0.32, y: h * 0.42)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.54),
            control: CGPoint(x: w * 0.25, y: h * 0.75)
        )

        // Right petal
        path.move(to: CGPoint(x: w * 0.5, y: h * 0.54))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.82, y: h * 0.67),
            control: CGPoint(x: w * 0.68, y: h * 0.42)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.54),
            control: CGPoint(x: w * 0.75, y: h * 0.75)
        )

        // Stem
        path.move(to: CGPoint(x: w * 0.5, y: h * 0.54))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.92))

        return path
    }
}

/// Scroll ornament for bottom decoration
struct ScrollOrnament: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Left scroll curl
        path.move(to: CGPoint(x: w * 0.17, y: h * 0.5))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.28, y: h * 0.33),
            control: CGPoint(x: w * 0.17, y: h * 0.33)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.29, y: h * 0.56),
            control: CGPoint(x: w * 0.33, y: h * 0.39)
        )

        // Right scroll curl
        path.move(to: CGPoint(x: w * 0.83, y: h * 0.5))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.72, y: h * 0.33),
            control: CGPoint(x: w * 0.83, y: h * 0.33)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.71, y: h * 0.56),
            control: CGPoint(x: w * 0.67, y: h * 0.39)
        )

        // Connecting lines to center
        path.move(to: CGPoint(x: w * 0.28, y: h * 0.5))
        path.addLine(to: CGPoint(x: w * 0.42, y: h * 0.5))

        path.move(to: CGPoint(x: w * 0.58, y: h * 0.5))
        path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.5))

        // Center diamond
        path.move(to: CGPoint(x: w * 0.5, y: h * 0.28))
        path.addLine(to: CGPoint(x: w * 0.58, y: h * 0.5))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.72))
        path.addLine(to: CGPoint(x: w * 0.42, y: h * 0.5))
        path.closeSubpath()

        // Accent dots
        path.addEllipse(in: CGRect(x: w * 0.34, y: h * 0.44, width: w * 0.06, height: h * 0.12))
        path.addEllipse(in: CGRect(x: w * 0.60, y: h * 0.44, width: w * 0.06, height: h * 0.12))

        return path
    }
}

/// Open book icon
struct BookIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Left page
        path.move(to: CGPoint(x: w * 0.5, y: h * 0.15))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.1, y: h * 0.25),
            control: CGPoint(x: w * 0.3, y: h * 0.1)
        )
        path.addLine(to: CGPoint(x: w * 0.1, y: h * 0.85))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.75),
            control: CGPoint(x: w * 0.3, y: h * 0.9)
        )

        // Right page
        path.move(to: CGPoint(x: w * 0.5, y: h * 0.15))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.9, y: h * 0.25),
            control: CGPoint(x: w * 0.7, y: h * 0.1)
        )
        path.addLine(to: CGPoint(x: w * 0.9, y: h * 0.85))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.75),
            control: CGPoint(x: w * 0.7, y: h * 0.9)
        )

        // Spine
        path.move(to: CGPoint(x: w * 0.5, y: h * 0.15))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.75))

        // Feather/quill on right
        path.move(to: CGPoint(x: w * 0.85, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.65, y: h * 0.6),
            control: CGPoint(x: w * 0.95, y: h * 0.3)
        )

        return path
    }
}

// MARK: - Enhanced Commentary Boxes (Premium Edition)

// Font helpers for commentary boxes (using available project fonts)
private enum CommentaryFonts {
    static func bodyFont() -> Font {
        if UIFont(name: "CormorantGaramond-Regular", size: 18) != nil {
            return .custom("CormorantGaramond-Regular", size: 18)
        }
        return .system(size: 18, design: .serif)
    }

    static func headerFont() -> Font {
        if UIFont(name: "Inter-Bold", size: 15) != nil {
            return .custom("Inter-Bold", size: 15)
        }
        return .system(size: 15, weight: .bold)
    }

    static func authorFont() -> Font {
        if UIFont(name: "Inter-Bold", size: 13.5) != nil {
            return .custom("Inter-Bold", size: 13.5)
        }
        return .system(size: 13.5, weight: .bold)
    }

    static func bookTitleFont() -> Font {
        if UIFont(name: "CormorantGaramond-Italic", size: 18) != nil {
            return .custom("CormorantGaramond-Italic", size: 18)
        }
        return .system(size: 18, design: .serif).italic()
    }
}

// MARK: - Text Concatenation Helper for Mixed Styling

/// Builds a combined Text view with different fonts/colors for author and book title
/// This approach is more reliable than AttributedString for mixed SwiftUI styling
private struct StyledCommentaryText: View {
    let content: String
    let authorName: String
    let bookTitle: String
    let authorColor: Color
    let bookTitleColor: Color

    // CRITICAL FIX: Use explicit dark text for light background boxes
    // Commentary boxes always have light backgrounds, so text must be dark even in dark mode
    private let bodyTextColor = AnalysisTheme.Light.textBody

    var body: some View {
        buildStyledText()
            .lineSpacing(4)
    }

    @ViewBuilder
    private func buildStyledText() -> some View {
        // Parse the content and build concatenated Text views
        let segments = parseSegments()
        segments.reduce(Text("")) { result, segment in
            result + segment
        }
    }

    private func parseSegments() -> [Text] {
        var segments: [Text] = []

        // Find positions of author and book title
        let authorRange = content.range(of: authorName)
        let bookRange = content.range(of: bookTitle)

        // Determine order of highlights
        var highlights: [(range: Range<String.Index>, type: HighlightType)] = []
        if let ar = authorRange {
            highlights.append((ar, .author))
        }
        if let br = bookRange {
            highlights.append((br, .bookTitle))
        }
        highlights.sort { $0.range.lowerBound < $1.range.lowerBound }

        var currentIndex = content.startIndex

        for highlight in highlights {
            // Add text before this highlight
            if currentIndex < highlight.range.lowerBound {
                let beforeText = String(content[currentIndex..<highlight.range.lowerBound])
                segments.append(
                    Text(beforeText)
                        .font(CommentaryFonts.bodyFont())
                        .foregroundColor(bodyTextColor)
                )
            }

            // Add the highlighted text
            let highlightedText = String(content[highlight.range])
            switch highlight.type {
            case .author:
                segments.append(
                    Text(highlightedText)
                        .font(CommentaryFonts.authorFont())
                        .foregroundColor(authorColor)
                )
            case .bookTitle:
                segments.append(
                    Text(highlightedText)
                        .font(CommentaryFonts.bookTitleFont())
                        .foregroundColor(bookTitleColor)
                )
            }

            currentIndex = highlight.range.upperBound
        }

        // Add remaining text after last highlight
        if currentIndex < content.endIndex {
            let afterText = String(content[currentIndex...])
            segments.append(
                Text(afterText)
                    .font(CommentaryFonts.bodyFont())
                    .foregroundColor(bodyTextColor)
            )
        }

        // If no highlights were found, return the entire content as body text
        if segments.isEmpty {
            segments.append(
                Text(content)
                    .font(CommentaryFonts.bodyFont())
                    .foregroundColor(bodyTextColor)
            )
        }

        return segments
    }

    private enum HighlightType {
        case author
        case bookTitle
    }
}

/// Premium Insight Atlas Note - Warm cream/orange gradient
/// Matches the HTML commentary box design
struct PremiumCommentaryInsightView: View {
    let authorName: String
    let bookTitle: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                // Lightbulb icon
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AnalysisTheme.insightOrange)

                Text("INSIGHT ATLAS NOTE")
                    .font(CommentaryFonts.headerFont())
                    .tracking(2)
                    .foregroundColor(AnalysisTheme.insightOrange)
            }

            // Body text with highlighted author and book (using Text concatenation)
            StyledCommentaryText(
                content: content,
                authorName: authorName,
                bookTitle: bookTitle,
                authorColor: AnalysisTheme.insightOrange,
                bookTitleColor: AnalysisTheme.textMuted
            )
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 28)
        .background(
            LinearGradient(
                colors: [
                    AnalysisTheme.insightBgStart,
                    AnalysisTheme.insightBgMid,
                    AnalysisTheme.insightBgEnd
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AnalysisTheme.insightOrangeLight, AnalysisTheme.insightOrange],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Premium Alternative Perspective - Teal/cyan gradient
struct PremiumCommentaryAlternativeView: View {
    let authorName: String
    let bookTitle: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                // Balance scales icon
                Image(systemName: "scale.3d")
                    .font(.system(size: 16))
                    .foregroundColor(AnalysisTheme.perspectiveTeal)

                Text("ALTERNATIVE PERSPECTIVE")
                    .font(CommentaryFonts.headerFont())
                    .tracking(2)
                    .foregroundColor(AnalysisTheme.perspectiveTeal)
            }

            // Body text with highlighted author and book (using Text concatenation)
            StyledCommentaryText(
                content: content,
                authorName: authorName,
                bookTitle: bookTitle,
                authorColor: AnalysisTheme.perspectiveTeal,
                bookTitleColor: AnalysisTheme.perspectiveTeal
            )
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 28)
        .background(
            LinearGradient(
                colors: [
                    AnalysisTheme.perspectiveBgStart,
                    AnalysisTheme.perspectiveBgMid,
                    AnalysisTheme.perspectiveBgEnd
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AnalysisTheme.perspectiveTeal, AnalysisTheme.perspectiveTealDark],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Premium Research Insight - Sage/warm yellow gradient
struct PremiumCommentaryResearchView: View {
    let authorName: String
    let bookTitle: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                // Document icon
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AnalysisTheme.researchSage)

                Text("RESEARCH INSIGHT")
                    .font(CommentaryFonts.headerFont())
                    .tracking(2)
                    .foregroundColor(AnalysisTheme.researchSage)
            }

            // Body text with highlighted author and book (using Text concatenation)
            StyledCommentaryText(
                content: content,
                authorName: authorName,
                bookTitle: bookTitle,
                authorColor: AnalysisTheme.researchSageLight,
                bookTitleColor: AnalysisTheme.textMuted
            )
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 28)
        .background(
            LinearGradient(
                colors: [
                    AnalysisTheme.researchBgStart,
                    AnalysisTheme.researchBgMid,
                    AnalysisTheme.researchBgEnd
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AnalysisTheme.researchSageLight, AnalysisTheme.researchSage],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Image Export Extension

extension View {
    /// Renders the view as a UIImage for export/sharing
    /// - Parameter size: Optional target size. If nil, uses intrinsic content size.
    /// - Returns: UIImage if rendering succeeded, nil otherwise.
    @MainActor
    func renderAsImage(size: CGSize? = nil) -> UIImage? {
        let hostingController = UIHostingController(rootView: self.ignoresSafeArea())
        hostingController.view.backgroundColor = .clear

        // Calculate the target size
        let targetSize: CGSize
        if let explicitSize = size {
            targetSize = explicitSize
        } else {
            // Let the view size itself
            hostingController.view.sizeToFit()
            targetSize = hostingController.view.intrinsicContentSize
        }

        // Ensure we have a valid size
        guard targetSize.width > 0 && targetSize.height > 0 else {
            return nil
        }

        // Set bounds and layout
        hostingController.view.bounds = CGRect(origin: .zero, size: targetSize)
        hostingController.view.frame = CGRect(origin: .zero, size: targetSize)

        // Force layout pass
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()

        // Render to image
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: {
            let format = UIGraphicsImageRendererFormat()
            format.scale = UIScreen.main.scale // Use device scale for crisp rendering
            format.opaque = false
            return format
        }())

        return renderer.image { _ in
            hostingController.view.drawHierarchy(in: hostingController.view.bounds, afterScreenUpdates: true)
        }
    }

    /// Renders the view as a high-resolution UIImage suitable for sharing
    /// - Parameter scale: The scale factor (e.g., 2.0 for 2x, 3.0 for 3x). Default is 2.0.
    /// - Parameter size: Optional target size at 1x scale.
    /// - Returns: UIImage at the specified scale if rendering succeeded.
    @MainActor
    func renderAsHighResImage(scale: CGFloat = 2.0, size: CGSize? = nil) -> UIImage? {
        let hostingController = UIHostingController(rootView: self.ignoresSafeArea())
        hostingController.view.backgroundColor = .clear

        let baseSize: CGSize
        if let explicitSize = size {
            baseSize = explicitSize
        } else {
            hostingController.view.sizeToFit()
            baseSize = hostingController.view.intrinsicContentSize
        }

        guard baseSize.width > 0 && baseSize.height > 0 else { return nil }

        hostingController.view.bounds = CGRect(origin: .zero, size: baseSize)
        hostingController.view.frame = CGRect(origin: .zero, size: baseSize)
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: baseSize, format: format)
        return renderer.image { _ in
            hostingController.view.drawHierarchy(in: hostingController.view.bounds, afterScreenUpdates: true)
        }
    }
}

// MARK: - Premium Card Export View

/// A container view for exporting premium cards as images with share sheet integration
struct PremiumCardExportView: View {
    enum CardType {
        case quoteCard(bookTitle: String, author: String, tagline: String)
        case insightNote(authorName: String, bookTitle: String, content: String)
        case alternativePerspective(authorName: String, bookTitle: String, content: String)
        case researchInsight(authorName: String, bookTitle: String, content: String)
    }

    let cardType: CardType
    let onExport: (UIImage) -> Void

    @State private var isExporting = false

    var body: some View {
        VStack(spacing: 24) {
            // Card preview with scroll for smaller screens
            ScrollView(.horizontal, showsIndicators: false) {
                cardView
                    .scaleEffect(previewScale)
            }
            .frame(height: previewHeight)

            // Export button
            Button(action: exportCard) {
                HStack(spacing: 8) {
                    if isExporting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Text(isExporting ? "Exporting..." : "Export as Image")
                }
                .font(.analysisUIBold())
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [AnalysisTheme.primaryGold, AnalysisTheme.accentOrange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(AnalysisTheme.Radius.full)
            }
            .disabled(isExporting)
            .opacity(isExporting ? 0.7 : 1.0)
        }
    }

    private var previewScale: CGFloat {
        switch cardType {
        case .quoteCard:
            return 0.45 // Larger card needs more scaling
        default:
            return 0.6
        }
    }

    private var previewHeight: CGFloat {
        switch cardType {
        case .quoteCard:
            return PremiumQuoteCardView.exportHeight * previewScale + 20
        default:
            return 200
        }
    }

    @ViewBuilder
    private var cardView: some View {
        switch cardType {
        case .quoteCard(let bookTitle, let author, let tagline):
            PremiumQuoteCardView(bookTitle: bookTitle, author: author, tagline: tagline)
        case .insightNote(let authorName, let bookTitle, let content):
            PremiumCommentaryInsightView(authorName: authorName, bookTitle: bookTitle, content: content)
                .frame(width: 540)
        case .alternativePerspective(let authorName, let bookTitle, let content):
            PremiumCommentaryAlternativeView(authorName: authorName, bookTitle: bookTitle, content: content)
                .frame(width: 540)
        case .researchInsight(let authorName, let bookTitle, let content):
            PremiumCommentaryResearchView(authorName: authorName, bookTitle: bookTitle, content: content)
                .frame(width: 540)
        }
    }

    @MainActor
    private func exportCard() {
        isExporting = true

        // Use high-res rendering for crisp export (2x scale)
        let exportSize: CGSize
        switch cardType {
        case .quoteCard:
            exportSize = CGSize(width: PremiumQuoteCardView.exportWidth, height: PremiumQuoteCardView.exportHeight)
        default:
            // Commentary boxes need dynamic height based on content
            exportSize = CGSize(width: 540, height: 0) // Height will be calculated
        }

        // Render with explicit size for quote card, auto-size for commentary boxes
        let image: UIImage?
        switch cardType {
        case .quoteCard:
            image = cardView.renderAsHighResImage(scale: 2.0, size: exportSize)
        default:
            image = cardView.renderAsHighResImage(scale: 2.0, size: nil)
        }

        isExporting = false

        if let exportedImage = image {
            onExport(exportedImage)
        }
    }
}

// MARK: - Standalone Export Functions

/// Exports a premium quote card as a UIImage
/// - Parameters:
///   - bookTitle: The book title to display
///   - author: The author name
///   - tagline: The tagline text (e.g., "contends...")
///   - scale: Export scale (default 2.0 for high-res)
/// - Returns: Rendered UIImage or nil if failed
@MainActor
func exportPremiumQuoteCard(
    bookTitle: String,
    author: String,
    tagline: String,
    scale: CGFloat = 2.0
) -> UIImage? {
    let card = PremiumQuoteCardView(bookTitle: bookTitle, author: author, tagline: tagline)
    let size = CGSize(width: PremiumQuoteCardView.exportWidth, height: PremiumQuoteCardView.exportHeight)
    return card.renderAsHighResImage(scale: scale, size: size)
}

/// Exports a premium commentary box as a UIImage
/// - Parameters:
///   - type: The type of commentary box
///   - authorName: Author name to highlight
///   - bookTitle: Book title to highlight
///   - content: The commentary content
///   - width: Export width (default 540)
///   - scale: Export scale (default 2.0)
/// - Returns: Rendered UIImage or nil if failed
@MainActor
func exportPremiumCommentaryBox(
    type: PremiumCardExportView.CardType,
    scale: CGFloat = 2.0
) -> UIImage? {
    let view: AnyView
    switch type {
    case .insightNote(let authorName, let bookTitle, let content):
        view = AnyView(PremiumCommentaryInsightView(authorName: authorName, bookTitle: bookTitle, content: content).frame(width: 540))
    case .alternativePerspective(let authorName, let bookTitle, let content):
        view = AnyView(PremiumCommentaryAlternativeView(authorName: authorName, bookTitle: bookTitle, content: content).frame(width: 540))
    case .researchInsight(let authorName, let bookTitle, let content):
        view = AnyView(PremiumCommentaryResearchView(authorName: authorName, bookTitle: bookTitle, content: content).frame(width: 540))
    case .quoteCard:
        return nil // Use exportPremiumQuoteCard for quote cards
    }
    return view.renderAsHighResImage(scale: scale, size: nil)
}

// MARK: - Premium Card Previews

#Preview("Premium Quote Card") {
    PremiumQuoteCardView(
        bookTitle: "Adult in Relationships",
        author: "David Richo",
        tagline: "contends..."
    )
    .padding()
    .background(Color(hex: "#e8e0d0"))
}

#Preview("Premium Commentary Boxes") {
    ScrollView {
        VStack(spacing: 20) {
            PremiumCommentaryInsightView(
                authorName: "Brené Brown",
                bookTitle: "Dare to Lead",
                content: "In her transformative work, Brené Brown delves into the power of vulnerability and courageous leadership, particularly in her seminal book Dare to Lead. She argues that true strength lies not in armored self-protection but in the willingness to be open, take risks, and embrace our imperfections."
            )

            PremiumCommentaryAlternativeView(
                authorName: "Herb Cohen",
                bookTitle: "You Can Negotiate Anything",
                content: "Offering a contrasting view on negotiation and influence, Herb Cohen emphasizes the importance of leverage, strategy, and understanding power dynamics. In his classic You Can Negotiate Anything, he suggests that successful outcomes are often the result of careful planning."
            )

            PremiumCommentaryResearchView(
                authorName: "Carol Dweck",
                bookTitle: "Mindset",
                content: "Groundbreaking research by psychologist Carol Dweck in her book Mindset reveals the profound impact of our core beliefs about our abilities. She distinguishes between a fixed mindset and a growth mindset."
            )
        }
        .padding()
    }
    .background(Color(hex: "#f5f2eb"))
}

// MARK: - Premium Author Spotlight Card (Layered Gold Frame Design)

/// A premium author spotlight card with layered gold frame effect matching the HTML reference.
/// Features: Outer white gradient card → Multi-layer gold frame → Parchment content with inlaid shadow
struct PremiumAuthorSpotlightCard: View {
    let authorName: String
    let bio: String
    let bookTitles: [String]

    // Export dimensions
    static let exportWidth: CGFloat = 670
    static let minExportHeight: CGFloat = 400

    init(authorName: String, bio: String, bookTitles: [String] = []) {
        self.authorName = authorName
        self.bio = bio
        self.bookTitles = bookTitles
    }

    var body: some View {
        // Outer Card - White gradient with soft edges
        VStack(spacing: 0) {
            outerCard
        }
        .background(AnalysisTheme.cardBackdrop)
    }

    // MARK: - Outer Card

    private var outerCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with book icon
            headerView
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

            // Gold Frame Structure
            goldFrameStructure
        }
        .background(
            LinearGradient(
                colors: [
                    AnalysisTheme.outerCardTop,
                    AnalysisTheme.outerCardMid,
                    AnalysisTheme.outerCardBottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        .shadow(color: .black.opacity(0.04), radius: 24, x: 0, y: 8)
        .padding(12)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 10) {
            // Custom book icon matching HTML SVG
            OpenBookIconFilled()
                .fill(AnalysisTheme.primaryGold)
                .frame(width: 26, height: 20)

            Text("Author Spotlight")
                .font(.custom("CormorantGaramond-SemiBold", size: 17))
                .italic()
                .tracking(3.4)
                .textCase(.uppercase)
                .foregroundColor(AnalysisTheme.primaryGoldText)
        }
    }

    // MARK: - Gold Frame Structure (5 Layers)

    private var goldFrameStructure: some View {
        // Layer 1: Outer dark gold border
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            AnalysisTheme.goldFrameOuter,
                            AnalysisTheme.goldFrameOuterMid,
                            AnalysisTheme.goldFrameOuterDark
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

            // Layer 2: Inner bright gold
            layer2InnerBrightGold
                .padding(3)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private var layer2InnerBrightGold: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 21)
                .fill(
                    LinearGradient(
                        colors: [
                            AnalysisTheme.goldFrameInnerLight,
                            AnalysisTheme.goldFrameInnerMid,
                            AnalysisTheme.goldFrameInnerDark
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Layer 3: Cream gap
            layer3CreamGap
                .padding(18)
        }
    }

    private var layer3CreamGap: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            AnalysisTheme.goldFrameCreamLight,
                            AnalysisTheme.goldFrameCreamMid,
                            AnalysisTheme.goldFrameCreamDark
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)

            // Layer 4: Thin gold pinstripe
            layer4GoldPinstripe
                .padding(10)
        }
    }

    private var layer4GoldPinstripe: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [
                            AnalysisTheme.goldPinstripeLight,
                            AnalysisTheme.goldPinstripeDark
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Layer 5: Parchment content area
            layer5ParchmentContent
                .padding(2)
        }
    }

    private var layer5ParchmentContent: some View {
        ZStack {
            // Parchment background with inlaid shadow effect
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [
                            AnalysisTheme.parchmentBase,
                            AnalysisTheme.parchmentMid,
                            AnalysisTheme.parchmentDark.opacity(0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                // Inlaid shadow effect
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.08),
                                    Color.clear,
                                    Color.clear,
                                    Color.white.opacity(0.3)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: AnalysisTheme.goldPinstripeDark.opacity(0.3), radius: 4, x: 0, y: 2)

            // Content
            contentView
        }
    }

    // MARK: - Content

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Author name - large coral text
            Text(authorName)
                .font(.custom("Inter-Bold", size: 48))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundColor(AnalysisTheme.accentCoral)
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
                .padding(.bottom, 24)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            // Bio text with highlighted book titles
            highlightedBioText
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 48)
    }

    private var highlightedBioText: some View {
        StyledBioText(
            bio: bio,
            bookTitles: bookTitles
        )
        .lineSpacing(6)
        .multilineTextAlignment(.leading)
    }
}

// MARK: - Styled Bio Text Helper for Author Spotlight

/// Builds a combined Text view with highlighted book titles using Text concatenation
/// This approach reliably applies different fonts/colors in SwiftUI
private struct StyledBioText: View {
    let bio: String
    let bookTitles: [String]

    // Fonts for bio text
    private var bodyFont: Font {
        if UIFont(name: "CormorantGaramond-Medium", size: 22) != nil {
            return .custom("CormorantGaramond-Medium", size: 22)
        }
        return .system(size: 22, design: .serif)
    }

    private var bookTitleFont: Font {
        if UIFont(name: "CormorantGaramond-SemiBoldItalic", size: 22) != nil {
            return .custom("CormorantGaramond-SemiBoldItalic", size: 22)
        }
        return .system(size: 22, design: .serif).italic()
    }

    // Coral colors for book titles
    private let coralColors: [Color] = [
        Color(hex: "#C67650"),
        Color(hex: "#BE6E48")
    ]

    var body: some View {
        buildStyledText()
    }

    @ViewBuilder
    private func buildStyledText() -> some View {
        let segments = parseSegments()
        segments.reduce(Text("")) { result, segment in
            result + segment
        }
    }

    private func parseSegments() -> [Text] {
        var segments: [Text] = []

        // Find all book title positions
        var highlights: [(range: Range<String.Index>, colorIndex: Int)] = []
        for (index, title) in bookTitles.enumerated() {
            if let range = bio.range(of: title) {
                highlights.append((range, index))
            }
        }
        highlights.sort { $0.range.lowerBound < $1.range.lowerBound }

        var currentIndex = bio.startIndex

        for highlight in highlights {
            // Add text before this highlight
            if currentIndex < highlight.range.lowerBound {
                let beforeText = String(bio[currentIndex..<highlight.range.lowerBound])
                segments.append(
                    Text(beforeText)
                        .font(bodyFont)
                        .foregroundColor(AnalysisTheme.textBody)
                )
            }

            // Add the highlighted book title
            let highlightedText = String(bio[highlight.range])
            let color = coralColors[highlight.colorIndex % coralColors.count]
            segments.append(
                Text(highlightedText)
                    .font(bookTitleFont)
                    .foregroundColor(color)
            )

            currentIndex = highlight.range.upperBound
        }

        // Add remaining text after last highlight
        if currentIndex < bio.endIndex {
            let afterText = String(bio[currentIndex...])
            segments.append(
                Text(afterText)
                    .font(bodyFont)
                    .foregroundColor(AnalysisTheme.textBody)
            )
        }

        // If no highlights were found, return the entire bio as body text
        if segments.isEmpty {
            segments.append(
                Text(bio)
                    .font(bodyFont)
                    .foregroundColor(AnalysisTheme.textBody)
            )
        }

        return segments
    }
}

// MARK: - Open Book Icon (Filled version matching HTML SVG)

struct OpenBookIconFilled: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Left page
        path.move(to: CGPoint(x: w * 0.019, y: h * 0.875))
        path.addCurve(
            to: CGPoint(x: w * 0.262, y: h * 0.74),
            control1: CGPoint(x: w * 0.019, y: h * 0.775),
            control2: CGPoint(x: w * 0.108, y: h * 0.74)
        )
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.74))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.05))
        path.addLine(to: CGPoint(x: w * 0.262, y: h * 0.05))
        path.addCurve(
            to: CGPoint(x: w * 0.019, y: h * 0.185),
            control1: CGPoint(x: w * 0.108, y: h * 0.05),
            control2: CGPoint(x: w * 0.019, y: h * 0.085)
        )
        path.closeSubpath()

        // Right page
        path.move(to: CGPoint(x: w * 0.981, y: h * 0.875))
        path.addCurve(
            to: CGPoint(x: w * 0.738, y: h * 0.74),
            control1: CGPoint(x: w * 0.981, y: h * 0.775),
            control2: CGPoint(x: w * 0.892, y: h * 0.74)
        )
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.74))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.05))
        path.addLine(to: CGPoint(x: w * 0.738, y: h * 0.05))
        path.addCurve(
            to: CGPoint(x: w * 0.981, y: h * 0.185),
            control1: CGPoint(x: w * 0.892, y: h * 0.05),
            control2: CGPoint(x: w * 0.981, y: h * 0.085)
        )
        path.closeSubpath()

        return path
    }
}

// MARK: - Premium Author Card Export Functions

/// Exports a premium author spotlight card as a UIImage
@MainActor
func exportPremiumAuthorSpotlightCard(
    authorName: String,
    bio: String,
    bookTitles: [String] = [],
    scale: CGFloat = 2.0
) -> UIImage? {
    let card = PremiumAuthorSpotlightCard(
        authorName: authorName,
        bio: bio,
        bookTitles: bookTitles
    )
    return card.renderAsHighResImage(scale: scale, size: nil)
}

// MARK: - Preview

#Preview("Premium Author Spotlight Card") {
    ScrollView {
        PremiumAuthorSpotlightCard(
            authorName: "Renée Evenson",
            bio: "Renée Evenson is a recognized expert in customer service, leadership, and communication. With decades of experience, she has dedicated her career to helping professionals refine their interpersonal skills and build stronger relationships in the workplace. Her insightful guidebooks provide actionable strategies and practical advice for achieving excellence in service and management. Among her acclaimed works are the essential resources, Powerful Phrases for Effective Customer Service and the comprehensive Customer Service Training 101, both of which have become staples in corporate training programs worldwide. Renée's commitment to fostering positive interactions and empowering individuals shines through in every word, making her a trusted voice in the field.",
            bookTitles: ["Powerful Phrases for Effective Customer Service", "Customer Service Training 101"]
        )
        .padding()
    }
    .background(AnalysisTheme.cardBackdrop)
}
