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

    // Pattern 3: Author Name, *Book Title* (Year) — the Go Deeper / Further
    // Reading form mandated by the elevation spec (author first, italic title).
    let authorFirstPattern = #"([A-Z][a-zA-Z\.'\-]+(?:\s+[A-Z][a-zA-Z\.'\-]+){0,3}),\s+\*([^*]+)\*\s*\((?:c\.\s*)?\d{4}[a-z]?\)"#
    if let regex = try? NSRegularExpression(pattern: authorFirstPattern, options: []) {
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            if let authorRange = Range(match.range(at: 1), in: text),
               let titleRange = Range(match.range(at: 2), in: text) {
                let title = String(text[titleRange]).trimmingCharacters(in: .whitespaces)
                let author = String(text[authorRange]).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty && !author.isEmpty && !references.contains(where: { $0.title == title }) {
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
                        .foregroundColor(AnalysisTheme.textMuted)
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
    let presentationText = PresentationTextSanitizer.attributedMarkupSource(text)
    var result = AttributedString(presentationText)

    // 1. Process citations: "[Book Title]" by [Author Name]
    // \p{Lu}/\p{L} rather than [A-Z]/[A-Za-z]: an ASCII-only class stops at the
    // first accented letter, so "Brené Brown" matched only "Bren", which was
    // then uppercased to "BREN" while "é Brown" stayed outside the match --
    // rendering the author as "BRENé Brown".
    let citationPattern = #"\"([^\"]+)\"\s+by\s+(\p{Lu}[\p{L}\.\-\']+(?:\s+\p{Lu}[\p{L}\.\-\']+){0,3})"#
    if let citationRegex = try? NSRegularExpression(pattern: citationPattern) {
        let matches = citationRegex.matches(
            in: presentationText,
            range: NSRange(presentationText.startIndex..., in: presentationText)
        )
        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: presentationText),
                  let titleRange = Range(match.range(at: 1), in: presentationText),
                  let authorRange = Range(match.range(at: 2), in: presentationText) else {
                continue
            }
            
            let fullText = String(presentationText[fullRange])
            let bookTitle = String(presentationText[titleRange])
            let authorName = String(presentationText[authorRange])
            
            if let attrRange = result.range(of: fullText) {
                var styledCitation = AttributedString("")
                
                var titleAttr = AttributedString(bookTitle)
                // Gold italic for book title
                titleAttr.font = .custom("CormorantGaramond-Italic", size: 17)
                titleAttr.foregroundColor = PremiumUI.ember
                
                var byAttr = AttributedString(" by ")
                byAttr.font = .custom("CormorantGaramond-Regular", size: 17)
                byAttr.foregroundColor = AnalysisTheme.textBody
                
                var authorAttr = AttributedString(authorName.uppercased())
                // Coral small caps (uppercased) for author
                authorAttr.font = .custom("Inter-SemiBold", size: 15) // Mimicking small caps
                authorAttr.foregroundColor = PremiumUI.ember
                
                styledCitation.append(titleAttr)
                styledCitation.append(byAttr)
                styledCitation.append(authorAttr)
                
                result.replaceSubrange(attrRange, with: styledCitation)
            }
        }
    }

    // 2. Process bold markdown syntax (**text**)
    applyInlineEmphasis(
        to: &result,
        pattern: #"\*\*([^*]+)\*\*"#,
        wrap: { "**\($0)**" },
        font: .analysisBodyBold()
    )

    // 3. Process italic markdown (*text* and _text_).
    //
    // Bold runs first and has already been consumed above, so a lone asterisk
    // here is emphasis. Without this pass the asterisks were rendered literally
    // to the reader, which is how "*arbitrary*" reached the page with its
    // markers intact.
    applyInlineEmphasis(
        to: &result,
        pattern: #"(?<![\*\w])\*([^\*\n]+)\*(?![\*\w])"#,
        wrap: { "*\($0)*" },
        font: .analysisBodyItalic()
    )
    applyInlineEmphasis(
        to: &result,
        pattern: #"(?<![_\w])_([^_\n]+)_(?![_\w])"#,
        wrap: { "_\($0)_" },
        font: .analysisBodyItalic()
    )

    return result
}

/// Replace every `pattern` match in `result` with its captured text restyled.
///
/// Matching is done against the current plain-text projection and applied in
/// reverse so earlier ranges stay valid as later ones are replaced.
private func applyInlineEmphasis(
    to result: inout AttributedString,
    pattern: String,
    wrap: (String) -> String,
    font: Font
) {
    let currentText = String(result.characters)
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
    let matches = regex.matches(in: currentText, range: NSRange(currentText.startIndex..., in: currentText))
    for match in matches.reversed() {
        guard let captureRange = Range(match.range(at: 1), in: currentText) else { continue }
        let inner = String(currentText[captureRange])
        guard let attrRange = result.range(of: wrap(inner)) else { continue }
        var styled = AttributedString(inner)
        styled.font = font
        result.replaceSubrange(attrRange, with: styled)
    }
}
