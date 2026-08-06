import SwiftUI
import UIKit

struct LibraryView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var dataManager: DataManager

    @AppStorage("premium_library_layout") private var layoutRawValue = PremiumLibraryLayout.grid.rawValue

    @State private var selectedFilter: PremiumLibraryFilter = .all
    @State private var selectedSort: PremiumLibrarySort = .recentlyUpdated
    @State private var searchText = ""
    @State private var showingGenerationView = false
    @State private var showingLibraryOptions = false
    @State private var pendingDelete: LibraryItem?
    @State private var sharePayload: LibrarySharePayload?
    @State private var exportError: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var layout: PremiumLibraryLayout {
        get { PremiumLibraryLayout(rawValue: layoutRawValue) ?? .grid }
        nonmutating set { layoutRawValue = newValue.rawValue }
    }

    private var filteredItems: [LibraryItem] {
        var items = dataManager.libraryItems

        switch selectedFilter {
        case .all: break
        case .favorites:
            items = items.filter { $0.isFavorite == true }
        case .recent:
            items = Array(
                items
                    .sorted { $0.updatedAt > $1.updatedAt }
                    .prefix(10)
            )
        case .drafts:
            items = items.filter { $0.summaryContent?.isEmpty != false }
        }

        if !searchText.isEmpty {
            items = items.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.author.localizedCaseInsensitiveContains(searchText) ||
                (item.summaryContent?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        switch selectedSort {
        case .recentlyUpdated:
            items.sort { $0.updatedAt > $1.updatedAt }
        case .recentlyCreated:
            items.sort { $0.createdAt > $1.createdAt }
        case .title:
            items.sort {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case .author:
            items.sort {
                $0.author.localizedCaseInsensitiveCompare($1.author) == .orderedAscending
            }
        }

        return items
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                libraryHeader

                if filteredItems.isEmpty {
                    emptyState
                } else {
                    Group {
                        switch layout {
                        case .grid:
                            gridContent
                        case .list:
                            listContent
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.99)))
                }
            }
            .background(PremiumUI.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .tint(PremiumUI.gold)
            .sheet(isPresented: $showingGenerationView) {
                GenerationView()
            }
            .sheet(isPresented: $showingLibraryOptions) {
                PremiumLibraryOptionsSheet(
                    selectedSort: $selectedSort,
                    selectedLayout: Binding(
                        get: { layout },
                        set: { layout = $0 }
                    )
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $sharePayload) { payload in
                ShareSheet(activityItems: [payload.url])
            }
            .alert(
                "Delete Guide?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                presenting: pendingDelete
            ) { item in
                Button("Delete", role: .destructive) {
                    deleteItem(item)
                }
                Button("Cancel", role: .cancel) {}
            } message: { item in
                Text("“\(item.title)” and its saved files will be removed from this device.")
            }
            .alert(
                "Unable to Export",
                isPresented: Binding(
                    get: { exportError != nil },
                    set: { if !$0 { exportError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError ?? "The guide could not be exported.")
            }
        }
    }

    private var libraryHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Library")
                        .font(PremiumUI.display(34, .bold))
                        .foregroundStyle(PremiumUI.ink)

                    Text("\(dataManager.libraryItems.count) \(dataManager.libraryItems.count == 1 ? "Guide" : "Guides")")
                        .font(PremiumUI.ui(15, .regular))
                        .foregroundStyle(PremiumUI.secondaryText)
                }

                Spacer()

                Button {
                    showingLibraryOptions = true
                    PremiumHaptics.selection()
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PremiumUI.ink)
                        .frame(width: 44, height: 44)
                        .background(PremiumUI.chipFill, in: Circle())
                }
                .accessibilityLabel("Library filters and sorting")

                Button {
                    showingGenerationView = true
                    PremiumHaptics.impact()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(PremiumUI.gold, in: Circle())
                        .shadow(color: PremiumUI.gold.opacity(0.25), radius: 6, x: 0, y: 3)
                }
                .accessibilityLabel("Create a new guide")
            }

            PremiumSearchField(
                text: $searchText,
                placeholder: "Search your library"
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(PremiumLibraryFilter.allCases) { filter in
                        Button {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                                selectedFilter = filter
                            }
                            PremiumHaptics.selection()
                        } label: {
                            Text(filter.rawValue)
                                .font(PremiumUI.ui(15, selectedFilter == filter ? .semibold : .regular))
                                .foregroundStyle(selectedFilter == filter ? Color.white : PremiumUI.ink)
                                .padding(.horizontal, 17)
                                .frame(height: 40)
                                .background(
                                    selectedFilter == filter ? PremiumUI.gold : PremiumUI.chipFill,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(PremiumUI.background)
    }

    private var gridContent: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ],
                spacing: 16
            ) {
                ForEach(filteredItems) { item in
                    NavigationLink {
                        AnalysisDetailView(item: item)
                            .toolbar(.visible, for: .navigationBar)
                    } label: {
                        PremiumGuideGridCard(
                            item: item,
                            status: status(for: item),
                            accentColor: accentColor(for: item)
                        )
                    }
                    .buttonStyle(PremiumCardButtonStyle(reduceMotion: reduceMotion))
                    .contextMenu {
                        itemActions(for: item)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    private var listContent: some View {
        List {
            ForEach(filteredItems) { item in
                NavigationLink {
                    AnalysisDetailView(item: item)
                        .toolbar(.visible, for: .navigationBar)
                } label: {
                    PremiumGuideListRow(
                        item: item,
                        status: status(for: item),
                        accentColor: accentColor(for: item)
                    )
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 5, leading: 18, bottom: 5, trailing: 18))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        pendingDelete = item
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        exportItem(item)
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .tint(PremiumUI.coral)

                    Button {
                        toggleFavorite(item)
                    } label: {
                        Label(
                            item.isFavorite == true ? "Unfavorite" : "Favorite",
                            systemImage: item.isFavorite == true ? "star.slash" : "star"
                        )
                    }
                    .tint(PremiumUI.gold)
                }
                .contextMenu {
                    itemActions(for: item)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(PremiumUI.background)
    }

    @ViewBuilder
    private func itemActions(for item: LibraryItem) -> some View {
        Button {
            toggleFavorite(item)
        } label: {
            Label(
                item.isFavorite == true ? "Remove Favorite" : "Favorite",
                systemImage: item.isFavorite == true ? "star.slash" : "star"
            )
        }

        Button {
            exportItem(item)
        } label: {
            Label("Export PDF", systemImage: "square.and.arrow.up")
        }

        Button(role: .destructive) {
            pendingDelete = item
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(PremiumUI.softGold)
                    .frame(width: 104, height: 104)

                Image(systemName: searchText.isEmpty ? "books.vertical.fill" : "magnifyingglass")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(PremiumUI.gold)
            }

            Text(searchText.isEmpty ? "Build your library" : "No guides found")
                .font(PremiumUI.display(22, .bold))
                .foregroundStyle(PremiumUI.ink)

            Text(
                searchText.isEmpty
                    ? "Create your first Insight Atlas guide and it will appear here."
                    : "Try another title, author, or keyword."
            )
            .font(PremiumUI.ui(15))
            .foregroundStyle(PremiumUI.secondaryText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 42)

            Button {
                if searchText.isEmpty {
                    showingGenerationView = true
                } else {
                    searchText = ""
                    selectedFilter = .all
                }
            } label: {
                Label(
                    searchText.isEmpty ? "Create Guide" : "Clear Search",
                    systemImage: searchText.isEmpty ? "plus" : "xmark"
                )
                    .font(PremiumUI.ui(15, .semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(PremiumUI.gold)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func status(for item: LibraryItem) -> PremiumGuideStatus {
        if let content = item.summaryContent, !content.isEmpty {
            return .completed
        }

        if environment.generationCoordinator.isGenerating,
           environment.generationCoordinator.currentGenerationId == item.id {
            return .inProgress
        }

        return .draft
    }

    private func accentColor(for item: LibraryItem) -> Color {
        let palette = [PremiumUI.gold, PremiumUI.burgundy, PremiumUI.coral, PremiumUI.teal]
        let scalarSum = item.id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[scalarSum % palette.count]
    }

    private func toggleFavorite(_ item: LibraryItem) {
        var mutableItem = item
        mutableItem.isFavorite = !(item.isFavorite ?? false)
        environment.updateLibraryItem(mutableItem)
        PremiumHaptics.notification(.success)
    }

    private func deleteItem(_ item: LibraryItem) {
        environment.deleteLibraryItem(item)
        pendingDelete = nil
        PremiumHaptics.notification(.warning)
    }

    private func exportItem(_ item: LibraryItem) {
        do {
            let url = try dataManager.exportGuide(item, format: .pdf)
            sharePayload = LibrarySharePayload(url: url)
            PremiumHaptics.notification(.success)
        } catch {
            exportError = error.localizedDescription
            PremiumHaptics.notification(.error)
        }
    }
}

enum PremiumLibraryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case favorites = "Favorites"
    case recent = "Recent"
    case drafts = "Drafts"

    var id: String { rawValue }
}

enum PremiumLibrarySort: String, CaseIterable, Identifiable {
    case recentlyUpdated = "Recently Updated"
    case recentlyCreated = "Recently Created"
    case title = "Title"
    case author = "Author"

    var id: String { rawValue }
}

enum PremiumLibraryLayout: String, CaseIterable, Identifiable {
    case grid
    case list

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }
}

enum PremiumGuideStatus: String {
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
        case .completed: return PremiumUI.goldDark
        case .inProgress: return PremiumUI.burgundy
        case .draft: return PremiumUI.secondaryText
        }
    }
}

struct PremiumSearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(PremiumUI.secondaryText)

            TextField(placeholder, text: $text)
                .font(PremiumUI.ui(16))
                .foregroundStyle(PremiumUI.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(PremiumUI.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 44)
        .background(PremiumUI.searchFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

struct PremiumGuideGridCard: View {
    let item: LibraryItem
    let status: PremiumGuideStatus
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(accentColor)
                .frame(height: 7)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top) {
                    LibraryCoverImageView(
                        title: item.title,
                        author: item.author,
                        coverImagePath: item.coverImagePath,
                        fallbackColor: accentColor
                    )
                    .frame(width: 54, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .shadow(color: Color.black.opacity(0.13), radius: 4, x: 0, y: 2)

                    Spacer(minLength: 8)

                    if item.isFavorite == true {
                        Image(systemName: "star.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(PremiumUI.gold)
                    }
                }

                Text(item.title)
                    .font(PremiumUI.display(17, .semibold))
                    .foregroundStyle(PremiumUI.ink)
                    .lineLimit(2)

                Text(item.author)
                    .font(PremiumUI.ui(14))
                    .foregroundStyle(PremiumUI.secondaryText)
                    .lineLimit(1)

                Spacer()

                Text("Updated \(item.updatedAt.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(PremiumUI.ui(13))
                    .foregroundStyle(PremiumUI.secondaryText)

                PremiumGuideStatusBadge(status: status)
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, minHeight: 238, alignment: .topLeading)
        .background(PremiumUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(PremiumUI.divider.opacity(0.75), lineWidth: 0.7)
        }
        .shadow(color: PremiumUI.cardShadow, radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .combine)
    }
}

struct PremiumGuideListRow: View {
    let item: LibraryItem
    let status: PremiumGuideStatus
    let accentColor: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.13))
                    .frame(width: 48, height: 48)

                Circle()
                    .stroke(accentColor, lineWidth: 1.5)
                    .frame(width: 44, height: 44)

                Image(systemName: "book.closed.fill")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(item.title)
                        .font(PremiumUI.display(16, .semibold))
                        .foregroundStyle(PremiumUI.ink)
                        .lineLimit(1)

                    if item.isFavorite == true {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(PremiumUI.gold)
                    }
                }

                Text(item.author)
                    .font(PremiumUI.ui(13))
                    .foregroundStyle(PremiumUI.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            PremiumGuideStatusBadge(status: status, compact: true)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(PremiumUI.gold)
        }
        .padding(.horizontal, 13)
        .frame(minHeight: 68)
        .background(PremiumUI.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(PremiumUI.divider.opacity(0.7), lineWidth: 0.7)
        }
        .shadow(color: PremiumUI.cardShadow.opacity(0.7), radius: 5, x: 0, y: 2)
        .accessibilityElement(children: .combine)
    }
}

struct PremiumGuideStatusBadge: View {
    let status: PremiumGuideStatus
    var compact = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: compact ? 9 : 10, weight: .semibold))

            Text(status.rawValue)
                .font(PremiumUI.ui(compact ? 10 : 11, .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, compact ? 7 : 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.12), in: Capsule())
        .opacity(status == .inProgress && !reduceMotion && pulse ? 0.55 : 1.0)
        .animation(
            status == .inProgress && !reduceMotion
                ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                : nil,
            value: pulse
        )
        .onAppear { if status == .inProgress { pulse = true } }
    }
}

struct PremiumLibraryOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedSort: PremiumLibrarySort
    @Binding var selectedLayout: PremiumLibraryLayout

    var body: some View {
        NavigationStack {
            List {
                Section("View") {
                    Picker("Layout", selection: $selectedLayout) {
                        ForEach(PremiumLibraryLayout.allCases) { layout in
                            Label(layout.title, systemImage: layout.icon)
                                .tag(layout)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(PremiumUI.card)
                }

                Section("Sort By") {
                    ForEach(PremiumLibrarySort.allCases) { sort in
                        Button {
                            selectedSort = sort
                            PremiumHaptics.selection()
                        } label: {
                            HStack {
                                Text(sort.rawValue)
                                    .foregroundStyle(PremiumUI.ink)

                                Spacer()

                                if selectedSort == sort {
                                    Image(systemName: "checkmark")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(PremiumUI.gold)
                                }
                            }
                        }
                        .listRowBackground(PremiumUI.card)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PremiumUI.background)
            .navigationTitle("Library Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .tint(PremiumUI.gold)
    }
}

struct LibrarySharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

enum PremiumHaptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func impact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

/// Subtle press feedback for tappable cards; respects Reduce Motion.
struct PremiumCardButtonStyle: ButtonStyle {
    var reduceMotion = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview("Premium Library") {
    LibraryView()
        .environmentObject(AppEnvironment.shared)
        .environmentObject(DataManager.shared)
}

// MARK: - Cover Image (preserved: used by GenerationView.GuidePreviewCard)
final class CoverImageCache {
    static let shared = CoverImageCache()
    private let cache = NSCache<NSString, UIImage>()

    func image(for path: String) -> UIImage? {
        cache.object(forKey: path as NSString)
    }

    func store(_ image: UIImage, for path: String) {
        cache.setObject(image, forKey: path as NSString)
    }
}

/// Loads a library cover off the main thread and caches it, so scrolling the
/// library list doesn't hit disk on every redraw.
struct CoverImage: View {
    let path: String?
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
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
        .task(id: path) { await load() }
        .accessibilityHidden(true)
    }

    private func load() async {
        guard let path else {
            image = nil
            return
        }
        if let cached = CoverImageCache.shared.image(for: path) {
            image = cached
            return
        }
        let data = await Task.detached(priority: .utility) { () -> Data? in
            guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return nil
            }
            return try? Data(contentsOf: dir.appendingPathComponent(path))
        }.value
        guard let data, let loaded = UIImage(data: data) else {
            image = nil
            return
        }
        CoverImageCache.shared.store(loaded, for: path)
        image = loaded
    }
}

