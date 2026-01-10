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

    static let brandOrange = Color(hex: "#E85D2D")           // Primary Orange - Primary brand
    static let brandOrangeLight = Color(hex: "#F07348")      // Orange 400
    static let brandOrangeDark = Color(hex: "#C74A1F")       // Orange 700
    static let brandNavy = Color(hex: "#2E5A7D")             // Navy Blue - Secondary brand
    static let brandNavyLight = Color(hex: "#4A7A9D")        // Navy 400
    static let brandNavyDark = Color(hex: "#1E3D54")         // Navy 700
    
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

    static let primaryGold = Color(hex: "#E85D2D")           // Primary Orange - Primary accent
    static let primaryGoldText = Color(hex: "#C74A1F")       // Orange 700 for text compliance
    static let primaryGoldLight = Color(hex: "#F07348")      // Orange 400
    static let primaryGoldDark = Color(hex: "#D85426")       // Orange 600
    static let primaryGoldSubtle = Color(hex: "#E85D2D").opacity(0.08)
    static let primaryGoldMuted = Color(hex: "#E85D2D").opacity(0.15)

    // MARK: - Premium Accent Colors (Modern Minimalistic)

    static let accentPrimary = Color(hex: "#E85D2D")         // Primary Orange - Primary CTAs
    static let accentSuccess = Color(hex: "#059669")         // Success green
    static let accentHighlight = Color(hex: "#E85D2D")       // Primary Orange - Highlights
    static let accentInfo = Color(hex: "#2E5A7D")            // Navy Blue - Information
    static let accentWarning = Color(hex: "#D97706")         // Warning
    static let accentError = Color(hex: "#DC2626")           // Error

    // MARK: - Secondary Palette - Refined Accents

    static let accentOrange = Color(hex: "#E85D2D")          // Primary Orange
    static let accentOrangeText = Color(hex: "#C74A1F")      // Orange 700 for text
    static let accentOrangeLight = Color(hex: "#F07348")     // Orange 400
    static let accentOrangeSubtle = Color(hex: "#E85D2D").opacity(0.08)

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

    static let accentCoral = Color(hex: "#E85D2D")           // Use accentOrange instead
    static let accentCoralText = Color(hex: "#C74A1F")       // Use accentOrangeText instead
    static let accentCoralLight = Color(hex: "#F07348")      // Use accentOrangeLight instead
    static let accentCoralSubtle = Color(hex: "#E85D2D").opacity(0.08)
    static let accentCoralMuted = Color(hex: "#E85D2D").opacity(0.15)

    // MARK: - Premium Commentary Box Colors (Modern Minimalistic)

    // Insight Note - Uses Primary Orange for warm highlights
    static let insightOrange = Color(hex: "#E85D2D")         // Primary Orange
    static let insightOrangeLight = Color(hex: "#F07348")    // Orange 400
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

    static let parchmentBase = Color(hex: "#FFFFFF")         // Pure White
    static let parchmentMid = Color(hex: "#F9FAFB")          // Gray 50
    static let parchmentDark = Color(hex: "#F3F4F6")         // Gray 100
    static let parchmentVignette = Color(hex: "#4B5563")     // Gray 600
    static let goldOrnament = Color(hex: "#E85D2D")          // Primary Orange
    static let goldTitle = Color(hex: "#E85D2D")             // Primary Orange
    static let coralAuthor = Color(hex: "#2E5A7D")           // Navy Blue
    static let inkMuted = Color(hex: "#4B5563")              // Gray 600

    // MARK: - Premium Frame Colors (Layered Card Design)

    // Layer 1: Outer primary orange gradient
    static let goldFrameOuter = Color(hex: "#E85D2D")        // Primary Orange
    static let goldFrameOuterMid = Color(hex: "#D85426")     // Orange 600
    static let goldFrameOuterDark = Color(hex: "#C74A1F")    // Orange 700

    // Layer 2: Inner lighter orange gradient
    static let goldFrameInnerLight = Color(hex: "#FAAB8D")   // Orange 200
    static let goldFrameInnerMid = Color(hex: "#F07348")     // Orange 400
    static let goldFrameInnerDark = Color(hex: "#E85D2D")    // Primary Orange

    // Layer 3: White gap
    static let goldFrameCreamLight = Color(hex: "#FFFFFF")   // White
    static let goldFrameCreamMid = Color(hex: "#FEF0EB")     // Orange 50
    static let goldFrameCreamDark = Color(hex: "#FCD4C4")    // Orange 100

    // Layer 4: Orange pinstripe
    static let goldPinstripeLight = Color(hex: "#F07348")    // Orange 400
    static let goldPinstripeDark = Color(hex: "#E85D2D")     // Primary Orange

    // Outer card gradient (Clean surfaces)
    static let outerCardTop = Color(hex: "#FFFFFF")          // Pure White
    static let outerCardMid = Color(hex: "#F9FAFB")          // Gray 50
    static let outerCardBottom = Color(hex: "#F3F4F6")       // Gray 100
    static let cardBackdrop = Color(hex: "#E5E7EB")          // Gray 200

    // MARK: - Text Colors (Adaptive Light/Dark with Fallbacks)

    /// Primary text - adapts to light/dark mode
    static let textHeading = Color(UIColor(named: "TextHeading") ?? UIColor(hex: "#111827"))
    static let textBody = Color(UIColor(named: "TextBody") ?? UIColor(hex: "#1F2937"))
    static let textMuted = Color(UIColor(named: "TextMuted") ?? UIColor(hex: "#6B7280"))
    static let textSubtle = Color(UIColor(named: "TextSubtle") ?? UIColor(hex: "#9CA3AF"))
    static let textInverse = Color(hex: "#FFFFFF")           // White (always)
    static let textHandwritten = Color(hex: "#2E5A7D")       // Navy Blue

    // MARK: - Background Colors (Adaptive Light/Dark with Fallbacks)

    /// Primary background - White in light mode, Navy 900 in dark mode
    static let bgPrimary = Color(UIColor(named: "BgPrimary") ?? UIColor(hex: "#FFFFFF"))
    /// Secondary background - Gray 50 in light mode, Navy 800 in dark mode
    static let bgSecondary = Color(UIColor(named: "BgSecondary") ?? UIColor(hex: "#F9FAFB"))
    /// Card background - White in light mode, Navy 700 in dark mode
    static let bgCard = Color(UIColor(named: "BgCard") ?? UIColor(hex: "#FFFFFF"))
    /// Elevated surface - White in light mode, Navy 600 in dark mode
    static let bgElevated = Color(UIColor(named: "BgElevated") ?? UIColor(hex: "#FFFFFF"))

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
            return .custom("CormorantGaramond-Bold", size: 34)
        }
        return .system(size: 34, weight: .bold, design: .serif)
    }

    static func analysisDisplayH1() -> Font {
        if UIFont(name: "CormorantGaramond-Bold", size: 30) != nil {
            return .custom("CormorantGaramond-Bold", size: 30)
        }
        return .system(size: 30, weight: .bold, design: .serif)
    }

    static func analysisDisplayH2() -> Font {
        if UIFont(name: "CormorantGaramond-SemiBold", size: 28) != nil {
            return .custom("CormorantGaramond-SemiBold", size: 28)
        }
        return .system(size: 28, weight: .semibold, design: .serif)
    }

    static func analysisDisplayH3() -> Font {
        if UIFont(name: "CormorantGaramond-SemiBold", size: 22) != nil {
            return .custom("CormorantGaramond-SemiBold", size: 22)
        }
        return .system(size: 22, weight: .semibold, design: .serif)
    }

    static func analysisDisplayH4() -> Font {
        if UIFont(name: "CormorantGaramond-Medium", size: 19) != nil {
            return .custom("CormorantGaramond-Medium", size: 19)
        }
        return .system(size: 19, weight: .medium, design: .serif)
    }

    // Body fonts (Cormorant Garamond for reading)
    static func analysisBody() -> Font {
        if UIFont(name: "CormorantGaramond-Regular", size: 17) != nil {
            return .custom("CormorantGaramond-Regular", size: 17)
        }
        return .system(size: 17, design: .serif)
    }

    static func analysisBodyLarge() -> Font {
        if UIFont(name: "CormorantGaramond-Regular", size: 19) != nil {
            return .custom("CormorantGaramond-Regular", size: 19)
        }
        return .system(size: 19, design: .serif)
    }

    static func analysisBodySmall() -> Font {
        if UIFont(name: "CormorantGaramond-Regular", size: 15) != nil {
            return .custom("CormorantGaramond-Regular", size: 15)
        }
        return .system(size: 15, design: .serif)
    }

    // UI fonts (Inter for labels and UI elements)
    static func analysisUI() -> Font {
        if UIFont(name: "Inter-Regular", size: 15) != nil {
            return .custom("Inter-Regular", size: 15)
        }
        return .system(size: 15)
    }

    static func analysisUIBold() -> Font {
        if UIFont(name: "Inter-SemiBold", size: 15) != nil {
            return .custom("Inter-SemiBold", size: 15)
        }
        return .system(size: 15, weight: .semibold)
    }

    static func analysisUISmall() -> Font {
        if UIFont(name: "Inter-Regular", size: 13) != nil {
            return .custom("Inter-Regular", size: 13)
        }
        return .system(size: 13)
    }

    // Handwritten accent (Caveat)
    static func analysisHandwritten() -> Font {
        if UIFont(name: "Caveat-Regular", size: 22) != nil {
            return .custom("Caveat-Regular", size: 22)
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

