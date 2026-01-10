import Foundation

extension String {
    /// Returns the localized version of the string
    var localized: String {
        NSLocalizedString(self, comment: "")
    }

    /// Returns the localized version of the string with arguments
    func localized(with arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}

// MARK: - Localization Keys

/// Centralized localization keys for type-safe access
enum L10n {

    // MARK: - Common

    enum Common {
        static let cancel = "common.cancel".localized
        static let save = "common.save".localized
        static let delete = "common.delete".localized
        static let done = "common.done".localized
        static let edit = "common.edit".localized
        static let close = "common.close".localized
        static let ok = "common.ok".localized
        static let error = "common.error".localized
        static let success = "common.success".localized
        static let loading = "common.loading".localized
        static let retry = "common.retry".localized
        static let share = "common.share".localized
        static let export = "common.export".localized
    }

    // MARK: - Tabs

    enum Tabs {
        static let library = "tabs.library".localized
        static let settings = "tabs.settings".localized
    }

    // MARK: - Library

    enum Library {
        static let title = "library.title".localized
        static let searchPlaceholder = "library.searchPlaceholder".localized
        static let emptyTitle = "library.empty.title".localized
        static let emptyMessage = "library.empty.message".localized
        static let importButton = "library.import.button".localized
        static let deleteConfirmTitle = "library.delete.confirm.title".localized
        static let deleteConfirmMessage = "library.delete.confirm.message".localized

        static func pages(_ count: Int) -> String {
            "library.item.pages".localized(with: count)
        }

        static func updated(_ date: String) -> String {
            "library.item.updated".localized(with: date)
        }
    }

    // MARK: - Settings

    enum Settings {
        static let title = "settings.title".localized
        static let sectionGeneration = "settings.section.generation".localized
        static let sectionApiConfiguration = "settings.section.apiConfiguration".localized
        static let sectionAbout = "settings.section.about".localized

        static let aiProviderTitle = "settings.aiProvider.title".localized
        static let aiProviderSubtitle = "settings.aiProvider.subtitle".localized
        static let generationModeTitle = "settings.generationMode.title".localized
        static let generationModeSubtitle = "settings.generationMode.subtitle".localized
        static let outputToneTitle = "settings.outputTone.title".localized
        static let outputToneSubtitle = "settings.outputTone.subtitle".localized
        static let defaultFormatTitle = "settings.defaultFormat.title".localized
        static let defaultFormatSubtitle = "settings.defaultFormat.subtitle".localized
        static let manageApiKeysTitle = "settings.manageApiKeys.title".localized
        static let aboutTitle = "settings.about.title".localized

        static func version(_ version: String) -> String {
            "settings.about.version".localized(with: version)
        }
    }

    // MARK: - API Keys

    enum ApiKeys {
        static let title = "settings.apiKeys.title".localized
        static let bothConfigured = "settings.apiKeys.bothConfigured".localized
        static let claudeConfigured = "settings.apiKeys.claudeConfigured".localized
        static let openaiConfigured = "settings.apiKeys.openaiConfigured".localized
        static let addKeys = "settings.apiKeys.addKeys".localized
        static let securityNote = "settings.apiKeys.securityNote".localized
        static let claudeTitle = "settings.apiKeys.claude.title".localized
        static let claudePlaceholder = "settings.apiKeys.claude.placeholder".localized
        static let openaiTitle = "settings.apiKeys.openai.title".localized
        static let openaiPlaceholder = "settings.apiKeys.openai.placeholder".localized
    }

    // MARK: - Generation

    enum Generation {
        static let title = "generation.title".localized
        static let analyzing = "generation.analyzing".localized
        static let structuring = "generation.structuring".localized
        static let writing = "generation.writing".localized
        static let addingInsights = "generation.addingInsights".localized
        static let finalizing = "generation.finalizing".localized
        static let complete = "generation.complete".localized
        static let error = "generation.error".localized
        static let cancel = "generation.cancel".localized
        static let cancelConfirmTitle = "generation.cancel.confirm.title".localized
        static let cancelConfirmMessage = "generation.cancel.confirm.message".localized

        static func words(_ count: Int) -> String {
            "generation.words".localized(with: count)
        }

        static func progress(_ percent: Int) -> String {
            "generation.progress".localized(with: percent)
        }
    }

    // MARK: - Export

    enum Export {
        static let title = "export.title".localized
        static let markdown = "export.format.markdown".localized
        static let plainText = "export.format.plainText".localized
        static let html = "export.format.html".localized
        static let pdf = "export.format.pdf".localized
        static let docx = "export.format.docx".localized
        static let success = "export.success".localized
        static let error = "export.error".localized
    }

    // MARK: - Errors

    enum Errors {
        static let noContent = "error.noContent".localized
        static let networkError = "error.networkError".localized
        static let invalidResponse = "error.invalidResponse".localized
        static let processingFailed = "error.processingFailed".localized
        static let exportFailed = "error.exportFailed".localized

        static func apiKeyMissing(_ provider: String) -> String {
            "error.apiKeyMissing".localized(with: provider)
        }
    }

    // MARK: - Accessibility

    enum Accessibility {
        static func libraryItem(title: String, author: String, pages: Int) -> String {
            "accessibility.library.item".localized(with: title, author, pages)
        }

        static func deleteItem(_ title: String) -> String {
            "accessibility.library.delete".localized(with: title)
        }

        static func apiKeyToggle(_ provider: String) -> String {
            "accessibility.settings.apiKeyToggle".localized(with: provider)
        }

        static func generationProgress(_ percent: Int) -> String {
            "accessibility.generation.progress".localized(with: percent)
        }

        static func guideSection(number: Int, title: String) -> String {
            "accessibility.guide.section".localized(with: number, title)
        }
    }

    // MARK: - Analysis Components

    enum Analysis {
        static let quickGlanceTitle = "analysis.quickGlance.title".localized
        static let insightNoteTitle = "analysis.insightNote.title".localized
        static let actionBoxTitle = "analysis.actionBox.title".localized
        static let takeawaysTitle = "analysis.takeaways.title".localized
        static let quoteTitle = "analysis.quote.title".localized
        static let alternativePerspectiveTitle = "analysis.alternativePerspective.title".localized
        static let researchInsightTitle = "analysis.researchInsight.title".localized
        static let visualGuideTitle = "analysis.visualGuide.title".localized
        static let referenceTableTitle = "analysis.referenceTable.title".localized
        static let processTimelineTitle = "analysis.processTimeline.title".localized
        static let conceptMapTitle = "analysis.conceptMap.title".localized
        static let exerciseTitle = "analysis.exercise.title".localized
        static let foundationalNarrativeTitle = "analysis.foundationalNarrative.title".localized
        static let structureMapTitle = "analysis.structureMap.title".localized

        static func readTime(_ minutes: Int) -> String {
            "analysis.quickGlance.readTime".localized(with: minutes)
        }
    }

    // MARK: - Brand

    enum Brand {
        static let name = "brand.name".localized
        static let tagline = "brand.tagline".localized
        static let taglineShort = "brand.taglineShort".localized
    }
}
