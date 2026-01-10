import SwiftUI

// MARK: - Book Analysis Model

struct BookAnalysis: Identifiable {
    let id: UUID
    var bookTitle: String
    var bookAuthor: String
    var category: BookCategory
    var status: AnalysisStatus
    var dateCreated: Date
    var dateModified: Date
    var isFavorite: Bool
    var atAGlance: AtAGlance?
    
    init(
        id: UUID = UUID(),
        bookTitle: String,
        bookAuthor: String,
        category: BookCategory,
        status: AnalysisStatus = .draft,
        dateCreated: Date = Date(),
        dateModified: Date = Date(),
        isFavorite: Bool = false,
        atAGlance: AtAGlance? = nil
    ) {
        self.id = id
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
        self.category = category
        self.status = status
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.isFavorite = isFavorite
        self.atAGlance = atAGlance
    }
    
    var dateModifiedFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: dateModified)
    }
}

// MARK: - At A Glance

struct AtAGlance {
    var coreThesis: String
    var keyInsights: [String]
    var practicalApplications: [String]
}

// MARK: - Book Category

enum BookCategory: String, CaseIterable, Identifiable {
    case science = "Science"
    case psychology = "Psychology"
    case philosophy = "Philosophy"
    case business = "Business"
    case selfHelp = "Self-Help"
    case history = "History"
    case biography = "Biography"
    case fiction = "Fiction"
    case other = "Other"
    
    var id: String { rawValue }
    
    var color: String {
        switch self {
        case .science: return "#CBA135"  // Gold
        case .psychology: return "#582534"  // Burgundy
        case .philosophy: return "#7A3A4D"  // Burgundy Light
        case .business: return "#E76F51"  // Coral
        case .selfHelp: return "#F09A85"  // Coral Light
        case .history: return "#A88A2D"  // Gold Dark
        case .biography: return "#DCBE5E"  // Gold Light
        case .fiction: return "#4A5568"  // Muted
        case .other: return "#D1CDC7"  // Rule
        }
    }
    
    var icon: String {
        switch self {
        case .science: return "flask.fill"
        case .psychology: return "brain.head.profile"
        case .philosophy: return "lightbulb.fill"
        case .business: return "briefcase.fill"
        case .selfHelp: return "person.fill"
        case .history: return "clock.fill"
        case .biography: return "person.crop.circle.fill"
        case .fiction: return "book.fill"
        case .other: return "square.grid.2x2.fill"
        }
    }
}

// MARK: - Analysis Status

enum AnalysisStatus: String, CaseIterable {
    case draft = "Draft"
    case inProgress = "In Progress"
    case completed = "Completed"
    
    var icon: String {
        switch self {
        case .draft: return "doc.text.fill"
        case .inProgress: return "clock.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .draft: return InsightAtlasColors.muted
        case .inProgress: return InsightAtlasColors.coral
        case .completed: return InsightAtlasColors.gold
        }
    }
}

// MARK: - Dashboard Stats

struct DashboardStats {
    var totalAnalyses: Int
    var thisMonth: Int
    var favorites: Int
    var exports: Int
}

// MARK: - Sidebar Section

enum SidebarSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case library = "Library"
    case favorites = "Favorites"
    case drafts = "Drafts"
    case exports = "Exports"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .library: return "books.vertical.fill"
        case .favorites: return "star.fill"
        case .drafts: return "doc.text.fill"
        case .exports: return "arrow.down.doc.fill"
        case .settings: return "gearshape.fill"
        }
    }
    
    static var mainSections: [SidebarSection] {
        [.dashboard, .library]
    }
    
    static var librarySections: [SidebarSection] {
        [.favorites, .drafts, .exports]
    }
}
