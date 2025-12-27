import Foundation
import SwiftUI
import SwiftData

/// Centralized service container for the application
/// Manages all major services and their dependencies
@MainActor
class AppEnvironment: ObservableObject {
    
    // MARK: - Services
    
    let modelContext: ModelContext
    let aiService: AIService
    let audioService: ElevenLabsAudioService
    let generationCoordinator: BackgroundGenerationCoordinator
    
    // MARK: - Published State
    
    @Published var userSettings: UserSettings
    @Published var isLoading: Bool = false
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.aiService = AIService()
        self.audioService = ElevenLabsAudioService()
        self.generationCoordinator = BackgroundGenerationCoordinator.shared
        
        // Load user settings
        self.userSettings = Self.loadSettings()
        
        // Migrate API keys from UserDefaults to Keychain (one-time)
        KeychainService.shared.migrateFromUserDefaults()
        
        // Configure services with dependencies
        setupServiceDependencies()
    }
    
    // MARK: - Service Configuration
    
    private func setupServiceDependencies() {
        // Configure generation coordinator with required services
        generationCoordinator.aiService = aiService
        generationCoordinator.audioService = audioService
    }
    
    // MARK: - Settings Management
    
    private static let settingsKey = "insight_atlas_settings"
    
    private static func loadSettings() -> UserSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey) else {
            return UserSettings()
        }
        
        do {
            return try JSONDecoder().decode(UserSettings.self, from: data)
        } catch {
            print("Failed to decode settings: \(error.localizedDescription)")
            return UserSettings()
        }
    }
    
    func saveSettings() {
        do {
            let data = try JSONEncoder().encode(userSettings)
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
        } catch {
            print("Failed to encode settings: \(error.localizedDescription)")
        }
    }
    
    func updateSettings(_ settings: UserSettings) {
        userSettings = settings
        saveSettings()
    }
    
    // MARK: - API Key Management
    
    func updateClaudeApiKey(_ key: String?) {
        KeychainService.shared.claudeApiKey = key
    }
    
    func updateOpenAIApiKey(_ key: String?) {
        KeychainService.shared.openaiApiKey = key
    }
    
    var hasValidApiKeys: Bool {
        switch userSettings.preferredProvider {
        case .claude:
            return KeychainService.shared.hasClaudeApiKey
        case .openai:
            return KeychainService.shared.hasOpenAIApiKey
        case .both:
            return KeychainService.shared.hasClaudeApiKey &&
                   KeychainService.shared.hasOpenAIApiKey
        }
    }
    
    // MARK: - Library Operations
    
    func addLibraryItem(_ item: LibraryItem) {
        modelContext.insert(item)
        try? modelContext.save()
    }
    
    func deleteLibraryItem(_ item: LibraryItem) {
        // Clean up associated files
        cleanupAudioFile(for: item)
        cleanupCoverImage(for: item)
        
        modelContext.delete(item)
        try? modelContext.save()
    }
    
    func updateLibraryItem(_ item: LibraryItem) {
        item.updatedAt = Date()
        try? modelContext.save()
    }
    
    // MARK: - File Management
    
    private let fileManager = FileManager.default
    
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
            print("Failed to store cover image: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func cleanupAudioFile(for item: LibraryItem) {
        guard let audioFileName = item.audioFileURL, !audioFileName.isEmpty else { return }
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let audioFileURL = documentsDir.appendingPathComponent(audioFileName)
        
        if fileManager.fileExists(atPath: audioFileURL.path) {
            try? fileManager.removeItem(at: audioFileURL)
        }
    }
    
    private func cleanupCoverImage(for item: LibraryItem) {
        guard let coverPath = item.coverImagePath, !coverPath.isEmpty else { return }
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let coverURL = documentsDir.appendingPathComponent(coverPath)
        
        if fileManager.fileExists(atPath: coverURL.path) {
            try? fileManager.removeItem(at: coverURL)
        }
    }
}

// MARK: - User Settings Model

struct UserSettings: Codable {
    var preferredProvider: AIProvider = .claude
    var defaultMode: GenerationMode = .standard
    var defaultTone: ToneMode = .accessible
    var defaultOutputFormat: OutputFormat = .fullGuide
    var defaultSummaryType: SummaryType = .accessible
    var autoGenerateAudio: Bool = false
    var selectedVoiceID: String?
}

// MARK: - Enums

enum AIProvider: String, Codable, CaseIterable {
    case claude = "Claude"
    case openai = "OpenAI"
    case both = "Both"
    
    var displayName: String { rawValue }
}

enum GenerationMode: String, Codable, CaseIterable {
    case standard = "Standard"
    case deepResearch = "Deep Research"
    
    var displayName: String { rawValue }
}

enum ToneMode: String, Codable, CaseIterable {
    case accessible = "Accessible"
    case academic = "Academic"
    case conversational = "Conversational"
    
    var displayName: String { rawValue }
}

enum OutputFormat: String, Codable, CaseIterable {
    case fullGuide = "Full Guide"
    case summary = "Summary"
    case keyPoints = "Key Points"
    
    var displayName: String { rawValue }
}

enum SummaryType: String, Codable, CaseIterable {
    case accessible = "Accessible"
    case comprehensive = "Comprehensive"
    case detailed = "Detailed"
    
    var displayName: String { rawValue }
}
