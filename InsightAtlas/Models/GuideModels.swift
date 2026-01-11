import Foundation
import SwiftUI

// MARK: - Library Item Model

struct LibraryItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var author: String
    var fileType: FileType
    var summaryContent: String?
    var provider: AIProvider
    var mode: GenerationMode
    var pageCount: Int?
    var isbn: String?  // For fetching book covers
    var coverImagePath: String?
    var isFavorite: Bool?
    var createdAt: Date
    var updatedAt: Date

    // MARK: - Summary Type Governor Metadata (v1.0)

    /// The summary type used for generation
    var summaryType: SummaryType?

    /// Word count after governor enforcement
    var governedWordCount: Int?

    /// Whether cut policy was activated during generation
    var cutPolicyActivated: Bool?

    /// Number of cut events during generation
    var cutEventCount: Int?

    // MARK: - Audio Metadata

    /// URL to the generated audio file (relative to app documents)
    var audioFileURL: String?

    /// ElevenLabs voice ID used for generation
    var audioVoiceID: String?

    /// Audio duration in seconds
    var audioDuration: TimeInterval?

    /// Number of audio generation attempts (allows retry up to max attempts)
    var audioGenerationAttempts: Int?

    /// Maximum allowed audio generation attempts before disabling retry
    static let maxAudioGenerationAttempts = 3

    /// Whether audio generation can be retried
    var canRetryAudioGeneration: Bool {
        guard audioFileURL == nil else { return false }  // Already has audio
        return (audioGenerationAttempts ?? 0) < Self.maxAudioGenerationAttempts
    }

    /// Legacy compatibility - maps to attempts > 0
    var audioGenerationAttempted: Bool? {
        get { (audioGenerationAttempts ?? 0) > 0 }
        set { if newValue == true && audioGenerationAttempts == nil { audioGenerationAttempts = 1 } }
    }

    // MARK: - Bookmarks

    /// User-created bookmarks within the guide
    var bookmarks: [GuideBookmark]?

    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        fileType: FileType,
        summaryContent: String? = nil,
        provider: AIProvider = .claude,
        mode: GenerationMode = .standard,
        pageCount: Int? = nil,
        isbn: String? = nil,
        coverImagePath: String? = nil,
        isFavorite: Bool? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        summaryType: SummaryType? = nil,
        governedWordCount: Int? = nil,
        cutPolicyActivated: Bool? = nil,
        cutEventCount: Int? = nil,
        audioFileURL: String? = nil,
        audioVoiceID: String? = nil,
        audioDuration: TimeInterval? = nil,
        audioGenerationAttempts: Int? = nil,
        bookmarks: [GuideBookmark]? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.fileType = fileType
        self.summaryContent = summaryContent
        self.provider = provider
        self.mode = mode
        self.pageCount = pageCount
        self.isbn = isbn
        self.coverImagePath = coverImagePath
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.summaryType = summaryType
        self.governedWordCount = governedWordCount
        self.cutPolicyActivated = cutPolicyActivated
        self.cutEventCount = cutEventCount
        self.audioFileURL = audioFileURL
        self.audioVoiceID = audioVoiceID
        self.audioDuration = audioDuration
        self.audioGenerationAttempts = audioGenerationAttempts
        self.bookmarks = bookmarks
    }

    /// Returns true if this item has generated audio available
    var hasAudio: Bool {
        audioFileURL != nil && audioDuration != nil
    }

    /// Formatted audio duration string (e.g., "5:42")
    var formattedAudioDuration: String? {
        guard let duration = audioDuration else { return nil }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Codable (with backward compatibility)

    private enum CodingKeys: String, CodingKey {
        case id, title, author, fileType, summaryContent, provider, mode
        case pageCount, isbn, coverImagePath, isFavorite, createdAt, updatedAt
        case summaryType, governedWordCount, cutPolicyActivated, cutEventCount
        case audioFileURL, audioVoiceID, audioDuration
        case audioGenerationAttempts
        case audioGenerationAttempted  // Legacy key for backward compatibility
        case bookmarks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decode(String.self, forKey: .author)
        fileType = try container.decode(FileType.self, forKey: .fileType)
        summaryContent = try container.decodeIfPresent(String.self, forKey: .summaryContent)
        provider = try container.decode(AIProvider.self, forKey: .provider)
        mode = try container.decode(GenerationMode.self, forKey: .mode)
        pageCount = try container.decodeIfPresent(Int.self, forKey: .pageCount)
        isbn = try container.decodeIfPresent(String.self, forKey: .isbn)
        coverImagePath = try container.decodeIfPresent(String.self, forKey: .coverImagePath)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        summaryType = try container.decodeIfPresent(SummaryType.self, forKey: .summaryType)
        governedWordCount = try container.decodeIfPresent(Int.self, forKey: .governedWordCount)
        cutPolicyActivated = try container.decodeIfPresent(Bool.self, forKey: .cutPolicyActivated)
        cutEventCount = try container.decodeIfPresent(Int.self, forKey: .cutEventCount)
        audioFileURL = try container.decodeIfPresent(String.self, forKey: .audioFileURL)
        audioVoiceID = try container.decodeIfPresent(String.self, forKey: .audioVoiceID)
        audioDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .audioDuration)
        bookmarks = try container.decodeIfPresent([GuideBookmark].self, forKey: .bookmarks)

        // Handle backward compatibility: try new key first, fall back to legacy key
        if let attempts = try container.decodeIfPresent(Int.self, forKey: .audioGenerationAttempts) {
            audioGenerationAttempts = attempts
        } else if let attempted = try container.decodeIfPresent(Bool.self, forKey: .audioGenerationAttempted) {
            // Convert legacy Bool to Int: true -> 1, false/nil -> 0
            audioGenerationAttempts = attempted ? 1 : 0
        } else {
            audioGenerationAttempts = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(author, forKey: .author)
        try container.encode(fileType, forKey: .fileType)
        try container.encodeIfPresent(summaryContent, forKey: .summaryContent)
        try container.encode(provider, forKey: .provider)
        try container.encode(mode, forKey: .mode)
        try container.encodeIfPresent(pageCount, forKey: .pageCount)
        try container.encodeIfPresent(isbn, forKey: .isbn)
        try container.encodeIfPresent(coverImagePath, forKey: .coverImagePath)
        try container.encodeIfPresent(isFavorite, forKey: .isFavorite)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(summaryType, forKey: .summaryType)
        try container.encodeIfPresent(governedWordCount, forKey: .governedWordCount)
        try container.encodeIfPresent(cutPolicyActivated, forKey: .cutPolicyActivated)
        try container.encodeIfPresent(cutEventCount, forKey: .cutEventCount)
        try container.encodeIfPresent(audioFileURL, forKey: .audioFileURL)
        try container.encodeIfPresent(audioVoiceID, forKey: .audioVoiceID)
        try container.encodeIfPresent(audioDuration, forKey: .audioDuration)
        try container.encodeIfPresent(audioGenerationAttempts, forKey: .audioGenerationAttempts)
        try container.encodeIfPresent(bookmarks, forKey: .bookmarks)
        // Note: We intentionally don't encode audioGenerationAttempted (legacy key)
    }
}

enum FileType: String, Codable {
    case pdf = "pdf"
    case epub = "epub"
}

// MARK: - Guide Bookmark

/// A bookmark within an Insight Atlas guide
struct GuideBookmark: Identifiable, Codable, Equatable {
    let id: UUID
    var sectionId: String       // The ID of the section (e.g., "section-1")
    var sectionTitle: String    // Human-readable section name
    var note: String?           // Optional user note
    var createdAt: Date
    var highlightColor: BookmarkColor

    init(
        id: UUID = UUID(),
        sectionId: String,
        sectionTitle: String,
        note: String? = nil,
        createdAt: Date = Date(),
        highlightColor: BookmarkColor = .gold
    ) {
        self.id = id
        self.sectionId = sectionId
        self.sectionTitle = sectionTitle
        self.note = note
        self.createdAt = createdAt
        self.highlightColor = highlightColor
    }
}

enum BookmarkColor: String, Codable, CaseIterable {
    case gold = "gold"
    case coral = "coral"
    case teal = "teal"
    case green = "green"
    case purple = "purple"

    var color: Color {
        switch self {
        case .gold: return Color(red: 0.85, green: 0.65, blue: 0.13)
        case .coral: return Color(red: 0.92, green: 0.45, blue: 0.35)
        case .teal: return Color(red: 0.0, green: 0.59, blue: 0.65)
        case .green: return Color(red: 0.25, green: 0.65, blue: 0.45)
        case .purple: return Color(red: 0.55, green: 0.35, blue: 0.75)
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - AI Provider

enum AIProvider: String, Codable, CaseIterable {
    case claude = "claude"
    case openai = "openai"
    case both = "both"

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .openai: return "OpenAI"
        case .both: return "Both"
        }
    }
}

// MARK: - Parsed Guide Models

/// Represents a fully parsed Insight Atlas guide with all enhancement components
struct ParsedGuide: Identifiable {
    let id = UUID()
    var quickGlance: QuickGlanceSummary?
    var foundationalNarrative: FoundationalNarrative?
    var executiveSummary: String
    var takeaways: [Takeaway]
    var parts: [GuidePart]
    var quotes: [BookQuote]
    var structureMap: StructureMap?
    var appendices: GuideAppendices?
    var rawContent: String
}

// MARK: - Enhancement 1: Quick Glance Summary

struct QuickGlanceSummary: Identifiable {
    let id = UUID()
    var title: String
    var author: String
    var readTime: String
    var oneSentencePremise: String
    var coreFrameworkOverview: String
    var mainConcepts: [NumberedConcept]
    var bottomLine: String
    var whoShouldRead: String
}

struct NumberedConcept: Identifiable {
    let id = UUID()
    var number: Int
    var name: String
    var description: String
}

// MARK: - Enhancement 2: Foundational Narrative

struct FoundationalNarrative: Identifiable {
    let id = UUID()
    var originStory: String
    var culturalContext: String
    var authorBackground: String
    var framingContext: String
}

// MARK: - Enhancement 3: Practical Examples

struct PracticalExample: Identifiable {
    let id = UUID()
    var situation: String
    var problemPattern: String?
    var solutionApplied: String?
    var exampleType: ExampleType
}

enum ExampleType: String {
    case negative = "negative"
    case positive = "positive"
    case beforeAfter = "before_after"
}

// MARK: - Enhancement 5: Structure Map

struct StructureMap: Identifiable {
    let id = UUID()
    var mappings: [ChapterMapping]
}

struct ChapterMapping: Identifiable {
    let id = UUID()
    var originalChapter: String
    var insightAtlasSection: String
}

// MARK: - Enhancement 6: Visual Frameworks

protocol VisualFramework: Identifiable {
    var id: UUID { get }
    var title: String { get }
}

struct FlowChart: VisualFramework, Identifiable {
    let id = UUID()
    var title: String
    var steps: [FlowChartStep]
}

struct FlowChartStep: Identifiable {
    let id = UUID()
    var content: String
    var isOutcome: Bool
}

struct ComparisonTable: VisualFramework, Identifiable {
    let id = UUID()
    var title: String
    var leftColumnHeader: String
    var rightColumnHeader: String
    var rows: [ComparisonRow]
}

struct ComparisonRow: Identifiable {
    let id = UUID()
    var leftValue: String
    var rightValue: String
}

struct ConceptMap: VisualFramework, Identifiable {
    let id = UUID()
    var title: String
    var centralConcept: String
    var connections: [ConceptConnection]
}

struct ConceptConnection: Identifiable {
    let id = UUID()
    var concept: String
    var relationship: String
}

struct ProcessDiagram: VisualFramework, Identifiable {
    let id = UUID()
    var title: String
    var phases: [ProcessPhase]
}

struct ProcessPhase: Identifiable {
    let id = UUID()
    var name: String
    var steps: [String]
}

struct HierarchyDiagram: VisualFramework, Identifiable {
    let id = UUID()
    var title: String
    var root: HierarchyNode
}

struct HierarchyNode: Identifiable {
    let id = UUID()
    var name: String
    var children: [HierarchyNode]
}

// MARK: - Enhancement 7: Action Boxes

struct ActionBox: Identifiable {
    let id = UUID()
    var conceptName: String
    var actions: [ActionStep]
}

struct ActionStep: Identifiable {
    let id = UUID()
    var number: Int
    var instruction: String
    var timeframe: String?
}

// MARK: - Enhancement 8: Enhanced Exercises

protocol Exercise: Identifiable {
    var id: UUID { get }
    var title: String { get }
    var estimatedTime: String? { get }
}

struct ReflectionExercise: Exercise {
    let id = UUID()
    var title: String
    var prompt: String
    var estimatedTime: String?
}

struct SelfAssessmentExercise: Exercise {
    let id = UUID()
    var title: String
    var topic: String
    var dimensions: [AssessmentDimension]
    var scoringInterpretation: String
    var estimatedTime: String?
}

struct AssessmentDimension: Identifiable {
    let id = UUID()
    var name: String
    var maxScore: Int
}

struct ScenarioExercise: Exercise {
    let id = UUID()
    var title: String
    var scenario: String
    var question: String
    var considerations: [String]
    var estimatedTime: String?
}

struct TrackingExercise: Exercise {
    let id = UUID()
    var title: String
    var conceptName: String
    var columns: [String]
    var reflectionQuestions: [String]
    var estimatedTime: String?
}

struct DialogueExercise: Exercise {
    let id = UUID()
    var title: String
    var situation: String
    var dialoguePairs: [DialoguePair]
    var estimatedTime: String?
}

struct DialoguePair: Identifiable {
    let id = UUID()
    var insteadOf: String
    var tryThis: String
}

struct PatternInterruptExercise: Exercise {
    let id = UUID()
    var title: String
    var triggerSituation: String
    var physicalCue: String
    var verbalCue: String
    var mentalCue: String
    var estimatedTime: String?
}

// MARK: - Enhancement 9: Enhanced Insight Notes

struct InsightNote: Identifiable {
    let id = UUID()
    var coreConnection: String
    var keyDistinction: String
    var practicalImplication: String
    var goDeeper: GoDeeper
}

struct GoDeeper: Identifiable {
    let id = UUID()
    var bookTitle: String
    var author: String
    var whatYoullLearn: String
}

// MARK: - Standard Components

struct Takeaway: Identifiable {
    let id = UUID()
    var number: Int
    var title: String
    var explanation: String
}

struct BookQuote: Identifiable {
    let id = UUID()
    var quote: String
    var contextBefore: String?
    var contextAfter: String?
    var significance: String?
}

struct GuidePart: Identifiable {
    let id = UUID()
    var partNumber: Int
    var title: String
    var content: String
    var subSections: [GuideSubSection]
    var examples: [PracticalExample]
    var insightNotes: [InsightNote]
    var visuals: [any VisualFramework]
    var actionBox: ActionBox?
    var exercises: [any Exercise]
}

struct GuideSubSection: Identifiable {
    let id = UUID()
    var title: String
    var content: String
}

struct GuideAppendices: Identifiable {
    let id = UUID()
    var structureMap: StructureMap?
    var exerciseWorkbook: [any Exercise]
    var visualSummary: [any VisualFramework]
    var recommendedReading: [RecommendedBook]
}

struct RecommendedBook: Identifiable {
    let id = UUID()
    var title: String
    var author: String
    var description: String
    var category: String
}

// MARK: - User Settings

/// User preferences stored in UserDefaults (non-sensitive data only)
/// API keys are stored securely in Keychain via KeychainService
struct UserSettings: Codable {
    var preferredProvider: AIProvider
    var preferredMode: GenerationMode
    var preferredTone: ToneMode
    var preferredFormat: OutputFormat
    var preferredSummaryType: SummaryType
    var preferredReaderProfile: ReaderProfile
    var autoGenerateAudio: Bool
    var selectedVoiceID: String?
    var playbackSpeed: PlaybackSpeed

    // MARK: - Computed Properties for API Keys (Keychain-backed)

    /// Claude API key - stored securely in Keychain (not Codable)
    var claudeApiKey: String? {
        get { KeychainService.shared.claudeApiKey }
        set { KeychainService.shared.claudeApiKey = newValue }
    }

    /// OpenAI API key - stored securely in Keychain (not Codable)
    var openaiApiKey: String? {
        get { KeychainService.shared.openaiApiKey }
        set { KeychainService.shared.openaiApiKey = newValue }
    }

    init(
        preferredProvider: AIProvider = .both,
        preferredMode: GenerationMode = .deepResearch,
        preferredTone: ToneMode = .professional,
        preferredFormat: OutputFormat = .fullGuide,
        preferredSummaryType: SummaryType = .deepResearch,
        preferredReaderProfile: ReaderProfile = .practitioner,
        autoGenerateAudio: Bool = true,
        selectedVoiceID: String? = nil,
        playbackSpeed: PlaybackSpeed = .normal
    ) {
        self.preferredProvider = preferredProvider
        self.preferredMode = preferredMode
        self.preferredTone = preferredTone
        self.preferredFormat = preferredFormat
        self.preferredSummaryType = preferredSummaryType
        self.preferredReaderProfile = preferredReaderProfile
        self.autoGenerateAudio = autoGenerateAudio
        self.selectedVoiceID = selectedVoiceID
        self.playbackSpeed = playbackSpeed
    }

    // MARK: - Codable (excludes API keys)

    private enum CodingKeys: String, CodingKey {
        case preferredProvider
        case preferredMode
        case preferredTone
        case preferredFormat
        case preferredSummaryType
        case preferredReaderProfile
        case autoGenerateAudio
        case selectedVoiceID
        case playbackSpeed
    }

    // Custom decoder to handle missing playbackSpeed in older settings
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preferredProvider = try container.decode(AIProvider.self, forKey: .preferredProvider)
        preferredMode = try container.decode(GenerationMode.self, forKey: .preferredMode)
        preferredTone = try container.decode(ToneMode.self, forKey: .preferredTone)
        preferredFormat = try container.decode(OutputFormat.self, forKey: .preferredFormat)
        preferredSummaryType = try container.decode(SummaryType.self, forKey: .preferredSummaryType)
        preferredReaderProfile = try container.decode(ReaderProfile.self, forKey: .preferredReaderProfile)
        autoGenerateAudio = try container.decode(Bool.self, forKey: .autoGenerateAudio)
        selectedVoiceID = try container.decodeIfPresent(String.self, forKey: .selectedVoiceID)
        playbackSpeed = try container.decodeIfPresent(PlaybackSpeed.self, forKey: .playbackSpeed) ?? .normal
    }
}

// MARK: - Playback Speed

/// Audio playback speed options
enum PlaybackSpeed: String, Codable, CaseIterable {
    case slow = "0.75x"
    case normal = "1.0x"
    case faster = "1.25x"
    case fast = "1.5x"
    case veryFast = "2.0x"

    var rate: Float {
        switch self {
        case .slow: return 0.75
        case .normal: return 1.0
        case .faster: return 1.25
        case .fast: return 1.5
        case .veryFast: return 2.0
        }
    }

    var displayName: String { rawValue }
}

// MARK: - Generation Status

enum GenerationPhase: String {
    case analyzing = "Analyzing content"
    case structuring = "Analyzing structure"
    case writing = "Writing summary"
    case addingInsights = "Adding insights"
    case finalizing = "Finalizing content"
    case complete = "Complete"
    case error = "Error"
}

struct GenerationStatus {
    var phase: GenerationPhase
    var progress: Double
    var wordCount: Int
    var model: String
    var error: String?
}

// MARK: - API Response Models

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

struct ClaudeRequest: Codable {
    let model: String
    let max_tokens: Int
    let stream: Bool
    let system: String
    let messages: [ClaudeMessage]
}

struct ClaudeStreamEvent: Codable {
    let type: String
    let delta: ClaudeDelta?
}

struct ClaudeDelta: Codable {
    let text: String?
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIRequest: Codable {
    let model: String
    let max_tokens: Int
    let stream: Bool
    let messages: [OpenAIMessage]
}
