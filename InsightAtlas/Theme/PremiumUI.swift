import SwiftUI
import UIKit

enum PremiumUI {
    static let themeStorageKey = "insight_atlas_theme_preference"
    static let accentStorageKey = "insight_atlas_accent_preference"

    /// Light/dark adaptive color from two hex strings, resolved per trait
    /// collection so the whole chrome follows the system (and the Theme setting).
    private static func adaptive(_ light: String, _ dark: String) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    // Accents — CMV-blended palette; hero gold plus supporting hues.
    // Dark variants are lightened for contrast on dark surfaces.
    static let gold       = adaptive("#B8962E", "#D4AF37")   // Metallic Gold (hero) — hue 46°
    static let goldDark   = adaptive("#B8962E", "#D4AF37")   // darkened gold for small (<20pt) icons
    static let burgundy   = adaptive("#7B203D", "#C56B82")
    static let coral      = adaptive("#E8553A", "#F0876F")   // Coral Arrow
    static let teal       = adaptive("#3B7C78", "#5FA9A4")
    static let skyBlue    = adaptive("#4BA3C8", "#6FC0DF")   // Sky Blue
    static let forest     = adaptive("#3D5840", "#7BAE80")   // Forest
    static let warmOrange = adaptive("#D87520", "#E89B5A")   // Warm Orange
    static let slate      = adaptive("#2C3E50", "#8CA3B8")   // Deep Slate — active navigation & shell iconography

    // Surfaces & text — "Warm Mist" cool-neutral base (2026 quiet-interface),
    // adaptive so dark mode renders correctly.
    static let background    = adaptive("#FAF9F6", "#111111")
    static let card          = adaptive("#FFFFFF", "#1E1E1E")   // pure white card surface
    static let searchFill    = adaptive("#EDEDEB", "#1C2024")   // Inset surface (search / segmented trough)
    static let chipFill      = adaptive("#E7EAEE", "#20252A")
    static let ink           = adaptive("#1E1E1E", "#F5F7FA")
    static let secondaryText = adaptive("#555555", "#C7CDD3")
    static let divider       = adaptive("#E1E4E8", "#2A2E33")
    static let softGold      = adaptive("#F5EFD6", "#332B18")

    static let cardShadow = Color.black.opacity(0.10)

    static func accent(from rawValue: String) -> Color {
        PremiumAccent(rawValue: rawValue)?.color ?? gold
    }

    // MARK: - Typography (bundled brand fonts, Dynamic Type–scalable)

    /// Display serif (Cormorant Garamond) — screen titles, book/card titles.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold, relativeTo style: Font.TextStyle = .title) -> Font {
        let name: String
        switch weight {
        case .bold:     name = "CormorantGaramond-Bold"
        case .semibold: name = "CormorantGaramond-SemiBold"
        case .medium:   name = "CormorantGaramond-Medium"
        default:        name = "CormorantGaramond-Regular"
        }
        return .custom(name, size: size, relativeTo: style)
    }

    /// UI sans (Inter) — labels, metadata, body chrome.
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        let name: String
        switch weight {
        case .bold:     name = "Inter-Bold"
        case .semibold: name = "Inter-SemiBold"
        case .medium:   name = "Inter-Medium"
        default:        name = "Inter-Regular"
        }
        return .custom(name, size: size, relativeTo: style)
    }
}

enum PremiumTheme: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "iphone"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

enum PremiumAccent: String, CaseIterable, Identifiable {
    case gold = "Gold"
    case burgundy = "Burgundy"
    case coral = "Coral"
    case teal = "Teal"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .gold: return PremiumUI.gold
        case .burgundy: return PremiumUI.burgundy
        case .coral: return PremiumUI.coral
        case .teal: return PremiumUI.teal
        }
    }
}
