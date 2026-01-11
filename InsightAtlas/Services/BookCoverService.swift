//
//  BookCoverService.swift
//  Insight Atlas
//
//  Fetches book covers from Open Library Covers API
//

import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.insightatlas", category: "BookCoverService")

// MARK: - Book Cover Service

actor BookCoverService {
    static let shared = BookCoverService()

    // MARK: - API Configuration

    private enum APIEndpoints {
        static let openLibrarySearch = "https://openlibrary.org/search.json"
        static let openLibraryCovers = "https://covers.openlibrary.org/b"
        static let googleBooksSearch = "https://www.googleapis.com/books/v1/volumes"
    }

    private var cache: [String: UIImage] = [:]
    private var inFlightTasks: [String: Task<UIImage?, Never>] = [:]

    /// Custom URLSession with appropriate timeouts for cover fetching
    private let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15  // 15 seconds for request
        config.timeoutIntervalForResource = 30 // 30 seconds total
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    private init() {}

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

    /// Fetch a book cover by ISBN
    func fetchCover(isbn: String, size: CoverSize = .medium) async -> UIImage? {
        let cacheKey = "isbn:\(isbn)|\(size.rawValue)"

        if let cached = cache[cacheKey] {
            return cached
        }

        if let existingTask = inFlightTasks[cacheKey] {
            return await existingTask.value
        }

        let task = Task<UIImage?, Never> {
            let image = await fetchCoverByISBN(isbn: isbn, size: size)
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

    // MARK: - Cover Size

    enum CoverSize: String {
        case small = "S"   // ~45px
        case medium = "M"  // ~180px
        case large = "L"   // ~450px
    }

    // MARK: - Private Methods

    private func performFetch(title: String, author: String, size: CoverSize) async -> UIImage? {
        // STEP 1: Try Open Library first
        if let searchResult = await searchBook(title: title, author: author) {
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
        }

        // STEP 2: Fall back to Google Books API
        if let googleImage = await fetchFromGoogleBooks(title: title, author: author, size: size) {
            return googleImage
        }

        // STEP 3: Return nil - caller will use stylized placeholder
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

        let urlString = "\(APIEndpoints.openLibrarySearch)?q=\(searchQuery)&limit=1&fields=key,title,author_name,isbn,cover_i,edition_key"

        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await urlSession.data(from: url)

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
            logger.debug("Search error for '\(title, privacy: .public)': \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchCoverByOLID(olid: String, size: CoverSize) async -> UIImage? {
        let urlString = "\(APIEndpoints.openLibraryCovers)/olid/\(olid)-\(size.rawValue).jpg"
        return await downloadImage(from: urlString)
    }

    private func fetchCoverByISBN(isbn: String, size: CoverSize) async -> UIImage? {
        let urlString = "\(APIEndpoints.openLibraryCovers)/isbn/\(isbn)-\(size.rawValue).jpg"
        return await downloadImage(from: urlString)
    }

    private func fetchCoverByCoverId(coverId: Int, size: CoverSize) async -> UIImage? {
        let urlString = "\(APIEndpoints.openLibraryCovers)/id/\(coverId)-\(size.rawValue).jpg"
        return await downloadImage(from: urlString)
    }

    private func downloadImage(from urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await urlSession.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            // Open Library returns a 1x1 pixel transparent GIF for missing covers
            // Check if the data is too small to be a real cover
            guard data.count > 1000 else { return nil }

            return UIImage(data: data)
        } catch {
            logger.debug("Download error for \(urlString, privacy: .public): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Google Books API Integration

    /// Fetch a book cover from Google Books API as fallback
    private func fetchFromGoogleBooks(title: String, author: String, size: CoverSize) async -> UIImage? {
        // Clean and encode search terms
        let cleanTitle = title.replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let cleanAuthor = author.components(separatedBy: ",").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? author

        let searchQuery = "intitle:\(cleanTitle)+inauthor:\(cleanAuthor)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let urlString = "\(APIEndpoints.googleBooksSearch)?q=\(searchQuery)&maxResults=1&fields=items(volumeInfo/imageLinks)"

        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await urlSession.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            let searchResponse = try JSONDecoder().decode(GoogleBooksSearchResponse.self, from: data)

            guard let imageLinks = searchResponse.items?.first?.volumeInfo?.imageLinks else {
                return nil
            }

            // Select appropriate image URL based on size
            let imageUrl: String?
            switch size {
            case .large:
                imageUrl = imageLinks.extraLarge ?? imageLinks.large ?? imageLinks.medium ?? imageLinks.thumbnail
            case .medium:
                imageUrl = imageLinks.medium ?? imageLinks.small ?? imageLinks.thumbnail
            case .small:
                imageUrl = imageLinks.smallThumbnail ?? imageLinks.thumbnail
            }

            guard var coverUrl = imageUrl else { return nil }

            // Google Books returns HTTP URLs, upgrade to HTTPS
            coverUrl = coverUrl.replacingOccurrences(of: "http://", with: "https://")

            // Remove zoom parameter for better quality
            if let range = coverUrl.range(of: "&zoom=") {
                let endIndex = coverUrl[range.upperBound...].firstIndex(of: "&") ?? coverUrl.endIndex
                coverUrl.removeSubrange(range.lowerBound..<endIndex)
            }

            return await downloadImage(from: coverUrl)

        } catch {
            logger.debug("Google Books error for '\(title, privacy: .public)': \(error.localizedDescription)")
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

// MARK: - Google Books Models

private struct GoogleBooksSearchResponse: Codable {
    let items: [GoogleBooksItem]?
}

private struct GoogleBooksItem: Codable {
    let volumeInfo: GoogleBooksVolumeInfo?
}

private struct GoogleBooksVolumeInfo: Codable {
    let imageLinks: GoogleBooksImageLinks?
}

private struct GoogleBooksImageLinks: Codable {
    let smallThumbnail: String?
    let thumbnail: String?
    let small: String?
    let medium: String?
    let large: String?
    let extraLarge: String?
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
                // Stylized fallback when no cover found from Open Library or Google Books
                StylizedBookCoverPlaceholder(
                    title: title,
                    author: author,
                    accentColor: fallbackColor
                )
            }
        }
        .task {
            await loadCover()
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

// MARK: - Book Cover Card View (for library items)

struct BookCoverCardView: View {
    let title: String
    let author: String
    let accentColor: Color
    let size: CGSize

    init(
        title: String,
        author: String,
        accentColor: Color = InsightAtlasColors.gold,
        size: CGSize = CGSize(width: 52, height: 52)
    ) {
        self.title = title
        self.author = author
        self.accentColor = accentColor
        self.size = size
    }

    var body: some View {
        AsyncBookCoverImage(
            title: title,
            author: author,
            size: .medium,
            fallbackColor: accentColor
        )
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
    }
}

// MARK: - Circular Book Cover View (matching current design)

struct CircularBookCoverView: View {
    let title: String
    let author: String
    let accentColor: Color
    let diameter: CGFloat

    @State private var coverImage: UIImage?
    @State private var isLoading = true

    init(
        title: String,
        author: String,
        accentColor: Color = InsightAtlasColors.gold,
        diameter: CGFloat = 52
    ) {
        self.title = title
        self.author = author
        self.accentColor = accentColor
        self.diameter = diameter
    }

    var body: some View {
        ZStack {
            if let image = coverImage {
                // Real book cover from Open Library or Google Books
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: diameter, height: diameter)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(accentColor.opacity(0.5), lineWidth: 2)
                    )
            } else if isLoading {
                // Loading state
                Circle()
                    .fill(accentColor.opacity(0.1))
                    .frame(width: diameter, height: diameter)

                Circle()
                    .stroke(accentColor, lineWidth: 2)
                    .frame(width: diameter, height: diameter)

                ProgressView()
                    .tint(accentColor)
                    .scaleEffect(0.7)
            } else {
                // Stylized fallback when no cover found
                StylizedBookCoverPlaceholder(
                    title: title,
                    author: author,
                    accentColor: accentColor
                )
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(accentColor.opacity(0.5), lineWidth: 2)
                )
            }
        }
        .task {
            await loadCover()
        }
    }

    private func loadCover() async {
        isLoading = true

        let image = await BookCoverService.shared.fetchCover(
            title: title,
            author: author,
            size: .medium
        )

        await MainActor.run {
            self.coverImage = image
            self.isLoading = false
        }
    }
}

// MARK: - Stylized Book Cover Placeholder

/// A beautifully styled fallback book cover that displays the title and author
/// when no real cover image is available from Open Library
struct StylizedBookCoverPlaceholder: View {
    let title: String
    let author: String
    let accentColor: Color

    /// Available cover styles that rotate based on title hash
    private enum CoverStyle: CaseIterable {
        case classic       // Elegant with border frame
        case modern        // Clean minimalist
        case vintage       // Aged paper look
        case academic      // Scholarly appearance
    }

    /// Deterministic style selection based on title
    private var coverStyle: CoverStyle {
        let hash = abs(title.hashValue)
        return CoverStyle.allCases[hash % CoverStyle.allCases.count]
    }

    /// Background gradient colors based on style
    private var backgroundGradient: LinearGradient {
        switch coverStyle {
        case .classic:
            return LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.12, blue: 0.10),
                    Color(red: 0.22, green: 0.18, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .modern:
            return LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.14, blue: 0.18),
                    Color(red: 0.08, green: 0.10, blue: 0.14)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .vintage:
            return LinearGradient(
                colors: [
                    Color(red: 0.28, green: 0.24, blue: 0.18),
                    Color(red: 0.22, green: 0.18, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .academic:
            return LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.12, blue: 0.16),
                    Color(red: 0.04, green: 0.08, blue: 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    /// Accent line color
    private var accentLineColor: Color {
        switch coverStyle {
        case .classic:
            return InsightAtlasColors.gold
        case .modern:
            return accentColor
        case .vintage:
            return Color(red: 0.85, green: 0.75, blue: 0.55)
        case .academic:
            return InsightAtlasColors.gold.opacity(0.8)
        }
    }

    /// Get initials from title (first letter of each word, max 2)
    private var titleInitials: String {
        let words = title.split(separator: " ")
            .filter { !["the", "a", "an", "of", "and", "or", "in", "on", "at", "to", "for"].contains($0.lowercased()) }
        let initials = words.prefix(2).compactMap { $0.first }.map { String($0).uppercased() }
        return initials.joined()
    }

    /// Truncated title for display
    private var displayTitle: String {
        if title.count <= 40 {
            return title
        }
        return String(title.prefix(37)) + "..."
    }

    /// Truncated author for display
    private var displayAuthor: String {
        let name = author.components(separatedBy: ",").first ?? author
        if name.count <= 25 {
            return name
        }
        return String(name.prefix(22)) + "..."
    }

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 80 || geometry.size.height < 80

            ZStack {
                // Background
                backgroundGradient

                // Decorative elements based on style
                decorativeOverlay(size: geometry.size)

                // Content
                if isCompact {
                    // Compact view: just initials
                    compactContent
                } else {
                    // Full view: title and author
                    fullContent(size: geometry.size)
                }
            }
        }
    }

    @ViewBuilder
    private func decorativeOverlay(size: CGSize) -> some View {
        switch coverStyle {
        case .classic:
            // Elegant double border frame
            RoundedRectangle(cornerRadius: 4)
                .stroke(accentLineColor.opacity(0.6), lineWidth: 1)
                .padding(6)
            RoundedRectangle(cornerRadius: 2)
                .stroke(accentLineColor.opacity(0.3), lineWidth: 0.5)
                .padding(10)

        case .modern:
            // Geometric accent line
            VStack {
                Spacer()
                Rectangle()
                    .fill(accentLineColor)
                    .frame(height: 3)
                    .padding(.horizontal, size.width * 0.15)
                    .padding(.bottom, size.height * 0.12)
            }

        case .vintage:
            // Corner flourishes
            VStack {
                HStack {
                    cornerFlourish
                    Spacer()
                    cornerFlourish.scaleEffect(x: -1, y: 1)
                }
                Spacer()
                HStack {
                    cornerFlourish.scaleEffect(x: 1, y: -1)
                    Spacer()
                    cornerFlourish.scaleEffect(x: -1, y: -1)
                }
            }
            .padding(8)

        case .academic:
            // Subtle horizontal lines
            VStack(spacing: 0) {
                Rectangle()
                    .fill(accentLineColor.opacity(0.4))
                    .frame(height: 1)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                Spacer()
                Rectangle()
                    .fill(accentLineColor.opacity(0.4))
                    .frame(height: 1)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
        }
    }

    private var cornerFlourish: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 12))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 12, y: 0))
        }
        .stroke(accentLineColor.opacity(0.5), lineWidth: 1)
        .frame(width: 12, height: 12)
    }

    private var compactContent: some View {
        Text(titleInitials.isEmpty ? "IA" : titleInitials)
            .font(.system(size: 18, weight: .semibold, design: .serif))
            .foregroundColor(accentLineColor)
    }

    private func fullContent(size: CGSize) -> some View {
        VStack(spacing: 0) {
            Spacer()

            // Title
            Text(displayTitle)
                .font(.system(size: titleFontSize(for: size), weight: .medium, design: .serif))
                .foregroundColor(.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, size.width * 0.1)

            // Decorative divider
            Rectangle()
                .fill(accentLineColor)
                .frame(width: min(size.width * 0.4, 60), height: 1)
                .padding(.vertical, size.height * 0.04)

            // Author
            Text(displayAuthor)
                .font(.system(size: authorFontSize(for: size), weight: .regular, design: .serif))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, size.width * 0.08)

            Spacer()
        }
        .padding(.vertical, size.height * 0.08)
    }

    private func titleFontSize(for size: CGSize) -> CGFloat {
        let baseSize = min(size.width, size.height)
        if baseSize < 100 { return 10 }
        if baseSize < 150 { return 12 }
        return 14
    }

    private func authorFontSize(for size: CGSize) -> CGFloat {
        let baseSize = min(size.width, size.height)
        if baseSize < 100 { return 8 }
        if baseSize < 150 { return 9 }
        return 11
    }
}

// MARK: - Preview

#Preview("Book Cover Views") {
    ScrollView {
        VStack(spacing: 24) {
            Text("With Real Covers")
                .font(.headline)

            HStack(spacing: 16) {
                // Circular cover
                CircularBookCoverView(
                    title: "Atomic Habits",
                    author: "James Clear",
                    accentColor: InsightAtlasColors.gold
                )

                // Card cover
                BookCoverCardView(
                    title: "Thinking, Fast and Slow",
                    author: "Daniel Kahneman",
                    accentColor: InsightAtlasColors.burgundy,
                    size: CGSize(width: 60, height: 90)
                )
            }

            Divider()

            Text("Stylized Placeholders")
                .font(.headline)

            // Showcase different styles
            HStack(spacing: 12) {
                StylizedBookCoverPlaceholder(
                    title: "The Art of War",
                    author: "Sun Tzu",
                    accentColor: InsightAtlasColors.gold
                )
                .frame(width: 80, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                StylizedBookCoverPlaceholder(
                    title: "Meditations",
                    author: "Marcus Aurelius",
                    accentColor: InsightAtlasColors.burgundy
                )
                .frame(width: 80, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                StylizedBookCoverPlaceholder(
                    title: "The Republic",
                    author: "Plato",
                    accentColor: InsightAtlasColors.teal
                )
                .frame(width: 80, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Larger placeholder
            StylizedBookCoverPlaceholder(
                title: "A Brief History of Time",
                author: "Stephen Hawking",
                accentColor: InsightAtlasColors.gold
            )
            .frame(width: 120, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Compact circular
            StylizedBookCoverPlaceholder(
                title: "1984",
                author: "George Orwell",
                accentColor: InsightAtlasColors.gold
            )
            .frame(width: 52, height: 52)
            .clipShape(Circle())
        }
        .padding()
    }
}
