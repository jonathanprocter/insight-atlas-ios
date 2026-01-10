//
//  InsightAtlasStyle.swift
//  Insight Atlas
//
//  Brand style constants for consistent UI across the app.
//  These values match the PDF generator for visual consistency.
//  Updated to OE Brand Identity - January 2025
//

import SwiftUI

// MARK: - OE Brand Color Palette
//
// Design Philosophy:
// - Orange (#E85D2D) as primary accent for CTAs, brand identity, key interactions
// - Navy Blue (#2E5A7D) for headers, navigation, professional anchoring
// - Clean white/gray surfaces for modern, readable interfaces
// - High contrast for accessibility (WCAG AA+ compliant)
//

struct InsightAtlasColors {

    // === BRAND COLORS (Primary Identity) ===
    static let brandOrange = Color(hex: "#E85D2D")         // Primary Brand Orange
    static let brandNavy = Color(hex: "#2E5A7D")           // Secondary Navy Blue

    // === ORANGE PALETTE ===
    static let orange50 = Color(hex: "#FEF0EB")            // Lightest
    static let orange100 = Color(hex: "#FCD4C4")
    static let orange200 = Color(hex: "#FAAB8D")
    static let orange300 = Color(hex: "#F58F6A")
    static let orange400 = Color(hex: "#F07348")
    static let orange500 = Color(hex: "#E85D2D")           // Primary
    static let orange600 = Color(hex: "#D85426")
    static let orange700 = Color(hex: "#C74A1F")
    static let orange800 = Color(hex: "#A63F1C")
    static let orange900 = Color(hex: "#8B3518")           // Darkest

    // === NAVY PALETTE ===
    static let navy50 = Color(hex: "#EBF3F7")              // Lightest
    static let navy100 = Color(hex: "#C9DEE9")
    static let navy200 = Color(hex: "#9DC0D6")
    static let navy300 = Color(hex: "#6B9AB8")
    static let navy400 = Color(hex: "#4A7A9D")
    static let navy500 = Color(hex: "#2E5A7D")             // Primary
    static let navy600 = Color(hex: "#254A66")
    static let navy700 = Color(hex: "#1E3D54")
    static let navy800 = Color(hex: "#162B3D")
    static let navy900 = Color(hex: "#0F1E2A")             // Darkest

    // === NEUTRAL GRAYS ===
    static let gray50 = Color(hex: "#F9FAFB")
    static let gray100 = Color(hex: "#F3F4F6")
    static let gray200 = Color(hex: "#E5E7EB")
    static let gray300 = Color(hex: "#D1D5DB")
    static let gray400 = Color(hex: "#9CA3AF")
    static let gray500 = Color(hex: "#6B7280")
    static let gray600 = Color(hex: "#4B5563")
    static let gray700 = Color(hex: "#374151")
    static let gray800 = Color(hex: "#1F2937")
    static let gray900 = Color(hex: "#111827")

    // === READING SURFACES (Light Mode) ===
    static let readingBgPrimary = Color(hex: "#FFFFFF")    // Primary Background
    static let readingBgSecondary = Color(hex: "#F9FAFB")  // Secondary Background
    static let readingBgTertiary = Color(hex: "#F3F4F6")   // Tertiary Background
    static let readingBgAccent = Color(hex: "#EBF3F7")     // Grouped Background (Navy tint)

    // === UI CHROME ===
    static let uiBgPrimary = Color(hex: "#FFFFFF")         // Primary UI Background
    static let uiBgSecondary = Color(hex: "#F9FAFB")       // Secondary UI Background

    // === PREMIUM ACCENT COLORS ===
    static let accentPrimary = Color(hex: "#E85D2D")       // Primary Orange - Primary CTAs
    static let accentSuccess = Color(hex: "#059669")       // Success Green
    static let accentHighlight = Color(hex: "#E85D2D")     // Primary Orange - Highlights
    static let accentInfo = Color(hex: "#2E5A7D")          // Navy Blue - Information
    static let accentPremium = Color(hex: "#2E5A7D")       // Navy Blue - Premium

    // === DESIGN SYSTEM COMPLIANCE (WCAG 2.1 AA) ===
    // CTX-04: "Apply It" section green (must use large text for compliance)
    static let applyItGreen = Color(hex: "#4A7C59")        // Apply It section background
    static let applyItGreenDark = Color(hex: "#3D6A4B")    // Darker variant for pressed states

    // Text colors with guaranteed WCAG AA contrast on white (#FFFFFF)
    static let textPrimaryWCAG = Color(hex: "#1A1A1A")     // 15.28:1 ratio (Passes AAA)
    static let textSecondaryWCAG = Color(hex: "#333333")   // 10.97:1 ratio (Passes AAA)
    static let textTertiaryWCAG = Color(hex: "#666666")    // 4.68:1 ratio (Passes AA)

    // CTX-02: BANNED - Never use these for text on light backgrounds
    // #999999 is 2.32:1 - FAILS WCAG AA - DO NOT USE FOR TEXT

    // === SEMANTIC COLORS (Light Mode) ===
    static let semanticWarning = Color(hex: "#D97706")     // Warning
    static let semanticError = Color(hex: "#DC2626")       // Error
    static let semanticSuccess = Color(hex: "#059669")     // Success
    static let semanticHighlightBg = Color(hex: "#FEF0EB") // Orange 50

    // === LEGACY ALIASES (For backwards compatibility) ===
    static let gold = Color(hex: "#E85D2D")                // Primary Orange
    static let goldLight = Color(hex: "#F07348")           // Orange 400
    static let goldDark = Color(hex: "#C74A1F")            // Orange 700

    // MARK: Text Colors (Modern Balanced Readability)
    static let heading = Color(hex: "#111827")             // Gray 900
    static let body = Color(hex: "#1F2937")                // Gray 800
    static let muted = Color(hex: "#6B7280")               // Gray 500
    static let subtle = Color(hex: "#9CA3AF")              // Gray 400

    // MARK: Backgrounds (Modern Clean)
    static let background = Color(hex: "#FFFFFF")          // Primary Background
    static let backgroundAlt = Color(hex: "#F9FAFB")       // Secondary Background
    static let cream = Color(hex: "#FEF0EB")               // Orange 50
    static let card = Color(hex: "#FFFFFF")                // Pure White for cards
    static let parchment = Color(hex: "#F9FAFB")           // Gray 50
    static let ivory = Color(hex: "#FFFFFF")               // Pure White

    // MARK: Borders & Rules
    static let rule = Color(hex: "#E5E7EB")                // Gray 200
    static let ruleLight = Color(hex: "#F3F4F6")           // Gray 100
    static let ruleDark = Color(hex: "#D1D5DB")            // Gray 300

    // MARK: Accent Colors (OE Brand Palette)
    static let burgundy = Color(hex: "#DC2626")            // Error Red (repurposed)
    static let burgundyLight = Color(hex: "#F87171")       // Light Error
    static let coral = Color(hex: "#E85D2D")               // Primary Orange
    static let coralLight = Color(hex: "#F07348")          // Orange 400
    static let teal = Color(hex: "#2E5A7D")                // Navy Blue
    static let tealLight = Color(hex: "#4A7A9D")           // Navy 400
    static let orange = Color(hex: "#E85D2D")              // Primary Orange
    static let orangeLight = Color(hex: "#F07348")         // Orange 400

    // MARK: Brand Colors
    static let brandSepia = Color(hex: "#4B5563")          // Gray 600
    static let brandSepiaLight = Color(hex: "#6B7280")     // Gray 500
    static let brandInk = Color(hex: "#111827")            // Gray 900

    // MARK: Shadow Colors
    static let shadow = Color(hex: "#2E5A7D").opacity(0.08)
    static let shadowMedium = Color(hex: "#2E5A7D").opacity(0.12)
}

// MARK: - Typography (Editorial hierarchy)

struct InsightAtlasTypography {

    // Headings
    static let largeTitle = Font.system(size: 30, weight: .bold, design: .default)
    static let h1 = Font.system(size: 24, weight: .bold, design: .default)
    static let h2 = Font.system(size: 20, weight: .bold, design: .default)
    static let h3 = Font.system(size: 18, weight: .semibold, design: .default)
    static let h4 = Font.system(size: 16, weight: .semibold, design: .default)

    // Body
    static let body = Font.system(size: 16, weight: .regular, design: .default)
    static let bodyBold = Font.system(size: 16, weight: .bold, design: .default)
    static let bodyItalic = Font.system(size: 16, weight: .regular, design: .default).italic()
    static let bodySmall = Font.system(size: 14, weight: .regular, design: .default)

    // UI Elements
    static let uiBody = Font.system(size: 15, weight: .regular, design: .default)
    static let uiSubheadline = Font.system(size: 13, weight: .regular, design: .default)
    static let caption = Font.system(size: 11, weight: .regular, design: .default)
    static let captionBold = Font.system(size: 11, weight: .semibold, design: .default)
    static let footnote = Font.system(size: 12, weight: .regular, design: .default)
    static let button = Font.system(size: 15, weight: .semibold, design: .default)
    static let buttonSmall = Font.system(size: 13, weight: .semibold, design: .default)
}

// MARK: - Spacing

struct InsightAtlasSpacing {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 22
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 44
}

// MARK: - Layout

struct InsightAtlasLayout {
    static let maxContentWidth: CGFloat = 720
    static let sectionSpacing: CGFloat = 32
    static let paragraphSpacing: CGFloat = 20
    static let blockSpacing: CGFloat = 24
    static let intraBlockSpacing: CGFloat = 12
}

// MARK: - Brand Assets

struct InsightAtlasBrand {
    static let tagline = "Where Understanding Illuminates the World"
    static let taglineShort = "Clarity is Strength"
    static let pullQuote = "Where the weight of understanding becomes the clarity to act."
    static let footerTagline = "Where the weight of understanding becomes the clarity to act."  // v13.3
}

// MARK: - Section Icons

struct InsightAtlasSectionIcons {
    static let executiveSummary = "☉"
    static let theoreticalFramework = "◈"
    static let practicalApplications = "✦"
    static let limitations = "◇"
    static let keyTakeaways = "★"
    static let generic = "◆"
}

// MARK: - Color Extension
// Note: Color.init(hex:) is defined in AnalysisTheme.swift to avoid duplication

// MARK: - UIColor Extension (for UIKit compatibility)

import UIKit

extension UIColor {
    // === BRAND COLORS ===
    static let iaBrandOrange = UIColor(hex: "#E85D2D")     // Primary Brand Orange
    static let iaBrandNavy = UIColor(hex: "#2E5A7D")       // Secondary Navy Blue

    // === PREMIUM ACCENT COLORS ===
    static let iaAccentPrimary = UIColor(hex: "#E85D2D")   // Primary Orange - Primary CTAs
    static let iaAccentSuccess = UIColor(hex: "#059669")   // Success Green
    static let iaAccentHighlight = UIColor(hex: "#E85D2D") // Primary Orange - Highlights
    static let iaAccentInfo = UIColor(hex: "#2E5A7D")      // Navy Blue - Information
    static let iaAccentPremium = UIColor(hex: "#2E5A7D")   // Navy Blue - Premium

    // === LEGACY "GOLD" - Now Primary Orange ===
    static let iaGold = UIColor(hex: "#E85D2D")            // Primary Orange
    static let iaGoldLight = UIColor(hex: "#F07348")       // Orange 400
    static let iaGoldDark = UIColor(hex: "#C74A1F")        // Orange 700

    // === TEXT COLORS (Modern Balanced Readability) ===
    static let iaHeading = UIColor(hex: "#111827")         // Gray 900
    static let iaBody = UIColor(hex: "#1F2937")            // Gray 800
    static let iaMuted = UIColor(hex: "#6B7280")           // Gray 500
    static let iaSubtle = UIColor(hex: "#9CA3AF")          // Gray 400

    // === READING BACKGROUNDS (Modern Clean) ===
    static let iaBackground = UIColor(hex: "#FFFFFF")      // Primary Background
    static let iaCream = UIColor(hex: "#FEF0EB")           // Orange 50
    static let iaCard = UIColor(hex: "#FFFFFF")            // Pure White
    static let iaIvory = UIColor(hex: "#FFFFFF")           // Pure White
    static let iaParchment = UIColor(hex: "#F9FAFB")       // Gray 50

    // === BORDERS ===
    static let iaRule = UIColor(hex: "#E5E7EB")            // Gray 200
    static let iaRuleLight = UIColor(hex: "#F3F4F6")       // Gray 100

    // === ACCENT COLORS (OE Brand Palette) ===
    static let iaBurgundy = UIColor(hex: "#DC2626")        // Error Red
    static let iaCoral = UIColor(hex: "#E85D2D")           // Primary Orange
    static let iaTeal = UIColor(hex: "#2E5A7D")            // Navy Blue
    static let iaOrange = UIColor(hex: "#E85D2D")          // Primary Orange

    // === BRAND ===
    static let iaSepia = UIColor(hex: "#4B5563")           // Gray 600

    // === SEMANTIC COLORS ===
    static let iaWarning = UIColor(hex: "#D97706")         // Warning
    static let iaError = UIColor(hex: "#DC2626")           // Error
    static let iaSuccess = UIColor(hex: "#059669")         // Success
    static let iaHighlightBg = UIColor(hex: "#FEF0EB")     // Orange 50

    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

// MARK: - Custom View Modifiers

struct InsightAtlasCardStyle: ViewModifier {
    var accentColor: Color = InsightAtlasColors.gold

    func body(content: Content) -> some View {
        content
            .padding(InsightAtlasSpacing.md)
            .background(InsightAtlasColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(InsightAtlasColors.rule, lineWidth: 1)
            )
    }
}

// MARK: - Premium Stage Header Style
struct PremiumStageHeaderStyle: ViewModifier {
    let stage: String

    func body(content: Content) -> some View {
        VStack(alignment: .center, spacing: 8) {
            Text("Stage \(stage)")
                .font(.system(size: 14, weight: .medium))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundColor(InsightAtlasColors.muted)

            content
                .font(InsightAtlasTypography.h1)
                .foregroundColor(InsightAtlasColors.heading)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Premium Subheader Style (Cream with gold left border)
struct PremiumSubheaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(InsightAtlasColors.gold)
                .frame(width: 4)

            content
                .font(InsightAtlasTypography.h2)
                .foregroundColor(InsightAtlasColors.heading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
        .background(InsightAtlasColors.cream)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: InsightAtlasColors.shadow, radius: 4, x: 0, y: 2)
    }
}

extension View {
    func premiumStageHeader(stage: String) -> some View {
        modifier(PremiumStageHeaderStyle(stage: stage))
    }

    func premiumSubheader() -> some View {
        modifier(PremiumSubheaderStyle())
    }
}

struct InsightAtlasPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(InsightAtlasTypography.button)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(configuration.isPressed ? InsightAtlasColors.goldDark : InsightAtlasColors.gold)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct InsightAtlasSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(InsightAtlasTypography.button)
            .foregroundColor(InsightAtlasColors.heading)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(InsightAtlasColors.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(InsightAtlasColors.rule, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension View {
    func insightAtlasCard(accent: Color = InsightAtlasColors.gold) -> some View {
        modifier(InsightAtlasCardStyle(accentColor: accent))
    }
}

// MARK: - Accent Bar Modifier

struct AccentBarModifier: ViewModifier {
    var color: Color = InsightAtlasColors.gold
    var width: CGFloat = 4

    func body(content: Content) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(color)
                .frame(width: width)

            content
                .padding(.leading, InsightAtlasSpacing.sm)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

extension View {
    func accentBar(color: Color = InsightAtlasColors.gold, width: CGFloat = 4) -> some View {
        modifier(AccentBarModifier(color: color, width: width))
    }
}

// MARK: - Async Book Cover Image View
// NOTE: Commented out until BookCoverService is implemented

/*
struct AsyncBookCoverImage: View {
    let title: String
    let author: String
    let size: BookCoverService.CoverSize
    let fallbackColor: Color

    @State private var coverImage: UIImage?
    @State private var isLoading = true
    @State private var loadFailed = false

    init(
        title: String,
        author: String,
        size: BookCoverService.CoverSize = .medium,
        fallbackColor: Color = InsightAtlasColors.gold
    ) {
        self.title = title
        self.author = author
        self.size = size
        self.fallbackColor = fallbackColor
    }

    var body: some View {
        Group {
            if let image = coverImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                // Loading placeholder
                ZStack {
                    fallbackColor.opacity(0.1)
                    ProgressView()
                        .tint(fallbackColor)
                }
            } else {
                // Fallback icon when no cover found
                fallbackView
            }
        }
        .task {
            await loadCover()
        }
    }

    private var fallbackView: some View {
        ZStack {
            fallbackColor.opacity(0.1)

            Image(systemName: "book.closed")
                .font(.system(size: 22))
                .foregroundColor(fallbackColor)
        }
    }

    private func loadCover() async {
        isLoading = true

        let image = await BookCoverService.shared.fetchCover(
            title: title,
            author: author,
            size: size
        )

        await MainActor.run {
            self.coverImage = image
            self.isLoading = false
            self.loadFailed = image == nil
        }
    }
}
*/
