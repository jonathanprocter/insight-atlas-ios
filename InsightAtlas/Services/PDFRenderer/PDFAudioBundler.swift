import Foundation
import ZIPFoundation
import UIKit

// MARK: - PDF Audio Bundler
// Creates exportable bundles combining PDF guides with audio narration

final class PDFAudioBundler {

    // MARK: - Types

    enum BundleError: LocalizedError {
        case pdfDataMissing
        case audioFileMissing
        case zipCreationFailed(Error)
        case exportDirectoryUnavailable

        var errorDescription: String? {
            switch self {
            case .pdfDataMissing:
                return "PDF data is missing"
            case .audioFileMissing:
                return "Audio file is missing"
            case .zipCreationFailed(let error):
                return "Failed to create ZIP archive: \(error.localizedDescription)"
            case .exportDirectoryUnavailable:
                return "Export directory is unavailable"
            }
        }
    }

    enum ExportFormat: String, CaseIterable, Identifiable {
        case pdfOnly = "PDF Only"
        case audioOnly = "Audio Only"
        case bundled = "PDF + Audio Bundle"

        var id: String { rawValue }

        var fileExtension: String {
            switch self {
            case .pdfOnly: return "pdf"
            case .audioOnly: return "mp3"
            case .bundled: return "zip"
            }
        }

        var systemImage: String {
            switch self {
            case .pdfOnly: return "doc.fill"
            case .audioOnly: return "speaker.wave.2.fill"
            case .bundled: return "archivebox.fill"
            }
        }
    }

    struct BundleResult {
        let url: URL
        let format: ExportFormat
        let fileSize: Int64
    }

    // MARK: - Properties

    private let fileManager = FileManager.default

    // MARK: - Public Methods

    /// Create an exportable bundle from a PDF and optional audio file
    /// - Parameters:
    ///   - pdfData: The PDF data to include
    ///   - audioURL: Optional audio file URL
    ///   - title: Document title for filename
    ///   - format: Export format (PDF only, audio only, or bundled)
    /// - Returns: BundleResult with URL to the created file
    func createBundle(
        pdfData: Data?,
        audioURL: URL?,
        title: String,
        format: ExportFormat
    ) throws -> BundleResult {
        let sanitizedTitle = sanitizeFilename(title)
        let exportDir = try getExportDirectory()

        switch format {
        case .pdfOnly:
            guard let pdf = pdfData else {
                throw BundleError.pdfDataMissing
            }
            let pdfURL = exportDir.appendingPathComponent("\(sanitizedTitle).pdf")
            try pdf.write(to: pdfURL)
            let size = try fileManager.attributesOfItem(atPath: pdfURL.path)[.size] as? Int64 ?? 0
            return BundleResult(url: pdfURL, format: format, fileSize: size)

        case .audioOnly:
            guard let audio = audioURL else {
                throw BundleError.audioFileMissing
            }
            let audioDestURL = exportDir.appendingPathComponent("\(sanitizedTitle).mp3")
            if fileManager.fileExists(atPath: audioDestURL.path) {
                try fileManager.removeItem(at: audioDestURL)
            }
            try fileManager.copyItem(at: audio, to: audioDestURL)
            let size = try fileManager.attributesOfItem(atPath: audioDestURL.path)[.size] as? Int64 ?? 0
            return BundleResult(url: audioDestURL, format: format, fileSize: size)

        case .bundled:
            return try createZIPBundle(pdfData: pdfData, audioURL: audioURL, title: sanitizedTitle, exportDir: exportDir)
        }
    }

    /// Determine available export formats based on content
    /// - Parameters:
    ///   - hasPDF: Whether PDF data is available
    ///   - hasAudio: Whether audio file is available
    /// - Returns: Array of available export formats
    func availableFormats(hasPDF: Bool, hasAudio: Bool) -> [ExportFormat] {
        var formats: [ExportFormat] = []

        if hasPDF {
            formats.append(.pdfOnly)
        }

        if hasAudio {
            formats.append(.audioOnly)
        }

        if hasPDF && hasAudio {
            formats.append(.bundled)
        }

        return formats
    }

    /// Get human-readable file size string
    /// - Parameter bytes: File size in bytes
    /// - Returns: Formatted string (e.g., "2.4 MB")
    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Private Methods

    private func createZIPBundle(
        pdfData: Data?,
        audioURL: URL?,
        title: String,
        exportDir: URL
    ) throws -> BundleResult {
        // Create a temporary directory for bundle contents
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Add PDF if available
        if let pdf = pdfData {
            let pdfPath = tempDir.appendingPathComponent("\(title).pdf")
            try pdf.write(to: pdfPath)
        }

        // Add audio if available
        if let audio = audioURL {
            let audioFilename = "\(title)_narration.mp3"
            let audioPath = tempDir.appendingPathComponent(audioFilename)
            try fileManager.copyItem(at: audio, to: audioPath)
        }

        // Add README file with bundle info
        let readmeContent = createReadmeContent(title: title, hasPDF: pdfData != nil, hasAudio: audioURL != nil)
        let readmePath = tempDir.appendingPathComponent("README.txt")
        try readmeContent.write(to: readmePath, atomically: true, encoding: .utf8)

        // Create ZIP archive
        let zipURL = exportDir.appendingPathComponent("\(title)_bundle.zip")

        if fileManager.fileExists(atPath: zipURL.path) {
            try fileManager.removeItem(at: zipURL)
        }

        do {
            try fileManager.zipItem(at: tempDir, to: zipURL)
        } catch {
            throw BundleError.zipCreationFailed(error)
        }

        let size = try fileManager.attributesOfItem(atPath: zipURL.path)[.size] as? Int64 ?? 0
        return BundleResult(url: zipURL, format: .bundled, fileSize: size)
    }

    private func createReadmeContent(title: String, hasPDF: Bool, hasAudio: Bool) -> String {
        var content = """
        Insight Atlas Export Bundle
        ===========================

        Title: \(title)

        Contents:
        """

        if hasPDF {
            content += "\n- \(title).pdf - Complete guide document"
        }

        if hasAudio {
            content += "\n- \(title)_narration.mp3 - Audio narration"
        }

        content += """


        ---
        Created with Insight Atlas
        https://insightatlas.app
        """

        return content
    }

    private func getExportDirectory() throws -> URL {
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw BundleError.exportDirectoryUnavailable
        }

        let exportDir = documentsDir.appendingPathComponent("Exports", isDirectory: true)

        if !fileManager.fileExists(atPath: exportDir.path) {
            try fileManager.createDirectory(at: exportDir, withIntermediateDirectories: true)
        }

        return exportDir
    }

    private func sanitizeFilename(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "\\/:*?\"<>|")
        var sanitized = name.components(separatedBy: invalidChars).joined(separator: "_")
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.isEmpty {
            sanitized = "export"
        }
        // Limit length to avoid filesystem issues
        if sanitized.count > 100 {
            sanitized = String(sanitized.prefix(100))
        }
        return sanitized
    }

    // MARK: - Cleanup

    /// Clean up old export files older than specified days
    /// - Parameter daysOld: Number of days after which files should be deleted
    func cleanupOldExports(daysOld: Int = 7) {
        guard let exportDir = try? getExportDirectory() else { return }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -daysOld, to: Date()) ?? Date()

        if let contents = try? fileManager.contentsOfDirectory(
            at: exportDir,
            includingPropertiesForKeys: [.creationDateKey]
        ) {
            for fileURL in contents {
                if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let creationDate = attributes[.creationDate] as? Date,
                   creationDate < cutoffDate {
                    try? fileManager.removeItem(at: fileURL)
                }
            }
        }
    }
}
