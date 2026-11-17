//
//  ExportMarkdownTable.swift
//  InsightAtlas
//
//  Shared markdown table parsing for PDF and DOCX exporters.
//

import Foundation

enum ExportMarkdownTable {
    static func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("|") && trimmed.contains("-") && trimmed.rangeOfCharacter(from: .letters) == nil
    }

    /// Parses a markdown table line into cells
    static func parseTableRow(_ line: String) -> [String] {
        var cells = line.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
        // Remove empty first/last cells from leading/trailing pipes
        if cells.first?.isEmpty == true { cells.removeFirst() }
        if cells.last?.isEmpty == true { cells.removeLast() }
        return cells
    }
}
