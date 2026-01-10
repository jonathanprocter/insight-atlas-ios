import SwiftUI

// MARK: - Insight Atlas Analysis Theme
// Adapted from the 2026 HTML template design system

struct AnalysisTheme {
    
    // MARK: - Brand Colors (from Logo)
    
    static let brandSepia = Color(hex: "#5C4A3D")
    static let brandSepiaLight = Color(hex: "#7A6A5D")
    static let brandParchment = Color(hex: "#F5F3ED")
    static let brandParchmentDark = Color(hex: "#E8E4DC")
    static let brandInk = Color(hex: "#3D3229")
    
    // MARK: - Primary Palette - Gold
    
    static let primaryGold = Color(hex: "#C9A227")
    static let primaryGoldLight = Color(hex: "#DCBE5E")
    static let primaryGoldDark = Color(hex: "#A88A1F")
    static let primaryGoldSubtle = Color(hex: "#C9A227").opacity(0.08)
    static let primaryGoldMuted = Color(hex: "#C9A227").opacity(0.25)
    
    // MARK: - Secondary Palette - Accents
    
    static let accentBurgundy = Color(hex: "#6B3A4A")
    static let accentBurgundyLight = Color(hex: "#8A5066")
    static let accentBurgundySubtle = Color(hex: "#6B3A4A").opacity(0.06)
    
    static let accentCoral = Color(hex: "#D4735C")
    static let accentCoralLight = Color(hex: "#E08B73")
    static let accentCoralSubtle = Color(hex: "#D4735C").opacity(0.08)
    
    static let accentTeal = Color(hex: "#2A8B7F")
    static let accentTealLight = Color(hex: "#3BA396")
    static let accentTealSubtle = Color(hex: "#2A8B7F").opacity(0.08)
    
    static let accentOrange = Color(hex: "#E89B5A")
    static let accentOrangeLight = Color(hex: "#F0B07A")
    static let accentOrangeSubtle = Color(hex: "#E89B5A").opacity(0.1)
    
    // MARK: - Text Colors
    
    static let textHeading = Color(hex: "#2D2520")
    static let textBody = Color(hex: "#3D3229")
    static let textMuted = Color(hex: "#5C5248")
    static let textSubtle = Color(hex: "#7A7168")
    static let textInverse = Color(hex: "#FDFCFA")
    static let textHandwritten = Color(hex: "#5C4A3D")
    
    // MARK: - Background Colors
    
    static let bgPrimary = Color(hex: "#FDFCFA")
    static let bgSecondary = Color(hex: "#F5F3ED")
    static let bgCard = Color(hex: "#FDFCFA")
    static let bgElevated = Color(hex: "#FFFFFF")
    
    // MARK: - Border Colors
    
    static let borderLight = Color(hex: "#E8E4DC")
    static let borderMedium = Color(hex: "#D1CDC7")
    static let borderDark = Color(hex: "#B8B0A3")
    
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
    // Display fonts (Cormorant Garamond)
    static func analysisDisplayTitle() -> Font {
        .custom("CormorantGaramond-Bold", size: 34)
    }
    
    static func analysisDisplayH2() -> Font {
        .custom("CormorantGaramond-SemiBold", size: 28)
    }
    
    static func analysisDisplayH3() -> Font {
        .custom("CormorantGaramond-SemiBold", size: 22)
    }
    
    static func analysisDisplayH4() -> Font {
        .custom("CormorantGaramond-Medium", size: 19)
    }
    
    // Body fonts (Cormorant Garamond for reading)
    static func analysisBody() -> Font {
        .custom("CormorantGaramond-Regular", size: 17)
    }
    
    static func analysisBodyLarge() -> Font {
        .custom("CormorantGaramond-Regular", size: 19)
    }
    
    static func analysisBodySmall() -> Font {
        .custom("CormorantGaramond-Regular", size: 15)
    }
    
    // UI fonts (Inter for labels and UI elements)
    static func analysisUI() -> Font {
        .custom("Inter-Regular", size: 15)
    }
    
    static func analysisUIBold() -> Font {
        .custom("Inter-SemiBold", size: 15)
    }
    
    static func analysisUISmall() -> Font {
        .custom("Inter-Regular", size: 13)
    }
    
    // Handwritten accent (Caveat)
    static func analysisHandwritten() -> Font {
        .custom("Caveat-Regular", size: 22)
    }
    
    static func analysisHandwrittenBold() -> Font {
        .custom("Caveat-SemiBold", size: 22)
    }
}

// MARK: - Color Hex Extension

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
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
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
