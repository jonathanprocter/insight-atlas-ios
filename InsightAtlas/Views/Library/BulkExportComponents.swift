//
//  BulkExportComponents.swift
//  InsightAtlas
//
//  UI components for bulk export functionality.
//  These are presentation-layer only components.
//

import SwiftUI

// MARK: - Bulk Action Bar

/// Bottom action bar shown during selection mode
struct BulkActionBar: View {
    let selectedCount: Int
    let onExport: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Cancel button
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(InsightAtlasColors.muted)
            }

            Spacer()

            // Selection count
            Text("\(selectedCount) selected")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(InsightAtlasColors.heading)

            Spacer()

            // Export button
            Button(action: onExport) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Export")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: selectedCount > 0
                            ? [InsightAtlasColors.gold, InsightAtlasColors.goldDark]
                            : [InsightAtlasColors.muted, InsightAtlasColors.muted],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(10)
                .shadow(
                    color: selectedCount > 0 ? InsightAtlasColors.gold.opacity(0.3) : .clear,
                    radius: 4,
                    x: 0,
                    y: 2
                )
            }
            .disabled(selectedCount == 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            InsightAtlasColors.card
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -4)
        )
    }
}

// MARK: - Bulk Export Sheet

/// Sheet for selecting export format during bulk export
struct BulkExportSheet: View {
    let selectedCount: Int
    let onFormatSelected: (ExportFormat) -> Void
    let onCancel: () -> Void

    /// Optional context about the current filter/search state
    /// Used to display clarity information to the user
    var filterContext: BulkExportFilterContext?

    // Available formats for bulk export (excluding plain text for simplicity)
    private let availableFormats: [ExportFormat] = [.pdf, .docx, .html, .markdown]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up.on.square")
                        .font(.system(size: 40))
                        .foregroundColor(InsightAtlasColors.gold)

                    Text("Export \(selectedCount) Guide\(selectedCount == 1 ? "" : "s")")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundColor(InsightAtlasColors.heading)

                    Text("Choose a format for your export")
                        .font(.system(size: 14))
                        .foregroundColor(InsightAtlasColors.muted)
                }
                .padding(.top, 24)

                // Scope clarity label (informational only)
                if let context = filterContext, context.hasActiveFilters {
                    BulkExportScopeLabel(context: context, selectedCount: selectedCount)
                        .padding(.horizontal, 20)
                }

                // Format options
                VStack(spacing: 12) {
                    ForEach(availableFormats, id: \.self) { format in
                        BulkExportFormatButton(format: format) {
                            onFormatSelected(format)
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                // Info text
                Text("All guides will be exported and combined into a single ZIP file.")
                    .font(.system(size: 12))
                    .foregroundColor(InsightAtlasColors.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
            }
            .background(InsightAtlasColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(InsightAtlasColors.gold)
                }
            }
        }
    }
}

// MARK: - Bulk Export Filter Context

/// Describes the current filter/search state for display purposes only.
/// Does NOT modify filtering logic — purely informational.
struct BulkExportFilterContext {
    let activeFilter: String?      // e.g., "Favorites", "Recent", "Drafts"
    let searchText: String?        // Current search query, if any
    let totalLibraryCount: Int     // Total items in library (unfiltered)
    let filteredCount: Int         // Items matching current filters

    var hasActiveFilters: Bool {
        (activeFilter != nil && activeFilter != "All") || (searchText.map { !$0.isEmpty } ?? false)
    }

    var filterDescription: String {
        var parts: [String] = []

        if let filter = activeFilter, filter != "All" {
            parts.append(filter.lowercased())
        }

        if let search = searchText, !search.isEmpty {
            parts.append("matching \"\(search)\"")
        }

        return parts.isEmpty ? "" : parts.joined(separator: " ")
    }
}

// MARK: - Bulk Export Scope Label

/// Informational label showing what items will be exported.
/// This is clarity-only — does NOT change filtering logic.
struct BulkExportScopeLabel: View {
    let context: BulkExportFilterContext
    let selectedCount: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundColor(InsightAtlasColors.gold.opacity(0.8))

            Text("Exporting \(selectedCount) of \(context.filteredCount) \(context.filterDescription) items")
                .font(.system(size: 12))
                .foregroundColor(InsightAtlasColors.muted)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(InsightAtlasColors.gold.opacity(0.08))
        )
    }
}

// MARK: - Bulk Export Format Button

/// Individual format selection button
struct BulkExportFormatButton: View {
    let format: ExportFormat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: format.bulkExportIcon)
                    .font(.system(size: 20))
                    .foregroundColor(InsightAtlasColors.gold)
                    .frame(width: 44, height: 44)
                    .background(InsightAtlasColors.gold.opacity(0.1))
                    .cornerRadius(10)

                // Label
                VStack(alignment: .leading, spacing: 2) {
                    Text(format.bulkExportDisplayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(InsightAtlasColors.heading)

                    Text(".\(format.fileExtension) files")
                        .font(.system(size: 12))
                        .foregroundColor(InsightAtlasColors.muted)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(InsightAtlasColors.muted.opacity(0.6))
            }
            .padding(16)
            .background(InsightAtlasColors.card)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(InsightAtlasColors.ruleLight, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bulk Export Progress View

/// Full-screen overlay showing export progress
struct BulkExportProgressView: View {
    let progress: BulkExportProgress
    let onCancel: () -> Void

    /// Optional hint about export readiness (informational only)
    var exportHint: BulkExportHint?

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { } // Prevent taps from passing through

            // Progress card
            VStack(spacing: 24) {
                // Progress indicator
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(InsightAtlasColors.ruleLight, lineWidth: 6)
                        .frame(width: 80, height: 80)

                    // Progress circle
                    Circle()
                        .trim(from: 0, to: progress.percentComplete)
                        .stroke(
                            InsightAtlasColors.gold,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: progress.percentComplete)

                    // Percentage or icon
                    if progress.phase == .complete {
                        Image(systemName: "checkmark")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(InsightAtlasColors.gold)
                    } else if case .failed = progress.phase {
                        Image(systemName: "xmark")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(InsightAtlasColors.coral)
                    } else {
                        Text("\(Int(progress.percentComplete * 100))%")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(InsightAtlasColors.heading)
                    }
                }

                // Status text
                VStack(spacing: 8) {
                    Text(progress.statusMessage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(InsightAtlasColors.heading)

                    if !progress.currentTitle.isEmpty && progress.phase == .exporting {
                        Text(progress.currentTitle)
                            .font(.system(size: 14))
                            .foregroundColor(InsightAtlasColors.muted)
                            .lineLimit(1)
                    }

                    // Visual export readiness hint (informational only)
                    if let hint = exportHint, progress.phase == .exporting {
                        BulkExportHintLabel(hint: hint)
                            .padding(.top, 4)
                    }
                }

                // Cancel button (only during export)
                if progress.phase == .exporting || progress.phase == .preparing {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(InsightAtlasColors.coral)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(InsightAtlasColors.coral.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(InsightAtlasColors.card)
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
            .padding(40)
        }
    }
}

// MARK: - Bulk Export Hint

/// Informational hints about export state.
/// These are display-only and do NOT affect export logic.
enum BulkExportHint {
    /// PDF export with visuals will use cached images
    case usingCachedVisuals

    /// Custom hint message
    case custom(String)

    var message: String {
        switch self {
        case .usingCachedVisuals:
            return "Using cached visuals for export"
        case .custom(let text):
            return text
        }
    }

    var icon: String {
        switch self {
        case .usingCachedVisuals:
            return "photo.on.rectangle"
        case .custom:
            return "info.circle"
        }
    }
}

// MARK: - Bulk Export Hint Label

/// Small informational label shown during export.
/// This is purely cosmetic and does NOT affect export behavior.
struct BulkExportHintLabel: View {
    let hint: BulkExportHint

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: hint.icon)
                .font(.system(size: 10))
            Text(hint.message)
                .font(.system(size: 11))
        }
        .foregroundColor(InsightAtlasColors.muted.opacity(0.8))
    }
}

// MARK: - Selection Checkbox

/// Checkbox shown on rows during selection mode
struct SelectionCheckbox: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    isSelected ? InsightAtlasColors.gold : InsightAtlasColors.muted.opacity(0.4),
                    lineWidth: 2
                )
                .frame(width: 24, height: 24)

            if isSelected {
                Circle()
                    .fill(InsightAtlasColors.gold)
                    .frame(width: 24, height: 24)

                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Selection Mode Header Controls

/// Header controls specific to selection mode
struct SelectionModeHeaderControls: View {
    let selectedCount: Int
    let totalCount: Int
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onCancel: () -> Void

    private var allSelected: Bool {
        selectedCount == totalCount && totalCount > 0
    }

    var body: some View {
        HStack(spacing: 12) {
            // Cancel button
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(InsightAtlasColors.coral)
            }

            Spacer()

            // Select All / Deselect All
            Button(action: {
                if allSelected {
                    onDeselectAll()
                } else {
                    onSelectAll()
                }
            }) {
                Text(allSelected ? "Deselect All" : "Select All")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(InsightAtlasColors.gold)
            }
        }
    }
}

// MARK: - Previews

#Preview("Bulk Action Bar") {
    VStack {
        Spacer()
        BulkActionBar(selectedCount: 3, onExport: {}, onCancel: {})
    }
    .background(InsightAtlasColors.background)
}

#Preview("Bulk Export Sheet") {
    BulkExportSheet(selectedCount: 5, onFormatSelected: { _ in }, onCancel: {})
}

#Preview("Export Progress") {
    BulkExportProgressView(
        progress: BulkExportProgress(
            completed: 2,
            total: 5,
            currentTitle: "The Four Agreements",
            phase: .exporting
        ),
        onCancel: {}
    )
}

#Preview("Selection Checkbox") {
    HStack(spacing: 20) {
        SelectionCheckbox(isSelected: false)
        SelectionCheckbox(isSelected: true)
    }
    .padding()
    .background(InsightAtlasColors.background)
}
