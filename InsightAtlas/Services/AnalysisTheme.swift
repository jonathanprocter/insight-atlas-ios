import SwiftUI

// MARK: - Insight Atlas Analysis Theme
// Premium Reading-Optimized Editorial Color System
//
// Design Philosophy:
// - Warm dominance (70-80%) for reading comfort and premium feel
// - Cool accents (20-30%) for UI clarity and professional structure
// - Muted, complex colors for sophistication over trendiness
// - High contrast (>10:1) for extended reading comfort
//

struct AnalysisTheme {

    // MARK: - Reading Surfaces (Warm - Primary 70%)

    static let readingBgPrimary = Color(hex: "#F9F8F7")      // Sepia White
    static let readingBgSecondary = Color(hex: "#F5F3EF")    // Parchment
    static let readingBgTertiary = Color(hex: "#EBE8E3")     // Warm Linen
    static let readingBgAccent = Color(hex: "#E7E3DA")       // Soft Sand

    // MARK: - Brand Colors (Warm Editorial)

    static let brandSepia = Color(hex: "#625E58")            // Warm Charcoal
    static let brandSepiaLight = Color(hex: "#A6A6A4")       // Warm Gray
    static let brandParchment = Color(hex: "#F5F3EF")        // Parchment
    static let brandParchmentDark = Color(hex: "#EBE8E3")    // Warm Linen
    static let brandInk = Color(hex: "#2B2826")              // Ink Black

    // MARK: - Primary Palette - Deep Teal (Replaces Gold)
    // WCAG AAA compliant on warm backgrounds

    static let primaryGold = Color(hex: "#0D7377")           // Deep Teal - Primary accent
    static let primaryGoldText = Color(hex: "#0D7377")       // Same - already compliant
    static let primaryGoldLight = Color(hex: "#2A9D8F")      // Lighter Teal
    static let primaryGoldDark = Color(hex: "#0B6166")       // Darker Teal
    static let primaryGoldSubtle = Color(hex: "#0D7377").opacity(0.06)
    static let primaryGoldMuted = Color(hex: "#0D7377").opacity(0.15)

    // MARK: - Premium Accent Colors (Sophisticated, Muted)

    static let accentPrimary = Color(hex: "#0D7377")         // Deep Teal - Primary CTAs
    static let accentSuccess = Color(hex: "#7A9B7F")         // Sage Green - Success
    static let accentHighlight = Color(hex: "#9B6B4F")       // Burnt Umber - Highlights
    static let accentInfo = Color(hex: "#5B7C99")            // Slate Blue - Information
    static let accentPremium = Color(hex: "#8B4049")         // Deep Burgundy - Premium

    // MARK: - Secondary Palette - Refined Accents

    static let accentBurgundy = Color(hex: "#8B4049")        // Deep Burgundy
    static let accentBurgundyLight = Color(hex: "#A55560")   // Lighter Burgundy
    static let accentBurgundySubtle = Color(hex: "#8B4049").opacity(0.06)

    static let accentCoral = Color(hex: "#9B6B4F")           // Burnt Umber
    static let accentCoralText = Color(hex: "#9B6B4F")       // Same - already compliant
    static let accentCoralLight = Color(hex: "#B8845F")      // Lighter Umber
    static let accentCoralSubtle = Color(hex: "#9B6B4F").opacity(0.06)
    static let accentCoralMuted = Color(hex: "#9B6B4F").opacity(0.15)

    static let accentTeal = Color(hex: "#0D7377")            // Deep Teal
    static let accentTealText = Color(hex: "#0D7377")        // Same - already compliant
    static let accentTealLight = Color(hex: "#2A9D8F")       // Lighter Teal
    static let accentTealSubtle = Color(hex: "#0D7377").opacity(0.06)
    static let accentTealMuted = Color(hex: "#0D7377").opacity(0.15)

    static let accentOrange = Color(hex: "#C89B5A")          // Amber
    static let accentOrangeText = Color(hex: "#9A7A3D")      // Darker Amber for text
    static let accentOrangeLight = Color(hex: "#D4AC6B")     // Lighter Amber
    static let accentOrangeSubtle = Color(hex: "#C89B5A").opacity(0.08)

    // MARK: - Premium Commentary Box Colors (Refined for Premium Reading)

    // Insight Note - Uses Burnt Umber for warm highlights
    static let insightOrange = Color(hex: "#9B6B4F")         // Burnt Umber
    static let insightOrangeLight = Color(hex: "#B8845F")    // Lighter Umber
    static let insightBgStart = Color(hex: "#F9F8F7")        // Sepia White
    static let insightBgMid = Color(hex: "#F5F3EF")          // Parchment
    static let insightBgEnd = Color(hex: "#EBE8E3")          // Warm Linen

    // Alternative Perspective - Uses Slate Blue for balanced info
    static let perspectiveTeal = Color(hex: "#5B7C99")       // Slate Blue
    static let perspectiveTealDark = Color(hex: "#4A6B88")   // Darker Slate Blue
    static let perspectiveBgStart = Color(hex: "#F5F7F9")    // Cool tint on Sepia
    static let perspectiveBgMid = Color(hex: "#EEF2F5")      // Slightly cooler
    static let perspectiveBgEnd = Color(hex: "#E8EDF2")      // Cool wash

    // Research Insight - Uses Sage Green for scholarly feel
    static let researchSage = Color(hex: "#7A9B7F")          // Sage Green
    static let researchSageLight = Color(hex: "#8AAB8F")     // Lighter Sage
    static let researchBgStart = Color(hex: "#F7F9F7")       // Greenish tint on Sepia
    static let researchBgMid = Color(hex: "#F2F6F2")         // Slightly greener
    static let researchBgEnd = Color(hex: "#EDF3ED")         // Sage wash

    // MARK: - Premium Quote Card Colors (Warm Parchment)

    static let parchmentBase = Color(hex: "#F9F8F7")         // Sepia White
    static let parchmentMid = Color(hex: "#EBE8E3")          // Warm Linen
    static let parchmentDark = Color(hex: "#E7E3DA")         // Soft Sand
    static let parchmentVignette = Color(hex: "#625E58")     // Warm Charcoal
    static let goldOrnament = Color(hex: "#0D7377")          // Deep Teal
    static let goldTitle = Color(hex: "#0D7377")             // Deep Teal
    static let coralAuthor = Color(hex: "#9B6B4F")           // Burnt Umber
    static let inkMuted = Color(hex: "#625E58")              // Warm Charcoal

    // MARK: - Premium Teal Frame Colors (Layered Card Design)

    // Layer 1: Outer deep teal gradient
    static let goldFrameOuter = Color(hex: "#0D7377")        // Deep Teal
    static let goldFrameOuterMid = Color(hex: "#0B6166")     // Darker Teal
    static let goldFrameOuterDark = Color(hex: "#095559")    // Darkest Teal

    // Layer 2: Inner bright teal gradient
    static let goldFrameInnerLight = Color(hex: "#2A9D8F")   // Lighter Teal
    static let goldFrameInnerMid = Color(hex: "#1E8A7E")     // Mid Teal
    static let goldFrameInnerDark = Color(hex: "#0D7377")    // Deep Teal

    // Layer 3: Warm cream gap
    static let goldFrameCreamLight = Color(hex: "#FDFCFA")   // Warm White
    static let goldFrameCreamMid = Color(hex: "#F9F8F7")     // Sepia White
    static let goldFrameCreamDark = Color(hex: "#F5F3EF")    // Parchment

    // Layer 4: Teal pinstripe
    static let goldPinstripeLight = Color(hex: "#2A9D8F")    // Lighter Teal
    static let goldPinstripeDark = Color(hex: "#0D7377")     // Deep Teal

    // Outer card gradient (Warm reading surfaces)
    static let outerCardTop = Color(hex: "#FFFFFF")          // Pure White
    static let outerCardMid = Color(hex: "#F9F8F7")          // Sepia White
    static let outerCardBottom = Color(hex: "#F5F3EF")       // Parchment
    static let cardBackdrop = Color(hex: "#EBE8E3")          // Warm Linen

    // MARK: - Text Colors (Maximum Readability AAA+)

    static let textHeading = Color(hex: "#625E58")           // Warm Charcoal
    static let textBody = Color(hex: "#2B2826")              // Ink Black (14.5:1 contrast)
    static let textMuted = Color(hex: "#A6A6A4")             // Warm Gray
    static let textSubtle = Color(hex: "#979C9F")            // Graphite
    static let textInverse = Color(hex: "#FFFFFF")           // White
    static let textHandwritten = Color(hex: "#625E58")       // Warm Charcoal

    // MARK: - Background Colors (Warm Reading Surfaces)

    static let bgPrimary = Color(hex: "#F9F8F7")             // Sepia White
    static let bgSecondary = Color(hex: "#F5F3EF")           // Parchment
    static let bgCard = Color(hex: "#FFFFFF")                // Pure White for elevated cards
    static let bgElevated = Color(hex: "#FFFFFF")            // Pure White

    // MARK: - Border Colors (Cool for UI separation)

    static let borderLight = Color(hex: "#E7E3DA")           // Soft Sand
    static let borderMedium = Color(hex: "#D4D5D8")          // Steel
    static let borderDark = Color(hex: "#979C9F")            // Graphite

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
