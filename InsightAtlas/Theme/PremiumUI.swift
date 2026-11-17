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

    // MARK: Accents — "Ember Forward"
    //
    // Three hues in a loose triad, replacing the previous eight-accent set:
    // ember leads (identity and action), indigo structures, celadon is the
    // quiet third. Every value below clears WCAG AA against its own surface in
    // both themes.
    //
    // Ember ships in two tones because a saturated warm hue cannot be both
    // vivid and legible on a light ground: `emberMark` is for marks only —
    // dots, rails, rules — and `ember` for anything bearing type (4.64:1 on
    // `background`, 5.10:1 on `card`). On dark surfaces one tone serves both.
    static let ember      = adaptive("#C2431F", "#F07A55")   // hero — type-safe
    static let emberMark  = adaptive("#E85C36", "#F07A55")   // hero — marks only, never type
    static let indigo     = adaptive("#26355E", "#8DA0D4")   // structure & navigation
    static let celadon    = adaptive("#41705F", "#6FB39C")   // quiet third — progress

    // Legacy accent names resolve onto the three hues above so existing call
    // sites adopt the theme without a rename sweep. Prefer `ember`, `indigo`
    // and `celadon` in new code; these aliases are the migration path.
    static let gold       = ember
    static let goldDark   = ember
    static let coral      = ember        // former CTA fill
    static let burgundy   = ember
    static let warmOrange = emberMark
    static let slate      = indigo
    static let skyBlue    = indigo
    static let teal       = celadon
    static let forest     = celadon

    // Tints and washes derived from the triad. `…Wash` are page/section
    // backgrounds (body ink stays above 13:1 on all of them); `…Tint` are
    // stronger fills for chips and gradient stops; `…Deep`/`…Soft` are the
    // high-contrast variants for text on the opposite ground.
    static let emberWash   = adaptive("#FBEDE8", "#2A1B15")
    static let emberTint   = adaptive("#F3D9CE", "#3A241B")
    static let emberDeep   = adaptive("#9E3517", "#F5A088")
    static let indigoWash  = adaptive("#EAEDF4", "#1A1F2E")
    static let indigoTint  = adaptive("#D3D9E8", "#252C40")
    static let indigoDeep  = adaptive("#1B2744", "#A9B8E0")
    static let celadonWash = adaptive("#E9F0EC", "#17241F")
    static let celadonTint = adaptive("#D6E4DC", "#1F3229")
    static let celadonDeep = adaptive("#2F5747", "#92C7B4")

    /// Destructive actions. Deliberately NOT part of the accent triad: it must
    /// read as red for meaning, but ember is already a red-orange at hue 13°,
    /// so the two are separated by value instead of hue (13 points darker,
    /// lower chroma) — otherwise Favourite and Delete look identical in the
    /// swipe row.
    static let destructive = adaptive("#7F1D1D", "#D98079")

    // MARK: Surfaces & text
    //
    // A single warm-neutral family: every surface sits in the same hue band so
    // nothing reads as a temperature mismatch. (The previous base mixed a warm
    // ground at hue 45° with cool chips and dividers at hue 214°.)
    static let background    = adaptive("#F5F4F1", "#141518")
    static let card          = adaptive("#FFFFFF", "#1D1F23")
    static let searchFill    = adaptive("#F0EEE9", "#1A1C20")   // Inset surface (search / segmented trough)
    static let chipFill      = adaptive("#EDEBE5", "#23262B")
    static let ink           = adaptive("#1E2229", "#EFF0F2")
    static let secondaryText = adaptive("#5F6670", "#A0A6AF")
    static let divider       = adaptive("#E4E2DC", "#2B2E34")
    /// Heavier rule for structural borders (table grids, framed blocks), so a
    /// "medium" border is actually distinguishable from a hairline.
    static let dividerStrong = adaptive("#D1CEC6", "#3A3E45")
    static let softGold      = adaptive("#F7E7E0", "#2A1B15")   // soft ember tint

    static let cardShadow = Color.black.opacity(0.10)

    /// UIKit mirror of the palette, for the AppKit/UIKit-facing call sites
    /// (attributed strings, PDF rendering, appearance proxies) that cannot take
    /// a SwiftUI `Color`. Values resolve from `Hex`, so they cannot drift.
    enum UI {
        private static func adaptive(_ light: String, _ dark: String) -> UIColor {
            UIColor { traits in
                UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
            }
        }
        static let ember       = adaptive(Hex.emberLight, Hex.emberDark)
        static let emberMark   = adaptive(Hex.emberMarkLight, Hex.emberMarkDark)
        static let emberWash   = adaptive(Hex.emberWashLight, Hex.emberWashDark)
        static let indigo      = adaptive(Hex.indigoLight, Hex.indigoDark)
        static let indigoWash  = adaptive(Hex.indigoWashLight, Hex.indigoWashDark)
        static let celadon     = adaptive(Hex.celadonLight, Hex.celadonDark)
        static let destructive = adaptive(Hex.destructiveLight, Hex.destructiveDark)
        static let background  = adaptive(Hex.backgroundLight, Hex.backgroundDark)
        static let card        = adaptive(Hex.cardLight, Hex.cardDark)
        static let chipFill    = adaptive(Hex.chipLight, Hex.chipDark)
        static let ink         = adaptive(Hex.inkLight, Hex.inkDark)
        static let muted       = adaptive(Hex.mutedLight, Hex.mutedDark)
        static let divider     = adaptive(Hex.dividerLight, Hex.dividerDark)
    }

    /// Alternate reading modes.
    ///
    /// Sepia and High Contrast are reader preferences, not brand colours — they
    /// deliberately depart from the triad. They live here anyway so that every
    /// colour value in the app is written down in exactly one file.
    enum Sepia {
        static let text    = adaptive("#2A2725", "#E7E1D8")
        static let muted   = adaptive("#8A8580", "#A69D92")
        static let bg      = adaptive("#FAFAF8", "#1E1B16")
        static let surface = adaptive("#F5F0E8", "#221F19")
        static let sunken  = adaptive("#F1ECDF", "#1E1B16")
        static let card    = adaptive("#FFFFFF", "#2A251E")
    }

    enum HighContrast {
        static let heading = adaptive("#0C0D0E", "#FFFFFF")
        static let body    = adaptive("#1A1C1E", "#F2F4F8")
        static let muted   = adaptive("#4A4F55", "#DEE3E8")
    }

    /// Raw palette values as hex strings.
    ///
    /// The exported-guide HTML and the PDF renderers build CSS, so they need
    /// strings rather than `Color`s. Both draw from here so there is exactly
    /// one place a palette value is written down. `light`/`dark` mirror the
    /// two halves of each `adaptive(_:_:)` pair above.
    enum Hex {
        // Accents
        static let emberLight       = "#C2431F"
        static let emberDark        = "#F07A55"
        static let emberMarkLight   = "#E85C36"
        static let emberMarkDark    = "#F07A55"
        static let indigoLight      = "#26355E"
        static let indigoDark       = "#8DA0D4"
        static let celadonLight     = "#41705F"
        static let celadonDark      = "#6FB39C"
        static let destructiveLight = "#7F1D1D"
        static let destructiveDark  = "#D98079"

        // Tints & washes
        static let emberWashLight   = "#FBEDE8"
        static let emberWashDark    = "#2A1B15"
        static let indigoWashLight  = "#EAEDF4"
        static let indigoWashDark   = "#1A1F2E"
        static let celadonWashLight = "#E9F0EC"
        static let celadonWashDark  = "#17241F"

        // Deep variants — text on a light ground, and the semantic accents
        // (caution, premium) that must not be confused with the brand marks.
        static let emberDeepLight   = "#9E3517"
        static let emberDeepDark    = "#F5A088"
        static let indigoDeepLight  = "#1B2744"
        static let indigoDeepDark   = "#A9B8E0"
        static let celadonDeepLight = "#2F5747"
        static let celadonDeepDark  = "#92C7B4"

        // Surfaces & text
        static let backgroundLight  = "#F5F4F1"
        static let backgroundDark   = "#141518"
        static let cardLight        = "#FFFFFF"
        static let cardDark         = "#1D1F23"
        static let chipLight        = "#EDEBE5"
        static let chipDark         = "#23262B"
        static let inkLight         = "#1E2229"
        static let inkDark          = "#EFF0F2"
        static let mutedLight       = "#5F6670"
        static let mutedDark        = "#A0A6AF"
        static let dividerLight     = "#E4E2DC"
        static let dividerDark      = "#2B2E34"
        /// A heavier rule than `divider`, for the borders meant to read as
        /// structural (table grids, PDF block frames) rather than as hairlines.
        static let dividerStrongLight = "#D1CEC6"
        static let dividerStrongDark  = "#3A3E45"

        /// Percent-encoded (`%23`) forms, for SVG data URIs embedded in the
        /// exported-guide CSS — a raw `#` terminates a URL fragment there.
        /// The `…OnDark` names carry the dark palette variants, for icons
        /// declared inside a `prefers-color-scheme: dark` block.
        enum URLEncoded {
            private static func enc(_ hex: String) -> String { "%23" + String(hex.dropFirst()) }
            static let ember         = enc(emberLight)
            static let emberOnDark   = enc(emberDark)
            static let celadon       = enc(celadonLight)
            static let celadonOnDark = enc(celadonDark)
            static let indigo        = enc(indigoLight)
        }

        /// `"r, g, b"` triplets of the same values, for CSS custom properties
        /// consumed as `rgba(var(--ember-rgb), 0.08)`.
        ///
        /// The exported guide needs dozens of tinted fills, borders and
        /// shadows. Writing those as literal `rgba(…)` is what let the export
        /// drift a full palette generation behind the app: a literal cannot be
        /// re-pointed, and it cannot be overridden inside a dark-mode block.
        /// Every tint in the export CSS therefore goes through one of these.
        enum RGB {
            private static func rgb(_ hex: String) -> String {
                var value: UInt64 = 0
                Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
                    .scanHexInt64(&value)
                return "\(value >> 16 & 0xFF), \(value >> 8 & 0xFF), \(value & 0xFF)"
            }
            static let emberLight       = rgb(Hex.emberLight)
            static let emberDark        = rgb(Hex.emberDark)
            static let emberMarkLight   = rgb(Hex.emberMarkLight)
            static let emberMarkDark    = rgb(Hex.emberMarkDark)
            static let indigoLight      = rgb(Hex.indigoLight)
            static let indigoDark       = rgb(Hex.indigoDark)
            static let celadonLight     = rgb(Hex.celadonLight)
            static let celadonDark      = rgb(Hex.celadonDark)
            static let destructiveLight = rgb(Hex.destructiveLight)
            static let destructiveDark  = rgb(Hex.destructiveDark)
            static let inkLight         = rgb(Hex.inkLight)
            static let inkDark          = rgb(Hex.inkDark)
        }
    }

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

/// The user-selectable accent, one per hue in the Ember Forward triad.
///
/// The previous four cases (Gold, Burgundy, Coral, Teal) predate the triad and
/// all but Teal resolved to the same ember, so the picker drew three identical
/// swatches under three different labels. Those spellings still decode — see
/// `init?(rawValue:)` — so a preference stored by an earlier build survives.
enum PremiumAccent: CaseIterable, Identifiable {
    case ember
    case indigo
    case celadon

    /// Legacy spelling kept for call sites that name the default accent.
    static let gold = PremiumAccent.ember

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .ember: return PremiumUI.ember
        case .indigo: return PremiumUI.indigo
        case .celadon: return PremiumUI.celadon
        }
    }
}

extension PremiumAccent: RawRepresentable {
    typealias RawValue = String

    var rawValue: String {
        switch self {
        case .ember: return "Ember"
        case .indigo: return "Indigo"
        case .celadon: return "Celadon"
        }
    }

    init?(rawValue: String) {
        switch rawValue {
        case "Ember", "Gold", "Burgundy", "Coral": self = .ember
        case "Indigo", "Slate", "SkyBlue": self = .indigo
        case "Celadon", "Teal", "Forest": self = .celadon
        default: return nil
        }
    }
}
