import Foundation
import SwiftUI

public enum LLMActionResult: Equatable {
    case success(String)
    case failure(String)
}

/// Lightweight router that maps control identifiers to concrete actions across screens.
@MainActor
public enum LLMActionRouter {

    /// Perform an action for a given identifier. Some actions require `value`.
    /// - Parameters:
    ///   - identifier: The accessibility identifier of the control or pattern id.
    ///   - value: Optional value (e.g., provider name, model slug).
    ///   - environment: AppEnvironment for stateful updates.
    /// - Returns: Result with human-readable message.
    static func perform(identifier: String, value: String? = nil, environment: AppEnvironment) -> LLMActionResult {
        // SETTINGS
        if let result = handleSettings(identifier: identifier, value: value, environment: environment) { return result }

        // LIBRARY
        if let result = handleLibrary(identifier: identifier, value: value, environment: environment) { return result }

        // GENERATION
        if let result = handleGeneration(identifier: identifier, value: value, environment: environment) { return result }

        // GUIDE
        if let result = handleGuide(identifier: identifier, value: value, environment: environment) { return result }

        return .failure("Unknown identifier: \(identifier)")
    }

    // MARK: - Settings

    private static func handleSettings(identifier: String, value: String?, environment: AppEnvironment) -> LLMActionResult? {
        // Pattern-based
        if identifier.hasPrefix("theme_option_") {
            let name = identifier.replacingOccurrences(of: "theme_option_", with: "").replacingOccurrences(of: "_", with: " ")
            UserDefaults.standard.set(name.capitalized, forKey: PremiumUI.themeStorageKey)
            UISelectionFeedbackGenerator().selectionChanged()
            return .success("Theme set to \(name)")
        }
        if identifier.hasPrefix("accent_option_") {
            let name = identifier.replacingOccurrences(of: "accent_option_", with: "").replacingOccurrences(of: "_", with: " ")
            UserDefaults.standard.set(name.capitalized, forKey: PremiumUI.accentStorageKey)
            UISelectionFeedbackGenerator().selectionChanged()
            return .success("Accent set to \(name)")
        }
        if identifier.hasPrefix("voice_row_") || identifier.hasPrefix("voice_preview_") {
            return .failure("Narration voice is fixed (Liam); voice selection is unavailable.")
        }
        if identifier.hasPrefix("securefield_toggle_visibility_") {
            return .failure("Visibility toggle is UI-only and requires a tap.")
        }

        // Direct matches
        switch identifier {
        case "reset_all_settings_button":
            resetAllSettings(environment: environment)
            return .success("All settings reset.")

        case "toggle_auto_generate_audio":
            environment.userSettings.autoGenerateAudio.toggle()
            environment.saveSettings()
            return .success("Auto-generate Audio set to \(environment.userSettings.autoGenerateAudio)")

        case "togglerow_increase_contrast":
            let key = "insight_atlas_high_contrast"
            let newValue = !(UserDefaults.standard.bool(forKey: key))
            UserDefaults.standard.set(newValue, forKey: key)
            UISelectionFeedbackGenerator().selectionChanged()
            return .success("Increase Contrast set to \(newValue)")

        case "togglerow_sepia_reading_mode":
            let key = "insight_atlas_sepia_mode"
            let newValue = !(UserDefaults.standard.bool(forKey: key))
            UserDefaults.standard.set(newValue, forKey: key)
            UISelectionFeedbackGenerator().selectionChanged()
            return .success("Sepia Reading Mode set to \(newValue)")

        case "voice_provider_picker":
            return .failure("Narration voice is fixed (Liam); the voice provider is not configurable.")

        case "playback_speed_picker":
            guard let v = value, let speed = parsePlaybackSpeed(v) else {
                return .failure("Provide a playback speed value (e.g., Normal, Fast).")
            }
            environment.userSettings.playbackSpeed = speed
            environment.saveSettings()
            return .success("Playback Speed set to \(speed.displayName)")

        case "openrouter_model_field":
            if let v = value, !v.isEmpty {
                UserDefaults.standard.set(v, forKey: OpenRouterConfig.modelStorageKey)
                UISelectionFeedbackGenerator().selectionChanged()
                return .success("OpenRouter model set to \(v)")
            } else {
                return .failure("Provide a model slug for OpenRouter.")
            }

        case "contact_support_button":
            if let url = URL(string: "mailto:support@example.com") {
                UIApplication.shared.open(url)
                return .success("Opened mail composer")
            }
            return .failure("Unable to open mail composer")

        case "rate_app_button":
            if let url = URL(string: "itms-apps://itunes.apple.com/app/id000000000?action=write-review") {
                UIApplication.shared.open(url)
                return .success("Opened App Store review page")
            }
            return .failure("Unable to open App Store")

        case "securefield_claude":
            guard let v = value else { return .failure("Provide an API key value.") }
            environment.updateClaudeApiKey(v.isEmpty ? nil : v)
            return .success("Updated Claude key")

        case "securefield_openrouter":
            guard let v = value else { return .failure("Provide an API key value.") }
            KeychainService.shared.openRouterApiKey = v.isEmpty ? nil : v
            return .success("Updated OpenRouter key")

        default:
            // Navigation rows require UI interaction in this architecture.
            if identifier.hasPrefix("navrow_") {
                return .success("Navigation row tapped: \(identifier)")
            }
            return nil
        }
    }

    // MARK: - Library

    private static func handleLibrary(identifier: String, value: String?, environment: AppEnvironment) -> LLMActionResult? {
        switch identifier {
        case "library_filter_all":
            // Would set filter in LibraryView scope; not globally available here.
            return .failure("Library filter requires UI context.")
        case "library_create_button":
            return .failure("Presenting GenerationView requires UI context.")
        default:
            if identifier.hasPrefix("library_item_") {
                return .failure("Navigating to a library item requires UI context.")
            }
            return nil
        }
    }

    // MARK: - Generation

    private static func handleGeneration(identifier: String, value: String?, environment: AppEnvironment) -> LLMActionResult? {
        switch identifier {
        case "generation_provider_picker":
            guard let v = value, let provider = AIProvider(rawValue: v) ?? AIProvider.allCases.first(where: { $0.displayName.lowercased() == v.lowercased() }) else {
                return .failure("Provide a valid AI provider.")
            }
            environment.userSettings.preferredProvider = provider
            environment.saveSettings()
            return .success("Preferred provider set to \(provider.displayName)")
        case "generation_mode_picker":
            guard let v = value, let m = GenerationMode(rawValue: v) ?? GenerationMode.allCases.first(where: { $0.displayName.lowercased() == v.lowercased() }) else {
                return .failure("Provide a valid generation mode.")
            }
            environment.userSettings.preferredMode = m
            environment.saveSettings()
            return .success("Generation mode set to \(m.displayName)")
        case "generation_tone_picker":
            guard let v = value, let t = ToneMode(rawValue: v) ?? ToneMode.allCases.first(where: { $0.displayName.lowercased() == v.lowercased() }) else {
                return .failure("Provide a valid tone.")
            }
            environment.userSettings.preferredTone = t
            environment.saveSettings()
            return .success("Tone set to \(t.displayName)")
        case "generation_format_picker":
            guard let v = value, let f = OutputFormat(rawValue: v) ?? OutputFormat.allCases.first(where: { $0.displayName.lowercased() == v.lowercased() }) else {
                return .failure("Provide a valid format.")
            }
            environment.userSettings.preferredFormat = f
            environment.saveSettings()
            return .success("Format set to \(f.displayName)")
        case "generation_summary_type_picker":
            guard let v = value, let s = SummaryType(rawValue: v) ?? SummaryType.allCases.first(where: { $0.displayName.lowercased() == v.lowercased() }) else {
                return .failure("Provide a valid summary type.")
            }
            environment.userSettings.preferredSummaryType = s
            environment.saveSettings()
            return .success("Summary type set to \(s.displayName)")
        case "generation_voice_provider_picker":
            return .failure("Narration voice is fixed (Liam); the voice provider is not configurable.")
        case "generation_audio_speed_slider":
            return .failure("Slider changes require UI context.")
        case "generation_choose_file_button", "generation_generate_button":
            return .failure("File selection and generation start require UI context.")
        default:
            return nil
        }
    }

    // MARK: - Guide

    private static func handleGuide(identifier: String, value: String?, environment: AppEnvironment) -> LLMActionResult? {
        switch identifier {
        case "guide_export_pdf_button":
            UIDriver.post(.exportGuide, payload: ["format": UIDriverExporterFormat.pdfOnly.rawValue])
            return .success("Requested export as PDF")
        case "guide_export_audio_button":
            UIDriver.post(.exportGuide, payload: ["format": UIDriverExporterFormat.audioOnly.rawValue])
            return .success("Requested export of audio only")
        case "guide_export_bundle_button":
            UIDriver.post(.exportGuide, payload: ["format": UIDriverExporterFormat.bundled.rawValue])
            return .success("Requested export of PDF + Audio bundle")
        case "audio_play_pause_button":
            UIDriver.post(.toggleGuideAudio)
            return .success("Toggled audio playback")
        case "audio_generate_button":
            UIDriver.post(.generateGuideAudio)
            return .success("Requested narration generation")
        case "guide_regenerate_content_button":
            UIDriver.post(.showRegenerateOptions)
            return .success("Requested regenerate options")
        default:
            if identifier.hasPrefix("guide_toc_") {
                let sectionId = String(identifier.dropFirst("guide_toc_".count))
                UIDriver.post(.navigateToLibraryItem, payload: ["sectionId": sectionId])
                return .success("Requested navigation to section \(sectionId)")
            }
            return nil
        }
    }

    // MARK: - Helpers

    private static func parsePlaybackSpeed(_ str: String) -> PlaybackSpeed? {
        let lower = str.lowercased()
        return PlaybackSpeed.allCases.first {
            String(describing: $0).lowercased() == lower || $0.displayName.lowercased() == lower
        }
    }

    private static func resetAllSettings(environment: AppEnvironment) {
        // Appearance
        UserDefaults.standard.set(PremiumTheme.system.rawValue, forKey: PremiumUI.themeStorageKey)
        UserDefaults.standard.set(PremiumAccent.gold.rawValue, forKey: PremiumUI.accentStorageKey)
        UserDefaults.standard.set(false, forKey: "insight_atlas_high_contrast")
        UserDefaults.standard.set(false, forKey: "insight_atlas_sepia_mode")

        // Generation defaults
        if let provider = AIProvider.allCases.first { environment.userSettings.preferredProvider = provider }
        if let mode = GenerationMode.allCases.first { environment.userSettings.preferredMode = mode }
        if let tone = ToneMode.allCases.first { environment.userSettings.preferredTone = tone }
        if let format = OutputFormat.allCases.first { environment.userSettings.preferredFormat = format }
        if let summary = SummaryType.allCases.first { environment.userSettings.preferredSummaryType = summary }

        // Audio defaults — narration order is fixed; only playback speed and the
        // auto-generate toggle are configurable.
        if let speed = PlaybackSpeed.allCases.first { environment.userSettings.playbackSpeed = speed }
        environment.userSettings.autoGenerateAudio = false

        environment.saveSettings()
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
