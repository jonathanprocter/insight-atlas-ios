import SwiftUI
import SwiftData

struct LibraryView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var environment: AppEnvironment
    
    // MARK: - SwiftData Query
    
    @Query(sort: \LibraryItem.updatedAt, order: .reverse) private var libraryItems: [LibraryItem]
    
    // MARK: - State
    
    @State private var selectedTab: LibraryTab = .all
    @State private var searchText = ""
    @State private var selectedIDs: Set<UUID> = []
    @State private var isSelectionMode = false
    @State private var showingGenerationView = false
    
    // MARK: - Computed Properties
    
    private var filteredItems: [LibraryItem] {
        var items = libraryItems
        
        // Filter by tab
        switch selectedTab {
        case .all:
            break
        case .favorites:
            items = items.filter { $0.isFavorite }
        case .recent:
            items = Array(items.prefix(10))
        case .drafts:
            items = items.filter { $0.summaryContent == nil }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            items = items.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.author.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return items
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Bar
                LibraryTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Content
                if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        gridContent
                            .padding()
                    }
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search guides")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingGenerationView = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isSelectionMode ? "Done" : "Select") {
                        isSelectionMode.toggle()
                        if !isSelectionMode {
                            selectedIDs.removeAll()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingGenerationView) {
                GenerationView()
            }
        }
    }
    
    // MARK: - Grid Content
    
    private var gridContent: some View {
        LazyVGrid(columns: gridColumns, spacing: 16) {
            ForEach(filteredItems) { item in
                NavigationLink(destination: GuideView(item: item)) {
                    LibraryItemCard(
                        item: item,
                        isSelected: selectedIDs.contains(item.id)
                    )
                    .contextMenu {
                        Button {
                            toggleFavorite(item)
                        } label: {
                            Label(
                                item.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                systemImage: item.isFavorite ? "heart.fill" : "heart"
                            )
                        }
                        
                        Button {
                            duplicateItem(item)
                        } label: {
                            Label("Duplicate", systemImage: "doc.on.doc")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            deleteItem(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .buttonStyle(.plain)
                .onTapGesture {
                    if isSelectionMode {
                        toggleSelection(item.id)
                    }
                }
            }
        }
    }
    
    // MARK: - Grid Columns
    
    private var gridColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
        ]
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Guides Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your first guide to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button {
                showingGenerationView = true
            } label: {
                Label("Create Guide", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func toggleFavorite(_ item: LibraryItem) {
        item.isFavorite.toggle()
        environment.updateLibraryItem(item)
    }
    
    private func duplicateItem(_ item: LibraryItem) {
        let duplicate = LibraryItem(
            title: "\(item.title) (Copy)",
            author: item.author,
            summaryContent: item.summaryContent,
            coverImagePath: item.coverImagePath,
            pageCount: item.pageCount,
            fileType: item.fileType,
            mode: item.mode,
            provider: item.provider,
            tone: item.tone,
            outputFormat: item.outputFormat
        )
        environment.addLibraryItem(duplicate)
    }
    
    private func deleteItem(_ item: LibraryItem) {
        environment.deleteLibraryItem(item)
    }
    
    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }
}

// MARK: - Library Tab

enum LibraryTab: String, CaseIterable {
    case all = "All"
    case favorites = "Favorites"
    case recent = "Recent"
    case drafts = "Drafts"
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .favorites: return "heart.fill"
        case .recent: return "clock.fill"
        case .drafts: return "doc.text"
        }
    }
}

// MARK: - Library Tab Bar

struct LibraryTabBar: View {
    @Binding var selectedTab: LibraryTab
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(LibraryTab.allCases, id: \.self) { tab in
                    TabButton(
                        title: tab.rawValue,
                        icon: tab.icon,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
                    }
                }
            }
        }
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color.gray.opacity(0.15))
            .cornerRadius(20)
        }
    }
}

// MARK: - Library Item Card

struct LibraryItemCard: View {
    let item: LibraryItem
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover Image
            coverImage
                .frame(height: 150)
                .clipped()
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(item.author)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                // Status and Read Time
                HStack {
                    statusBadge
                    Spacer()
                    if let readTime = item.readTime {
                        Label(readTime, systemImage: "clock")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
        }
        .frame(height: 240)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
    
    private var coverImage: some View {
        Group {
            if let imageData = item.loadCoverImageData(),
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: "book.closed")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
        }
    }
    
    private var statusBadge: some View {
        let isCompleted = item.summaryContent != nil
        let color: Color = isCompleted ? .green : .orange
        let icon = isCompleted ? "checkmark.circle.fill" : "circle.dotted"
        let text = isCompleted ? "Complete" : "Draft"
        
        return Label(text, systemImage: icon)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}
