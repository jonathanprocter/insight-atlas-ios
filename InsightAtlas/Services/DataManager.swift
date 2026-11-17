import Foundation
import SwiftUI
import PDFKit
import UIKit
import os.log

private let logger = Logger(subsystem: "com.insightatlas", category: "DataManager")

/// Manages persistent data storage for the app
@MainActor
class DataManager: ObservableObject {

    // MARK: - Shared Instance

    static let shared = DataManager()

    // MARK: - Published Properties

    @Published var libraryItems: [LibraryItem] = []
    @Published var userSettings: UserSettings = UserSettings()
    @Published var isLoading: Bool = false

    // MARK: - Private Properties

    private let libraryKey = "insight_atlas_library"
    private let fileManager = FileManager.default

    // MARK: - Initialization

    init() {
        // Migrate API keys from UserDefaults to Keychain (one-time)
        KeychainService.shared.migrateFromUserDefaults()
        loadData()
    }

    // MARK: - Library Management

    /// Add a new item to the library
    func addLibraryItem(_ item: LibraryItem) {
        libraryItems.insert(item, at: 0)
        saveLibrary()
    }

    /// Update an existing library item
    func updateLibraryItem(_ item: LibraryItem) {
        if let index = libraryItems.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = item
            updatedItem.updatedAt = Date()
            libraryItems[index] = updatedItem
            saveLibrary()
        }
    }

    /// Update a library item with new content
    func updateLibraryItem(_ item: LibraryItem, with newContent: String) {
        if let index = libraryItems.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = libraryItems[index]
            updatedItem.summaryContent = newContent
            updatedItem.updatedAt = Date()
            libraryItems[index] = updatedItem
            saveLibrary()
        }
    }

    // MARK: - Narration State (Pocket / Kokoro)

    /// Persist a durable narration lifecycle state on an item so an in-progress
    /// or failed job survives relaunch.
    func setNarrationState(_ state: NarrationState, for itemId: UUID) {
        guard let index = libraryItems.firstIndex(where: { $0.id == itemId }) else { return }
        libraryItems[index].narrationState = state
        libraryItems[index].updatedAt = Date()
        saveLibrary()
    }

    /// Apply a completed narration asset to an item and mark it `.ready`.
    func applyNarration(_ asset: NarrationAsset, for itemId: UUID) {
        guard let index = libraryItems.firstIndex(where: { $0.id == itemId }) else { return }
        libraryItems[index].audioFileURL = asset.relativeFileName
        libraryItems[index].audioVoiceID = asset.voiceID
        libraryItems[index].audioDuration = asset.duration
        libraryItems[index].narrationState = .ready
        libraryItems[index].updatedAt = Date()
        saveLibrary()
    }

    /// Record that the most recent narration attempt failed. Any previously
    /// valid audio is intentionally left untouched.
    func markNarrationFailed(for itemId: UUID) {
        guard let index = libraryItems.firstIndex(where: { $0.id == itemId }) else { return }
        libraryItems[index].narrationState = .failed
        libraryItems[index].updatedAt = Date()
        saveLibrary()
    }

    /// Delete a library item and its associated audio file
    func deleteLibraryItem(_ item: LibraryItem) {
        // Clean up associated audio file if it exists
        cleanupAudioFile(for: item)
        cleanupCoverImage(for: item)
        GuideBodyStore.delete(item.id)
        SourceTextStore.delete(item.id)
        libraryItems.removeAll { $0.id == item.id }
        saveLibrary()
    }

    /// Delete multiple library items and their associated audio files
    func deleteLibraryItems(at offsets: IndexSet) {
        // Clean up audio files for items being deleted
        for index in offsets {
            if index < libraryItems.count {
                cleanupAudioFile(for: libraryItems[index])
                cleanupCoverImage(for: libraryItems[index])
                GuideBodyStore.delete(libraryItems[index].id)
                SourceTextStore.delete(libraryItems[index].id)
            }
        }
        libraryItems.remove(atOffsets: offsets)
        saveLibrary()
    }

    /// The guide body for an item: the in-memory copy when present, otherwise
    /// read from `GuideBodyStore`. Bodies are not hydrated at launch.
    func guideBody(for id: UUID) -> String? {
        if let inline = libraryItems.first(where: { $0.id == id })?.summaryContent, !inline.isEmpty {
            return inline
        }
        return GuideBodyStore.load(id)
    }

    /// Load all library items from storage
    func loadLibraryItems() -> [LibraryItem] {
        return libraryItems
    }

    /// Save a single library item (add or update)
    func saveLibraryItem(_ item: LibraryItem) {
        if let index = libraryItems.firstIndex(where: { $0.id == item.id }) {
            libraryItems[index] = item
        } else {
            libraryItems.insert(item, at: 0)
        }
        saveLibrary()
    }

    /// Clean up audio file associated with a library item
    private func cleanupAudioFile(for item: LibraryItem) {
        guard let audioFileName = item.audioFileURL, !audioFileName.isEmpty else { return }

        // Audio files are stored in the documents directory
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let audioFileURL = documentsDir.appendingPathComponent(audioFileName)

        // Delete the audio file if it exists
        if fileManager.fileExists(atPath: audioFileURL.path) {
            do {
                try fileManager.removeItem(at: audioFileURL)
            } catch {
                // Log error but don't fail the deletion
                logger.warning("Failed to delete audio file \(audioFileName, privacy: .public): \(error.localizedDescription)")
            }
        }
    }

    /// Save cover image data to disk and return the relative path.
    func storeCoverImageData(_ data: Data, for itemID: UUID) -> String? {
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let coversDir = documentsDir.appendingPathComponent("covers", isDirectory: true)
        do {
            if !fileManager.fileExists(atPath: coversDir.path) {
                try fileManager.createDirectory(at: coversDir, withIntermediateDirectories: true)
            }
            let filename = "\(itemID.uuidString).jpg"
            let fileURL = coversDir.appendingPathComponent(filename)
            try data.write(to: fileURL, options: .atomic)
            return "covers/\(filename)"
        } catch {
            logger.warning("Failed to store cover image: \(error.localizedDescription)")
            return nil
        }
    }

    /// Clean up cover image file associated with a library item.
    private func cleanupCoverImage(for item: LibraryItem) {
        guard let coverPath = item.coverImagePath, !coverPath.isEmpty else { return }
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let coverURL = documentsDir.appendingPathComponent(coverPath)

        if fileManager.fileExists(atPath: coverURL.path) {
            do {
                try fileManager.removeItem(at: coverURL)
            } catch {
                logger.warning("Failed to delete cover image \(coverPath, privacy: .public): \(error.localizedDescription)")
            }
        }
    }

    /// Get a specific library item by ID
    func getLibraryItem(id: UUID) -> LibraryItem? {
        return libraryItems.first { $0.id == id }
    }

    /// Save summary content to a library item with optional generation metadata
    func saveSummary(for itemId: UUID, content: String, metadata: GenerationMetadata? = nil) {
        if let index = libraryItems.firstIndex(where: { $0.id == itemId }) {
            libraryItems[index].summaryContent = content
            libraryItems[index].updatedAt = Date()

            // Apply governor metadata if available
            if let meta = metadata {
                libraryItems[index].summaryType = meta.summaryType
                libraryItems[index].governedWordCount = meta.governedWordCount
                libraryItems[index].cutPolicyActivated = meta.cutPolicyActivated
                libraryItems[index].cutEventCount = meta.cutEventCount

                // Apply audio metadata
                libraryItems[index].audioFileURL = meta.audioFileURL
                libraryItems[index].audioVoiceID = meta.audioVoiceID
                libraryItems[index].audioDuration = meta.audioDuration
                libraryItems[index].audioGenerationAttempted = true
            }

            saveLibrary()
        }
    }

    /// Update audio metadata for an existing library item (audio-only generation)
    func updateAudioMetadata(
        for itemId: UUID,
        audioFileURL: String,
        audioVoiceID: String,
        audioDuration: TimeInterval
    ) {
        if let index = libraryItems.firstIndex(where: { $0.id == itemId }) {
            libraryItems[index].audioFileURL = audioFileURL
            libraryItems[index].audioVoiceID = audioVoiceID
            libraryItems[index].audioDuration = audioDuration
            libraryItems[index].audioGenerationAttempted = true
            libraryItems[index].updatedAt = Date()
            saveLibrary()
        }
    }

    // MARK: - Settings Management

    /// AppEnvironment is the settings source of truth. This forwards so any
    /// leftover call site cannot write a divergent UserDefaults blob.
    func updateSettings(_ settings: UserSettings) {
        AppEnvironment.shared.updateSettings(settings)
    }

    /// Update Claude API key (stored securely in Keychain)
    func updateClaudeApiKey(_ key: String?) {
        KeychainService.shared.claudeApiKey = key
    }

    /// Check if API keys are configured (reads from Keychain). Uses the
    /// mirrored settings copy so this never re-enters AppEnvironment.init.
    var hasValidApiKeys: Bool {
        switch userSettings.preferredProvider {
        case .claude:
            return KeychainService.shared.hasClaudeApiKey
        case .openRouter:
            return KeychainService.shared.hasOpenRouterApiKey
        case .minimax:
            return MiniMaxOAuthService.hasStoredCredentials
        }
    }

    // MARK: - Persistence

    private func loadData() {
        loadLibrary()
        // Do not load settings here — AppEnvironment owns UserDefaults and
        // mirrors into `userSettings` on init/save.
    }

    private func loadLibrary() {
        guard let data = UserDefaults.standard.data(forKey: libraryKey) else {
            // No library data yet - this is normal for first launch
            logger.debug("No library data found in UserDefaults")
            return
        }

        do {
            let items = try JSONDecoder().decode([LibraryItem].self, from: data)

            // Bodies stay on disk and load lazily via `guideBody(for:)`. Only
            // libraries written before the split, which still carry text
            // inline, need migrating to files once.
            var pendingMigration: [(UUID, String)] = []
            for item in items {
                if let inline = item.summaryContent, !inline.isEmpty {
                    pendingMigration.append((item.id, inline))
                }
            }
            GuideBodyStore.refreshKnownIDs()

            libraryItems = items.sorted { $0.updatedAt > $1.updatedAt }
            logger.info("Loaded \(items.count) library items")

            let ids = Set(items.map(\.id))
            if pendingMigration.isEmpty {
                Task.detached(priority: .utility) {
                    GuideBodyStore.pruneOrphans(keeping: ids)
                    SourceTextStore.pruneOrphans(keeping: ids)
                }
            } else {
                // Writing every body inline blocked launch on a large library,
                // which iOS terminates as an unresponsive start. Migrate off the
                // main actor, then persist the shrunken metadata blob.
                logger.info("Migrating \(pendingMigration.count) guide body/bodies out of UserDefaults")
                Task.detached(priority: .utility) { [pendingMigration] in
                    for (id, body) in pendingMigration {
                        GuideBodyStore.save(body, for: id)
                    }
                    GuideBodyStore.pruneOrphans(keeping: ids)
                    SourceTextStore.pruneOrphans(keeping: ids)
                    await MainActor.run { DataManager.shared.completeBodyMigration(pendingMigration) }
                }
            }
        } catch {
            logger.error("Failed to decode library: \(error.localizedDescription)")

            // Attempt recovery: back up the corrupted data, then clear the
            // primary key so we don't re-read (and re-fail on) the same blob
            // every launch — otherwise the error recurs and backups accumulate.
            let backupKey = "\(libraryKey)_backup_\(Int(Date().timeIntervalSince1970))"
            UserDefaults.standard.set(data, forKey: backupKey)
            UserDefaults.standard.removeObject(forKey: libraryKey)
            logger.warning("Corrupted library data backed up to '\(backupKey)' and cleared")
            pruneLibraryBackups(keeping: 2)

            // Post notification so UI can inform user
            NotificationCenter.default.post(
                name: .libraryLoadFailed,
                object: nil,
                userInfo: ["error": error.localizedDescription]
            )
        }
    }


    /// Keep only the newest `keeping` corrupted-library backups.
    ///
    /// Each backup is a full copy of the library blob, which carries the guide
    /// text. They were written on every decode failure and never removed, so
    /// repeated corruption grew UserDefaults without bound and none of the
    /// older copies were ever read.
    private func pruneLibraryBackups(keeping: Int) {
        let defaults = UserDefaults.standard
        let prefix = "\(libraryKey)_backup_"
        let backups = defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(prefix) }
            .sorted { lhs, rhs in
                (Int(lhs.dropFirst(prefix.count)) ?? 0) > (Int(rhs.dropFirst(prefix.count)) ?? 0)
            }
        guard backups.count > keeping else { return }
        for stale in backups.dropFirst(keeping) {
            defaults.removeObject(forKey: stale)
        }
        logger.info("Pruned \(backups.count - keeping) stale library backup(s)")
    }

    /// Persist metadata after an out-of-band body migration completes.
    func persistLibraryMetadata() {
        saveLibrary()
    }

    /// Persist the shrunken metadata blob, then release migrated inline bodies
    /// that are unchanged and safely on disk so they are not held in memory.
    private func completeBodyMigration(_ migrated: [(UUID, String)]) {
        persistLibraryMetadata()
        for (id, body) in migrated {
            guard let index = libraryItems.firstIndex(where: { $0.id == id }),
                  libraryItems[index].summaryContent == body,
                  GuideBodyStore.exists(id) else { continue }
            libraryItems[index].summaryContent = nil
        }
    }

    private func saveLibrary() {
        // Guide bodies live in files; UserDefaults holds metadata only. Encoding
        // the bodies here meant every narration-state change rewrote the whole
        // library, and kept all guide text resident from launch.
        var metadataOnly = libraryItems
        for index in metadataOnly.indices {
            guard let body = metadataOnly[index].summaryContent, !body.isEmpty else { continue }
            // Drop the inline copy ONLY once the file is safely written. Ignoring
            // the result erased the body from UserDefaults while it was absent
            // from disk, so the guide came back empty on the next launch.
            if GuideBodyStore.save(body, for: metadataOnly[index].id) {
                metadataOnly[index].summaryContent = nil
            } else {
                logger.error("Guide body write failed; keeping it inline so nothing is lost")
            }
        }

        do {
            let data = try JSONEncoder().encode(metadataOnly)
            UserDefaults.standard.set(data, forKey: libraryKey)
        } catch {
            logger.error("Failed to encode library: \(error.localizedDescription)")
        }
    }

    /// Accept a mirrored copy from AppEnvironment. Does not write UserDefaults.
    func adoptMirroredSettings(_ settings: UserSettings) {
        userSettings = settings
    }

    /// Deprecated: settings persistence lives on AppEnvironment.
    func saveSettings() {
        AppEnvironment.shared.userSettings = userSettings
        AppEnvironment.shared.saveSettings()
    }

    // MARK: - Export

    /// Export progress tracking for async operations
    enum ExportProgress {
        case preparing
        case converting(percent: Double)
        case writing
        case complete
    }

    /// Async export with progress reporting
    /// Note: Yields between phases to allow UI updates during long exports
    nonisolated func exportGuideAsync(
        _ item: LibraryItem,
        format: ExportFormat,
        progress: ((ExportProgress) -> Void)? = nil
    ) async throws -> URL {
        await MainActor.run {
            progress?(.preparing)
        }

        await Task.yield()

        // Rasterize structured visuals into the cache before layout, reporting
        // real prerender progress instead of a cosmetic 50% jump.
        if format == .pdf, let rawContent = item.summaryContent ?? GuideBodyStore.load(item.id) {
            await PDFVisualPrerenderer.prerender(content: rawContent) { done, total in
                let fraction = total > 0 ? Double(done) / Double(total) : 1
                // Reserve 0…0.7 for prerender; layout/write takes the rest.
                progress?(.converting(percent: 0.05 + 0.65 * fraction))
            }
        } else {
            await MainActor.run {
                progress?(.converting(percent: 0.5))
            }
        }

        await MainActor.run {
            progress?(.writing)
        }

        // Run export on the main actor so PDF rendering never needs main.sync.
        let url = try await MainActor.run {
            try exportGuide(item, format: format)
        }

        await MainActor.run {
            progress?(.complete)
        }
        return url
    }

    /// Drop in-memory guide bodies under memory pressure. Bodies remain on disk
    /// via `GuideBodyStore` and reload when a guide is opened.
    @discardableResult
    func purgeResidentGuideBodies() -> Int {
        var purged = 0
        for index in libraryItems.indices {
            if let body = libraryItems[index].summaryContent, !body.isEmpty {
                libraryItems[index].summaryContent = nil
                purged += 1
            }
        }
        return purged
    }

    /// Export a guide to a file with comprehensive error handling
    nonisolated func exportGuide(_ item: LibraryItem, format: ExportFormat) throws -> URL {
        guard let rawContent = item.summaryContent ?? GuideBodyStore.load(item.id), !rawContent.isEmpty else {
            throw DataManagerError.noContent
        }

        // Track A · release gate — applies to every non-PDF format (html/txt/md).
        // Repairs safe defects and blocks export of a manuscript with unshippable
        // defects, so no format can leak a truncated or corrupted guide.
        let content = try ManuscriptGate.prepareForExport(rawContent, title: item.title, author: item.author)

        // Generate clean, readable filename in Title Case with proper formatting
        let sanitizedTitle = sanitizeFilename(item.title)
        let fileName = "\(sanitizedTitle) - Insight Atlas Guide"
        let tempDir = FileManager.default.temporaryDirectory

        do {
            switch format {
            case .markdown:
                // Keep the historical extension for compatibility while making
                // the user-facing payload syntax-free like every other export.
                let readableContent = PresentationTextSanitizer.plainText(content)
                let fileURL = tempDir.appendingPathComponent("\(fileName).md")
                do {
                    try readableContent.write(to: fileURL, atomically: true, encoding: .utf8)
                } catch {
                    throw DataManagerError.fileWriteFailed(path: fileURL.path)
                }
                return fileURL

            case .plainText:
                let plainContent = PresentationTextSanitizer.plainText(content)
                let fileURL = tempDir.appendingPathComponent("\(fileName).txt")
                do {
                    try plainContent.write(to: fileURL, atomically: true, encoding: .utf8)
                } catch {
                    throw DataManagerError.fileWriteFailed(path: fileURL.path)
                }
                return fileURL

            case .html:
                let htmlContent = convertToHTML(content, title: item.title, author: item.author)
                guard !htmlContent.isEmpty else {
                    throw DataManagerError.htmlConversionFailed(reason: "Generated HTML content is empty")
                }
                let fileURL = tempDir.appendingPathComponent("\(fileName).html")
                do {
                    try htmlContent.write(to: fileURL, atomically: true, encoding: .utf8)
                } catch {
                    throw DataManagerError.fileWriteFailed(path: fileURL.path)
                }
                return fileURL

            case .pdf:
                let pdfURL = tempDir.appendingPathComponent("\(fileName).pdf")
                do {
                    try generatePDF(content: content, title: item.title, author: item.author, to: pdfURL)
                } catch let error as DataManagerError {
                    throw error
                } catch {
                    throw DataManagerError.pdfGenerationFailed(reason: error.localizedDescription)
                }
                return pdfURL

            case .docx:
                let docxURL = tempDir.appendingPathComponent("\(fileName).docx")
                do {
                    try generateDOCX(content: content, title: item.title, author: item.author, to: docxURL)
                } catch let error as DataManagerError {
                    throw error
                } catch {
                    throw DataManagerError.docxGenerationFailed(reason: error.localizedDescription)
                }
                return docxURL
            }
        } catch let error as DataManagerError {
            throw error
        } catch {
            throw DataManagerError.exportFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Filename Helpers

    /// Sanitize filename to be clean and readable with proper Title Case
    /// Follows the format: [Book Title] - Insight Atlas Guide
    nonisolated func sanitizeFilename(_ title: String) -> String {
        ExportBrandAssets.sanitizeFilename(title)
    }

    // MARK: - HTML Conversion Helpers

    nonisolated private func convertToHTML(_ markdown: String, title: String, author: String) -> String {
        GuideHTMLExporter.convert(markdown, title: title, author: author)
    }

    nonisolated private func generatePremiumHTML(content: String, title: String, author: String, fullContent: String, tocEntries: [(text: String, level: Int, id: String)] = []) -> String {
        GuideHTMLExporter.generatePremiumHTML(content: content, title: title, author: author, fullContent: fullContent, tocEntries: tocEntries)
    }

    nonisolated private func calculateReadingTime(from content: String) -> Int {
        ExportBrandAssets.calculateReadingTime(from: content)
    }

    nonisolated private func getLogoBase64() -> String? {
        ExportBrandAssets.getLogoBase64()
    }

    nonisolated private func getLogoImage() -> UIImage? {
        ExportBrandAssets.getLogoImage()
    }

    // MARK: - PDF Generation

    nonisolated private func generatePDF(content: String, title: String, author: String, to url: URL) throws {
        try GuidePDFExporter.generate(content: content, title: title, author: author, to: url)
    }

    // MARK: - DOCX Generation

    nonisolated private func generateDOCX(content: String, title: String, author: String, to url: URL) throws {
        try GuideDOCXExporter.generate(content: content, title: title, author: author, to: url)
    }

}

// MARK: - Types

enum ExportFormat: String, CaseIterable {
    case markdown = "Markdown (.md)"
    case plainText = "Plain Text (.txt)"
    case html = "HTML (.html)"
    case pdf = "PDF (.pdf)"
    case docx = "Word Document (.docx)"

    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .plainText: return "txt"
        case .html: return "html"
        case .pdf: return "pdf"
        case .docx: return "docx"
        }
    }
}

enum DataManagerError: LocalizedError {
    case noContent
    case exportFailed(reason: String)
    case pdfGenerationFailed(reason: String)
    case docxGenerationFailed(reason: String)
    case htmlConversionFailed(reason: String)
    case fileWriteFailed(path: String)
    case zipArchiveFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .noContent:
            return "No content available to export. Please generate an analysis first."
        case .exportFailed(let reason):
            return "Failed to export the guide: \(reason)"
        case .pdfGenerationFailed(let reason):
            return "PDF generation failed: \(reason)"
        case .docxGenerationFailed(let reason):
            return "Word document generation failed: \(reason)"
        case .htmlConversionFailed(let reason):
            return "HTML conversion failed: \(reason)"
        case .fileWriteFailed(let path):
            return "Failed to write file to: \(path)"
        case .zipArchiveFailed(let reason):
            return "Failed to create document archive: \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noContent:
            return "Generate an analysis for this book before exporting."
        case .exportFailed:
            return "Try a different export format or check available storage."
        case .pdfGenerationFailed:
            return "Try exporting as HTML or Markdown instead."
        case .docxGenerationFailed:
            return "Try exporting as PDF or HTML instead."
        case .htmlConversionFailed:
            return "Try exporting as Markdown or plain text instead."
        case .fileWriteFailed:
            return "Check if you have sufficient storage space."
        case .zipArchiveFailed:
            return "Try restarting the app and exporting again."
        }
    }
}
