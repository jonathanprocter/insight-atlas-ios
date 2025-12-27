import Foundation
import SwiftData

@Model
final class LibraryItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var author: String
    var summaryContent: String?
    var createdAt: Date
    var updatedAt: Date
    
    // File paths
    var coverImagePath: String?
    var audioFileURL: String?
    
    // Metadata
    var pageCount: Int?
    var fileType: String // "pdf" or "epub"
    var isFavorite: Bool
    
    // Generation metadata
    var mode: String // GenerationMode raw value
    var provider: String // AIProvider raw value
    var tone: String // ToneMode raw value
    var outputFormat: String // OutputFormat raw value
    var summaryType: String? // SummaryType raw value
    
    // Audio metadata
    var audioVoiceID: String?
    var audioDuration: TimeInterval?
    var audioGenerationAttempted: Bool
    
    // Quality metrics
    var governedWordCount: Int?
    var cutPolicyActivated: Bool
    var cutEventCount: Int
    
    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        summaryContent: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        coverImagePath: String? = nil,
        audioFileURL: String? = nil,
        pageCount: Int? = nil,
        fileType: String = "pdf",
        isFavorite: Bool = false,
        mode: String = "standard",
        provider: String = "claude",
        tone: String = "accessible",
        outputFormat: String = "fullGuide",
        summaryType: String? = nil,
        audioVoiceID: String? = nil,
        audioDuration: TimeInterval? = nil,
        audioGenerationAttempted: Bool = false,
        governedWordCount: Int? = nil,
        cutPolicyActivated: Bool = false,
        cutEventCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.summaryContent = summaryContent
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.coverImagePath = coverImagePath
        self.audioFileURL = audioFileURL
        self.pageCount = pageCount
        self.fileType = fileType
        self.isFavorite = isFavorite
        self.mode = mode
        self.provider = provider
        self.tone = tone
        self.outputFormat = outputFormat
        self.summaryType = summaryType
        self.audioVoiceID = audioVoiceID
        self.audioDuration = audioDuration
        self.audioGenerationAttempted = audioGenerationAttempted
        self.governedWordCount = governedWordCount
        self.cutPolicyActivated = cutPolicyActivated
        self.cutEventCount = cutEventCount
    }
    
    // Computed properties for UI
    var readTime: String? {
        guard let wordCount = governedWordCount else { return nil }
        let minutes = wordCount / 200 // Average reading speed
        return "\(minutes) min read"
    }
    
    var formattedAudioDuration: String? {
        guard let duration = audioDuration else { return nil }
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // Helper to load cover image data
    func loadCoverImageData() -> Data? {
        guard let path = coverImagePath else { return nil }
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let fileURL = documentsDir.appendingPathComponent(path)
        return try? Data(contentsOf: fileURL)
    }
}

// MARK: - Legacy Support (for migration)

struct LegacyLibraryItem: Codable {
    let id: UUID
    let title: String
    let author: String
    let summaryContent: String?
    let createdAt: Date
    let updatedAt: Date
    let coverImagePath: String?
    let audioFileURL: String?
    let pageCount: Int?
    let fileType: String
    let isFavorite: Bool?
    let mode: String
    let provider: String
    let tone: String
    let outputFormat: String
    let summaryType: String?
    let audioVoiceID: String?
    let audioDuration: TimeInterval?
    let audioGenerationAttempted: Bool?
    let governedWordCount: Int?
    let cutPolicyActivated: Bool?
    let cutEventCount: Int?
}
