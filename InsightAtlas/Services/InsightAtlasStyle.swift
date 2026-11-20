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
// - Ember as primary accent for CTAs, brand identity, key interactions
// - Indigo for headers, navigation, professional anchoring
// - Clean white/gray surfaces for modern, readable interfaces
// - High contrast for accessibility (WCAG AA+ compliant)
//

struct InsightAtlasColors {

    // === BRAND COLORS (Primary Identity) ===
    static let brandOrange = PremiumUI.emberMark         // Primary Brand Orange
    static let brandNavy = PremiumUI.indigo           // Secondary Navy Blue

    // === ORANGE PALETTE ===
    static let orange50 = PremiumUI.emberWash            // Lightest
    static let orange100 = PremiumUI.emberTint
    static let orange200 = PremiumUI.emberTint
    static let orange300 = PremiumUI.emberMark
    static let orange400 = PremiumUI.emberMark
    static let orange500 = PremiumUI.emberMark           // Primary
    static let orange600 = PremiumUI.ember
    static let orange700 = PremiumUI.ember
    static let orange800 = PremiumUI.emberDeep
    static let orange900 = PremiumUI.emberDeep           // Darkest

    // === NAVY PALETTE ===
    static let navy50 = PremiumUI.indigoWash              // Lightest
    static let navy100 = PremiumUI.indigoTint
    static let navy200 = PremiumUI.indigoTint
    static let navy300 = PremiumUI.indigo
    static let navy400 = PremiumUI.indigo
    static let navy500 = PremiumUI.indigo             // Primary
    static let navy600 = PremiumUI.indigoDeep
    static let navy700 = PremiumUI.indigoDeep
    static let navy800 = PremiumUI.indigoDeep
    static let navy900 = PremiumUI.indigoDeep             // Darkest

    // === NEUTRAL GRAYS ===
    static let gray50 = PremiumUI.background
    static let gray100 = PremiumUI.chipFill
    static let gray200 = PremiumUI.divider
    static let gray300 = PremiumUI.divider
    static let gray400 = PremiumUI.secondaryText
    static let gray500 = PremiumUI.secondaryText
    static let gray600 = PremiumUI.secondaryText
    static let gray700 = PremiumUI.ink
    static let gray800 = PremiumUI.ink
    static let gray900 = PremiumUI.ink

    // === READING SURFACES (Light Mode) ===
    static let readingBgPrimary = PremiumUI.background    // Primary Background
    static let readingBgSecondary = PremiumUI.card  // Secondary Background
    static let readingBgTertiary = PremiumUI.chipFill   // Tertiary Background
    static let readingBgAccent = PremiumUI.indigoWash     // Grouped Background (Navy tint)

    // === UI CHROME ===
    static let uiBgPrimary = PremiumUI.background         // Primary UI Background
    static let uiBgSecondary = PremiumUI.card       // Secondary UI Background

    // === PREMIUM ACCENT COLORS ===
    static let accentPrimary = PremiumUI.emberMark       // Primary Orange - Primary CTAs
    static let accentSuccess = PremiumUI.celadon       // Success Green
    static let accentHighlight = PremiumUI.emberMark     // Primary Orange - Highlights
    static let accentInfo = PremiumUI.indigo          // Navy Blue - Information
    static let accentPremium = PremiumUI.indigo       // Navy Blue - Premium

    // === DESIGN SYSTEM COMPLIANCE (WCAG 2.1 AA) ===
    // CTX-04: "Apply It" section green (must use large text for compliance)
    static let applyItGreen = PremiumUI.celadon        // Apply It section background
    static let applyItGreenDark = PremiumUI.celadonDeep    // Darker variant for pressed states

    // Text colors with guaranteed WCAG AA contrast on white (#FFFFFF).
    // Primary and secondary intentionally share `ink`: the palette defines one
    // body ink and one muted step, so this is a two-tier ramp, not three.
    static let textPrimaryWCAG = PremiumUI.ink               // Passes AAA
    static let textSecondaryWCAG = PremiumUI.ink             // Passes AAA
    static let textTertiaryWCAG = PremiumUI.secondaryText    // Passes AA

    // CTX-02: BANNED - Never use these for text on light backgrounds
    // #999999 is 2.32:1 - FAILS WCAG AA - DO NOT USE FOR TEXT

    // === SEMANTIC COLORS (Light Mode) ===
    // Caution is the deep ember, not the brand mark: a "warning" drawn in the
    // primary accent is indistinguishable from ordinary brand chrome.
    static let semanticWarning = PremiumUI.emberDeep     // Warning
    static let semanticError = PremiumUI.destructive       // Error
    static let semanticSuccess = PremiumUI.celadon     // Success
    static let semanticHighlightBg = PremiumUI.emberWash // Orange 50

    // === LEGACY ALIASES (For backwards compatibility) ===
    // Type-safe ember (4.64:1 on background): this alias carries text at many
    // call sites, and `emberMark` fails AA on type.
    static let gold = PremiumUI.ember
    // Lighter-but-saturated ember for gradient stops and progress fills —
    // the pale emberTint wash would make those fade to near-invisible.
    static let goldLight = Color(hex: PremiumUI.Hex.emberDark)
    static let goldDark = PremiumUI.ember            // Orange 700

    // MARK: Text Colors (Modern Balanced Readability)
    // heading/body and muted/subtle each collapse to a single palette step by
    // design — the triad defines one body ink and one muted tone.
    static let heading = PremiumUI.ink
    static let body = PremiumUI.ink
    static let muted = PremiumUI.secondaryText
    static let subtle = PremiumUI.secondaryText

    // MARK: Backgrounds (Modern Clean)
    static let background = PremiumUI.background          // Primary Background
    static let backgroundAlt = PremiumUI.card       // Secondary Background
    static let cream = PremiumUI.emberWash               // Orange 50
    static let card = PremiumUI.card                // Pure White for cards
    static let parchment = PremiumUI.card           // Gray 50
    static let ivory = PremiumUI.card               // Pure White

    // MARK: Borders & Rules
    static let rule = PremiumUI.divider                // Gray 200
    static let ruleLight = PremiumUI.chipFill           // Gray 100
    static let ruleDark = PremiumUI.divider            // Gray 300

    // MARK: Accent Colors (OE Brand Palette)
    static let burgundy = PremiumUI.destructive            // Error Red (repurposed)
    static let burgundyLight = PremiumUI.emberDeep       // Light Error
    static let coral = PremiumUI.ember                   // ember — carries type
    static let coralLight = PremiumUI.emberTint          // pale ember wash
    static let teal = PremiumUI.indigo                // Navy Blue
    static let tealLight = PremiumUI.indigoTint           // Navy 400
    static let orange = PremiumUI.ember                  // ember — carries type
    static let orangeLight = PremiumUI.emberTint         // pale ember wash

    // MARK: Brand Colors
    // No ramp here: both resolve to the one muted step the palette defines.
    static let brandSepia = PremiumUI.secondaryText
    static let brandSepiaLight = PremiumUI.secondaryText
    static let brandInk = PremiumUI.ink            // Gray 900

    // MARK: Shadow Colors
    static let shadow = PremiumUI.indigo.opacity(0.08)
    static let shadowMedium = PremiumUI.indigo.opacity(0.12)
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
    // PINNED TO THE LIGHT PALETTE ON PURPOSE. These are the colours the legacy
    // PDF path draws with (~35 sites in `DataManager.generateLegacyPDF`), and a
    // PDF is printed output: it has no trait collection of its own and must not
    // inherit the device's. A trait-adaptive value here renders light-ember
    // text and near-black "card" fills onto a #F5F4F1 page when the phone is in
    // dark mode. `PremiumUI.UI.*` stays adaptive for on-screen UIKit chrome.
    private static func pinned(_ hex: String) -> UIColor { UIColor(hex: hex) }

    // === BRAND COLORS ===
    static let iaBrandOrange = pinned(PremiumUI.Hex.emberMarkLight)  // ember (marks)
    static let iaBrandNavy = pinned(PremiumUI.Hex.indigoLight)       // indigo

    // === PREMIUM ACCENT COLORS ===
    static let iaAccentPrimary = pinned(PremiumUI.Hex.emberMarkLight)   // ember — primary CTAs
    static let iaAccentSuccess = pinned(PremiumUI.Hex.celadonLight)     // celadon — success
    static let iaAccentHighlight = pinned(PremiumUI.Hex.emberMarkLight) // ember — highlights
    static let iaAccentInfo = pinned(PremiumUI.Hex.indigoLight)         // indigo — information
    static let iaAccentPremium = pinned(PremiumUI.Hex.indigoLight)      // indigo — premium

    // === LEGACY "GOLD" - Now ember ===
    static let iaGold = pinned(PremiumUI.Hex.emberMarkLight)   // ember (marks)
    // Mirrors SwiftUI `InsightAtlasColors.goldLight`: the lighter-but-saturated
    // ember tone, not a second copy of `iaGold`.
    static let iaGoldLight = pinned(PremiumUI.Hex.emberDark)
    static let iaGoldDark = pinned(PremiumUI.Hex.emberLight)   // ember (type-safe)

    // === TEXT COLORS (Modern Balanced Readability) ===
    static let iaHeading = pinned(PremiumUI.Hex.inkLight)
    static let iaBody = pinned(PremiumUI.Hex.inkLight)
    static let iaMuted = pinned(PremiumUI.Hex.mutedLight)
    static let iaSubtle = pinned(PremiumUI.Hex.mutedLight)

    // === READING BACKGROUNDS (Modern Clean) ===
    static let iaBackground = pinned(PremiumUI.Hex.backgroundLight)
    static let iaCream = pinned(PremiumUI.Hex.emberWashLight)
    static let iaCard = pinned(PremiumUI.Hex.cardLight)        // Pure White
    static let iaIvory = pinned(PremiumUI.Hex.cardLight)       // Pure White
    static let iaParchment = pinned(PremiumUI.Hex.cardLight)   // Pure White

    // === BORDERS ===
    static let iaRule = pinned(PremiumUI.Hex.dividerLight)
    static let iaRuleLight = pinned(PremiumUI.Hex.chipLight)

    // === ACCENT COLORS (OE Brand Palette) ===
    static let iaBurgundy = pinned(PremiumUI.Hex.destructiveLight)  // Error Red
    static let iaCoral = pinned(PremiumUI.Hex.emberMarkLight)
    static let iaTeal = pinned(PremiumUI.Hex.indigoLight)
    static let iaOrange = pinned(PremiumUI.Hex.emberMarkLight)

    // === BRAND ===
    static let iaSepia = pinned(PremiumUI.Hex.mutedLight)

    // === SEMANTIC COLORS ===
    // Caution reads as the deep ember so it is distinguishable from brand marks.
    static let iaWarning = pinned(PremiumUI.Hex.emberDeepLight)
    static let iaError = pinned(PremiumUI.Hex.destructiveLight)
    static let iaSuccess = pinned(PremiumUI.Hex.celadonLight)
    static let iaHighlightBg = pinned(PremiumUI.Hex.emberWashLight)

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
