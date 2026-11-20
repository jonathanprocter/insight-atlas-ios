import SwiftUI

// MARK: - Insight Atlas Analysis Theme
//
// Semantic names for the reading and analysis surfaces. This file holds NO
// colour values of its own — every token resolves to the "Ember Forward"
// palette in `PremiumUI`, which is the single source of truth.
//
// Palette: ember leads (identity and action), indigo structures, celadon is
// the quiet third; Sepia and High Contrast are reader modes that deliberately
// depart from the triad. The many names below are kept because ~21 files call
// them; prefer `PremiumUI.ember` / `.indigo` / `.celadon` in new code.
//

struct AnalysisTheme {

    // MARK: - Brand Primary Colors (From OE Logo)

    static let brandOrange = PremiumUI.emberMark
    static let brandOrangeLight = PremiumUI.emberTint
    static let brandOrangeDark = PremiumUI.ember
    static let brandNavy = PremiumUI.indigo
    static let brandNavyLight = PremiumUI.indigoTint
    static let brandNavyDark = PremiumUI.indigoDeep

    // MARK: - Mockup Palette (Terracotta + Warm Neutrals)
    // Adaptive so the warm editorial reading surface has a legible dark-mode
    // counterpart. Light values are the original paper tones; dark values are
    // warm charcoals that keep contrast with the adaptive text colors.

    private static func adaptivePalette(light: String, dark: String) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
    
    // MARK: - Appearance Overrides (High Contrast & Sepia)
    private enum AppearanceKeys {
        static let highContrast = "insight_atlas_high_contrast"
        static let sepiaMode = "insight_atlas_sepia_mode"
    }

    private static var isHighContrast: Bool {
        UserDefaults.standard.bool(forKey: AppearanceKeys.highContrast)
    }

    private static var isSepia: Bool {
        UserDefaults.standard.bool(forKey: AppearanceKeys.sepiaMode)
    }

    static let terracotta = PremiumUI.ember
    static let warmCream = PremiumUI.background
    static let lightTan = PremiumUI.chipFill
    static let warmGray = PremiumUI.card

    // Legacy aliases (deprecated - use brandNavy)
    static let brandBlue = PremiumUI.indigo
    static let brandBlueLight = PremiumUI.indigoTint
    static let brandBlueDark = PremiumUI.indigoDeep

    // MARK: - Reading Surfaces (Modern Clean)

    static let readingBgPrimary = PremiumUI.background
    static let readingBgSecondary = PremiumUI.card
    static let readingBgTertiary = PremiumUI.chipFill
    static let readingBgAccent = PremiumUI.divider

    // MARK: - Legacy Names (Deprecated - use reading surfaces above)

    static let brandSepia = PremiumUI.secondaryText
    static let brandSepiaLight = PremiumUI.secondaryText
    static let brandParchment = PremiumUI.card
    static let brandParchmentDark = PremiumUI.chipFill
    static let brandInk = PremiumUI.ink
    static let brandCream = PremiumUI.emberWash
    static let brandBurgundy = PremiumUI.destructive

    // MARK: - Primary Palette - Primary Orange (Brand Primary)
    // WCAG AAA compliant on white backgrounds

    // Type-safe ember. This token both carries type and fills the primary CTA
    // under a white label, and `emberMark` clears neither (3.17:1 / 3.49:1).
    // `emberMark` is reserved for the mark tokens below (rules, dots, rails).
    static let primaryGold = PremiumUI.ember
    static let primaryGoldText = PremiumUI.ember
    // The lighter-but-still-saturated ember (gradient stops, trend bars, and
    // fills that carry white text) — NOT the pale emberTint wash, which would
    // wash out white text and thin bars. Hex.emberDark is that tone.
    static let primaryGoldLight = Color(hex: PremiumUI.Hex.emberDark)
    static let primaryGoldDark = PremiumUI.emberDeep
    static let primaryGoldSubtle = PremiumUI.emberMark.opacity(0.08)
    static let primaryGoldMuted = PremiumUI.emberMark.opacity(0.15)

    // MARK: - Design System Supporting Palette (v2.0 — matches PremiumUI)
    // Status/section differentiators drawn from the Insight Atlas Design System.
    // These never appear in navigation or primary CTAs — that territory is gold.

    // Library status semantics, shared with `LibraryView`/`LibraryComponents`:
    // new = ember, in progress = celadon, completed = muted. `dsCoral` keeps
    // destructive for the swipe-row delete tint only.
    static let dsCoral = PremiumUI.destructive
    static let dsSkyBlue = PremiumUI.ember         // new
    static let dsForest = PremiumUI.celadon        // in progress
    static let dsWarmOrange = PremiumUI.secondaryText  // completed

    // MARK: - Premium Accent Colors (Modern Minimalistic)

    static let accentPrimary = PremiumUI.ember
    static let accentSuccess = PremiumUI.celadon
    // Both call sites are inline advisory text, so this must be type-safe.
    static let accentHighlight = PremiumUI.ember
    static let accentInfo = PremiumUI.indigo
    // Deep ember, so a caution is distinguishable from ordinary brand chrome.
    static let accentWarning = PremiumUI.emberDeep
    static let accentError = PremiumUI.destructive

    // MARK: - Secondary Palette - Refined Accents

    static let accentOrange = PremiumUI.ember
    static let accentOrangeText = PremiumUI.ember
    static let accentOrangeLight = PremiumUI.emberTint
    static let accentOrangeSubtle = PremiumUI.emberMark.opacity(0.08)

    static let accentNavy = PremiumUI.indigo
    static let accentNavyText = PremiumUI.indigo
    static let accentNavyLight = PremiumUI.indigoTint
    static let accentNavySubtle = PremiumUI.indigo.opacity(0.08)
    static let accentNavyMuted = PremiumUI.indigo.opacity(0.15)

    // Legacy aliases (use accentNavy instead)
    static let accentTeal = PremiumUI.indigo
    static let accentTealText = PremiumUI.indigo
    static let accentTealLight = PremiumUI.indigoTint
    static let accentTealSubtle = PremiumUI.indigo.opacity(0.08)
    static let accentTealMuted = PremiumUI.indigo.opacity(0.15)
    
    // Deprecated - remove these
    static let accentBurgundy = PremiumUI.destructive
    static let accentBurgundyLight = PremiumUI.emberDeep
    static let accentBurgundySubtle = PremiumUI.destructive.opacity(0.08)

    static let accentCoral = PremiumUI.ember
    static let accentCoralText = PremiumUI.ember
    static let accentCoralLight = PremiumUI.emberTint
    static let accentCoralSubtle = PremiumUI.emberMark.opacity(0.08)
    static let accentCoralMuted = PremiumUI.emberMark.opacity(0.15)

    // Additional accent colors for editorial blocks
    static let accentGreen = PremiumUI.celadon
    static let accentBlue = PremiumUI.indigo
    static let accentPurple = PremiumUI.indigoDeep

    // MARK: - Premium Commentary Box Colors (Modern Minimalistic)

    // Insight Note - Uses ember for warm highlights (carries the block title)
    static let insightOrange = PremiumUI.ember
    static let insightOrangeLight = PremiumUI.emberTint
    static let insightBgStart = PremiumUI.card
    static let insightBgMid = PremiumUI.emberWash
    static let insightBgEnd = PremiumUI.emberTint

    // Alternative Perspective - Uses Navy Blue for balanced info
    static let perspectiveTeal = PremiumUI.indigo
    static let perspectiveTealDark = PremiumUI.indigoDeep
    static let perspectiveBgStart = PremiumUI.card
    static let perspectiveBgMid = PremiumUI.indigoWash
    static let perspectiveBgEnd = PremiumUI.indigoTint

    // Research Insight - Uses Success Green for scholarly feel
    static let researchSage = PremiumUI.celadon
    // Used as TEXT (author highlights) on light wash backgrounds, so it must
    // stay contrast-safe — celadonDeep, not the near-invisible celadonTint.
    static let researchSageLight = PremiumUI.celadonDeep
    static let researchBgStart = PremiumUI.card
    static let researchBgMid = PremiumUI.celadonWash
    static let researchBgEnd = PremiumUI.celadonTint

    // MARK: - Premium Quote Card Colors (Clean Modern)

    static let parchmentBase = PremiumUI.background
    static let parchmentMid = PremiumUI.card
    static let parchmentDark = PremiumUI.chipFill
    static let parchmentVignette = PremiumUI.secondaryText
    static let goldOrnament = PremiumUI.emberMark
    static let goldTitle = PremiumUI.ember
    static let coralAuthor = PremiumUI.indigo
    static let inkMuted = PremiumUI.secondaryText

    // MARK: - Premium Frame Colors (Layered Card Design)

    // Layer 1: Outer primary orange gradient
    static let goldFrameOuter = PremiumUI.emberMark
    static let goldFrameOuterMid = PremiumUI.ember
    static let goldFrameOuterDark = PremiumUI.emberDeep

    // Layer 2: Inner lighter orange gradient (pale → light-saturated → primary
    // ramp, mirroring the original Orange 200 → 400 → primary frame)
    static let goldFrameInnerLight = PremiumUI.emberTint
    static let goldFrameInnerMid = Color(hex: PremiumUI.Hex.emberDark)
    static let goldFrameInnerDark = PremiumUI.emberMark

    // Layer 3: White gap
    static let goldFrameCreamLight = PremiumUI.emberWash   // subtle gold parchment
    static let goldFrameCreamMid = PremiumUI.emberWash
    static let goldFrameCreamDark = PremiumUI.emberTint

    // Layer 4: Orange pinstripe
    static let goldPinstripeLight = PremiumUI.emberTint
    static let goldPinstripeDark = PremiumUI.emberMark

    // Outer card gradient (Clean surfaces)
    static let outerCardTop = PremiumUI.background
    static let outerCardMid = PremiumUI.card
    static let outerCardBottom = PremiumUI.chipFill
    static let cardBackdrop = PremiumUI.divider

    // MARK: - Text Colors (Adaptive Light/Dark with Fallbacks)

    /// Primary text - adapts to light/dark mode
    static var textHeading: Color {
        if isSepia { return PremiumUI.Sepia.text }
        if isHighContrast { return PremiumUI.HighContrast.heading }
        return PremiumUI.ink
    }

    static var textBody: Color {
        if isSepia { return PremiumUI.Sepia.text }
        if isHighContrast { return PremiumUI.HighContrast.body }
        return PremiumUI.ink
    }

    static var textMuted: Color {
        if isSepia { return PremiumUI.Sepia.muted }
        if isHighContrast { return PremiumUI.HighContrast.muted }
        return PremiumUI.secondaryText
    }
    static let textSubtle = PremiumUI.secondaryText
    static let textInverse = PremiumUI.card
    static let textHandwritten = PremiumUI.indigo

    // MARK: - Background Colors (Adaptive Light/Dark with Fallbacks)

    /// Primary background - White in light mode, Navy 900 in dark mode
    static var bgPrimary: Color {
        if isSepia { return PremiumUI.Sepia.bg }
        return PremiumUI.background
    }
    /// Secondary background
    static var bgSecondary: Color {
        if isSepia { return PremiumUI.Sepia.surface }
        return PremiumUI.card
    }
    /// Warm "parchment" canvas — a distinctly cream/tan surface (not white, not
    /// grey) so pure-white cards lift off it. Used as the Library's primary surface.
    static var paper: Color {
        if isSepia { return PremiumUI.Sepia.sunken }
        return PremiumUI.chipFill
    }
    /// Card background
    static var bgCard: Color {
        if isSepia { return PremiumUI.Sepia.card }
        return PremiumUI.card
    }
    /// Elevated surface
    static let bgElevated = PremiumUI.card

    // MARK: - Border Colors (Adaptive Light/Dark with Fallbacks)

    static let borderLight = PremiumUI.divider
    static let borderMedium = PremiumUI.dividerStrong
    static let borderDark = PremiumUI.secondaryText

    // MARK: - Fallback Static Colors (for non-adaptive contexts)
    //
    // These are FIXED values, not adaptive: `Light` members stay light-palette
    // in dark mode and vice versa. Views that draw on an always-light surface
    // (e.g. a box filled with `Color.white`) use `Light` so their text stays
    // dark in dark mode. Pinned to `PremiumUI.Hex` so values cannot drift from
    // the palette.

    struct Light {
        static let textHeading = Color(hex: PremiumUI.Hex.inkLight)
        static let textBody = Color(hex: PremiumUI.Hex.inkLight)
        static let textMuted = Color(hex: PremiumUI.Hex.mutedLight)
        static let textSubtle = Color(hex: PremiumUI.Hex.mutedLight)
        static let bgPrimary = Color(hex: PremiumUI.Hex.backgroundLight)
        static let bgSecondary = Color(hex: PremiumUI.Hex.cardLight)
        static let bgCard = Color(hex: PremiumUI.Hex.cardLight)
        static let borderLight = Color(hex: PremiumUI.Hex.dividerLight)
        static let borderMedium = Color(hex: PremiumUI.Hex.dividerStrongLight)
    }

    struct Dark {
        static let textHeading = Color(hex: PremiumUI.Hex.inkDark)
        static let textBody = Color(hex: PremiumUI.Hex.inkDark)
        static let textMuted = Color(hex: PremiumUI.Hex.mutedDark)
        static let textSubtle = Color(hex: PremiumUI.Hex.mutedDark)
        static let bgPrimary = Color(hex: PremiumUI.Hex.backgroundDark)
        static let bgSecondary = Color(hex: PremiumUI.Hex.cardDark)
        static let bgCard = Color(hex: PremiumUI.Hex.cardDark)
        static let borderLight = Color(hex: PremiumUI.Hex.dividerDark)
        static let borderMedium = Color(hex: PremiumUI.Hex.dividerStrongDark)
    }

    // MARK: - Spacing

    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let base: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xl2: CGFloat = 32
        static let xl3: CGFloat = 40
        static let xl4: CGFloat = 48
        static let xl5: CGFloat = 64
    }

    // MARK: - Corner Radius

    struct Radius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let full: CGFloat = 9999
    }

    // MARK: - Shadows

    static let shadowCard = Color.black.opacity(0.06)
    static let shadowCardHover = Color.black.opacity(0.1)
}

// MARK: - Typography Extensions

extension Font {
    // Display fonts (Cormorant Garamond) - with fallbacks
    static func analysisDisplayTitle() -> Font {
        if UIFont(name: "CormorantGaramond-Bold", size: 34) != nil {
            return .custom("CormorantGaramond-Bold", size: 34, relativeTo: .largeTitle)
        }
        return .system(size: 34, weight: .bold, design: .serif)
    }

    static func analysisDisplayH1() -> Font {
        if UIFont(name: "CormorantGaramond-Bold", size: 30) != nil {
            return .custom("CormorantGaramond-Bold", size: 30, relativeTo: .title)
        }
        return .system(size: 30, weight: .bold, design: .serif)
    }

    static func analysisDisplayH2() -> Font {
        if UIFont(name: "CormorantGaramond-SemiBold", size: 28) != nil {
            return .custom("CormorantGaramond-SemiBold", size: 28, relativeTo: .title)
        }
        return .system(size: 28, weight: .semibold, design: .serif)
    }

    static func analysisDisplayH3() -> Font {
        if UIFont(name: "CormorantGaramond-SemiBold", size: 22) != nil {
            return .custom("CormorantGaramond-SemiBold", size: 22, relativeTo: .title2)
        }
        return .system(size: 22, weight: .semibold, design: .serif)
    }

    static func analysisDisplayH4() -> Font {
        if UIFont(name: "CormorantGaramond-Medium", size: 19) != nil {
            return .custom("CormorantGaramond-Medium", size: 19, relativeTo: .title3)
        }
        return .system(size: 19, weight: .medium, design: .serif)
    }

    // Body fonts (Cormorant Garamond for reading)
    static func analysisBody() -> Font {
        if UIFont(name: "CormorantGaramond-Regular", size: 17) != nil {
            return .custom("CormorantGaramond-Regular", size: 17, relativeTo: .body)
        }
        return .system(size: 17, design: .serif)
    }

    /// Bold run inside body prose. Stays in the serif family so inline
    /// `**emphasis**` does not drop into the system sans face mid-sentence.
    static func analysisBodyBold() -> Font {
        if UIFont(name: "CormorantGaramond-Bold", size: 17) != nil {
            return .custom("CormorantGaramond-Bold", size: 17, relativeTo: .body)
        }
        return .system(size: 17, weight: .bold, design: .serif)
    }

    /// Italic run inside body prose; same family rule as `analysisBodyBold`.
    static func analysisBodyItalic() -> Font {
        if UIFont(name: "CormorantGaramond-Italic", size: 17) != nil {
            return .custom("CormorantGaramond-Italic", size: 17, relativeTo: .body)
        }
        return .system(size: 17, design: .serif).italic()
    }

    static func analysisBodyLarge() -> Font {
        if UIFont(name: "CormorantGaramond-Regular", size: 19) != nil {
            return .custom("CormorantGaramond-Regular", size: 19, relativeTo: .body)
        }
        return .system(size: 19, design: .serif)
    }

    static func analysisBodySmall() -> Font {
        if UIFont(name: "CormorantGaramond-Regular", size: 15) != nil {
            return .custom("CormorantGaramond-Regular", size: 15, relativeTo: .subheadline)
        }
        return .system(size: 15, design: .serif)
    }

    // UI fonts (Inter for labels and UI elements)
    static func analysisUI() -> Font {
        if UIFont(name: "Inter-Regular", size: 15) != nil {
            return .custom("Inter-Regular", size: 15, relativeTo: .subheadline)
        }
        return .system(size: 15)
    }

    static func analysisUIBold() -> Font {
        if UIFont(name: "Inter-SemiBold", size: 15) != nil {
            return .custom("Inter-SemiBold", size: 15, relativeTo: .subheadline)
        }
        return .system(size: 15, weight: .semibold)
    }

    static func analysisUISmall() -> Font {
        if UIFont(name: "Inter-Regular", size: 13) != nil {
            return .custom("Inter-Regular", size: 13, relativeTo: .footnote)
        }
        return .system(size: 13)
    }

    // Handwritten accent (Caveat)
    static func analysisHandwritten() -> Font {
        if UIFont(name: "Caveat-Regular", size: 22) != nil {
            return .custom("Caveat-Regular", size: 22, relativeTo: .title2)
        }
        return .system(size: 22, design: .rounded)
    }

    static func analysisHandwrittenBold() -> Font {
        if UIFont(name: "Caveat-SemiBold", size: 22) != nil {
            return .custom("Caveat-SemiBold", size: 22)
        }
        return .system(size: 22, weight: .semibold, design: .rounded)
    }
}

// MARK: - View Modifiers

struct AnalysisCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AnalysisTheme.Spacing.base)
            .background(AnalysisTheme.bgCard)
            .cornerRadius(AnalysisTheme.Radius.lg)
            .shadow(color: AnalysisTheme.shadowCard, radius: 8, x: 0, y: 2)
    }
}

struct AnalysisBlockHeaderStyle: ViewModifier {
    let accentColor: Color

    func body(content: Content) -> some View {
        content
            .font(.analysisUIBold())
            .foregroundColor(AnalysisTheme.textHeading)
            .padding(.bottom, AnalysisTheme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 4)
                    .offset(x: -AnalysisTheme.Spacing.base)
            }
    }
}

extension View {
    func analysisCard() -> some View {
        modifier(AnalysisCardStyle())
    }

    func analysisBlockHeader(accentColor: Color = AnalysisTheme.primaryGold) -> some View {
        modifier(AnalysisBlockHeaderStyle(accentColor: accentColor))
    }

    /// Primary call-to-action: Metallic Gold capsule with white label and a
    /// gold elevation shadow (Design System §Primary Button).
    func analysisPrimaryCTA() -> some View {
        modifier(AnalysisPrimaryCTAStyle())
    }

    /// Secondary call-to-action: gold "ghost" capsule (12% gold fill, gold
    /// label) for the subordinate action in a pair.
    func analysisSecondaryCTA() -> some View {
        modifier(AnalysisSecondaryCTAStyle())
    }
}

// MARK: - Call-to-Action Button Styles (Design System v2.0)

/// Gold capsule primary CTA. Apply to the button's label content — it owns the
/// full-width sizing, vertical padding, fill, capsule shape, and shadow so the
/// icon's own font size is preserved.
struct AnalysisPrimaryCTAStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundColor(.white)
            .background(AnalysisTheme.primaryGold)
            .clipShape(Capsule())
            .shadow(color: AnalysisTheme.primaryGold.opacity(0.25), radius: 12, y: 4)
    }
}

/// Gold-ghost secondary CTA — quiet counterpart to the primary capsule.
struct AnalysisSecondaryCTAStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundColor(AnalysisTheme.primaryGold)
            .background(AnalysisTheme.primaryGold.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Markdown Helper

/// Parses inline markdown (bold, italic) into AttributedString for display
func parseMarkdownInline(_ text: String) -> AttributedString {
    do {
        var attributedString = try AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )
        // Apply custom font styling
        for run in attributedString.runs {
            if run.attributes.inlinePresentationIntent?.contains(.stronglyEmphasized) == true {
                attributedString[run.range].font = UIFont(name: "CormorantGaramond-Bold", size: 17) ?? UIFont.boldSystemFont(ofSize: 17)
            } else if run.attributes.inlinePresentationIntent?.contains(.emphasized) == true {
                attributedString[run.range].font = UIFont(name: "CormorantGaramond-Italic", size: 17) ?? UIFont.italicSystemFont(ofSize: 17)
            }
        }
        return attributedString
    } catch {
        return AttributedString(text)
    }
}

/// Parse markdown with explicit foreground color applied
/// Use this when rendering text in boxes with non-adaptive backgrounds
func parseMarkdownInline(_ text: String, foregroundColor: Color) -> AttributedString {
    do {
        var attributedString = try AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )
        // Apply foreground color to entire string first
        attributedString.foregroundColor = foregroundColor

        // Apply custom font styling (preserving the foreground color)
        for run in attributedString.runs {
            if run.attributes.inlinePresentationIntent?.contains(.stronglyEmphasized) == true {
                attributedString[run.range].font = UIFont(name: "CormorantGaramond-Bold", size: 17) ?? UIFont.boldSystemFont(ofSize: 17)
            } else if run.attributes.inlinePresentationIntent?.contains(.emphasized) == true {
                attributedString[run.range].font = UIFont(name: "CormorantGaramond-Italic", size: 17) ?? UIFont.italicSystemFont(ofSize: 17)
            }
        }
        return attributedString
    } catch {
        var fallback = AttributedString(text)
        fallback.foregroundColor = foregroundColor
        return fallback
    }
}
// MARK: - Color Hex Extension

extension Color {
    /// Initialize Color from hex string (e.g., "#D35F2E" or "D35F2E")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Convert Color to hex string
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX",
                      lroundf(r * 255),
                      lroundf(g * 255),
                      lroundf(b * 255))
    }
}


// MARK: - Premium CTA View Modifiers

extension View {
    /// Ember primary CTA using PremiumUI tokens.
    ///
    /// A solid fill, not a gradient: `gold` and `goldDark` both resolve to
    /// ember, so the two stops were identical. White on ember is 5.10:1.
    func premiumPrimaryCTA() -> some View {
        self
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(PremiumUI.ember)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }

    /// Ghost capsule secondary CTA using PremiumUI tokens.
    func premiumSecondaryCTA() -> some View {
        self
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(PremiumUI.gold)
            .background(PremiumUI.gold.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(PremiumUI.gold.opacity(0.30), lineWidth: 1))
    }
}
