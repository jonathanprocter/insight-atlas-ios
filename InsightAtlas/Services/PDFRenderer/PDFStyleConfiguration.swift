import UIKit
import CoreGraphics

// MARK: - PDF Style Configuration
// Integrates with AnalysisTheme for consistent styling across app and PDF exports

struct PDFStyleConfiguration {

    // MARK: - Page Layout

    struct PageLayout {
        static let pageWidth: CGFloat = 612.0  // US Letter width in points (8.5")
        static let pageHeight: CGFloat = 792.0 // US Letter height in points (11")
        static let pageSize = CGSize(width: pageWidth, height: pageHeight)

        // Margins - scholarly generous margins
        static let marginTop: CGFloat = 72.0    // 1 inch
        static let marginBottom: CGFloat = 72.0 // 1 inch
        static let marginLeft: CGFloat = 90.0   // 1.25 inches
        static let marginRight: CGFloat = 90.0  // 1.25 inches

        static let contentWidth: CGFloat = pageWidth - marginLeft - marginRight
        static let contentHeight: CGFloat = pageHeight - marginTop - marginBottom

        static var contentRect: CGRect {
            CGRect(x: marginLeft, y: marginTop, width: contentWidth, height: contentHeight)
        }
    }

    // MARK: - Premium Color System (OE Brand Identity)
    //
    // Design Philosophy:
    // - Burnt Orange (#D35F2E) as primary action/accent color - warm, energetic, distinctive
    // - Deep Steel Blue (#3B5E7A) as secondary accent - professional, trustworthy, balanced
    // - Deep Burgundy (#7B2D3E) for premium/emphasis - sophisticated, rich
    // - Warm cream surfaces for comfortable reading
    // - High contrast (>10:1) for extended reading comfort
    // - Complementary color theory: Orange ↔ Blue creates visual interest
    //

    struct Colors {
        // === BRAND COLORS (From OE Logo) ===
        static let brandOrange = UIColor(hex: "#D35F2E")         // Burnt Orange - Primary brand
        static let brandOrangeLight = UIColor(hex: "#E07A4D")    // Lighter Orange
        static let brandOrangeDark = UIColor(hex: "#B84D22")     // Darker Orange
        static let brandBlue = UIColor(hex: "#3B5E7A")           // Steel Blue - Secondary brand
        static let brandBlueLight = UIColor(hex: "#4F7694")      // Lighter Blue
        static let brandBlueDark = UIColor(hex: "#2D4A61")       // Darker Blue
        static let brandBurgundy = UIColor(hex: "#7B2D3E")       // Deep Burgundy - Premium
        static let brandCream = UIColor(hex: "#F5F0E8")          // Warm Cream - from logo "O"

        // === READING SURFACES (Warm - Primary 70%) ===
        static let readingBgPrimary = UIColor(hex: "#FAFAF8")    // Warm White - Primary reading background
        static let readingBgSecondary = UIColor(hex: "#F5F0E8")  // Brand Cream - Alternative reading surface
        static let readingBgTertiary = UIColor(hex: "#EDE8E0")   // Warm Linen - Quote blocks, section backgrounds
        static let readingBgAccent = UIColor(hex: "#E5E0D8")     // Soft Sand - Hover states, subtle dividers

        // === UI CHROME (Minimalist) ===
        static let uiBgPrimary = UIColor(hex: "#FAFAF8")         // Warm White - Navigation, header
        static let uiBgSecondary = UIColor(hex: "#F0EBE3")       // Light Cream - Sidebar backgrounds
        static let uiBorderPrimary = UIColor(hex: "#D5D0C8")     // Warm Steel - Borders, input fields
        static let uiBorderSubtle = UIColor(hex: "#E5E0D8")      // Soft Sand - Subtle borders

        // === TYPOGRAPHY COLORS (Maximum Readability AAA+) ===
        static let textPrimary = UIColor(hex: "#2A2725")         // Ink Black - Primary reading text (14.5:1 contrast)
        static let textHeading = UIColor(hex: "#2A2725")         // Ink Black - Headings, emphasis
        static let textUI = UIColor(hex: "#5A5550")              // Warm Charcoal - UI text
        static let textSecondary = UIColor(hex: "#8A8580")       // Warm Gray - Metadata, timestamps
        static let textTertiary = UIColor(hex: "#9A9590")        // Lighter Gray - Icons, secondary UI
        static let textInverse = UIColor(hex: "#FFFFFF")         // White - Inverse text on dark backgrounds

        // === PREMIUM ACCENT COLORS (Modern Minimalistic) ===
        static let accentPrimary = UIColor(hex: "#D35F2E")       // Burnt Orange - Primary CTAs, links, progress
        static let accentSuccess = UIColor(hex: "#5A8A6B")       // Muted Sage - Success, completion, resume
        static let accentHighlight = UIColor(hex: "#D35F2E")     // Burnt Orange - Highlights, bookmarks
        static let accentInfo = UIColor(hex: "#3B5E7A")          // Steel Blue - Information, tooltips
        static let accentPremium = UIColor(hex: "#7B2D3E")       // Deep Burgundy - Premium badges, VIP features

        // === SEMANTIC COLORS (Functional) ===
        static let semanticWarning = UIColor(hex: "#D9A441")     // Warm Amber - Warning
        static let semanticError = UIColor(hex: "#C45526")       // Dark Orange - Error (stays in brand)
        static let semanticInfo = UIColor(hex: "#3B5E7A")        // Steel Blue - Informative
        static let semanticHighlightBg = UIColor(hex: "#FDF5E8") // Soft Orange Tint - Highlighting

        // === PRIMARY PALETTE - Burnt Orange ===
        static let primaryGold = UIColor(hex: "#D35F2E")         // Burnt Orange
        static let primaryGoldLight = UIColor(hex: "#E07A4D")    // Lighter Orange
        static let primaryGoldDark = UIColor(hex: "#B84D22")     // Darker Orange

        // === SECONDARY ACCENTS ===
        static let accentBurgundy = UIColor(hex: "#7B2D3E")      // Deep Burgundy (Premium)
        static let accentBurgundyLight = UIColor(hex: "#9A4458") // Lighter Burgundy
        static let accentCoral = UIColor(hex: "#D35F2E")         // Burnt Orange
        static let accentCoralLight = UIColor(hex: "#E07A4D")    // Lighter Orange
        static let accentTeal = UIColor(hex: "#3B5E7A")          // Steel Blue
        static let accentOrange = UIColor(hex: "#D35F2E")        // Burnt Orange
        static let accentCrimson = UIColor(hex: "#7B2D3E")       // Deep Burgundy
        static let accentPurple = UIColor(hex: "#3B5E7A")        // Steel Blue

        // Brand Colors - Warm editorial palette
        static let brandSepia = UIColor(hex: "#5A5550")          // Warm Charcoal
        static let brandSepiaLight = UIColor(hex: "#8A8580")     // Warm Gray
        static let brandParchment = UIColor(hex: "#F5F0E8")      // Brand Cream
        static let brandParchmentDark = UIColor(hex: "#EDE8E0")  // Warm Linen
        static let brandInk = UIColor(hex: "#2A2725")            // Ink Black

        // Text Colors - Optimized for reading
        static let textBody = UIColor(hex: "#2A2725")            // Ink Black
        static let textMuted = UIColor(hex: "#8A8580")           // Warm Gray
        static let textSubtle = UIColor(hex: "#9A9590")          // Lighter Gray

        // Background Colors - Warm reading surfaces
        static let bgPrimary = UIColor(hex: "#FAFAF8")           // Warm White
        static let bgSecondary = UIColor(hex: "#F5F0E8")         // Brand Cream
        static let bgCard = UIColor(hex: "#FFFFFF")              // Pure White for elevated cards
        static let bgCream = UIColor(hex: "#F5F0E8")             // Brand Cream

        // Border Colors - Subtle for minimalist design
        static let borderLight = UIColor(hex: "#E5E0D8")         // Soft Sand
        static let borderMedium = UIColor(hex: "#D5D0C8")        // Warm Steel
        static let borderDark = UIColor(hex: "#9A9590")          // Warm Graphite
    }

    // MARK: - Typography

    struct Typography {
        // Font names with fallbacks
        private static let serifFontName = "CormorantGaramond-Regular"
        private static let serifBoldFontName = "CormorantGaramond-Bold"
        private static let serifSemiBoldFontName = "CormorantGaramond-SemiBold"
        private static let serifMediumFontName = "CormorantGaramond-Medium"
        private static let serifItalicFontName = "CormorantGaramond-Italic"
        private static let uiFontName = "Inter-Regular"
        private static let uiBoldFontName = "Inter-SemiBold"

        // Display fonts (for titles and headings)
        static func displayTitle() -> UIFont {
            UIFont(name: serifBoldFontName, size: 34) ??
            UIFont.boldSystemFont(ofSize: 34)
        }

        static func displayH1() -> UIFont {
            UIFont(name: serifBoldFontName, size: 30) ??
            UIFont.boldSystemFont(ofSize: 30)
        }

        static func displayH2() -> UIFont {
            UIFont(name: serifSemiBoldFontName, size: 28) ??
            UIFont.systemFont(ofSize: 28, weight: .semibold)
        }

        static func displayH3() -> UIFont {
            UIFont(name: serifSemiBoldFontName, size: 22) ??
            UIFont.systemFont(ofSize: 22, weight: .semibold)
        }

        static func displayH4() -> UIFont {
            UIFont(name: serifMediumFontName, size: 19) ??
            UIFont.systemFont(ofSize: 19, weight: .medium)
        }

        // Body fonts
        static func body() -> UIFont {
            UIFont(name: serifFontName, size: 17) ??
            UIFont.systemFont(ofSize: 17)
        }

        static func bodyLarge() -> UIFont {
            UIFont(name: serifFontName, size: 19) ??
            UIFont.systemFont(ofSize: 19)
        }

        static func bodySmall() -> UIFont {
            UIFont(name: serifFontName, size: 15) ??
            UIFont.systemFont(ofSize: 15)
        }

        static func bodyBold() -> UIFont {
            UIFont(name: serifBoldFontName, size: 17) ??
            UIFont.boldSystemFont(ofSize: 17)
        }

        static func bodyItalic() -> UIFont {
            UIFont(name: serifItalicFontName, size: 17) ??
            UIFont.italicSystemFont(ofSize: 17)
        }

        // UI fonts (for labels, captions)
        static func caption() -> UIFont {
            UIFont(name: uiFontName, size: 12) ??
            UIFont.systemFont(ofSize: 12)
        }

        static func captionBold() -> UIFont {
            UIFont(name: uiBoldFontName, size: 12) ??
            UIFont.boldSystemFont(ofSize: 12)
        }

        static func label() -> UIFont {
            UIFont(name: uiBoldFontName, size: 13) ??
            UIFont.boldSystemFont(ofSize: 13)
        }

        static func pageNumber() -> UIFont {
            UIFont(name: uiFontName, size: 12) ??
            UIFont.systemFont(ofSize: 12)
        }

        // Block header fonts
        static func blockHeader() -> UIFont {
            UIFont(name: uiBoldFontName, size: 13) ??
            UIFont.boldSystemFont(ofSize: 13)
        }
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

        // Line heights
        static let bodyLineHeight: CGFloat = 22
        static let headingLineHeight: CGFloat = 34

        // Paragraph spacing
        static let paragraphSpacing: CGFloat = 12
        static let sectionSpacing: CGFloat = 20  // Reduced from 24pt to avoid excessive whitespace
        static let blockSpacing: CGFloat = 14    // Reduced from 16pt for tighter layout

        // Heading-specific spacing
        static let headingTopMargin: CGFloat = 16  // Space before headings
        static let headingBottomMargin: CGFloat = 8 // Space after headings before content
    }

    // MARK: - Corner Radius

    struct Radius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 6
        static let lg: CGFloat = 8
    }

    // MARK: - Block Styles (Modern Minimalistic - OE Brand)

    struct BlockStyles {
        // Quick Glance - Uses Burnt Orange for primary accent
        static let quickGlanceBorderColor = Colors.accentPrimary        // Burnt Orange
        static let quickGlanceBgColor = Colors.bgCard
        static let quickGlanceHeaderBgColor = Colors.readingBgSecondary // Brand Cream

        // Insight Note - Uses Burnt Orange for warm highlights
        static let insightNoteBorderColor = Colors.accentHighlight      // Burnt Orange
        static let insightNoteBgColor = Colors.accentHighlight.withAlphaComponent(0.08)
        static let insightNoteIconColor = Colors.accentHighlight

        // Alternative Perspective - Unified styling matching Insight Note pattern
        static let alternativePerspectiveBorderColor = Colors.accentInfo // Steel Blue
        static let alternativePerspectiveBgColor = Colors.accentInfo.withAlphaComponent(0.08)
        static let alternativePerspectiveIconColor = Colors.accentInfo
        static let alternativePerspectiveHeaderBgColor = Colors.accentInfo
        static let alternativePerspectiveBorderWidth: CGFloat = 1.0
        static let alternativePerspectiveCornerRadius: CGFloat = 6.0

        // Research Insight - Unified styling matching Insight Note pattern
        static let researchInsightBorderColor = Colors.accentInfo       // Steel Blue
        static let researchInsightBgColor = Colors.accentInfo.withAlphaComponent(0.08)
        static let researchInsightIconColor = Colors.accentInfo
        static let researchInsightHeaderBgColor = Colors.accentInfo
        static let researchInsightBorderWidth: CGFloat = 1.0
        static let researchInsightCornerRadius: CGFloat = 6.0

        // Action Box - Uses Muted Sage for actionable success
        static let actionBoxBorderColor = Colors.accentSuccess          // Muted Sage
        static let actionBoxBgColor = Colors.accentSuccess.withAlphaComponent(0.08)
        static let actionBoxHeaderBgColor = Colors.accentSuccess

        // Exercise - Uses Burnt Orange for engagement
        static let exerciseBorderColor = Colors.accentPrimary           // Burnt Orange
        static let exerciseBgColor = Colors.accentPrimary.withAlphaComponent(0.08)
        static let exerciseIconColor = Colors.accentPrimary

        // Key Takeaways - Uses Burnt Orange for primary importance
        static let takeawaysBorderColor = Colors.accentPrimary          // Burnt Orange
        static let takeawaysBgColor = Colors.bgCard
        static let takeawaysIconColor = Colors.accentPrimary

        // Foundational Narrative - Uses Deep Burgundy for premium storytelling
        static let narrativeBorderColor = Colors.accentPremium          // Deep Burgundy
        static let narrativeBgColor = Colors.accentPremium.withAlphaComponent(0.06)

        // Blockquote - Uses Deep Burgundy for literary sophistication
        static let blockquoteBorderColor = Colors.accentPremium         // Deep Burgundy
        static let blockquoteBgColor = Colors.readingBgSecondary        // Brand Cream

        // Flowchart - Uses Steel Blue for clear visualization
        static let flowchartArrowColor = Colors.accentInfo              // Steel Blue
        static let flowchartBoxBorderColor = Colors.borderMedium        // Warm Steel
        static let flowchartBoxBgColor = Colors.bgCard
    }

    // MARK: - Icons (Unicode symbols for PDF)

    struct Icons {
        static let quickGlance = "👁"
        static let insightNote = "💡"
        static let alternativePerspective = "⚖️"
        static let researchInsight = "🔬"
        static let actionBox = "✓"
        static let exercise = "✏️"
        static let takeaways = "★"
        static let narrative = "📖"
        static let flowchart = "📊"
        static let conceptMap = "🗺️"
        static let processTimeline = "⟶"
        static let quote = "❝"
        static let bullet = "•"
        static let arrow = "→"
        static let downArrow = "↓"
        static let checkmark = "✓"
        static let book = "📖"
        static let diamondFilled = "◆"
        static let diamondOutline = "◇"
    }

    // MARK: - Premium Block Styles (Modern Minimalistic - OE Brand)

    struct PremiumStyles {
        // Premium Quote Block - Uses Deep Burgundy for literary sophistication
        static let quoteBorderColor = Colors.accentPremium              // Deep Burgundy
        static let quoteBorderWidth: CGFloat = 4
        static let quoteMarkColor = Colors.accentPremium.withAlphaComponent(0.25)
        static let quoteTextColor = Colors.textPrimary                  // Ink Black
        static let quoteAuthorColor = Colors.accentPremium              // Deep Burgundy
        static let quoteSourceColor = Colors.textSecondary              // Warm Gray

        // Author Spotlight Block - Uses Deep Burgundy for premium exclusivity
        static let authorSpotlightOuterBorderColor = Colors.accentPremium // Deep Burgundy
        static let authorSpotlightInnerBorderColor = Colors.accentPremium.withAlphaComponent(0.6)
        static let authorSpotlightBgColor = Colors.bgCard               // Pure White
        static let authorSpotlightHeaderColor = Colors.accentPremium    // Deep Burgundy
        static let authorSpotlightNameColor = Colors.brandOrange        // Burnt Orange
        static let authorSpotlightBookTitleColor = Colors.brandOrange   // Burnt Orange

        // Section Divider - Uses Burnt Orange for primary hierarchy
        static let dividerLineColor = Colors.accentPrimary              // Burnt Orange
        static let dividerDiamondColor = Colors.accentPrimary           // Burnt Orange

        // Premium Section Headers - Burnt Orange with Ink Black text
        static let h1Color = Colors.accentPrimary                       // Burnt Orange
        static let h1OrnamentColor = Colors.accentPrimary               // Burnt Orange
        static let h2BorderColor = Colors.accentPrimary                 // Burnt Orange
        static let h2LabelColor = Colors.textSecondary                  // Warm Gray
        static let h2HeadingColor = Colors.textHeading                  // Ink Black
    }

    // MARK: - Premium Typography

    struct PremiumTypography {
        // Premium Quote
        static func quoteText() -> UIFont {
            UIFont(name: "CormorantGaramond-Italic", size: 22) ??
            UIFont(name: "Georgia-Italic", size: 22) ??
            UIFont.italicSystemFont(ofSize: 22)
        }

        static func quoteAuthor() -> UIFont {
            UIFont(name: "HelveticaNeue-Bold", size: 11) ??
            UIFont.boldSystemFont(ofSize: 11)
        }

        static func quoteSource() -> UIFont {
            UIFont(name: "CormorantGaramond-Italic", size: 12) ??
            UIFont(name: "Georgia-Italic", size: 12) ??
            UIFont.italicSystemFont(ofSize: 12)
        }

        // Author Spotlight
        static func authorName() -> UIFont {
            UIFont(name: "CormorantGaramond-Bold", size: 28) ??
            UIFont(name: "Georgia-Bold", size: 28) ??
            UIFont.boldSystemFont(ofSize: 28)
        }

        static func authorBio() -> UIFont {
            UIFont(name: "CormorantGaramond-Regular", size: 13) ??
            UIFont(name: "Georgia", size: 13) ??
            UIFont.systemFont(ofSize: 13)
        }

        static func bookTitle() -> UIFont {
            UIFont(name: "CormorantGaramond-Italic", size: 13) ??
            UIFont(name: "Georgia-Italic", size: 13) ??
            UIFont.italicSystemFont(ofSize: 13)
        }

        // Premium Section Headers
        static func sectionH1() -> UIFont {
            UIFont(name: "CormorantGaramond-Bold", size: 24) ??
            UIFont(name: "Georgia-Bold", size: 24) ??
            UIFont.boldSystemFont(ofSize: 24)
        }

        static func sectionH2() -> UIFont {
            UIFont(name: "CormorantGaramond-Bold", size: 26) ??
            UIFont(name: "Georgia-Bold", size: 26) ??
            UIFont.boldSystemFont(ofSize: 26)
        }

        static func sectionLabel() -> UIFont {
            UIFont(name: "HelveticaNeue-Medium", size: 10) ??
            UIFont.systemFont(ofSize: 10, weight: .medium)
        }
    }

    // MARK: - Cover Page Configuration

    struct CoverPage {
        static let taglineTop = "Where Understanding Illuminates the World"
        static let taglineBottom = "Insight Atlas"
        static let brandSubtitle = "A Comprehensive Analysis Guide"

        // Logo positioning
        static let logoMaxWidth: CGFloat = 300
        static let logoMaxHeight: CGFloat = 300
        static let logoTopOffset: CGFloat = 180 // From top of page

        // Title positioning
        static let titleTopOffset: CGFloat = 520 // From top of page
        static let authorTopOffset: CGFloat = 560

        // Tagline positioning
        static let topTaglineY: CGFloat = 100
        static let bottomTaglineY: CGFloat = 680  // Moved up to stay within border
    }
}

// Note: UIColor(hex:) extension is defined in InsightAtlasStyle.swift
// This file uses that extension for hex color initialization

// MARK: - NSAttributedString Helpers

extension PDFStyleConfiguration {

    /// Create paragraph style with specified line height and alignment
    static func paragraphStyle(
        lineHeight: CGFloat = Spacing.bodyLineHeight,
        alignment: NSTextAlignment = .left,
        paragraphSpacing: CGFloat = Spacing.paragraphSpacing
    ) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = lineHeight
        style.maximumLineHeight = lineHeight
        style.alignment = alignment
        style.paragraphSpacing = paragraphSpacing
        return style
    }

    /// Create attributes for body text
    static func bodyAttributes(
        color: UIColor = Colors.textBody,
        alignment: NSTextAlignment = .left
    ) -> [NSAttributedString.Key: Any] {
        [
            .font: Typography.body(),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle(alignment: alignment)
        ]
    }

    /// Create attributes for heading text
    static func headingAttributes(
        level: Int,
        color: UIColor = Colors.textHeading,
        alignment: NSTextAlignment = .left
    ) -> [NSAttributedString.Key: Any] {
        let font: UIFont
        switch level {
        case 1: font = Typography.displayH1()
        case 2: font = Typography.displayH2()
        case 3: font = Typography.displayH3()
        case 4: font = Typography.displayH4()
        default: font = Typography.displayH2()
        }

        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle(
                lineHeight: Spacing.headingLineHeight,
                alignment: alignment,
                paragraphSpacing: Spacing.sectionSpacing
            )
        ]
    }

    /// Create attributes for block header labels
    static func blockHeaderAttributes(color: UIColor = Colors.textInverse) -> [NSAttributedString.Key: Any] {
        [
            .font: Typography.blockHeader(),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle(lineHeight: 14, alignment: .left, paragraphSpacing: 4)
        ]
    }

    /// Create attributes for captions
    static func captionAttributes(
        color: UIColor = Colors.textMuted,
        alignment: NSTextAlignment = .center
    ) -> [NSAttributedString.Key: Any] {
        [
            .font: Typography.caption(),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle(lineHeight: 12, alignment: alignment, paragraphSpacing: 4)
        ]
    }
}
