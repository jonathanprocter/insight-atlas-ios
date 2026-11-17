//
//  ExportBrandAssets.swift
//  Shared export branding helpers (filename, logo, reading time).
//

import Foundation
import UIKit

enum ExportBrandAssets {
static func sanitizeFilename(_ title: String) -> String {
    // Remove invalid filename characters
    var sanitized = title

    // Characters not allowed in filenames
    let invalidChars = CharacterSet(charactersIn: "/\\?%*|\"<>:")
    sanitized = sanitized.components(separatedBy: invalidChars).joined(separator: "")

    // Trim whitespace and normalize multiple spaces to single space
    sanitized = sanitized.trimmingCharacters(in: .whitespaces)
    sanitized = sanitized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

    // Ensure the title is not empty
    if sanitized.isEmpty {
        sanitized = "Untitled"
    }

    return sanitized
}



/// Calculate dynamic reading time based on word count
static func calculateReadingTime(from content: String) -> Int {
    let wordsPerMinute = 225.0
    let wordCount = Double(content.split(whereSeparator: { $0.isWhitespace }).count)
    return max(1, Int(ceil(wordCount / wordsPerMinute)))
}

/// Get the Insight Atlas logo as a base64-encoded data URL for HTML embedding
///
/// `UIImage(named:)` and `pngData()` are thread-safe, so this reads the asset
/// directly instead of blocking on the main queue (`main.sync` from a
/// background export can deadlock against a main thread that is waiting).
static func getLogoBase64() -> String? {
    guard let logoImage = UIImage(named: "Logo"),
          let pngData = logoImage.pngData() else {
        return nil
    }
    return "data:image/png;base64,\(pngData.base64EncodedString())"
}

/// Get the Insight Atlas logo UIImage for PDF rendering
static func getLogoImage() -> UIImage? {
    UIImage(named: "Logo")
}

}
