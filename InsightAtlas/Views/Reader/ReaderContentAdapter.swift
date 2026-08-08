import Foundation

/// Bridges a generated `LibraryItem` into the reader's `BookSection` model.
///
/// The guide body is stored as a single markdown/prose string in
/// `summaryContent`. This adapter splits it into navigable sections on the
/// top-level markdown headings, turning the remaining prose into paragraph
/// blocks. It intentionally maps only what the reader renders today
/// (headings + paragraphs); richer block types are a later enhancement.
extension ReaderViewModel {

    /// Build a reader view-model from a library guide, or `nil` when the guide
    /// has no readable body yet (e.g. a draft still generating).
    static func make(from item: LibraryItem) -> ReaderViewModel? {
        let content = item.summaryContent?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !content.isEmpty else { return nil }

        let sections = Self.sections(from: content, fallbackTitle: item.title)
        guard !sections.isEmpty else { return nil }

        return ReaderViewModel(bookTitle: item.title, sections: sections)
    }

    // MARK: - Markdown → sections

    /// Split markdown into sections on `#`/`##`/`###` heading lines. Prose
    /// before the first heading (or an unheaded document) becomes a single
    /// section titled with the guide title.
    private static func sections(from markdown: String, fallbackTitle: String) -> [BookSection] {
        var sections: [BookSection] = []
        var currentTitle: String?
        var currentParagraphs: [String] = []

        func flush() {
            let hasBody = !currentParagraphs.isEmpty
            guard hasBody || currentTitle != nil else { return }
            let index = sections.count + 1
            let title = currentTitle ?? fallbackTitle
            sections.append(
                BookSection(
                    index: index,
                    title: title,
                    partLabel: String(format: "Part %02d", index),
                    partName: title,
                    blocks: currentParagraphs.map { ReaderBlock.paragraph($0) }
                )
            )
            currentTitle = nil
            currentParagraphs = []
        }

        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if let heading = Self.headingText(from: line) {
                flush()
                currentTitle = heading
            } else if !line.isEmpty {
                currentParagraphs.append(line)
            }
        }
        flush()

        return sections
    }

    /// Returns the trimmed text of a markdown heading line (`# …` through
    /// `### …`), or `nil` if the line is not a heading.
    private static func headingText(from line: String) -> String? {
        guard line.hasPrefix("#") else { return nil }
        let hashes = line.prefix { $0 == "#" }
        guard (1...3).contains(hashes.count) else { return nil }
        let text = line.dropFirst(hashes.count).trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }
}
