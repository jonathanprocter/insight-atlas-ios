//
//  EditorialMarkupCanonicalizer.swift
//  InsightAtlas
//
//  Extracted from EditorialContentRenderer so markup repair can evolve
//  without editing the megaview.
//

import Foundation

/// Repairs formatting mistakes in generated editorial markup without inventing,
/// deleting, or reordering semantic prose. The reader parser is line-oriented,
/// so each control tag is normalized onto its own structural line.
enum EditorialMarkupCanonicalizer {
    private static let tagPattern = #"\[/?[A-Z][A-Z0-9_]*(?::[^\]]*)?\]"#
    private static let fullTagPattern = #"^\[/?[A-Z][A-Z0-9_]*(?::[^\]]*)?\]$"#

    static func canonicalize(_ content: String) -> String {
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        guard let regex = try? NSRegularExpression(pattern: tagPattern) else {
            return normalized
        }

        let separated = regex.stringByReplacingMatches(
            in: normalized,
            range: NSRange(normalized.startIndex..., in: normalized),
            withTemplate: "\n$0\n"
        )
        let lines = separated.components(separatedBy: "\n").map {
            $0.trimmingCharacters(in: .whitespaces)
        }

        var output: [String] = []
        var previousWasEmpty = false
        for line in lines {
            // Debris from a tag whose name was stripped, or from a tag the
            // model split across lines. Prose is never a lone bracket, and
            // leaving these in printed "[" and "]" as body paragraphs in
            // shipped PDFs. Dropped here so every downstream parser — reader,
            // PDF, and HTML export — is rid of them at one choke point.
            if line.allSatisfy({ $0 == "[" || $0 == "]" || $0.isWhitespace }), !line.isEmpty {
                continue
            }
            if line.isEmpty {
                if !previousWasEmpty, !output.isEmpty { output.append("") }
                previousWasEmpty = true
            } else {
                if isEditorialTagLine(line),
                   output.last?.isEmpty == true,
                   output.count >= 2,
                   isEditorialTagLine(output[output.count - 2]) {
                    output.removeLast()
                }
                output.append(line)
                previousWasEmpty = false
            }
        }
        while output.last?.isEmpty == true { output.removeLast() }

        // Generated headings are semantically one line. If the model omits the
        // closing tag, terminate the heading after its first non-empty text line
        // so following prose cannot become a multi-paragraph TOC entry.
        var repaired: [String] = []
        var index = 0
        while index < output.count {
            let line = output[index]
            let upper = line.uppercased()
            let headerName: String? = upper == "[PREMIUM_H1]" ? "PREMIUM_H1"
                : (upper == "[PREMIUM_H2]" ? "PREMIUM_H2" : nil)
            guard let headerName else {
                repaired.append(line)
                index += 1
                continue
            }

            repaired.append(line)
            index += 1
            while index < output.count, output[index].isEmpty {
                repaired.append(output[index])
                index += 1
            }
            if index < output.count, !isEditorialTagLine(output[index]) {
                repaired.append(output[index])
                index += 1
            }
            if index < output.count, isClosingTagLine(output[index], named: headerName) {
                repaired.append(output[index])
                index += 1
            } else {
                repaired.append("[/\(headerName)]")
            }
        }
        while repaired.last?.isEmpty == true { repaired.removeLast() }
        return repaired.joined(separator: "\n")
    }

    static func isEditorialTagLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.range(of: fullTagPattern, options: .regularExpression) != nil
    }

    static func isClosingTagLine(_ line: String, named name: String) -> Bool {
        line.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare("[/\(name)]") == .orderedSame
    }
}
