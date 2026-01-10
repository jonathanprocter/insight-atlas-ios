import SwiftUI

// MARK: - View Accessibility Extensions

extension View {
    /// Add accessibility label with hint
    func accessibilityLabeled(_ label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }

    /// Mark view as button with label
    func accessibilityButton(_ label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }

    /// Mark view as header
    func accessibilityHeader(_ label: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isHeader)
    }

    /// Mark view as image with description
    func accessibilityImage(_ description: String) -> some View {
        self
            .accessibilityLabel(description)
            .accessibilityAddTraits(.isImage)
    }

    /// Mark view as static text (not interactive)
    func accessibilityStaticText(_ label: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isStaticText)
    }

    /// Mark view for updates that should be announced
    func accessibilityAnnounces(_ value: String) -> some View {
        self
            .accessibilityValue(value)
            .accessibilityAddTraits(.updatesFrequently)
    }

    /// Hide decorative elements from accessibility
    func accessibilityDecorative() -> some View {
        self.accessibilityHidden(true)
    }

    /// Combine multiple elements into one accessibility element
    func accessibilityCombined(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }

    /// Add accessibility identifier for UI testing
    func accessibilityID(_ identifier: String) -> some View {
        self.accessibilityIdentifier(identifier)
    }
}

// MARK: - Accessibility Identifiers

/// Centralized accessibility identifiers for UI testing
enum AccessibilityID {

    // MARK: - Library

    enum Library {
        static let searchField = "library.search.field"
        static let importButton = "library.import.button"
        static let itemList = "library.item.list"
        static func item(_ id: UUID) -> String { "library.item.\(id.uuidString)" }
        static func deleteButton(_ id: UUID) -> String { "library.item.delete.\(id.uuidString)" }
    }

    // MARK: - Settings

    enum Settings {
        static let root = "settings.root"
        static let aiProviderRow = "settings.row.aiProvider"
        static let generationModeRow = "settings.row.generationMode"
        static let outputToneRow = "settings.row.outputTone"
        static let defaultFormatRow = "settings.row.defaultFormat"
        static let apiKeysRow = "settings.row.apiKeys"
        static let aboutRow = "settings.row.about"
    }

    // MARK: - API Keys

    enum ApiKeys {
        static let claudeField = "apikeys.claude.field"
        static let claudeToggle = "apikeys.claude.toggle"
        static let openaiField = "apikeys.openai.field"
        static let openaiToggle = "apikeys.openai.toggle"
        static let saveButton = "apikeys.save.button"
        static let cancelButton = "apikeys.cancel.button"
    }

    // MARK: - Generation

    enum Generation {
        static let progressView = "generation.progress"
        static let statusLabel = "generation.status"
        static let wordCount = "generation.wordCount"
        static let cancelButton = "generation.cancel.button"
    }

    // MARK: - Guide

    enum Guide {
        static let scrollView = "guide.scrollView"
        static let exportButton = "guide.export.button"
        static let shareButton = "guide.share.button"
        static let regenerateButton = "guide.regenerate.button"
        static func section(_ index: Int) -> String { "guide.section.\(index)" }
    }

    // MARK: - Export

    enum Export {
        static let formatPicker = "export.format.picker"
        static let exportButton = "export.action.button"
        static func formatOption(_ format: String) -> String { "export.format.\(format)" }
    }
}
