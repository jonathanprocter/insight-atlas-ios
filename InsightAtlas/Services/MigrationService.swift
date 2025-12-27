import Foundation
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.insightatlas", category: "Migration")

/// Service responsible for migrating data from UserDefaults to SwiftData
@MainActor
class MigrationService {
    
    private static let migrationCompletedKey = "insight_atlas_migration_completed_v1"
    private static let legacyLibraryKey = "insight_atlas_library"
    
    /// Check if migration has already been completed
    static var isMigrationCompleted: Bool {
        UserDefaults.standard.bool(forKey: migrationCompletedKey)
    }
    
    /// Perform migration from UserDefaults to SwiftData
    static func migrate(to modelContext: ModelContext) async throws {
        guard !isMigrationCompleted else {
            logger.info("Migration already completed, skipping")
            return
        }
        
        logger.info("Starting migration from UserDefaults to SwiftData")
        
        // Load legacy data from UserDefaults
        guard let data = UserDefaults.standard.data(forKey: legacyLibraryKey) else {
            logger.info("No legacy data found, marking migration as complete")
            markMigrationComplete()
            return
        }
        
        do {
            // Decode legacy items
            let legacyItems = try JSONDecoder().decode([LegacyLibraryItem].self, from: data)
            logger.info("Found \(legacyItems.count) items to migrate")
            
            // Convert and insert into SwiftData
            for legacyItem in legacyItems {
                let newItem = LibraryItem(
                    id: legacyItem.id,
                    title: legacyItem.title,
                    author: legacyItem.author,
                    summaryContent: legacyItem.summaryContent,
                    createdAt: legacyItem.createdAt,
                    updatedAt: legacyItem.updatedAt,
                    coverImagePath: legacyItem.coverImagePath,
                    audioFileURL: legacyItem.audioFileURL,
                    pageCount: legacyItem.pageCount,
                    fileType: legacyItem.fileType,
                    isFavorite: legacyItem.isFavorite ?? false,
                    mode: legacyItem.mode,
                    provider: legacyItem.provider,
                    tone: legacyItem.tone,
                    outputFormat: legacyItem.outputFormat,
                    summaryType: legacyItem.summaryType,
                    audioVoiceID: legacyItem.audioVoiceID,
                    audioDuration: legacyItem.audioDuration,
                    audioGenerationAttempted: legacyItem.audioGenerationAttempted ?? false,
                    governedWordCount: legacyItem.governedWordCount,
                    cutPolicyActivated: legacyItem.cutPolicyActivated ?? false,
                    cutEventCount: legacyItem.cutEventCount ?? 0
                )
                
                modelContext.insert(newItem)
            }
            
            // Save all items
            try modelContext.save()
            logger.info("Successfully migrated \(legacyItems.count) items")
            
            // Backup the old data before removing
            backupLegacyData(data)
            
            // Remove legacy data from UserDefaults
            UserDefaults.standard.removeObject(forKey: legacyLibraryKey)
            
            // Mark migration as complete
            markMigrationComplete()
            
            logger.info("Migration completed successfully")
            
        } catch {
            logger.error("Migration failed: \(error.localizedDescription)")
            throw MigrationError.migrationFailed(reason: error.localizedDescription)
        }
    }
    
    /// Backup legacy data before deletion
    private static func backupLegacyData(_ data: Data) {
        let backupKey = "\(legacyLibraryKey)_backup_\(Int(Date().timeIntervalSince1970))"
        UserDefaults.standard.set(data, forKey: backupKey)
        logger.info("Legacy data backed up to '\(backupKey)'")
    }
    
    /// Mark migration as complete
    private static func markMigrationComplete() {
        UserDefaults.standard.set(true, forKey: migrationCompletedKey)
    }
    
    /// Force re-migration (for testing purposes only)
    static func resetMigration() {
        UserDefaults.standard.removeObject(forKey: migrationCompletedKey)
        logger.warning("Migration status reset - migration will run again on next launch")
    }
}

// MARK: - Migration Errors

enum MigrationError: LocalizedError {
    case migrationFailed(reason: String)
    case dataCorrupted
    
    var errorDescription: String? {
        switch self {
        case .migrationFailed(let reason):
            return "Migration failed: \(reason)"
        case .dataCorrupted:
            return "Legacy data is corrupted and cannot be migrated"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .migrationFailed:
            return "Please contact support with the error details. Your data has been backed up."
        case .dataCorrupted:
            return "Your library data may be corrupted. A backup has been created."
        }
    }
}
