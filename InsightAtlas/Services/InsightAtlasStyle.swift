//
//  InsightAtlasStyle.swift
//  Insight Atlas
//
//  Brand style constants for consistent UI across the app.
//  These values match the PDF generator for visual consistency.
//

import SwiftUI

// MARK: - Color Palette (Premium Cream/Gold Aesthetic)

struct InsightAtlasColors {

    // MARK: Primary Gold (Master Template 2026)
    static let gold = Color(hex: "#CBA135")         // Master Template 2026 gold
    static let goldLight = Color(hex: "#DCBE5E")    // Light gold for backgrounds
    static let goldDark = Color(hex: "#A88A1F")     // Dark gold for emphasis

    // MARK: Text Colors (Master Template 2026 - Brown/Sepia)
    static let heading = Color(hex: "#2D2520")      // Deep brown for headings
    static let body = Color(hex: "#3D3229")         // Ink for body text
    static let muted = Color(hex: "#5C5248")        // Muted brown for secondary
    static let subtle = Color(hex: "#7A7168")       // Subtle brown for hints

    // MARK: Premium Backgrounds (Master Template 2026)
    static let background = Color(hex: "#FDFCFA")   // Primary background
    static let backgroundAlt = Color(hex: "#F5F3ED") // Parchment cream - secondary
    static let cream = Color(hex: "#FEFCE8")        // Premium cream for cards
    static let card = Color(hex: "#FFFFFF")         // Card background
    static let parchment = Color(hex: "#F5F3ED")    // Classic parchment
    static let ivory = Color(hex: "#FDFCFA")        // Primary background

    // MARK: Borders & Rules
    static let rule = Color(hex: "#D4CFC5")         // Medium border
    static let ruleLight = Color(hex: "#E8E4DC")    // Light border
    static let ruleDark = Color(hex: "#B8B0A3")     // Dark border

    // MARK: Accent Colors (Premium Palette)
    static let burgundy = Color(hex: "#582534")     // Deep burgundy
    static let burgundyLight = Color(hex: "#8A5066") // Light burgundy
    static let coral = Color(hex: "#E76F51")        // Warm coral
    static let coralLight = Color(hex: "#E08B73")   // Light coral
    static let teal = Color(hex: "#2A8B7F")         // Rich teal
    static let tealLight = Color(hex: "#3BA396")    // Light teal
    static let orange = Color(hex: "#E89B5A")       // Warm orange
    static let orangeLight = Color(hex: "#F0B07A")  // Light orange

    // MARK: Brand Colors (Sepia/Ink)
    static let brandSepia = Color(hex: "#5C4A3D")   // Sepia brown
    static let brandSepiaLight = Color(hex: "#7A6A5D") // Light sepia
    static let brandInk = Color(hex: "#3D3229")     // Deep ink

    // MARK: Shadow Colors (Master Template 2026 - Brown-based)
    static let shadow = Color(hex: "#2D2520").opacity(0.08)
    static let shadowMedium = Color(hex: "#2D2520").opacity(0.12)
}

// MARK: - Typography (iOS optimized sizes)

struct InsightAtlasTypography {

    // Headings - Sans Serif
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
    static let h1 = Font.system(size: 28, weight: .bold, design: .default)
    static let h2 = Font.system(size: 22, weight: .bold, design: .default)
    static let h3 = Font.system(size: 18, weight: .semibold, design: .default)
    static let h4 = Font.system(size: 16, weight: .semibold, design: .default)

    // Body - Serif (for reading content)
    static let body = Font.system(size: 17, weight: .regular, design: .serif)
    static let bodyBold = Font.system(size: 17, weight: .bold, design: .serif)
    static let bodyItalic = Font.system(size: 17, weight: .regular, design: .serif).italic()
    static let bodySmall = Font.system(size: 15, weight: .regular, design: .serif)

    // UI Elements - Sans Serif
    static let uiBody = Font.system(size: 17, weight: .regular, design: .default)
    static let uiSubheadline = Font.system(size: 15, weight: .regular, design: .default)
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let captionBold = Font.system(size: 12, weight: .semibold, design: .default)
    static let footnote = Font.system(size: 13, weight: .regular, design: .default)
    static let button = Font.system(size: 17, weight: .semibold, design: .default)
    static let buttonSmall = Font.system(size: 15, weight: .semibold, design: .default)
}

// MARK: - Spacing

struct InsightAtlasSpacing {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 22
    static let xl: CGFloat = 32
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
    // Primary Gold (Master Template 2026)
    static let iaGold = UIColor(hex: "#C9A227")
    static let iaGoldLight = UIColor(hex: "#DCBE5E")
    static let iaGoldDark = UIColor(hex: "#A88A1F")

    // Text Colors (Master Template 2026 - Brown/Sepia)
    static let iaHeading = UIColor(hex: "#2D2520")
    static let iaBody = UIColor(hex: "#3D3229")
    static let iaMuted = UIColor(hex: "#5C5248")
    static let iaSubtle = UIColor(hex: "#7A7168")

    // Premium Backgrounds (Master Template 2026)
    static let iaBackground = UIColor(hex: "#FDFCFA")
    static let iaCream = UIColor(hex: "#FEFCE8")
    static let iaCard = UIColor(hex: "#FFFFFF")
    static let iaIvory = UIColor(hex: "#FDFCFA")
    static let iaParchment = UIColor(hex: "#F5F3ED")

    // Borders
    static let iaRule = UIColor(hex: "#D4CFC5")
    static let iaRuleLight = UIColor(hex: "#E8E4DC")

    // Accent Colors
    static let iaBurgundy = UIColor(hex: "#6B3A4A")
    static let iaCoral = UIColor(hex: "#D4735C")
    static let iaTeal = UIColor(hex: "#2A8B7F")
    static let iaOrange = UIColor(hex: "#E89B5A")

    // Brand
    static let iaSepia = UIColor(hex: "#5C4A3D")

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
            .background(InsightAtlasColors.cream)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: InsightAtlasColors.shadow, radius: 4, x: 0, y: 2)
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

// MARK: - Book Cover Service

actor BookCoverService {
    static let shared = BookCoverService()

    private var cache: [String: UIImage] = [:]
    private var inFlightTasks: [String: Task<UIImage?, Never>] = [:]

    private init() {}

    // MARK: - Cover Size

    enum CoverSize: String {
        case small = "S"   // ~45px
        case medium = "M"  // ~180px
        case large = "L"   // ~450px
    }

    // MARK: - Public API

    /// Fetch a book cover by title and author
    func fetchCover(title: String, author: String, size: CoverSize = .medium) async -> UIImage? {
        let cacheKey = "\(title)|\(author)|\(size.rawValue)"

        // Check cache first
        if let cached = cache[cacheKey] {
            return cached
        }

        // Check if there's already a request in flight
        if let existingTask = inFlightTasks[cacheKey] {
            return await existingTask.value
        }

        // Create new fetch task
        let task = Task<UIImage?, Never> {
            let image = await performFetch(title: title, author: author, size: size)
            if let image = image {
                cache[cacheKey] = image
            }
            inFlightTasks.removeValue(forKey: cacheKey)
            return image
        }

        inFlightTasks[cacheKey] = task
        return await task.value
    }

    /// Clear the cache
    func clearCache() {
        cache.removeAll()
    }

    // MARK: - Private Methods

    private func performFetch(title: String, author: String, size: CoverSize) async -> UIImage? {
        // First try to search for the book to get an OLID or ISBN
        guard let searchResult = await searchBook(title: title, author: author) else {
            return nil
        }

        // Try fetching by OLID first (most reliable)
        if let olid = searchResult.olid {
            if let image = await fetchCoverByOLID(olid: olid, size: size) {
                return image
            }
        }

        // Try ISBN if available
        if let isbn = searchResult.isbn {
            if let image = await fetchCoverByISBN(isbn: isbn, size: size) {
                return image
            }
        }

        // Try cover ID as last resort
        if let coverId = searchResult.coverId {
            if let image = await fetchCoverByCoverId(coverId: coverId, size: size) {
                return image
            }
        }

        return nil
    }

    private func searchBook(title: String, author: String) async -> BookSearchResult? {
        // Clean and encode search terms
        let cleanTitle = title.replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let cleanAuthor = author.components(separatedBy: ",").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? author

        let searchQuery = "\(cleanTitle) \(cleanAuthor)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let urlString = "https://openlibrary.org/search.json?q=\(searchQuery)&limit=1&fields=key,title,author_name,isbn,cover_i,edition_key"

        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            let searchResponse = try JSONDecoder().decode(OpenLibrarySearchResponse.self, from: data)

            guard let firstDoc = searchResponse.docs.first else { return nil }

            return BookSearchResult(
                olid: firstDoc.edition_key?.first,
                isbn: firstDoc.isbn?.first(where: { $0.count == 13 }) ?? firstDoc.isbn?.first,
                coverId: firstDoc.cover_i
            )
        } catch {
            print("BookCoverService: Search error - \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchCoverByOLID(olid: String, size: CoverSize) async -> UIImage? {
        let urlString = "https://covers.openlibrary.org/b/olid/\(olid)-\(size.rawValue).jpg"
        return await downloadImage(from: urlString)
    }

    private func fetchCoverByISBN(isbn: String, size: CoverSize) async -> UIImage? {
        let urlString = "https://covers.openlibrary.org/b/isbn/\(isbn)-\(size.rawValue).jpg"
        return await downloadImage(from: urlString)
    }

    private func fetchCoverByCoverId(coverId: Int, size: CoverSize) async -> UIImage? {
        let urlString = "https://covers.openlibrary.org/b/id/\(coverId)-\(size.rawValue).jpg"
        return await downloadImage(from: urlString)
    }

    private func downloadImage(from urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            // Open Library returns a 1x1 pixel transparent GIF for missing covers
            // Check if the data is too small to be a real cover
            guard data.count > 1000 else { return nil }

            return UIImage(data: data)
        } catch {
            print("BookCoverService: Download error - \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Search Models

private struct BookSearchResult {
    let olid: String?
    let isbn: String?
    let coverId: Int?
}

private struct OpenLibrarySearchResponse: Codable {
    let docs: [OpenLibraryDoc]
}

private struct OpenLibraryDoc: Codable {
    let key: String?
    let title: String?
    let author_name: [String]?
    let isbn: [String]?
    let cover_i: Int?
    let edition_key: [String]?
}

// MARK: - Async Book Cover Image View

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
