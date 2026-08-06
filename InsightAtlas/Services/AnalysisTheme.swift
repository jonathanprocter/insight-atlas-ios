import SwiftUI

// MARK: - Insight Atlas Analysis Theme
// Modern Minimalistic Color System - Based on OE Brand Identity
//
// Design Philosophy:
// - Burnt Orange (#D35F2E) as primary action/accent color - warm, energetic, distinctive
// - Deep Steel Blue (#3B5E7A) as secondary accent - professional, trustworthy, balanced
// - Deep Burgundy (#7B2D3E) for premium/emphasis - sophisticated, rich
// - Warm cream surfaces for comfortable reading
// - High contrast (>10:1) for extended reading comfort
// - Complementary color theory: Orange ↔ Blue creates visual interest
// - Analogous warmth: Orange → Burgundy creates cohesive premium feel
//

struct AnalysisTheme {

    // MARK: - Brand Primary Colors (From OE Logo)

    static let brandOrange = Color(hex: "#D3AF37")           // Primary Orange - Primary brand
    static let brandOrangeLight = Color(hex: "#E0C04A")      // Orange 400
    static let brandOrangeDark = Color(hex: "#B8962E")       // Orange 700
    static let brandNavy = Color(hex: "#2E5A7D")             // Navy Blue - Secondary brand
    static let brandNavyLight = Color(hex: "#4A7A9D")        // Navy 400
    static let brandNavyDark = Color(hex: "#1E3D54")         // Navy 700

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

    static let terracotta = adaptivePalette(light: "#CC9966", dark: "#D9A876")
    static let warmCream = adaptivePalette(light: "#FAFCFD", dark: "#24262A")
    static let lightTan = adaptivePalette(light: "#E7EAEE", dark: "#2E3237")
    static let warmGray = adaptivePalette(light: "#F2F4F1", dark: "#1E2022")

    // Legacy aliases (deprecated - use brandNavy)
    static let brandBlue = Color(hex: "#2E5A7D")             // Navy Blue - Secondary brand
    static let brandBlueLight = Color(hex: "#4A7A9D")        // Lighter Navy
    static let brandBlueDark = Color(hex: "#1E3D54")         // Darker Navy

    // MARK: - Reading Surfaces (Modern Clean)

    static let readingBgPrimary = Color(hex: "#FFFFFF")      // Pure White - Modern & Clean
    static let readingBgSecondary = Color(hex: "#F9FAFB")    // Gray 50
    static let readingBgTertiary = Color(hex: "#F3F4F6")     // Gray 100
    static let readingBgAccent = Color(hex: "#E5E7EB")       // Gray 200

    // MARK: - Legacy Names (Deprecated - use reading surfaces above)

    static let brandSepia = Color(hex: "#4B5563")            // Gray 600
    static let brandSepiaLight = Color(hex: "#6B7280")       // Gray 500
    static let brandParchment = Color(hex: "#F9FAFB")        // Gray 50
    static let brandParchmentDark = Color(hex: "#F3F4F6")    // Gray 100
    static let brandInk = Color(hex: "#111827")              // Gray 900
    static let brandCream = Color(hex: "#FEF0EB")            // Orange 50
    static let brandBurgundy = Color(hex: "#DC2626")         // Error red (repurposed)

    // MARK: - Primary Palette - Primary Orange (Brand Primary)
    // WCAG AAA compliant on white backgrounds

    static let primaryGold = Color(hex: "#D3AF37")           // Primary Orange - Primary accent
    static let primaryGoldText = Color(hex: "#B8962E")       // Orange 700 for text compliance
    static let primaryGoldLight = Color(hex: "#E0C04A")      // Orange 400
    static let primaryGoldDark = Color(hex: "#B8962E")       // Orange 600
    static let primaryGoldSubtle = Color(hex: "#D3AF37").opacity(0.08)
    static let primaryGoldMuted = Color(hex: "#D3AF37").opacity(0.15)

    // MARK: - Design System Supporting Palette (v2.0 — matches PremiumUI)
    // Status/section differentiators drawn from the Insight Atlas Design System.
    // These never appear in navigation or primary CTAs — that territory is gold.

    static let dsCoral = Color(hex: "#E8553A")               // Destructive / alerts
    static let dsSkyBlue = Color(hex: "#4BA3C8")             // New / informational
    static let dsForest = Color(hex: "#3D5840")              // Completed / success
    static let dsWarmOrange = Color(hex: "#D87520")          // In-progress / active

    // MARK: - Premium Accent Colors (Modern Minimalistic)

    static let accentPrimary = Color(hex: "#D3AF37")         // Primary Orange - Primary CTAs
    static let accentSuccess = Color(hex: "#059669")         // Success green
    static let accentHighlight = Color(hex: "#D3AF37")       // Primary Orange - Highlights
    static let accentInfo = Color(hex: "#2E5A7D")            // Navy Blue - Information
    static let accentWarning = Color(hex: "#D97706")         // Warning
    static let accentError = Color(hex: "#DC2626")           // Error

    // MARK: - Secondary Palette - Refined Accents

    static let accentOrange = Color(hex: "#D3AF37")          // Primary Orange
    static let accentOrangeText = Color(hex: "#B8962E")      // Orange 700 for text
    static let accentOrangeLight = Color(hex: "#E0C04A")     // Orange 400
    static let accentOrangeSubtle = Color(hex: "#D3AF37").opacity(0.08)

    static let accentNavy = Color(hex: "#2E5A7D")            // Navy Blue (secondary brand)
    static let accentNavyText = Color(hex: "#2E5A7D")        // Same - already compliant
    static let accentNavyLight = Color(hex: "#4A7A9D")       // Navy 400
    static let accentNavySubtle = Color(hex: "#2E5A7D").opacity(0.08)
    static let accentNavyMuted = Color(hex: "#2E5A7D").opacity(0.15)

    // Legacy aliases (use accentNavy instead)
    static let accentTeal = Color(hex: "#2E5A7D")            // Navy Blue (was teal)
    static let accentTealText = Color(hex: "#2E5A7D")
    static let accentTealLight = Color(hex: "#4A7A9D")
    static let accentTealSubtle = Color(hex: "#2E5A7D").opacity(0.08)
    static let accentTealMuted = Color(hex: "#2E5A7D").opacity(0.15)
    
    // Deprecated - remove these
    static let accentBurgundy = Color(hex: "#7B2D3E")        // Deprecated
    static let accentBurgundyLight = Color(hex: "#9A4458")   // Deprecated
    static let accentBurgundySubtle = Color(hex: "#7B2D3E").opacity(0.08)

    static let accentCoral = Color(hex: "#D3AF37")           // Use accentOrange instead
    static let accentCoralText = Color(hex: "#B8962E")       // Use accentOrangeText instead
    static let accentCoralLight = Color(hex: "#E0C04A")      // Use accentOrangeLight instead
    static let accentCoralSubtle = Color(hex: "#D3AF37").opacity(0.08)
    static let accentCoralMuted = Color(hex: "#D3AF37").opacity(0.15)

    // Additional accent colors for editorial blocks
    static let accentGreen = Color(hex: "#059669")           // Success green for action boxes
    static let accentBlue = Color(hex: "#2563EB")            // Blue for flowcharts/diagrams
    static let accentPurple = Color(hex: "#7C3AED")          // Purple for alternative perspectives

    // MARK: - Premium Commentary Box Colors (Modern Minimalistic)

    // Insight Note - Uses Primary Orange for warm highlights
    static let insightOrange = Color(hex: "#D3AF37")         // Primary Orange
    static let insightOrangeLight = Color(hex: "#E0C04A")    // Orange 400
    static let insightBgStart = Color(hex: "#FFFFFF")        // White
    static let insightBgMid = Color(hex: "#FEF0EB")          // Orange 50
    static let insightBgEnd = Color(hex: "#FCD4C4")          // Orange 100

    // Alternative Perspective - Uses Navy Blue for balanced info
    static let perspectiveTeal = Color(hex: "#2E5A7D")       // Navy Blue
    static let perspectiveTealDark = Color(hex: "#1E3D54")   // Navy 700
    static let perspectiveBgStart = Color(hex: "#FFFFFF")    // White
    static let perspectiveBgMid = Color(hex: "#EBF3F7")      // Navy 50
    static let perspectiveBgEnd = Color(hex: "#C9DEE9")      // Navy 100

    // Research Insight - Uses Success Green for scholarly feel
    static let researchSage = Color(hex: "#059669")          // Success Green
    static let researchSageLight = Color(hex: "#34D399")     // Success Green (dark mode)
    static let researchBgStart = Color(hex: "#FFFFFF")       // White
    static let researchBgMid = Color(hex: "#F0FDF4")         // Green tint
    static let researchBgEnd = Color(hex: "#D1FAE5")         // Green wash

    // MARK: - Premium Quote Card Colors (Clean Modern)

    static let parchmentBase = adaptivePalette(light: "#FAFCFD", dark: "#24262A")
    static let parchmentMid = Color(hex: "#F9FAFB")          // Gray 50
    static let parchmentDark = Color(hex: "#F3F4F6")         // Gray 100
    static let parchmentVignette = Color(hex: "#4B5563")     // Gray 600
    static let goldOrnament = Color(hex: "#D3AF37")          // Primary Orange
    static let goldTitle = Color(hex: "#D3AF37")             // Primary Orange
    static let coralAuthor = Color(hex: "#2E5A7D")           // Navy Blue
    static let inkMuted = Color(hex: "#4B5563")              // Gray 600

    // MARK: - Premium Frame Colors (Layered Card Design)

    // Layer 1: Outer primary orange gradient
    static let goldFrameOuter = Color(hex: "#D3AF37")        // Primary Orange
    static let goldFrameOuterMid = Color(hex: "#B8962E")     // Orange 600
    static let goldFrameOuterDark = Color(hex: "#B8962E")    // Orange 700

    // Layer 2: Inner lighter orange gradient
    static let goldFrameInnerLight = Color(hex: "#FAAB8D")   // Orange 200
    static let goldFrameInnerMid = Color(hex: "#E0C04A")     // Orange 400
    static let goldFrameInnerDark = Color(hex: "#D3AF37")    // Primary Orange

    // Layer 3: White gap
    static let goldFrameCreamLight = adaptivePalette(light: "#FCFAF2", dark: "#26241C")   // subtle gold parchment
    static let goldFrameCreamMid = adaptivePalette(light: "#F7F0DE", dark: "#2C2820")
    static let goldFrameCreamDark = adaptivePalette(light: "#F0E7CE", dark: "#332E1F")

    // Layer 4: Orange pinstripe
    static let goldPinstripeLight = Color(hex: "#E0C04A")    // Orange 400
    static let goldPinstripeDark = Color(hex: "#D3AF37")     // Primary Orange

    // Outer card gradient (Clean surfaces)
    static let outerCardTop = Color(hex: "#FFFFFF")          // Pure White
    static let outerCardMid = Color(hex: "#F9FAFB")          // Gray 50
    static let outerCardBottom = Color(hex: "#F3F4F6")       // Gray 100
    static let cardBackdrop = Color(hex: "#E5E7EB")          // Gray 200

    // MARK: - Text Colors (Adaptive Light/Dark with Fallbacks)

    /// Primary text - adapts to light/dark mode
    static var textHeading: Color {
        if isSepia { return Color(hex: "#2A2725") }
        if isHighContrast { return adaptivePalette(light: "#0C0D0E", dark: "#FFFFFF") }
        return adaptivePalette(light: "#111827", dark: "#F5F7FA")
    }

    static var textBody: Color {
        if isSepia { return Color(hex: "#2A2725") }
        if isHighContrast { return adaptivePalette(light: "#1A1C1E", dark: "#F2F4F8") }
        return adaptivePalette(light: "#1F2937", dark: "#E6EAEE")
    }

    static var textMuted: Color {
        if isSepia { return Color(hex: "#8A8580") }
        if isHighContrast { return adaptivePalette(light: "#4A4F55", dark: "#DEE3E8") }
        return adaptivePalette(light: "#6B7280", dark: "#C7CDD3")
    }
    static let textSubtle = Color(UIColor(named: "TextSubtle") ?? UIColor(hex: "#9CA3AF"))
    static let textInverse = Color(hex: "#FFFFFF")           // White (always)
    static let textHandwritten = Color(hex: "#2E5A7D")       // Navy Blue

    // MARK: - Background Colors (Adaptive Light/Dark with Fallbacks)

    /// Primary background - White in light mode, Navy 900 in dark mode
    static var bgPrimary: Color {
        if isSepia { return adaptivePalette(light: "#FAFAF8", dark: "#1E1B16") }
        return adaptivePalette(light: "#F3F4F1", dark: "#111315")
    }
    /// Secondary background
    static var bgSecondary: Color {
        if isSepia { return adaptivePalette(light: "#F5F0E8", dark: "#221F19") }
        return adaptivePalette(light: "#ECEFF2", dark: "#16191D")
    }
    /// Card background
    static var bgCard: Color {
        if isSepia { return adaptivePalette(light: "#FFFFFF", dark: "#2A251E") }
        return adaptivePalette(light: "#FAFCFD", dark: "#171A1D")
    }
    /// Elevated surface
    static let bgElevated = adaptivePalette(light: "#FFFFFF", dark: "#2A2D31")

    // MARK: - Border Colors (Adaptive Light/Dark with Fallbacks)

    static let borderLight = Color(UIColor(named: "BorderLight") ?? UIColor(hex: "#E5E7EB"))
    static let borderMedium = Color(UIColor(named: "BorderMedium") ?? UIColor(hex: "#D1D5DB"))
    static let borderDark = Color(UIColor(named: "BorderDark") ?? UIColor(hex: "#9CA3AF"))

    // MARK: - Fallback Static Colors (for non-adaptive contexts)

    struct Light {
        static let textHeading = Color(hex: "#111827")       // Gray 900
        static let textBody = Color(hex: "#1F2937")          // Gray 800
        static let textMuted = Color(hex: "#6B7280")         // Gray 500
        static let textSubtle = Color(hex: "#9CA3AF")        // Gray 400
        static let bgPrimary = Color(hex: "#FFFFFF")         // White
        static let bgSecondary = Color(hex: "#F9FAFB")       // Gray 50
        static let bgCard = Color(hex: "#FFFFFF")            // White
        static let borderLight = Color(hex: "#E5E7EB")       // Gray 200
        static let borderMedium = Color(hex: "#D1D5DB")      // Gray 300
    }

    struct Dark {
        static let textHeading = Color(hex: "#FFFFFF")       // White
        static let textBody = Color(hex: "#C9DEE9")          // Navy 100
        static let textMuted = Color(hex: "#9DC0D6")         // Navy 200
        static let textSubtle = Color(hex: "#6B9AB8")        // Navy 300
        static let bgPrimary = Color(hex: "#0F1E2A")         // Navy 900
        static let bgSecondary = Color(hex: "#162B3D")       // Navy 800
        static let bgCard = Color(hex: "#1E3D54")            // Navy 700
        static let borderLight = Color(hex: "#254A66")       // Navy 600
        static let borderMedium = Color(hex: "#4A7A9D")      // Navy 400
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

