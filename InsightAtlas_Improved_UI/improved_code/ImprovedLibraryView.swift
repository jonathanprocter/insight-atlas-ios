import SwiftUI

// MARK: - Improved Library View

struct ImprovedLibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var searchText = ""
    @State private var selectedFilter: LibraryFilter = .all
    @State private var viewMode: ViewMode = .grid
    @State private var showingNewAnalysis = false
    
    enum ViewMode {
        case grid, list
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                InsightAtlasColors.background
                    .ignoresSafeArea()
                
                if viewModel.analyses.isEmpty {
                    EmptyLibraryView(onAddBook: { showingNewAnalysis = true })
                } else {
                    ScrollView {
                        VStack(spacing: InsightAtlasSpacing.md) {
                            // Search bar
                            SearchBar(text: $searchText, placeholder: "Search your library")
                                .padding(.horizontal)
                            
                            // Filter chips
                            FilterChipsView(selectedFilter: $selectedFilter)
                                .padding(.horizontal)
                            
                            // Content
                            if viewMode == .grid {
                                GridLibraryView(
                                    analyses: filteredAnalyses,
                                    onSelect: { analysis in
                                        // Handle selection
                                    }
                                )
                            } else {
                                ListLibraryView(
                                    analyses: filteredAnalyses,
                                    onSelect: { analysis in
                                        // Handle selection
                                    }
                                )
                            }
                            
                            Spacer(minLength: 40)
                        }
                        .padding(.top)
                    }
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: { /* Search action */ }) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(InsightAtlasColors.gold)
                        }
                        
                        Button(action: { /* Filter action */ }) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundColor(InsightAtlasColors.gold)
                        }
                        
                        Menu {
                            Button(action: { viewMode = .grid }) {
                                Label("Grid View", systemImage: "square.grid.2x2")
                            }
                            Button(action: { viewMode = .list }) {
                                Label("List View", systemImage: "list.bullet")
                            }
                        } label: {
                            Image(systemName: viewMode == .grid ? "square.grid.2x2" : "list.bullet")
                                .foregroundColor(InsightAtlasColors.gold)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingNewAnalysis) {
                NewAnalysisView(onCreate: { analysis in
                    viewModel.addAnalysis(analysis)
                    showingNewAnalysis = false
                })
            }
        }
    }
    
    var filteredAnalyses: [BookAnalysis] {
        var result = viewModel.analyses
        
        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .favorites:
            result = result.filter { $0.isFavorite }
        case .recent:
            result = result.sorted { $0.dateModified > $1.dateModified }.prefix(10).map { $0 }
        case .drafts:
            result = result.filter { $0.status == .draft }
        }
        
        // Apply search
        if !searchText.isEmpty {
            result = result.filter {
                $0.bookTitle.localizedCaseInsensitiveContains(searchText) ||
                $0.bookAuthor.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
}

// MARK: - Filter Chips

enum LibraryFilter: String, CaseIterable {
    case all = "All"
    case favorites = "Favorites"
    case recent = "Recent"
    case drafts = "Drafts"
}

struct FilterChipsView: View {
    @Binding var selectedFilter: LibraryFilter
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibraryFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(InsightAtlasTypography.labelSmall)
                .foregroundColor(isSelected ? .white : InsightAtlasColors.heading)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? InsightAtlasColors.gold : InsightAtlasColors.backgroundAlt)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? InsightAtlasColors.gold : InsightAtlasColors.rule, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Grid Library View

struct GridLibraryView: View {
    let analyses: [BookAnalysis]
    let onSelect: (BookAnalysis) -> Void
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(analyses) { analysis in
                GridAnalysisCard(analysis: analysis) {
                    onSelect(analysis)
                }
            }
        }
        .padding(.horizontal)
    }
}

struct GridAnalysisCard: View {
    let analysis: BookAnalysis
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Accent bar
                Rectangle()
                    .fill(Color(hex: analysis.category.color))
                    .frame(height: 4)
                
                VStack(alignment: .leading, spacing: 12) {
                    // Book cover or icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(InsightAtlasColors.backgroundAlt)
                            .frame(height: 120)
                        
                        Image("Logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .opacity(0.3)
                    }
                    
                    // Book title
                    Text(analysis.bookTitle)
                        .font(InsightAtlasTypography.h3)
                        .foregroundColor(InsightAtlasColors.heading)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Author
                    Text("By \(analysis.bookAuthor)")
                        .font(InsightAtlasTypography.caption)
                        .foregroundColor(InsightAtlasColors.muted)
                        .lineLimit(1)
                    
                    // Date
                    Text("Updated \(analysis.dateModifiedFormatted)")
                        .font(InsightAtlasTypography.caption)
                        .foregroundColor(InsightAtlasColors.muted)
                    
                    // Status badge
                    StatusBadge(status: analysis.status)
                }
                .padding(12)
            }
            .background(InsightAtlasColors.card)
            .cornerRadius(InsightAtlasRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: InsightAtlasRadius.medium)
                    .stroke(InsightAtlasColors.rule, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - List Library View

struct ListLibraryView: View {
    let analyses: [BookAnalysis]
    let onSelect: (BookAnalysis) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(analyses) { analysis in
                ListAnalysisRow(analysis: analysis) {
                    onSelect(analysis)
                }
            }
        }
        .padding(.horizontal)
    }
}

struct ListAnalysisRow: View {
    let analysis: BookAnalysis
    let onTap: () -> Void
    @State private var showingActions = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: analysis.category.color).opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: analysis.category.color))
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(analysis.bookTitle)
                        .font(InsightAtlasTypography.body)
                        .foregroundColor(InsightAtlasColors.heading)
                        .lineLimit(1)
                    
                    Text("\(analysis.bookAuthor) • \(analysis.dateModifiedFormatted)")
                        .font(InsightAtlasTypography.caption)
                        .foregroundColor(InsightAtlasColors.muted)
                }
                
                Spacer()
                
                // Status badge
                StatusBadge(status: analysis.status)
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(InsightAtlasColors.muted)
            }
            .padding(12)
            .background(InsightAtlasColors.card)
            .cornerRadius(InsightAtlasRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: InsightAtlasRadius.medium)
                    .stroke(InsightAtlasColors.rule, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: { /* Favorite */ }) {
                Label("Favorite", systemImage: "star")
            }
            Button(action: { /* Export */ }) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive, action: { /* Delete */ }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: AnalysisStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 10))
            
            Text(status.rawValue)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(status.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.15))
        .cornerRadius(12)
    }
}

// MARK: - Library ViewModel

class LibraryViewModel: ObservableObject {
    @Published var analyses: [BookAnalysis] = []
    
    init() {
        // Load sample data
        loadSampleData()
    }
    
    func addAnalysis(_ analysis: BookAnalysis) {
        analyses.append(analysis)
    }
    
    private func loadSampleData() {
        analyses = [
            BookAnalysis(
                bookTitle: "The Extended Mind",
                bookAuthor: "Annie Murphy Paul",
                category: .science,
                status: .completed
            ),
            BookAnalysis(
                bookTitle: "Thinking, Fast and Slow",
                bookAuthor: "Daniel Kahneman",
                category: .psychology,
                status: .inProgress
            ),
            BookAnalysis(
                bookTitle: "Atomic Habits",
                bookAuthor: "James Clear",
                category: .selfHelp,
                status: .draft
            )
        ]
    }
}

// MARK: - Analysis Status

enum AnalysisStatus: String {
    case completed = "Completed"
    case inProgress = "In Progress"
    case draft = "Draft"
    
    var icon: String {
        switch self {
        case .completed: return "checkmark.circle.fill"
        case .inProgress: return "clock.fill"
        case .draft: return "doc.text.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .completed: return InsightAtlasColors.gold
        case .inProgress: return InsightAtlasColors.coral
        case .draft: return InsightAtlasColors.muted
        }
    }
}

// MARK: - Preview

#Preview {
    ImprovedLibraryView()
}
