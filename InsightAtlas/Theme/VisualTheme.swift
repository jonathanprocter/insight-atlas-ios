//
//  VisualTheme.swift
//  InsightAtlas
//
//  Style tokens for visual rendering consistency across SwiftUI and PDF.
//

import SwiftUI

enum VisualTheme {
    // MARK: - SwiftUI Tokens

    /// Corner radius for visual images in SwiftUI
    static let cornerRadius: CGFloat = 8

    /// Shadow opacity for visual images in SwiftUI
    static let shadowOpacity: Double = 0.15

    /// Caption font for visual descriptions
    static let captionFont: Font = .caption

    /// Background color for error states
    static let background: Color = AnalysisTheme.bgCard

    /// Spacing between image and caption
    static let captionSpacing: CGFloat = 8

    // MARK: - PDF Tokens

    /// Corner radius for visual images in PDF
    static let pdfCornerRadius: CGFloat = 8

    /// Shadow opacity for visual images in PDF
    static let pdfShadowOpacity: CGFloat = 0.1

    // MARK: - Shared Tokens

    /// Minimum height for visual placeholder
    static let minPlaceholderHeight: CGFloat = 150

    /// Loading indicator height
    static let loadingHeight: CGFloat = 200
}
