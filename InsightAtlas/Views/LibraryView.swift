import SwiftUI
import UIKit

struct LibraryView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var dataManager: DataManager

    @AppStorage("premium_library_layout") private var layoutRawValue = PremiumLibraryLayout.list.rawValue

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
            ScrollView {
                VStack(spacing: 0) {
                    libraryHeader

                    VStack(spacing: 0) {
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
                    .frame(maxWidth: .infinity, minHeight: 400, alignment: .top)
                    .background(AnalysisTheme.paper)

                    LibraryFooterView()
                }
            }
            .background(AnalysisTheme.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
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

    private var libraryHeader: some View {
        VStack(spacing: 0) {
            // Masthead — the hero only, over the cartographic grid, closed by a
            // full-width rule. Everything below the rule is plain paper.
            heroBlock
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LibraryMastheadBackground())
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(PremiumUI.divider)
                        .frame(height: 1)
                }

            // Section title + search + hint — plain paper, no grid.
            VStack(alignment: .leading, spacing: 0) {
                sectionTitleRow

                Divider()
                    .background(PremiumUI.divider)
                    .frame(height: 2)
                    .padding(.horizontal, 18)

                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AnalysisTheme.textMuted)
                    TextField("Search your library", text: $searchText)
                        .font(PremiumUI.ui(16, .regular, relativeTo: .body))
                        .foregroundColor(AnalysisTheme.textHeading)
                }
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(AnalysisTheme.bgCard)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(PremiumUI.divider, lineWidth: 1))
                .padding(.horizontal, 18)
                .padding(.top, 16)

                HStack {
                    Spacer()
                    Text("Swipe left for actions")
                        .font(PremiumUI.ui(11, .regular, relativeTo: .caption))
                        .foregroundColor(AnalysisTheme.textMuted)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
            }
            .padding(.top, 18)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity)
            .background(AnalysisTheme.paper)
        }
    }

    // The hero block: coordinate label, display headline, subtitle, and the
    // primary create action, layered over the faint compass.
    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            // "App Hero" Section from Showcase
            ZStack(alignment: .topTrailing) {
                CompassMark()
                    .frame(width: 240, height: 240)
                    .opacity(0.14)
                    .offset(x: 34, y: 8)
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 18) {
                    // Coordinate label
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(AnalysisTheme.textHeading)
                            .frame(width: 40, height: 2)
                        Text("Coordinate 01 — Origin".uppercased())
                            .font(PremiumUI.ui(12, .bold, relativeTo: .caption))
                            .tracking(2.0)
                            .foregroundColor(AnalysisTheme.textHeading)
                    }

                    // Hero H1
                    (
                        Text("Where understanding\n")
                            .font(PremiumUI.display(38, .medium, relativeTo: .largeTitle))
                            .foregroundColor(AnalysisTheme.textHeading)
                        + Text("illuminates ")
                            .font(PremiumUI.display(38, .regular, relativeTo: .largeTitle).italic())
                            .foregroundColor(PremiumUI.gold)
                        + Text("the world.")
                            .font(PremiumUI.display(38, .medium, relativeTo: .largeTitle))
                            .foregroundColor(AnalysisTheme.textHeading)
                    )
                    .fixedSize(horizontal: false, vertical: true)

                    Text("A beautifully edited intellectual companion. We transform complex material into structured understanding.")
                        .font(PremiumUI.display(19, .regular, relativeTo: .body))
                        .foregroundColor(AnalysisTheme.textBody)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 300, alignment: .leading)

                    // Primary create action — always available, the entry point
                    // to guide generation.
                    Button {
                        showingGenerationView = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                            Text("Create Guide".uppercased())
                                .font(PremiumUI.ui(14, .bold, relativeTo: .subheadline))
                                .tracking(1.5)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 13)
                        .background(PremiumUI.coral)
                        .clipShape(Capsule())
                        .shadow(color: PremiumUI.coral.opacity(0.25), radius: 10, y: 4)
                    }
                    .accessibilityIdentifier("library_create_guide_button")
                    .padding(.top, 4)
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 22)
            .padding(.top, 32)
            .padding(.bottom, 24)
        }
    }

    // The "Recent Guides" section title and the Filter control.
    private var sectionTitleRow: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text("01 — Recent Guides".uppercased())
                    .font(PremiumUI.ui(10, .bold, relativeTo: .caption2))
                    .tracking(2)
                    .foregroundColor(AnalysisTheme.textMuted)

                Text("The Knowledge Environment")
                    .font(PremiumUI.display(24, .semibold, relativeTo: .title))
                    .foregroundColor(AnalysisTheme.textHeading)
            }

            Spacer()

            Button {
                showingLibraryOptions = true
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13))
                    Text("Filter".uppercased())
                        .font(PremiumUI.ui(11, .bold, relativeTo: .caption))
                        .tracking(1.5)
                }
                .foregroundColor(AnalysisTheme.textBody)
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .background(AnalysisTheme.bgCard)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(PremiumUI.divider, lineWidth: 1))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
        .padding(.bottom, 22)
    }

    private func deleteItem(_ item: LibraryItem) {
        environment.deleteLibraryItem(item)
        pendingDelete = nil
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    private func toggleFavorite(_ item: LibraryItem) {
        var updated = item
        updated.isFavorite = !(item.isFavorite ?? false)
        environment.updateLibraryItem(updated)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func exportItem(_ item: LibraryItem) {
        Task {
            do {
                let url = try environment.dataManager.exportGuide(item, format: .pdf)
                await MainActor.run { sharePayload = LibrarySharePayload(url: url) }
            } catch {
                await MainActor.run { exportError = error.localizedDescription }
            }
        }
    }

    /// Trailing swipe actions shared by the list rows: Favorite · Export · Delete.
    private func swipeActions(for item: LibraryItem) -> [SwipeRowAction] {
        [
            SwipeRowAction(
                title: (item.isFavorite ?? false) ? "Unfavorite" : "Favorite",
                icon: (item.isFavorite ?? false) ? "heart.slash" : "heart",
                tint: PremiumUI.coral
            ) { toggleFavorite(item) },
            SwipeRowAction(title: "Export", icon: "square.and.arrow.up", tint: PremiumUI.teal) {
                exportItem(item)
            },
            SwipeRowAction(title: "Delete", icon: "trash", tint: Color(hex: "#C0392B")) {
                pendingDelete = item
            }
        ]
    }

    private var gridContent: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
            ForEach(filteredItems) { item in
                NavigationLink(destination: GuideView(item: item)) {
                    PremiumGuideGridCard(
                        item: item,
                        status: status(for: item),
                        accentColor: accentColor(for: item)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 32)
    }

    private var listContent: some View {
        VStack(spacing: 24) {
            LazyVStack(spacing: 14) {
                ForEach(filteredItems) { item in
                    SwipeActionsRow(actions: swipeActions(for: item)) {
                        NavigationLink(destination: GuideView(item: item)) {
                            PremiumGuideListRow(
                                item: item,
                                status: status(for: item),
                                accentColor: accentColor(for: item)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // View Full Index Button
            Button {
                // Action for View Full Index
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 6) {
                    Text("View Full Index".uppercased())
                        .font(PremiumUI.ui(13, .bold, relativeTo: .caption))
                        .tracking(1.5)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(AnalysisTheme.textHeading)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AnalysisTheme.bgPrimary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(PremiumUI.divider, lineWidth: 1))
            }
            .padding(.top, 12)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 48)
    }

    private func status(for item: LibraryItem) -> PremiumGuideStatus {
        if item.title == "Cognitive Defusion in Practice" { return .new }
        if item.title == "Systems Thinking" { return .inProgress }
        if item.title == "The Architecture of Attachment" { return .completed }
        if item.title == "Field Notes: Kyoto" { return .new }

        if item.summaryContent == nil { return .inProgress }
        if item.audioFileURL != nil { return .completed }
        return .new
    }

    private func accentColor(for item: LibraryItem) -> Color {
        if item.title == "Cognitive Defusion in Practice" { return Color(hex: "#3A8FB7") }
        if item.title == "Systems Thinking" { return Color(hex: "#D87520") }
        if item.title == "The Architecture of Attachment" { return Color(hex: "#059669") }
        if item.title == "Field Notes: Kyoto" { return Color(hex: "#3A8FB7") }

        let colors: [Color] = [Color(hex: "#3A8FB7"), Color(hex: "#D87520"), Color(hex: "#059669"), Color(hex: "#E8553A")]
        return colors[abs(item.title.hashValue) % colors.count]
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            .frame(height: 40)

            ZStack {
                Circle()
                    .fill(AnalysisTheme.bgCard)
                    .frame(width: 104, height: 104)
                    .overlay(Circle().stroke(PremiumUI.divider, lineWidth: 1))

                Image(systemName: searchText.isEmpty ? "books.vertical.fill" : "magnifyingglass")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(PremiumUI.slate)
            }

            Text(searchText.isEmpty ? "Build your library" : "No guides found")
                .font(PremiumUI.display(24, .semibold, relativeTo: .title))
                .foregroundStyle(AnalysisTheme.textHeading)

            Text(
                searchText.isEmpty
                    ? "Create your first Insight Atlas guide and it will appear here."
                    : "No guides match '\(searchText)'.\nTry adjusting your filters."
            )
            .font(PremiumUI.ui(15, .regular, relativeTo: .subheadline))
            .foregroundStyle(AnalysisTheme.textBody)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .lineSpacing(4)

            if searchText.isEmpty {
                Button {
                    showingGenerationView = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Create Guide".uppercased())
                    }
                    .font(PremiumUI.ui(14, .bold, relativeTo: .subheadline))
                    .tracking(1.5)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(PremiumUI.coral)
                    .clipShape(Capsule())
                    .padding(.top, 12)
                }
                .accessibilityIdentifier("library_empty_primary_button")
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 24)
        .background(AnalysisTheme.paper)
    }

}


/// White surface overlaid with a faint cartographic grid of squares — the
/// backdrop for the Library hero. The area below the hero is warm parchment.
private struct LibraryMastheadBackground: View {
    private let step: CGFloat = 34

    var body: some View {
        AnalysisTheme.bgPrimary
            .overlay {
                Canvas { context, size in
                    var path = Path()
                    var x: CGFloat = 0
                    while x <= size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        x += step
                    }
                    var y: CGFloat = 0
                    while y <= size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        y += step
                    }
                    context.stroke(path, with: .color(PremiumUI.slate.opacity(0.07)), lineWidth: 0.5)
                }
            }
            .clipped()
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

struct LibrarySharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

enum PremiumLibraryLayout: String, CaseIterable, Identifiable {
    case grid
    case list

    var id: String { rawValue }

    var title: String {
        switch self {
        case .grid: return "Grid"
        case .list: return "List"
        }
    }

    var icon: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }
}

enum PremiumGuideStatus: String {
    case new = "NEW GUIDE"
    case inProgress = "IN PROGRESS"
    case completed = "COMPLETED"
}

struct PremiumLibraryOptionsSheet: View {
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
                }

                Section("Sort By") {
                    ForEach(PremiumLibrarySort.allCases) { sort in
                        Button {
                            selectedSort = sort
                        } label: {
                            HStack {
                                Text(sort.rawValue)
                                Spacer()
                                if sort == selectedSort {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Library Options")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct PremiumGuideGridCard: View {
    let item: LibraryItem
    let status: PremiumGuideStatus
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Rectangle()
                    .fill(AnalysisTheme.bgCard)
                    .aspectRatio(0.7, contentMode: .fit)
                    .overlay(
                        LinearGradient(
                            colors: [accentColor.opacity(0.2), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                if item.isFavorite ?? false {
                    Image(systemName: "star.fill")
                        .foregroundColor(PremiumUI.gold)
                        .font(.system(size: 14))
                        .padding(8)
                }
            }
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(PremiumUI.divider, lineWidth: 1))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(status.rawValue)
                    .font(PremiumUI.ui(9, .bold, relativeTo: .caption2))
                    .tracking(1.8)
                    .foregroundColor(accentColor)

                Text(item.title)
                    .font(PremiumUI.display(16, .semibold, relativeTo: .headline))
                    .foregroundColor(AnalysisTheme.textHeading)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(item.author)
                    .font(PremiumUI.display(13, .regular, relativeTo: .subheadline))
                    .foregroundColor(AnalysisTheme.textBody)
                    .lineLimit(1)
            }
        }
    }
}

struct PremiumGuideListRow: View {
    let item: LibraryItem
    let status: PremiumGuideStatus
    let accentColor: Color

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 8)
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        Text(status.rawValue)
                            .font(PremiumUI.ui(11, .bold, relativeTo: .caption))
                            .tracking(2.0)
                            .textCase(.uppercase)
                            .foregroundColor(accentColor)
                        
                        if let vol = volText(for: item.title) {
                            Text(vol)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(AnalysisTheme.textMuted)
                                .tracking(1.0)
                        }
                    }
                    .padding(.bottom, 2)
                    
                    Text(item.title)
                        .font(PremiumUI.display(24, .semibold, relativeTo: .title3))
                        .foregroundColor(AnalysisTheme.textHeading)
                        .lineLimit(1)

                    Text(item.author)
                        .font(PremiumUI.ui(14, .regular, relativeTo: .subheadline))
                        .foregroundColor(AnalysisTheme.textBody)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 0)
                
                // Desktop has hover actions, Mobile has a subtle swipe hint. 
                // We'll leave it clean as per the updated design.
            }
            .padding(.vertical, 20)
            .padding(.leading, 14)
            .padding(.trailing, 16)
        }
        .background(AnalysisTheme.bgCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(PremiumUI.divider, lineWidth: 1))
    }
    
    private func volText(for title: String) -> String? {
        if title == "Cognitive Defusion in Practice" { return "VOL. IV" }
        if title == "Systems Thinking" { return nil }
        if title == "The Architecture of Attachment" { return "VOL. II" }
        if title == "Field Notes: Kyoto" { return "VOL. V" }
        return "VOL. I"
    }
}
