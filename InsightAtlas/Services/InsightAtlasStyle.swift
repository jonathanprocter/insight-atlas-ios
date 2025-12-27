//
//  InsightAtlasStyle.swift
//  Insight Atlas
//
//  Brand style constants for consistent UI across the app.
//  These values match the PDF generator for visual consistency.
//

import SwiftUI

// MARK: - Premium Color Palette (Reading-Optimized Editorial)
//
// Design Philosophy:
// - Warm dominance (70-80%) for reading comfort and premium feel
// - Cool accents (20-30%) for UI clarity and professional structure
// - Muted, complex colors for sophistication over trendiness
// - High contrast (>10:1) for extended reading comfort
//

struct InsightAtlasColors {

    // === READING SURFACES (Warm - Primary 70%) ===
    static let readingBgPrimary = Color(hex: "#F9F8F7")    // Sepia White
    static let readingBgSecondary = Color(hex: "#F5F3EF")  // Parchment
    static let readingBgTertiary = Color(hex: "#EBE8E3")   // Warm Linen
    static let readingBgAccent = Color(hex: "#E7E3DA")     // Soft Sand

    // === UI CHROME (Cool - Secondary 20-30%) ===
    static let uiBgPrimary = Color(hex: "#F9F9F9")         // Slate White
    static let uiBgSecondary = Color(hex: "#E8E9EE")       // Silver Mist

    // === PREMIUM ACCENT COLORS (Sophisticated, Muted - 10%) ===
    static let accentPrimary = Color(hex: "#0D7377")       // Deep Teal - Primary CTAs
    static let accentSuccess = Color(hex: "#7A9B7F")       // Sage Green - Success states
    static let accentHighlight = Color(hex: "#9B6B4F")     // Burnt Umber - Highlights
    static let accentInfo = Color(hex: "#5B7C99")          // Slate Blue - Information
    static let accentPremium = Color(hex: "#8B4049")       // Deep Burgundy - Premium

    // === SEMANTIC COLORS ===
    static let semanticWarning = Color(hex: "#C89B5A")     // Amber
    static let semanticError = Color(hex: "#B85C5C")       // Muted Red
    static let semanticHighlightBg = Color(hex: "#F4E8C1") // Soft Yellow

    // === LEGACY ALIASES (For backwards compatibility) ===
    // Primary "Gold" - Now Deep Teal for sophistication
    static let gold = Color(hex: "#0D7377")                // Deep Teal
    static let goldLight = Color(hex: "#2A9D8F")           // Lighter Teal
    static let goldDark = Color(hex: "#0B6166")            // Darker Teal

    // MARK: Text Colors (Maximum Readability AAA+)
    static let heading = Color(hex: "#625E58")             // Warm Charcoal
    static let body = Color(hex: "#2B2826")                // Ink Black (14.5:1 contrast)
    static let muted = Color(hex: "#A6A6A4")               // Warm Gray
    static let subtle = Color(hex: "#979C9F")              // Graphite

    // MARK: Backgrounds (Warm Reading Surfaces)
    static let background = Color(hex: "#F9F8F7")          // Sepia White
    static let backgroundAlt = Color(hex: "#F5F3EF")       // Parchment
    static let cream = Color(hex: "#F9F8F7")               // Sepia White
    static let card = Color(hex: "#FFFFFF")                // Pure White for elevated cards
    static let parchment = Color(hex: "#F5F3EF")           // Parchment
    static let ivory = Color(hex: "#F9F8F7")               // Sepia White

    // MARK: Borders & Rules (Cool for UI separation)
    static let rule = Color(hex: "#D4D5D8")                // Steel
    static let ruleLight = Color(hex: "#E7E3DA")           // Soft Sand
    static let ruleDark = Color(hex: "#979C9F")            // Graphite

    // MARK: Accent Colors (Refined Premium Palette)
    static let burgundy = Color(hex: "#8B4049")            // Deep Burgundy
    static let burgundyLight = Color(hex: "#A55560")       // Lighter Burgundy
    static let coral = Color(hex: "#9B6B4F")               // Burnt Umber
    static let coralLight = Color(hex: "#B8845F")          // Lighter Umber
    static let teal = Color(hex: "#0D7377")                // Deep Teal
    static let tealLight = Color(hex: "#2A9D8F")           // Lighter Teal
    static let orange = Color(hex: "#C89B5A")              // Amber
    static let orangeLight = Color(hex: "#D4AC6B")         // Lighter Amber

    // MARK: Brand Colors (Warm Editorial)
    static let brandSepia = Color(hex: "#625E58")          // Warm Charcoal
    static let brandSepiaLight = Color(hex: "#A6A6A4")     // Warm Gray
    static let brandInk = Color(hex: "#2B2826")            // Ink Black

    // MARK: Shadow Colors (Warm-tinted for editorial feel)
    static let shadow = Color(hex: "#625E58").opacity(0.06)
    static let shadowMedium = Color(hex: "#625E58").opacity(0.12)
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

extension Color {
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
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - UIColor Extension (for UIKit compatibility)

import UIKit

extension UIColor {
    // === PREMIUM ACCENT COLORS ===
    static let iaAccentPrimary = UIColor(hex: "#0D7377")   // Deep Teal - Primary CTAs
    static let iaAccentSuccess = UIColor(hex: "#7A9B7F")   // Sage Green - Success
    static let iaAccentHighlight = UIColor(hex: "#9B6B4F") // Burnt Umber - Highlights
    static let iaAccentInfo = UIColor(hex: "#5B7C99")      // Slate Blue - Information
    static let iaAccentPremium = UIColor(hex: "#8B4049")   // Deep Burgundy - Premium

    // === LEGACY "GOLD" - Now Deep Teal ===
    static let iaGold = UIColor(hex: "#0D7377")            // Deep Teal
    static let iaGoldLight = UIColor(hex: "#2A9D8F")       // Lighter Teal
    static let iaGoldDark = UIColor(hex: "#0B6166")        // Darker Teal

    // === TEXT COLORS (Maximum Readability AAA+) ===
    static let iaHeading = UIColor(hex: "#625E58")         // Warm Charcoal
    static let iaBody = UIColor(hex: "#2B2826")            // Ink Black
    static let iaMuted = UIColor(hex: "#A6A6A4")           // Warm Gray
    static let iaSubtle = UIColor(hex: "#979C9F")          // Graphite

    // === READING BACKGROUNDS (Warm Surfaces) ===
    static let iaBackground = UIColor(hex: "#F9F8F7")      // Sepia White
    static let iaCream = UIColor(hex: "#F9F8F7")           // Sepia White
    static let iaCard = UIColor(hex: "#FFFFFF")            // Pure White
    static let iaIvory = UIColor(hex: "#F9F8F7")           // Sepia White
    static let iaParchment = UIColor(hex: "#F5F3EF")       // Parchment

    // === BORDERS (Cool for UI separation) ===
    static let iaRule = UIColor(hex: "#D4D5D8")            // Steel
    static let iaRuleLight = UIColor(hex: "#E7E3DA")       // Soft Sand

    // === REFINED ACCENT COLORS ===
    static let iaBurgundy = UIColor(hex: "#8B4049")        // Deep Burgundy
    static let iaCoral = UIColor(hex: "#9B6B4F")           // Burnt Umber
    static let iaTeal = UIColor(hex: "#0D7377")            // Deep Teal
    static let iaOrange = UIColor(hex: "#C89B5A")          // Amber

    // === BRAND ===
    static let iaSepia = UIColor(hex: "#625E58")           // Warm Charcoal

    // === SEMANTIC COLORS ===
    static let iaWarning = UIColor(hex: "#C89B5A")         // Amber
    static let iaError = UIColor(hex: "#B85C5C")           // Muted Red
    static let iaHighlightBg = UIColor(hex: "#F4E8C1")     // Soft Yellow

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
