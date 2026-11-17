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
        let renderOnMain: () throws -> Void = { [self] in
            // Use the new InsightAtlasPDFRenderer for premium PDF generation
            let pdfRenderer = InsightAtlasPDFRenderer()

            var options = InsightAtlasPDFRenderer.RenderOptions.default
            options.includeCoverPage = true
            options.includeTableOfContents = true
            options.includePageNumbers = true
            options.includeHeader = false
            options.logoImage = self.getLogoImage()

            do {
                let parsedContent = ParsedAnalysisContent.parse(from: content)
                if !parsedContent.sections.isEmpty || parsedContent.quickGlance != nil {
                    let pdfData = try pdfRenderer.generatePDFData(
                        from: parsedContent,
                        title: title,
                        author: author,
                        options: options
                    )
                    try pdfData.write(to: url)
                } else {
                    try pdfRenderer.generatePDF(
                        from: content,
                        title: title,
                        author: author,
                        to: url,
                        options: options
                    )
                }
            } catch {
                // Fall back to legacy PDF generation if new renderer fails
                try self.generateLegacyPDF(content: content, title: title, author: author, to: url)
            }
        }

        if Thread.isMainThread {
            try MainActor.assumeIsolated { try renderOnMain() }
            return
        }

        // Prefer `exportGuideAsync`, which hops with `await MainActor.run` and
        // never uses main.sync. Sync off-main callers are rare; keep a last-
        // resort hop that cannot run while already holding the main thread.
        var renderError: Error?
        DispatchQueue.main.sync {
            do {
                try renderOnMain()
            } catch {
                renderError = error
            }
        }
        if let renderError {
            throw renderError
        }
    }

    /// Legacy PDF generation (fallback)
    nonisolated private func generateLegacyPDF(content: String, title: String, author: String, to url: URL) throws {
        let pageWidth: CGFloat = 612  // US Letter width in points
        let pageHeight: CGFloat = 792 // US Letter height in points
        let margin: CGFloat = 72      // 1 inch margins

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let attributedContent = createAttributedString(from: content, title: title, author: author, pageWidth: pageWidth - margin * 2)

        let data = pdfRenderer.pdfData { context in
            // Draw premium cover page first
            context.beginPage()
            drawPDFCoverPage(context: context.cgContext, title: title, author: author, content: content, pageWidth: pageWidth, pageHeight: pageHeight)

            let textRect = CGRect(x: margin, y: margin, width: pageWidth - margin * 2, height: pageHeight - margin * 2)

            // Calculate text layout for content pages
            let framesetter = CTFramesetterCreateWithAttributedString(attributedContent)
            var currentPosition = 0
            var pageNumber = 1  // Start at 1 since cover page is page 0

            while currentPosition < attributedContent.length {
                context.beginPage()
                pageNumber += 1

                // Draw header on first content page (page 2)
                if pageNumber == 2 {
                    drawPDFHeader(context: context.cgContext, title: title, author: author, rect: textRect)
                }

                let headerOffset: CGFloat = pageNumber == 2 ? 190 : 0 // Includes logo height on first content page
                let contentRect = CGRect(x: textRect.origin.x,
                                        y: textRect.origin.y + headerOffset,
                                        width: textRect.width,
                                        height: textRect.height - headerOffset - 30) // Leave room for footer

                let path = CGPath(rect: contentRect, transform: nil)
                let frame = CTFramesetterCreateFrame(framesetter,
                                                     CFRangeMake(currentPosition, 0),
                                                     path,
                                                     nil)

                // Draw the text
                context.cgContext.textMatrix = .identity
                context.cgContext.translateBy(x: 0, y: pageHeight)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)

                CTFrameDraw(frame, context.cgContext)

                // Get the range that was drawn
                let visibleRange = CTFrameGetVisibleStringRange(frame)
                currentPosition += visibleRange.length

                // Reset transform for footer
                context.cgContext.scaleBy(x: 1.0, y: -1.0)
                context.cgContext.translateBy(x: 0, y: -pageHeight)

                // Draw page footer (showing page number minus 1 so content starts at page 1)
                drawPDFFooter(context: context.cgContext, pageNumber: pageNumber - 1, pageWidth: pageWidth, pageHeight: pageHeight)
            }
        }

        try data.write(to: url)
    }

    nonisolated private func drawPDFHeader(context: CGContext, title: String, author: String, rect: CGRect) {
        var yOffset: CGFloat = rect.origin.y

        // Draw logo if available
        if let logo = getLogoImage() {
            let logoHeight: CGFloat = 60
            let logoWidth = logoHeight * (logo.size.width / logo.size.height)
            let logoRect = CGRect(x: rect.origin.x, y: yOffset, width: logoWidth, height: logoHeight)
            logo.draw(in: logoRect)
            yOffset += logoHeight + 10
        }

        // Brand text
        let brandAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor.iaGold,
            .kern: 2
        ]
        let brandText = "INSIGHT ATLAS GUIDE"
        let brandString = NSAttributedString(string: brandText, attributes: brandAttributes)
        brandString.draw(at: CGPoint(x: rect.origin.x, y: yOffset))

        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .bold),
            .foregroundColor: UIColor.iaHeading
        ]
        let titleString = NSAttributedString(string: title, attributes: titleAttributes)
        titleString.draw(at: CGPoint(x: rect.origin.x, y: yOffset + 20))

        // Author
        let authorAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 14),
            .foregroundColor: UIColor.iaMuted
        ]
        let authorString = NSAttributedString(string: "by \(author)", attributes: authorAttributes)
        authorString.draw(at: CGPoint(x: rect.origin.x, y: yOffset + 55))

        // Gold divider line
        context.setStrokeColor(UIColor.iaGold.cgColor)
        context.setLineWidth(2)
        context.move(to: CGPoint(x: rect.origin.x, y: yOffset + 85))
        context.addLine(to: CGPoint(x: rect.origin.x + rect.width, y: yOffset + 85))
        context.strokePath()
    }

    nonisolated private func drawPDFFooter(context: CGContext, pageNumber: Int, pageWidth: CGFloat, pageHeight: CGFloat) {
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.iaMuted
        ]

        let footerText = "Insight Atlas Guide • Page \(pageNumber)"
        let footerString = NSAttributedString(string: footerText, attributes: footerAttributes)
        let footerSize = footerString.size()

        footerString.draw(at: CGPoint(x: (pageWidth - footerSize.width) / 2, y: pageHeight - 50))
    }

    // MARK: - Premium Cover Page

    /// Extracts the Quick Glance content from the guide for the cover page
    nonisolated private func extractQuickGlanceForCover(from content: String) -> [String] {
        var bullets: [String] = []
        let lines = content.components(separatedBy: .newlines)
        var inQuickGlance = false

        for line in lines {
            if line.hasPrefix("[QUICK_GLANCE]") {
                inQuickGlance = true
                continue
            }
            if line.hasPrefix("[/QUICK_GLANCE]") {
                break // Only use first Quick Glance block
            }
            if inQuickGlance {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // Extract bullet points (lines starting with - or •)
                if trimmed.hasPrefix("-") || trimmed.hasPrefix("•") || trimmed.hasPrefix("*") {
                    var bulletText = trimmed
                    bulletText.removeFirst()
                    bulletText = bulletText.trimmingCharacters(in: .whitespaces)
                    // Strip markdown from bullet text
                    bulletText = stripMarkdownForPDF(bulletText)
                    if !bulletText.isEmpty && bullets.count < 5 {
                        bullets.append(bulletText)
                    }
                }
            }
        }

        return bullets
    }

    /// Draws decorative corner frames on the cover page
    nonisolated private func drawCornerFrames(context: CGContext, pageWidth: CGFloat, pageHeight: CGFloat, margin: CGFloat) {
        let cornerLength: CGFloat = 40
        let cornerInset: CGFloat = margin - 20

        context.setStrokeColor(UIColor.iaGold.cgColor)
        context.setLineWidth(2)

        // Top-left corner
        context.move(to: CGPoint(x: cornerInset, y: cornerInset + cornerLength))
        context.addLine(to: CGPoint(x: cornerInset, y: cornerInset))
        context.addLine(to: CGPoint(x: cornerInset + cornerLength, y: cornerInset))

        // Top-right corner
        context.move(to: CGPoint(x: pageWidth - cornerInset - cornerLength, y: cornerInset))
        context.addLine(to: CGPoint(x: pageWidth - cornerInset, y: cornerInset))
        context.addLine(to: CGPoint(x: pageWidth - cornerInset, y: cornerInset + cornerLength))

        // Bottom-left corner
        context.move(to: CGPoint(x: cornerInset, y: pageHeight - cornerInset - cornerLength))
        context.addLine(to: CGPoint(x: cornerInset, y: pageHeight - cornerInset))
        context.addLine(to: CGPoint(x: cornerInset + cornerLength, y: pageHeight - cornerInset))

        // Bottom-right corner
        context.move(to: CGPoint(x: pageWidth - cornerInset - cornerLength, y: pageHeight - cornerInset))
        context.addLine(to: CGPoint(x: pageWidth - cornerInset, y: pageHeight - cornerInset))
        context.addLine(to: CGPoint(x: pageWidth - cornerInset, y: pageHeight - cornerInset - cornerLength))

        context.strokePath()
    }

    /// Draws the premium cover page for PDF exports
    nonisolated private func drawPDFCoverPage(context: CGContext, title: String, author: String, content: String, pageWidth: CGFloat, pageHeight: CGFloat) {
        let margin: CGFloat = 72
        let centerX = pageWidth / 2

        // Draw decorative corner frames
        drawCornerFrames(context: context, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin)

        var yPosition: CGFloat = 120

        // Draw logo centered at top
        if let logo = getLogoImage() {
            let logoHeight: CGFloat = 80
            let logoWidth = logoHeight * (logo.size.width / logo.size.height)
            let logoRect = CGRect(x: centerX - logoWidth / 2, y: yPosition, width: logoWidth, height: logoHeight)
            logo.draw(in: logoRect)
            yPosition += logoHeight + 20
        }

        // Brand text - "INSIGHT ATLAS"
        let brandAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: UIColor.iaGold,
            .kern: 4
        ]
        let brandText = "INSIGHT ATLAS"
        let brandString = NSAttributedString(string: brandText, attributes: brandAttributes)
        let brandSize = brandString.size()
        brandString.draw(at: CGPoint(x: centerX - brandSize.width / 2, y: yPosition))
        yPosition += 40

        // Gold decorative line
        context.setStrokeColor(UIColor.iaGold.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: margin + 80, y: yPosition))
        context.addLine(to: CGPoint(x: pageWidth - margin - 80, y: yPosition))
        context.strokePath()
        yPosition += 30

        // Main title - large, bold, centered
        let titleStyle = NSMutableParagraphStyle()
        titleStyle.alignment = .center
        titleStyle.lineSpacing = 8

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 36, weight: .bold),
            .foregroundColor: UIColor.iaHeading,
            .paragraphStyle: titleStyle
        ]

        let titleRect = CGRect(x: margin, y: yPosition, width: pageWidth - margin * 2, height: 120)
        let titleString = NSAttributedString(string: title.uppercased(), attributes: titleAttributes)
        titleString.draw(in: titleRect)
        yPosition += 100

        // Author line
        let authorStyle = NSMutableParagraphStyle()
        authorStyle.alignment = .center

        let authorAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 16),
            .foregroundColor: UIColor.iaMuted,
            .paragraphStyle: authorStyle
        ]
        let authorString = NSAttributedString(string: "Based on the work of \(author)", attributes: authorAttributes)
        let authorRect = CGRect(x: margin, y: yPosition, width: pageWidth - margin * 2, height: 30)
        authorString.draw(in: authorRect)
        yPosition += 50

        // Another decorative line
        context.setStrokeColor(UIColor.iaGold.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: margin + 80, y: yPosition))
        context.addLine(to: CGPoint(x: pageWidth - margin - 80, y: yPosition))
        context.strokePath()
        yPosition += 40

        // "AT A GLANCE" card
        let quickGlanceBullets = extractQuickGlanceForCover(from: content)

        if !quickGlanceBullets.isEmpty {
            let cardMargin: CGFloat = 60
            let cardX = cardMargin
            let cardWidth = pageWidth - cardMargin * 2
            let cardY = yPosition

            // Calculate card height based on content
            let bulletLineHeight: CGFloat = 24
            let cardPadding: CGFloat = 20
            let headerHeight: CGFloat = 35
            let cardHeight = headerHeight + cardPadding * 2 + CGFloat(quickGlanceBullets.count) * bulletLineHeight + 10

            // Draw card background with subtle border
            let cardRect = CGRect(x: cardX, y: cardY, width: cardWidth, height: cardHeight)

            // Fill with light background
            context.setFillColor(UIColor.iaCard.cgColor)
            context.fill(cardRect)

            // Draw burgundy accent line at top of card
            context.setFillColor(UIColor.iaBurgundy.cgColor)
            context.fill(CGRect(x: cardX, y: cardY, width: cardWidth, height: 4))

            // Card header - "AT A GLANCE"
            let cardHeaderAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: UIColor.iaBurgundy,
                .kern: 2
            ]
            let cardHeaderString = NSAttributedString(string: "AT A GLANCE", attributes: cardHeaderAttributes)
            cardHeaderString.draw(at: CGPoint(x: cardX + cardPadding, y: cardY + 12))

            // Draw bullet points
            let bulletAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Georgia", size: 11) ?? UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.iaBody
            ]

            let bulletSymbolAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.iaGold
            ]

            var bulletY = cardY + headerHeight + 8
            let bulletTextWidth = cardWidth - cardPadding * 2 - 25  // Available width for text

            for bullet in quickGlanceBullets {
                // Gold bullet symbol
                let bulletSymbol = NSAttributedString(string: "◆  ", attributes: bulletSymbolAttributes)
                bulletSymbol.draw(at: CGPoint(x: cardX + cardPadding, y: bulletY))

                // Bullet text with word wrapping instead of truncation
                let bulletParagraphStyle = NSMutableParagraphStyle()
                bulletParagraphStyle.lineBreakMode = .byWordWrapping

                var wrappedBulletAttributes = bulletAttributes
                wrappedBulletAttributes[.paragraphStyle] = bulletParagraphStyle

                let bulletTextString = NSAttributedString(string: bullet, attributes: wrappedBulletAttributes)
                let bulletTextRect = CGRect(x: cardX + cardPadding + 20, y: bulletY, width: bulletTextWidth, height: bulletLineHeight * 3)
                bulletTextString.draw(with: bulletTextRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)

                // Calculate actual height used and advance accordingly
                let boundingRect = bulletTextString.boundingRect(with: CGSize(width: bulletTextWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, context: nil)
                bulletY += max(bulletLineHeight, boundingRect.height + 4)
            }

            yPosition = cardY + cardHeight + 30
        }

        // Tagline at bottom
        let taglineStyle = NSMutableParagraphStyle()
        taglineStyle.alignment = .center

        let taglineAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 12),
            .foregroundColor: UIColor.iaMuted,
            .paragraphStyle: taglineStyle
        ]
        let taglineString = NSAttributedString(string: "Where Understanding Illuminates the World", attributes: taglineAttributes)
        let taglineRect = CGRect(x: margin, y: pageHeight - 80, width: pageWidth - margin * 2, height: 30)
        taglineString.draw(in: taglineRect)

        // Small decorative element above tagline
        let diamondAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.iaGold
        ]
        let diamondStyle = NSMutableParagraphStyle()
        diamondStyle.alignment = .center
        var diamondAttrs = diamondAttributes
        diamondAttrs[.paragraphStyle] = diamondStyle
        let diamondString = NSAttributedString(string: "◆ ◇ ◆", attributes: diamondAttrs)
        let diamondRect = CGRect(x: margin, y: pageHeight - 100, width: pageWidth - margin * 2, height: 20)
        diamondString.draw(in: diamondRect)
    }

    /// Strips all markdown formatting from text for clean PDF output
    nonisolated private func stripMarkdownForPDF(_ text: String) -> String {
        var result = text

        // Remove bold markers
        if let regex = try? NSRegularExpression(pattern: #"\*\*([^*]+)\*\*"#) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1")
        }

        // Remove italic markers (single asterisks around text)
        if let regex = try? NSRegularExpression(pattern: #"(?<!\*)\*([^*]+)\*(?!\*)"#) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1")
        }

        // Remove code backticks
        result = result.replacingOccurrences(of: "`", with: "")

        // Remove markdown links, keep text: [text](url) -> text
        if let regex = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\([^)]+\)"#) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1")
        }

        return result
    }

    /// Checks if a line is a markdown table separator (like |---|---|)
    nonisolated private func isTableSeparator(_ line: String) -> Bool {
        ExportMarkdownTable.isTableSeparator(line)
    }

    /// Parses a markdown table line into cells
    nonisolated private func parseTableRow(_ line: String) -> [String] {
        ExportMarkdownTable.parseTableRow(line)
    }

    nonisolated private func createAttributedString(from content: String, title: String, author: String, pageWidth: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // Default paragraph style
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        paragraphStyle.paragraphSpacing = 12

        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Georgia", size: 12) ?? UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.iaBody,
            .paragraphStyle: paragraphStyle
        ]

        let headingStyle = NSMutableParagraphStyle()
        headingStyle.paragraphSpacingBefore = 24
        headingStyle.paragraphSpacing = 8

        let partHeadingStyle = NSMutableParagraphStyle()
        partHeadingStyle.paragraphSpacingBefore = 32
        partHeadingStyle.paragraphSpacing = 12

        // Special block styles
        let blockHeaderStyle = NSMutableParagraphStyle()
        blockHeaderStyle.paragraphSpacingBefore = 16
        blockHeaderStyle.paragraphSpacing = 4

        let quickGlanceHeaderAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor.iaGold,
            .paragraphStyle: blockHeaderStyle
        ]

        let insightNoteHeaderAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor.iaCoral,
            .paragraphStyle: blockHeaderStyle
        ]

        let actionBoxHeaderAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor.iaBurgundy,
            .paragraphStyle: blockHeaderStyle
        ]

        let blockContentStyle = NSMutableParagraphStyle()
        blockContentStyle.lineSpacing = 4
        blockContentStyle.paragraphSpacing = 8
        blockContentStyle.firstLineHeadIndent = 12
        blockContentStyle.headIndent = 12

        let blockContentAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Georgia", size: 11) ?? UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.iaBody,
            .paragraphStyle: blockContentStyle
        ]

        // Divider style
        let dividerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.iaGold
        ]

        // Table cell style
        let tableCellStyle = NSMutableParagraphStyle()
        tableCellStyle.lineSpacing = 2
        tableCellStyle.paragraphSpacing = 4

        let tableHeaderAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor.iaHeading,
            .paragraphStyle: tableCellStyle
        ]

        let tableCellAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Georgia", size: 10) ?? UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.iaBody,
            .paragraphStyle: tableCellStyle
        ]

        // Parse content and build attributed string
        let lines = content.components(separatedBy: "\n")
        var inSpecialBlock = false
        var currentBlockType = ""
        var inTable = false

        for line in lines {
            // Handle special block opening markers
            if line.hasPrefix("[QUICK_GLANCE]") {
                inSpecialBlock = true
                currentBlockType = "QUICK_GLANCE"
                result.append(NSAttributedString(string: "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", attributes: [.foregroundColor: UIColor.iaGold]))
                result.append(NSAttributedString(string: "👁 QUICK GLANCE\n", attributes: quickGlanceHeaderAttributes))

                // Add dynamic reading time
                let readingTime = calculateReadingTime(from: content)
                result.append(NSAttributedString(string: "\(readingTime) min read\n\n", attributes: [
                    .font: UIFont.systemFont(ofSize: 9, weight: .medium),
                    .foregroundColor: UIColor.iaGold
                ]))
                continue
            }

            if line.hasPrefix("[INSIGHT_NOTE]") {
                inSpecialBlock = true
                currentBlockType = "INSIGHT_NOTE"
                result.append(NSAttributedString(string: "\n💡 INSIGHT ATLAS NOTE\n", attributes: insightNoteHeaderAttributes))
                continue
            }

            if line.hasPrefix("[ACTION_BOX") {
                inSpecialBlock = true
                currentBlockType = "ACTION_BOX"
                result.append(NSAttributedString(string: "\n✓ APPLY IT\n", attributes: actionBoxHeaderAttributes))
                continue
            }

            if line.hasPrefix("[FOUNDATIONAL_NARRATIVE]") {
                inSpecialBlock = true
                currentBlockType = "FOUNDATIONAL_NARRATIVE"
                result.append(NSAttributedString(string: "\n📖 THE STORY BEHIND THE IDEAS\n", attributes: quickGlanceHeaderAttributes))
                continue
            }

            if line.hasPrefix("[STRUCTURE_MAP]") {
                inSpecialBlock = true
                currentBlockType = "STRUCTURE_MAP"
                result.append(NSAttributedString(string: "\n🗺️ STRUCTURE MAP\n", attributes: quickGlanceHeaderAttributes))
                continue
            }

            if line.hasPrefix("[TAKEAWAYS]") {
                inSpecialBlock = true
                currentBlockType = "TAKEAWAYS"
                result.append(NSAttributedString(string: "\n⭐ KEY TAKEAWAYS\n", attributes: quickGlanceHeaderAttributes))
                continue
            }

            if line.hasPrefix("[VISUAL_FLOWCHART") {
                inSpecialBlock = true
                currentBlockType = "VISUAL_FLOWCHART"
                result.append(NSAttributedString(string: "\n📊 VISUAL GUIDE\n", attributes: quickGlanceHeaderAttributes))
                continue
            }

            if line.hasPrefix("[VISUAL_TABLE") {
                inSpecialBlock = true
                currentBlockType = "VISUAL_TABLE"
                result.append(NSAttributedString(string: "\n📋 REFERENCE TABLE\n", attributes: quickGlanceHeaderAttributes))
                continue
            }

            if line.hasPrefix("[EXERCISE_") || line.hasPrefix("[EXERCISE]") {
                inSpecialBlock = true
                currentBlockType = "EXERCISE"
                result.append(NSAttributedString(string: "\n✏️ EXERCISE\n", attributes: actionBoxHeaderAttributes))
                continue
            }

            if line.hasPrefix("[QUOTE]") {
                inSpecialBlock = true
                currentBlockType = "QUOTE"
                continue
            }

            // Handle special block closing markers
            if line.hasPrefix("[/QUICK_GLANCE]") || line.hasPrefix("[/INSIGHT_NOTE]") ||
               line.hasPrefix("[/ACTION_BOX]") || line.hasPrefix("[/QUOTE]") ||
               line.hasPrefix("[/FOUNDATIONAL_NARRATIVE]") || line.hasPrefix("[/STRUCTURE_MAP]") ||
               line.hasPrefix("[/TAKEAWAYS]") || line.hasPrefix("[/VISUAL_FLOWCHART]") ||
               line.hasPrefix("[/VISUAL_TABLE]") || line.hasPrefix("[/EXERCISE") {
                if currentBlockType == "QUICK_GLANCE" {
                    result.append(NSAttributedString(string: "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", attributes: [.foregroundColor: UIColor.iaGold]))
                }
                inSpecialBlock = false
                currentBlockType = ""
                inTable = false
                continue
            }

            // Skip any remaining block markers
            if line.hasPrefix("[") && line.contains("]") && !line.contains("](") {
                continue
            }

            // Skip box drawing characters but render cleaner version
            if line.contains("┌") || line.contains("├") || line.contains("└") ||
               line.contains("│") || line.contains("─") || line.contains("┐") ||
               line.contains("┤") || line.contains("┘") {
                // Clean the line of box characters for PDF
                var cleanLine = line
                for char in ["┌", "├", "└", "│", "─", "┐", "┤", "┘"] {
                    cleanLine = cleanLine.replacingOccurrences(of: char, with: "")
                }
                cleanLine = cleanLine.trimmingCharacters(in: .whitespaces)
                cleanLine = stripMarkdownForPDF(cleanLine)
                if !cleanLine.isEmpty && !cleanLine.contains("↓") {
                    result.append(NSAttributedString(string: "  \(cleanLine)\n", attributes: blockContentAttributes))
                }
                continue
            }

            // Skip arrow indicators (render as flow indicator)
            if line.trimmingCharacters(in: .whitespaces) == "↓" {
                result.append(NSAttributedString(string: "    ↓\n", attributes: [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.iaGold
                ]))
                continue
            }

            // Handle horizontal rules (---)
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine == "---" || trimmedLine == "***" || trimmedLine == "___" {
                result.append(NSAttributedString(string: "\n◆ ◇ ◆\n\n", attributes: dividerAttributes))
                continue
            }

            // Handle ═══ box drawing dividers - convert to premium ornament
            if trimmedLine.contains("═══") || (trimmedLine.count > 3 && trimmedLine.filter({ $0 == "═" }).count > trimmedLine.count / 2) {
                result.append(NSAttributedString(string: "\n◇ ◆ ◇\n\n", attributes: dividerAttributes))
                continue
            }

            // Handle markdown tables
            if trimmedLine.hasPrefix("|") && trimmedLine.contains("|") {
                // Check if this is a separator line
                if isTableSeparator(trimmedLine) {
                    continue // Skip separator lines
                }

                let cells = parseTableRow(trimmedLine)
                if !cells.isEmpty {
                    if !inTable {
                        // This is the header row
                        inTable = true
                        let headerText = cells.joined(separator: "  |  ")
                        result.append(NSAttributedString(string: "\(headerText)\n", attributes: tableHeaderAttributes))
                        result.append(NSAttributedString(string: "─────────────────────────────────────\n", attributes: dividerAttributes))
                    } else {
                        // Data row
                        let rowText = cells.joined(separator: "  |  ")
                        result.append(NSAttributedString(string: "\(stripMarkdownForPDF(rowText))\n", attributes: tableCellAttributes))
                    }
                }
                continue
            } else if inTable && !trimmedLine.isEmpty && !trimmedLine.hasPrefix("|") {
                // End of table
                inTable = false
                result.append(NSAttributedString(string: "\n", attributes: bodyAttributes))
            }

            // Content inside special blocks
            if inSpecialBlock {
                if !trimmedLine.isEmpty {
                    // Skip lines that are just ## headers inside blocks (often duplicates)
                    if trimmedLine.hasPrefix("## ") {
                        continue
                    }

                    // Handle quote blocks specially
                    if currentBlockType == "QUOTE" {
                        let quoteStyle = NSMutableParagraphStyle()
                        quoteStyle.firstLineHeadIndent = 20
                        quoteStyle.headIndent = 20
                        let quoteAttributes: [NSAttributedString.Key: Any] = [
                            .font: UIFont.italicSystemFont(ofSize: 12),
                            .foregroundColor: UIColor.iaMuted,
                            .paragraphStyle: quoteStyle
                        ]
                        let cleanText = stripMarkdownForPDF(trimmedLine)
                        result.append(NSAttributedString(string: "\"\(cleanText)\"\n", attributes: quoteAttributes))
                    }
                    // Handle list items in blocks
                    else if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("* ") {
                        let itemText = stripMarkdownForPDF(String(trimmedLine.dropFirst(2)))
                        result.append(NSAttributedString(string: "  • \(itemText)\n", attributes: blockContentAttributes))
                    }
                    // Handle numbered items in blocks
                    else if let _ = trimmedLine.range(of: "^\\d+\\.", options: .regularExpression) {
                        let cleanText = stripMarkdownForPDF(trimmedLine)
                        result.append(NSAttributedString(string: "  \(cleanText)\n", attributes: blockContentAttributes))
                    }
                    // Regular block content
                    else {
                        let cleanText = stripMarkdownForPDF(trimmedLine)
                        result.append(NSAttributedString(string: "  \(cleanText)\n", attributes: blockContentAttributes))
                    }
                }
                continue
            }

            // Handle # PART headers (main section dividers)
            if line.hasPrefix("# ") && !line.hasPrefix("## ") {
                let headerText = stripMarkdownForPDF(String(line.dropFirst(2)))
                let partAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                    .foregroundColor: UIColor.iaHeading,
                    .paragraphStyle: partHeadingStyle
                ]
                result.append(NSAttributedString(string: "\n", attributes: bodyAttributes))
                result.append(NSAttributedString(string: "◆ ◇ ◆\n\n", attributes: dividerAttributes))
                result.append(NSAttributedString(string: "\(headerText)\n", attributes: partAttributes))
                continue
            }

            // Headers
            if line.hasPrefix("## ") {
                let headerText = stripMarkdownForPDF(String(line.dropFirst(3)))
                let headerAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                    .foregroundColor: UIColor.iaHeading,
                    .paragraphStyle: headingStyle
                ]
                result.append(NSAttributedString(string: "\n\(headerText)\n", attributes: headerAttributes))
                continue
            }

            if line.hasPrefix("### ") {
                let headerText = stripMarkdownForPDF(String(line.dropFirst(4)))
                let headerAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                    .foregroundColor: UIColor.iaHeading,
                    .paragraphStyle: headingStyle
                ]
                result.append(NSAttributedString(string: "\n\(headerText)\n", attributes: headerAttributes))
                continue
            }

            // List items
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                let itemText = stripMarkdownForPDF(String(line.dropFirst(2)))
                result.append(NSAttributedString(string: "• \(itemText)\n", attributes: bodyAttributes))
                continue
            }

            // Numbered list items
            if let _ = trimmedLine.range(of: "^\\d+\\.", options: .regularExpression) {
                let cleanText = stripMarkdownForPDF(trimmedLine)
                result.append(NSAttributedString(string: "\(cleanText)\n", attributes: bodyAttributes))
                continue
            }

            // Regular text
            if !trimmedLine.isEmpty {
                // Strip all markdown formatting
                let processedLine = stripMarkdownForPDF(line)
                result.append(NSAttributedString(string: processedLine + "\n", attributes: bodyAttributes))
            } else {
                result.append(NSAttributedString(string: "\n", attributes: bodyAttributes))
            }
        }

        return result
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
