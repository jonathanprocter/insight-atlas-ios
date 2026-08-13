import UIKit

// MARK: - WCAG Contrast (Directives §C3)
//
// Utility to verify text/background pairs meet WCAG AA contrast during rendering
// and in tests. AA requires ≥ 4.5:1 for normal text and ≥ 3.0:1 for large/bold
// text and UI accents.

enum WCAGContrast {

    static let aaNormal: CGFloat = 4.5
    static let aaLarge: CGFloat = 3.0

    /// Relative luminance per WCAG 2.1.
    static func relativeLuminance(_ color: UIColor) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ c: CGFloat) -> CGFloat {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    /// Contrast ratio between two colors (1…21).
    static func ratio(_ a: UIColor, _ b: UIColor) -> CGFloat {
        let la = relativeLuminance(a)
        let lb = relativeLuminance(b)
        let hi = max(la, lb), lo = min(la, lb)
        return (hi + 0.05) / (lo + 0.05)
    }

    static func meetsAA(_ foreground: UIColor, on background: UIColor, large: Bool = false) -> Bool {
        ratio(foreground, background) >= (large ? aaLarge : aaNormal)
    }
}
