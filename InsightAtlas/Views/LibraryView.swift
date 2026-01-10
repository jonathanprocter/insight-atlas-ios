import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var environment: AppEnvironment
    
    @State private var selectedFilter: LibraryFilter = .all
    @State private var searchText = ""
    @State private var showingGenerationView = false
    @State private var libraryItems: [LibraryItem] = []
    
    private var filteredItems: [LibraryItem] {
        var items = libraryItems
        
        switch selectedFilter {
        case .all: break
        case .favorites: items = items.filter { $0.isFavorite == true }
        case .recent: items = Array(items.prefix(10))
        case .completed: items = items.filter { $0.summaryContent != nil }
        case .inProgress: items = items.filter { $0.summaryContent == nil }
        }
        
        if !searchText.isEmpty {
            items = items.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.author.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return items
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(LibraryFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                title: filter.displayName,
                                isSelected: selectedFilter == filter
                            ) {
                                selectedFilter = filter
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                
                Divider()
                
                if filteredItems.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            NavigationLink(destination: AnalysisDetailView(item: item)) {
                                BookRow(item: item)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteItem(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    toggleFavorite(item)
                                } label: {
                                    Label("Favorite", systemImage: "heart")
                                }
                                .tint(AnalysisTheme.primaryGold)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Library")
            .searchable(text: $searchText, prompt: "Search")
            .toolbar {
                Button {
                    showingGenerationView = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
            }
            .tint(AnalysisTheme.primaryGold)
            .sheet(isPresented: $showingGenerationView) {
                GenerationView()
            }
            .onAppear {
                loadLibraryItems()
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "books.vertical")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(.secondary)
            Text("No guides yet")
                .font(.title3)
                .fontWeight(.medium)
            Text("Create your first guide to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                showingGenerationView = true
            } label: {
                Text("Create Guide")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AnalysisTheme.primaryGold)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func loadLibraryItems() {
        libraryItems = DataManager.shared.loadLibraryItems()
            .sorted { $0.updatedAt > $1.updatedAt }
    }
    
    private func toggleFavorite(_ item: LibraryItem) {
        var mutableItem = item
        mutableItem.isFavorite = !(item.isFavorite ?? false)
        environment.updateLibraryItem(mutableItem)
        loadLibraryItems()
    }
    
    private func deleteItem(_ item: LibraryItem) {
        environment.deleteLibraryItem(item)
        loadLibraryItems()
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? AnalysisTheme.primaryGold : Color(.systemGray6))
                )
        }
    }
}

struct BookRow: View {
    let item: LibraryItem
    
    var body: some View {
        HStack(spacing: 12) {
            coverImage
                .frame(width: 60, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)
                Text(item.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(item.summaryContent != nil ? AnalysisTheme.primaryGold : Color.secondary)
                            .frame(width: 6, height: 6)
                        Text(item.summaryContent != nil ? "Complete" : "Draft")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let readTime = item.readTime {
                        Text("·").foregroundStyle(.secondary)
                        Text(readTime)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if item.isFavorite == true {
                        Text("·").foregroundStyle(.secondary)
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(AnalysisTheme.primaryGold)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
    
    private var coverImage: some View {
        Group {
            if let coverPath = item.coverImagePath,
               let imageData = loadCoverImageData(from: coverPath),
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color(.systemGray5)
                    Image(systemName: "book.closed")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private func loadCoverImageData(from path: String) -> Data? {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let fileURL = documentsDir.appendingPathComponent(path)
        return try? Data(contentsOf: fileURL)
    }
}

extension LibraryItem {
    var readTime: String? {
        guard let wordCount = governedWordCount else { return nil }
        let minutes = wordCount / 200
        if minutes < 1 {
            return "<1 min"
        }
        return "\(minutes) min"
    }
}
