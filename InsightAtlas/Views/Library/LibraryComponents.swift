//
//  LibraryComponents.swift
//  InsightAtlas
//
//  Composable UI components for the Library view.
//  These components are presentation-layer only and do not modify
//  domain models, persistence, or export pipelines.
//

import SwiftUI
import UIKit

// MARK: - Library Header View

/// Brand-aligned header with logo, title, and action buttons.
///
/// Reusable across different library layout modes (grid/list).
struct LibraryHeaderView: View {
    let itemCount: Int
    let isSearchActive: Bool
    let onSearchToggle: () -> Void
    let onAddTapped: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                // Logo mark
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Library")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundColor(InsightAtlasColors.heading)
                    Text("\(itemCount) \(itemCount == 1 ? "Guide" : "Guides")")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(InsightAtlasColors.gold)
                }

                Spacer()

                HStack(spacing: 12) {
                    // Search button
                    LibraryIconButton(
                        icon: isSearchActive ? "xmark" : "magnifyingglass",
                        isActive: isSearchActive,
                        activeColor: InsightAtlasColors.coral,
                        inactiveColor: InsightAtlasColors.brandSepia,
                        action: onSearchToggle
                    )
                    .accessibilityLabel(isSearchActive ? "Close" : "Search library")
                    .accessibilityHint("Double tap to search your guides")
                    .accessibilityIdentifier("library_search_field")

                    // Add button with gold gradient
                    LibraryAddButton(action: onAddTapped)
                        .accessibilityLabel("Import Book")
                        .accessibilityHint("Double tap to import a PDF or EPUB book")
                        .accessibilityIdentifier("library_import_button")
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)

            // DESIGN SYSTEM FIX: 24px padding-bottom with divider at bottom
            // This creates the required 24px gap between header and content
            Spacer()
                .frame(height: 24)

            // Divider line at bottom of 24px padding
            LibraryAccentDivider()
        }
        .frame(height: 64)  // Fixed header height per Design System
        .background(
            Color(hex: "#F8F8F8").opacity(0.85)
                .background(.ultraThinMaterial)
        )
    }
}

// MARK: - Library Icon Button

/// Circular icon button with active/inactive states.
struct LibraryIconButton: View {
    let icon: String
    let isActive: Bool
    let activeColor: Color
    let inactiveColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                action()
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isActive ? activeColor : inactiveColor)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isActive ? activeColor.opacity(0.1) : InsightAtlasColors.backgroundAlt)
                )
        }
    }
}

// MARK: - Library Add Button

/// Gold gradient add button for importing books.
struct LibraryAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    LinearGradient(
                        colors: [InsightAtlasColors.gold, InsightAtlasColors.goldDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: InsightAtlasColors.gold.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - Library Accent Divider

/// Divider line per Design System specification.
/// Uses `#EAEAEA` (ui-border) for dividers and inactive borders.
struct LibraryAccentDivider: View {
    /// Use accent style (gold gradient) or standard divider (ui-border)
    var useAccentStyle: Bool = false

    var body: some View {
        Rectangle()
            .fill(
                useAccentStyle
                    ? AnyShapeStyle(LinearGradient(
                        colors: [
                            InsightAtlasColors.gold.opacity(0.3),
                            InsightAtlasColors.gold,
                            InsightAtlasColors.gold.opacity(0.3)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    : AnyShapeStyle(Color(hex: "#EAEAEA"))  // Design System: ui-border
            )
            .frame(height: 1)
    }
}

// MARK: - Library Search Bar

/// Brand-styled search bar with clear button.
struct LibrarySearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search your library..."

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(InsightAtlasColors.gold)
                .font(.system(size: 14, weight: .medium))

            TextField(placeholder, text: $text)
                .font(.system(size: 16, design: .serif))
                .foregroundColor(InsightAtlasColors.heading)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(InsightAtlasColors.gold.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(InsightAtlasColors.card)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(InsightAtlasColors.gold.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(12)
        .shadow(color: InsightAtlasColors.gold.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Library Filter Bar

/// Horizontal scrolling filter pills using existing LibraryFilter enum.
/// Brand-aligned with icons for visual clarity.
struct LibraryFilterBar: View {
    @Binding var selectedFilter: LibraryFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibraryFilter.allCases, id: \.self) { filter in
                    LibraryFilterPill(
                        filter: filter,
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

// MARK: - Library Filter Pill

/// Individual filter pill with brand styling and icon support.
/// Refined design with icons for visual clarity and brand alignment.
struct LibraryFilterPill: View {
    let filter: LibraryFilter
    let isSelected: Bool
    let action: () -> Void

    // Legacy initializer for backward compatibility
    init(title: String, isSelected: Bool, action: @escaping () -> Void) {
        // Map title back to filter enum for icon support
        self.filter = LibraryFilter(rawValue: title) ?? .all
        self.isSelected = isSelected
        self.action = action
    }

    // New initializer with direct filter enum
    init(filter: LibraryFilter, isSelected: Bool, action: @escaping () -> Void) {
        self.filter = filter
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 11, weight: .medium))
                Text(filter.rawValue)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
            }
            .foregroundColor(isSelected ? .white : InsightAtlasColors.brandSepia)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            colors: [InsightAtlasColors.gold, InsightAtlasColors.goldDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color(InsightAtlasColors.backgroundAlt)
                    }
                }
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : InsightAtlasColors.rule, lineWidth: 1)
            )
            .shadow(color: isSelected ? InsightAtlasColors.gold.opacity(0.2) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Status Badge

/// Displays the reading/completion status of a library item.
/// Uses existing BookStatus enum.
struct StatusBadge: View {
    let status: BookStatus

    /// Compact mode for list rows (smaller padding)
    var isCompact: Bool = false

    var body: some View {
        HStack(spacing: isCompact ? 4 : 5) {
            Image(systemName: status.icon)
                .font(.system(size: isCompact ? 9 : 10, weight: .medium))
            Text(status.displayText)
                .font(.system(size: isCompact ? 10 : 11, weight: .semibold))
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundColor(status.color)
        .padding(.horizontal, isCompact ? 8 : 10)
        .padding(.vertical, isCompact ? 4 : 5)
        .background(
            Capsule()
                .fill(status.color.opacity(0.12))
        )
        .overlay(
            Capsule()
                .stroke(status.color.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - Library Row View

/// List-style row for library items (alternative to GridBookCard).
///
/// Displays: book icon, title, author, year, status badge, chevron.
/// Supports selection mode with checkbox and swipe actions via the parent List context.
struct LibraryRowView: View {
    let item: LibraryItem
    let accentColor: Color

    /// Whether selection mode is active
    var isSelecting: Bool = false

    /// Whether this item is currently selected
    var isSelected: Bool = false

    // Derive status from item
    private var status: BookStatus {
        if item.summaryContent != nil {
            return .completed
        } else {
            return .inProgress
        }
    }

    // Format year from createdAt date
    private var yearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: item.createdAt)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox (shown in selection mode)
            if isSelecting {
                SelectionCheckbox(isSelected: isSelected)
                    .transition(.scale.combined(with: .opacity))
            }

            // Book cover - fetched from Open Library API (replaces generic icon)
            LibraryCoverImageView(
                title: item.title,
                author: item.author,
                coverImagePath: item.coverImagePath,
                fallbackColor: accentColor
            )
            .frame(width: 44, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(accentColor.opacity(0.2), lineWidth: 0.5)
            )
            .overlay(alignment: .topTrailing) {
                if item.isFavorite ?? false {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(5)
                        .background(
                            Circle()
                                .fill(InsightAtlasColors.coral)
                        )
                        .offset(x: 6, y: -6)
                        .accessibilityLabel("Favorite")
                }
            }
            .shadow(color: accentColor.opacity(0.1), radius: 2, x: 0, y: 1)

            // Title and author
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundColor(InsightAtlasColors.heading)
                    .lineLimit(1)

                Text("\(item.author), \(yearString)")
                    .font(.system(size: 14))
                    .foregroundColor(InsightAtlasColors.muted)
                    .lineLimit(1)
            }

            Spacer()

            // Status badge
            StatusBadge(status: status, isCompact: true)

            // Chevron (hidden in selection mode)
            if !isSelecting {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(InsightAtlasColors.muted.opacity(0.6))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            isSelected && isSelecting
                ? InsightAtlasColors.gold.opacity(0.08)
                : InsightAtlasColors.card
        )
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isSelected && isSelecting
                        ? InsightAtlasColors.gold.opacity(0.5)
                        : InsightAtlasColors.ruleLight,
                    lineWidth: isSelected && isSelecting ? 2 : 1
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isSelecting)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Selectable Library Row View

/// Wrapper for LibraryRowView that handles selection tap
struct SelectableLibraryRowView: View {
    let item: LibraryItem
    let accentColor: Color
    let isSelecting: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onNavigate: () -> Void

    var body: some View {
        Button {
            if isSelecting {
                onTap()
            } else {
                onNavigate()
            }
        } label: {
            LibraryRowView(
                item: item,
                accentColor: accentColor,
                isSelecting: isSelecting,
                isSelected: isSelected
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Book Icon View

/// Stylized book icon with customizable accent color.
struct BookIconView: View {
    let color: Color
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.15))
                .frame(width: size, height: size)

            Image(systemName: "book.closed.fill")
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundColor(color)
        }
    }
}

// MARK: - Library Cover Image View

/// Prefer the locally extracted cover; fall back to online lookup if missing.
struct LibraryCoverImageView: View {
    let title: String
    let author: String
    let coverImagePath: String?
    let fallbackColor: Color

    @State private var localImage: UIImage?

    var body: some View {
        Group {
            if let image = localImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LocalCoverPlaceholder(
                    title: title,
                    author: author,
                    accentColor: fallbackColor
                )
            }
        }
        .task {
            await loadCoverImage()
        }
    }

    private func loadCoverImage() async {
        let image = loadLocalImage()
        await MainActor.run {
            localImage = image
        }
    }

    private func loadLocalImage() -> UIImage? {
        guard let coverImagePath, !coverImagePath.isEmpty else { return nil }
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let coverURL = documentsDir.appendingPathComponent(coverImagePath)
        return UIImage(contentsOfFile: coverURL.path)
    }
}

private struct LocalCoverPlaceholder: View {
    let title: String
    let author: String
    let accentColor: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.2),
                            accentColor.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 9, weight: .semibold, design: .serif))
                    .foregroundColor(InsightAtlasColors.heading)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(author)
                    .font(.system(size: 8, weight: .regular))
                    .foregroundColor(InsightAtlasColors.muted)
                    .lineLimit(1)
            }
            .padding(6)
        }
        .accessibilityLabel("\(title) by \(author)")
    }
}

// MARK: - Library List View

/// List-style layout for library items (alternative to grid).
///
/// This is a pure presentation component - filtering logic remains in LibraryView.
/// Supports selection mode for bulk operations.
struct LibraryListView: View {
    let items: [LibraryItem]
    let isSelecting: Bool
    let selectedIDs: Set<UUID>
    let onItemSelected: (LibraryItem) -> Void
    let onSelectionToggle: (LibraryItem) -> Void
    let onFavorite: (LibraryItem) -> Void
    let onExport: (LibraryItem) -> Void
    let onDelete: (LibraryItem) -> Void

    // Default initializer for backward compatibility
    init(
        items: [LibraryItem],
        isSelecting: Bool = false,
        selectedIDs: Set<UUID> = [],
        onItemSelected: @escaping (LibraryItem) -> Void,
        onSelectionToggle: @escaping (LibraryItem) -> Void = { _ in },
        onFavorite: @escaping (LibraryItem) -> Void,
        onExport: @escaping (LibraryItem) -> Void,
        onDelete: @escaping (LibraryItem) -> Void
    ) {
        self.items = items
        self.isSelecting = isSelecting
        self.selectedIDs = selectedIDs
        self.onItemSelected = onItemSelected
        self.onSelectionToggle = onSelectionToggle
        self.onFavorite = onFavorite
        self.onExport = onExport
        self.onDelete = onDelete
    }

    // Accent colors for visual variety
    private static let accentColors: [Color] = [
        InsightAtlasColors.gold,
        InsightAtlasColors.burgundy,
        InsightAtlasColors.coral,
        InsightAtlasColors.teal
    ]

    private func accentColor(for item: LibraryItem) -> Color {
        let index = abs(item.title.hashValue) % Self.accentColors.count
        return Self.accentColors[index]
    }

    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(items) { item in
                Button {
                    if isSelecting {
                        onSelectionToggle(item)
                    } else {
                        onItemSelected(item)
                    }
                } label: {
                    LibraryRowView(
                        item: item,
                        accentColor: accentColor(for: item),
                        isSelecting: isSelecting,
                        isSelected: selectedIDs.contains(item.id)
                    )
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if !isSelecting {
                        Button {
                            onFavorite(item)
                        } label: {
                            Label("Favorite", systemImage: "heart")
                        }
                        .tint(InsightAtlasColors.coral)

                        Button {
                            onExport(item)
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .tint(InsightAtlasColors.teal)

                        Button(role: .destructive) {
                            onDelete(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .contextMenu {
                    if !isSelecting {
                        Button {
                            onFavorite(item)
                        } label: {
                            Label("Favorite", systemImage: "heart")
                        }

                        Button {
                            onExport(item)
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }

                        Button(role: .destructive) {
                            onDelete(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Layout Mode Toggle

/// Toggle between grid and list view modes.
enum LibraryLayoutMode: String, CaseIterable {
    case grid
    case list

    var icon: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }
}

/// Button to toggle between grid and list layouts.
struct LayoutModeToggle: View {
    @Binding var mode: LibraryLayoutMode

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                mode = mode == .grid ? .list : .grid
            }
        } label: {
            Image(systemName: mode == .grid ? "list.bullet" : "square.grid.2x2")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(InsightAtlasColors.brandSepia)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(InsightAtlasColors.backgroundAlt)
                )
        }
        .accessibilityLabel(mode == .grid ? "Switch to list view" : "Switch to grid view")
    }
}

// MARK: - Preview

#Preview("Library Header") {
    VStack {
        LibraryHeaderView(
            itemCount: 12,
            isSearchActive: false,
            onSearchToggle: {},
            onAddTapped: {}
        )
        Spacer()
    }
    .background(InsightAtlasColors.background)
}

#Preview("Library Search Bar") {
    VStack {
        LibrarySearchBar(text: .constant(""))
        LibrarySearchBar(text: .constant("Atomic Habits"))
    }
    .padding()
    .background(InsightAtlasColors.background)
}

#Preview("Library Filter Bar") {
    @Previewable @State var filter: LibraryFilter = .all
    LibraryFilterBar(selectedFilter: $filter)
        .padding()
        .background(InsightAtlasColors.background)
}

#Preview("Status Badges") {
    HStack(spacing: 12) {
        StatusBadge(status: .completed)
        StatusBadge(status: .inProgress)
        StatusBadge(status: .draft)
    }
    .padding()
    .background(InsightAtlasColors.background)
}

#Preview("Book Icon") {
    HStack(spacing: 16) {
        BookIconView(color: InsightAtlasColors.gold)
        BookIconView(color: InsightAtlasColors.burgundy)
        BookIconView(color: InsightAtlasColors.coral)
        BookIconView(color: InsightAtlasColors.teal)
    }
    .padding()
    .background(InsightAtlasColors.background)
}
