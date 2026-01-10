import Foundation
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.insightatlas", category: "AppEnvironment")

/// Centralized service container for the application
/// Manages all major services and their dependencies
@MainActor
class AppEnvironment: ObservableObject {

    // MARK: - Shared Instance
    
    static let shared = AppEnvironment()

    // MARK: - Services

    let aiService: AIService
    let audioService: ElevenLabsAudioService
    let generationCoordinator: BackgroundGenerationCoordinator
    let dataManager: DataManager

    // MARK: - Published State

    @Published var userSettings: UserSettings
    @Published var isLoading: Bool = false

    // MARK: - Initialization

    init() {
        self.aiService = AIService()
        self.audioService = ElevenLabsAudioService()
        self.generationCoordinator = BackgroundGenerationCoordinator.shared
        self.dataManager = DataManager.shared

        // Load user settings
        self.userSettings = Self.loadSettings()

        // Migrate API keys from UserDefaults to Keychain (one-time)
        KeychainService.shared.migrateFromUserDefaults()

        // Configure services with dependencies
        setupServiceDependencies()
    }

    // MARK: - Service Configuration

    private func setupServiceDependencies() {
        // Services are configured internally in their respective classes
        // BackgroundGenerationCoordinator uses its own AIService instance
    }

    // MARK: - Settings Management

    private static let settingsKey = "insight_atlas_settings"

    private static func loadSettings() -> UserSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey) else {
            logger.info("No saved settings found, using defaults")
            return UserSettings()
        }

        do {
            return try JSONDecoder().decode(UserSettings.self, from: data)
        } catch {
            logger.error("Failed to decode settings: \(error.localizedDescription). Using defaults.")
            return UserSettings()
        }
    }

    func saveSettings() {
        do {
            let data = try JSONEncoder().encode(userSettings)
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
            logger.debug("Settings saved successfully")
        } catch {
            logger.error("Failed to encode settings: \(error.localizedDescription)")
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
            return KeychainService.shared.hasClaudeApiKey ||
                   KeychainService.shared.hasOpenAIApiKey
        }
    }

    // MARK: - Library Operations

    func addLibraryItem(_ item: LibraryItem) {
        // For now, persist using DataManager since we're keeping the existing Codable LibraryItem
        DataManager.shared.saveLibraryItem(item)
    }

    func deleteLibraryItem(_ item: LibraryItem) {
        // Clean up associated files
        cleanupAudioFile(for: item)
        cleanupCoverImage(for: item)

        DataManager.shared.deleteLibraryItem(item)
    }

    func updateLibraryItem(_ item: LibraryItem) {
        var mutableItem = item
        mutableItem.updatedAt = Date()
        DataManager.shared.saveLibraryItem(mutableItem)
    }

    // MARK: - File Management

    private let fileManager = FileManager.default

    func storeCoverImageData(_ data: Data, for itemID: UUID) -> String? {
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logger.error("Unable to access documents directory for cover storage")
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
            logger.debug("Cover image stored: \(filename)")
            return "covers/\(filename)"
        } catch {
            logger.error("Failed to store cover image: \(error.localizedDescription)")
            return nil
        }
    }

    private func cleanupAudioFile(for item: LibraryItem) {
        guard let audioFileName = item.audioFileURL, !audioFileName.isEmpty else { return }
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logger.warning("Unable to access documents directory for audio cleanup")
            return
        }
        let audioFileURL = documentsDir.appendingPathComponent(audioFileName)

        if fileManager.fileExists(atPath: audioFileURL.path) {
            do {
                try fileManager.removeItem(at: audioFileURL)
                logger.debug("Cleaned up audio file: \(audioFileName)")
            } catch {
                logger.warning("Failed to cleanup audio file \(audioFileName): \(error.localizedDescription)")
            }
        }
    }

    private func cleanupCoverImage(for item: LibraryItem) {
        guard let coverPath = item.coverImagePath, !coverPath.isEmpty else { return }
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logger.warning("Unable to access documents directory for cover cleanup")
            return
        }
        let coverURL = documentsDir.appendingPathComponent(coverPath)

        if fileManager.fileExists(atPath: coverURL.path) {
            do {
                try fileManager.removeItem(at: coverURL)
                logger.debug("Cleaned up cover image: \(coverPath)")
            } catch {
                logger.warning("Failed to cleanup cover image \(coverPath): \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Library Filter (for Library UI filtering)

enum LibraryFilter: String, CaseIterable {
    case all = "All"
    case favorites = "Favorites"
    case recent = "Recent"
    case completed = "Completed"
    case inProgress = "In Progress"

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .favorites: return "heart.fill"
        case .recent: return "clock.fill"
        case .completed: return "checkmark.circle.fill"
        case .inProgress: return "circle.dotted"
        }
    }

    var displayName: String { rawValue }
}

// MARK: - Book Status (for Library item status badges)

enum BookStatus: String, CaseIterable {
    case completed = "Completed"
    case inProgress = "In Progress"
    case notStarted = "Not Started"
    case draft = "Draft"

    var icon: String {
        switch self {
        case .completed: return "checkmark.circle.fill"
        case .inProgress: return "circle.dotted"
        case .notStarted: return "circle"
        case .draft: return "doc.text"
        }
    }

    var displayText: String { rawValue }

    var color: Color {
        switch self {
        case .completed: return .green
        case .inProgress: return .orange
        case .notStarted: return .gray
        case .draft: return .blue
        }
    }
}
