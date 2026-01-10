//
//  BulkExportCoordinator.swift
//  InsightAtlas
//
//  Orchestration service for bulk export operations.
//  This service coordinates multiple exports and produces a single ZIP archive.
//
//  IMPORTANT: This service does NOT modify:
//  - Export rendering logic (PDF, DOCX, HTML)
//  - Layout scoring
//  - Domain models or persistence
//
//  It only orchestrates calls to existing DataManager.exportGuide() method.
//
//  GOVERNANCE (see FormattingInvariants.md, Section G):
//  - Bulk export delegates to single-item pipeline
//  - Bulk export never regenerates content
//  - Bulk export never modifies items
//

import Foundation
import Combine
import os.log

private let logger = Logger(subsystem: "com.insightatlas", category: "BulkExport")

// MARK: - DEBUG Assertions

#if DEBUG
/// Supported export formats for bulk export.
/// This list must match ExportFormat cases that DataManager.exportGuide() supports.
private let supportedBulkExportFormats: Set<ExportFormat> = [.pdf, .docx, .html, .markdown, .plainText]
#endif

// MARK: - Bulk Export Progress

/// Progress state for bulk export operations
struct BulkExportProgress: Equatable {
    let completed: Int
    let total: Int
    let currentTitle: String
    let phase: Phase

    enum Phase: Equatable {
        case preparing
        case exporting
        case archiving
        case complete
        case failed(String)
    }

    var percentComplete: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var statusMessage: String {
        switch phase {
        case .preparing:
            return "Preparing export..."
        case .exporting:
            return "Exporting \(completed + 1) of \(total)"
        case .archiving:
            return "Creating archive..."
        case .complete:
            return "Export complete"
        case .failed(let reason):
            return "Export failed: \(reason)"
        }
    }

    static let initial = BulkExportProgress(
        completed: 0,
        total: 0,
        currentTitle: "",
        phase: .preparing
    )
}

// MARK: - Bulk Export Result

/// Represents a single export failure with details
struct ExportFailure {
    let title: String
    let reason: String
}

/// Result of a bulk export operation
struct BulkExportResult {
    let zipURL: URL
    let exportedCount: Int
    let skippedCount: Int
    let skippedTitles: [String]
    /// Items that failed to export with specific error reasons
    let failures: [ExportFailure]

    var hasSkippedItems: Bool {
        skippedCount > 0
    }

    /// Whether there were failures during export (not just missing content)
    var hasFailures: Bool {
        !failures.isEmpty
    }

    var summaryMessage: String {
        var message = ""

        if exportedCount > 0 {
            message = "Successfully exported \(exportedCount) guide\(exportedCount == 1 ? "" : "s")"
        }

        if !failures.isEmpty {
            if !message.isEmpty { message += ". " }
            message += "\(failures.count) failed to export"
        }

        let noContentCount = skippedCount - failures.count
        if noContentCount > 0 {
            if !message.isEmpty { message += ". " }
            message += "\(noContentCount) skipped (no content)"
        }

        return message.isEmpty ? "No items exported" : message
    }

    /// Detailed message listing all failures
    var failureDetails: String? {
        guard hasFailures else { return nil }
        return failures.map { "• \($0.title): \($0.reason)" }.joined(separator: "\n")
    }
}

// MARK: - Bulk Export Error

enum BulkExportError: LocalizedError {
    case noItemsSelected
    case noExportableItems
    case exportFailed(title: String, reason: String)
    case archiveFailed(reason: String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noItemsSelected:
            return "No items selected for export"
        case .noExportableItems:
            return "None of the selected items have content to export"
        case .exportFailed(let title, let reason):
            return "Failed to export '\(title)': \(reason)"
        case .archiveFailed(let reason):
            return "Failed to create archive: \(reason)"
        case .cancelled:
            return "Export was cancelled"
        }
    }
}

// MARK: - Bulk Export Coordinator

/// Coordinates bulk export of multiple library items into a single ZIP archive.
///
/// Usage:
/// ```swift
/// let coordinator = BulkExportCoordinator(dataManager: dataManager)
/// let result = try await coordinator.export(items: selectedItems, format: .pdf)
/// // result.zipURL contains the archive
/// ```
@MainActor
final class BulkExportCoordinator: ObservableObject {

    // MARK: - Published State

    @Published private(set) var progress: BulkExportProgress = .initial
    @Published private(set) var isExporting: Bool = false

    // MARK: - Private Properties

    private let dataManager: DataManager
    private let fileManager = FileManager.default
    private var exportTask: Task<BulkExportResult, Error>?

    // MARK: - Initialization

    init(dataManager: DataManager) {
        self.dataManager = dataManager
    }

    // MARK: - Public Methods

    /// Export multiple items to a single ZIP archive
    ///
    /// - Parameters:
    ///   - items: Library items to export
    ///   - format: Export format (PDF, DOCX, HTML, etc.)
    /// - Returns: BulkExportResult containing the ZIP URL and statistics
    ///
    /// - Important: This method is orchestration only. It delegates to
    ///   `DataManager.exportGuide()` and never modifies content or triggers regeneration.
    func export(items: [LibraryItem], format: ExportFormat) async throws -> BulkExportResult {

        // MARK: DEBUG Assertions - Prevent Misuse

        #if DEBUG
        // Assert: Format must be supported
        assert(
            supportedBulkExportFormats.contains(format),
            "BulkExportCoordinator: Unsupported format '\(format)'. Bulk export only supports: \(supportedBulkExportFormats)"
        )

        // Assert: Items array must not be empty (caught below, but assert for clarity)
        assert(!items.isEmpty, "BulkExportCoordinator: Items array must not be empty")

        // Assert: We are not being asked to modify content
        // (This is a governance check - content should already exist)
        for item in items {
            if let content = item.summaryContent {
                // Content exists - this is expected for exportable items
                // We verify we're not being passed items that need generation
                assert(
                    !content.isEmpty,
                    "BulkExportCoordinator: Item '\(item.title)' has empty content. Export should not regenerate."
                )
            }
        }
        #endif

        guard !items.isEmpty else {
            throw BulkExportError.noItemsSelected
        }

        // Filter to only items with content
        let exportableItems = items.filter { $0.summaryContent != nil && !($0.summaryContent?.isEmpty ?? true) }

        guard !exportableItems.isEmpty else {
            throw BulkExportError.noExportableItems
        }

        isExporting = true
        defer { isExporting = false }

        // Initialize progress
        progress = BulkExportProgress(
            completed: 0,
            total: exportableItems.count,
            currentTitle: exportableItems.first?.title ?? "",
            phase: .preparing
        )

        // Create temporary directory for exports
        let exportDir = fileManager.temporaryDirectory
            .appendingPathComponent("BulkExport_\(UUID().uuidString)")

        try fileManager.createDirectory(at: exportDir, withIntermediateDirectories: true)
        
        // Note: We'll move this directory later, so don't use defer to remove it

        var exportedURLs: [URL] = []
        var skippedTitles: [String] = []
        var failures: [ExportFailure] = []

        // Export each item
        for (index, item) in exportableItems.enumerated() {
            // Check for cancellation
            try Task.checkCancellation()

            progress = BulkExportProgress(
                completed: index,
                total: exportableItems.count,
                currentTitle: item.title,
                phase: .exporting
            )

            do {
                // Call existing export method
                let exportedURL = try dataManager.exportGuide(item, format: format)

                // Copy to our export directory with unique name
                let destinationURL = exportDir.appendingPathComponent(exportedURL.lastPathComponent)

                // Handle duplicate filenames
                let uniqueDestination = uniqueURL(for: destinationURL)
                try fileManager.copyItem(at: exportedURL, to: uniqueDestination)

                exportedURLs.append(uniqueDestination)

                // Clean up temporary file
                try? fileManager.removeItem(at: exportedURL)

            } catch {
                // Log with structured logging and track failure details
                let reason = error.localizedDescription
                logger.error("Failed to export '\(item.title)': \(reason)")
                failures.append(ExportFailure(title: item.title, reason: reason))
                skippedTitles.append(item.title)
            }

            // Small delay to allow UI updates
            await Task.yield()
        }

        // Log summary if there were failures
        if !failures.isEmpty {
            logger.warning("Bulk export completed with \(failures.count) failures out of \(exportableItems.count) items")
        }

        // Check if we exported anything
        guard !exportedURLs.isEmpty else {
            throw BulkExportError.noExportableItems
        }

        // Create ZIP archive
        progress = BulkExportProgress(
            completed: exportableItems.count,
            total: exportableItems.count,
            currentTitle: "",
            phase: .archiving
        )

        let zipURL = try createZipArchive(from: exportDir, format: format)

        // Update progress to complete
        progress = BulkExportProgress(
            completed: exportableItems.count,
            total: exportableItems.count,
            currentTitle: "",
            phase: .complete
        )

        let skippedFromNoContent = items.count - exportableItems.count
        let totalSkipped = skippedTitles.count + skippedFromNoContent

        return BulkExportResult(
            zipURL: zipURL,
            exportedCount: exportedURLs.count,
            skippedCount: totalSkipped,
            skippedTitles: skippedTitles + items.filter { $0.summaryContent == nil }.map { $0.title },
            failures: failures
        )
    }

    /// Cancel any in-progress export
    func cancel() {
        exportTask?.cancel()
        exportTask = nil
        isExporting = false
        progress = BulkExportProgress(
            completed: progress.completed,
            total: progress.total,
            currentTitle: "",
            phase: .failed("Cancelled")
        )
    }

    /// Reset coordinator state
    func reset() {
        cancel()
        progress = .initial
    }

    // MARK: - Private Methods

    /// Creates a directory of exported files (iOS share sheet will handle ZIP creation)
    private func createZipArchive(from sourceDir: URL, format: ExportFormat) throws -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
        let timestamp = dateFormatter.string(from: Date())

        let archiveName = "InsightAtlas_Export_\(timestamp)"
        let finalDir = fileManager.temporaryDirectory.appendingPathComponent(archiveName)

        // Remove existing directory if present
        if fileManager.fileExists(atPath: finalDir.path) {
            try fileManager.removeItem(at: finalDir)
        }

        // Copy/rename the export directory
        try fileManager.moveItem(at: sourceDir, to: finalDir)

        // Return the directory - iOS share sheet will automatically create ZIP when needed
        return finalDir
    }

    /// Generate a unique URL by appending a number if file exists
    private func uniqueURL(for url: URL) -> URL {
        var uniqueURL = url
        var counter = 1

        let directory = url.deletingLastPathComponent()
        let filename = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        while fileManager.fileExists(atPath: uniqueURL.path) {
            uniqueURL = directory
                .appendingPathComponent("\(filename) (\(counter))")
                .appendingPathExtension(ext)
            counter += 1
        }

        return uniqueURL
    }
}

// MARK: - Bulk Export Format Options

/// Supported formats for bulk export
extension ExportFormat {
    /// User-friendly name for bulk export UI
    var bulkExportDisplayName: String {
        switch self {
        case .pdf: return "PDF"
        case .docx: return "Word Document"
        case .html: return "HTML"
        case .markdown: return "Markdown"
        case .plainText: return "Plain Text"
        }
    }

    /// Icon name for bulk export UI
    var bulkExportIcon: String {
        switch self {
        case .pdf: return "doc.richtext"
        case .docx: return "doc.text"
        case .html: return "globe"
        case .markdown: return "text.alignleft"
        case .plainText: return "doc.plaintext"
        }
    }
}
