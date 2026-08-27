import Foundation
import SwiftUI

public struct LLMControl: Identifiable, Codable, Hashable {
    public let id: String
    public let title: String
    public let kind: String // e.g., button, toggle, picker, navigation, field, menu, card

    public init(id: String, title: String, kind: String) {
        self.id = id
        self.title = title
        self.kind = kind
    }
}

/// Registry of UI controls that an LLM or automation can reference by identifier.
public enum LLMUIRegistry {
    // MARK: - Aggregated

    public static func allControls() -> [LLMControl] {
        var controls: [LLMControl] = []
        controls += settingsControls()
        controls += libraryControls()
        controls += generationControls()
        controls += guideControls()
        controls += dynamicPatternControls()
        return controls
    }

    // MARK: - Per-screen registries

    public static func settingsControls() -> [LLMControl] {
        [
            LLMControl(id: "settings_search_field", title: "Search settings", kind: "search"),
            LLMControl(id: "settings_more_menu", title: "More options", kind: "menu"),
            LLMControl(id: "reset_all_settings_button", title: "Reset All Settings", kind: "button"),

            // Cards
            LLMControl(id: "settings_card_generation", title: "Generation", kind: "card"),
            LLMControl(id: "settings_card_api_configuration", title: "API Configuration", kind: "card"),
            LLMControl(id: "settings_card_audio_&_narration", title: "Audio & Narration", kind: "card"),
            LLMControl(id: "settings_card_appearance", title: "Appearance", kind: "card"),
            LLMControl(id: "settings_card_about_&_support", title: "About & Support", kind: "card"),

            // Generation
            LLMControl(id: "navrow_ai_provider", title: "AI Provider", kind: "navigation"),
            LLMControl(id: "navrow_generation_mode", title: "Generation Mode", kind: "navigation"),
            LLMControl(id: "navrow_output_tone", title: "Output Tone", kind: "navigation"),
            LLMControl(id: "navrow_default_format", title: "Default Format", kind: "navigation"),

            // API
            LLMControl(id: "navrow_manage_api_keys", title: "Manage API Keys", kind: "navigation"),
            LLMControl(id: "securefield_claude", title: "Claude API Key", kind: "field"),
            LLMControl(id: "securefield_openrouter", title: "OpenRouter API Key", kind: "field"),
            LLMControl(id: "openrouter_model_field", title: "OpenRouter model slug", kind: "field"),
            LLMControl(id: "openrouter_model_menu", title: "OpenRouter model suggestions", kind: "menu"),

            // Audio (on-device Kokoro voice and playback settings)
            LLMControl(id: "navrow_audio_settings", title: "Audio Settings", kind: "navigation"),
            LLMControl(id: "playback_speed_picker", title: "Playback Speed", kind: "picker"),
            LLMControl(id: "toggle_auto_generate_audio", title: "Auto-generate Audio", kind: "toggle"),

            // Appearance
            LLMControl(id: "navrow_theme", title: "Theme", kind: "navigation"),
            LLMControl(id: "navrow_accent_color", title: "Accent Color", kind: "navigation"),
            LLMControl(id: "togglerow_increase_contrast", title: "Increase Contrast", kind: "toggle"),
            LLMControl(id: "togglerow_sepia_reading_mode", title: "Sepia Reading Mode", kind: "toggle"),

            // About & Support
            LLMControl(id: "navrow_help_&_tutorials", title: "Help & Tutorials", kind: "navigation"),
            LLMControl(id: "navrow_privacy_policy", title: "Privacy Policy", kind: "navigation"),
            LLMControl(id: "navrow_system_info", title: "System Info", kind: "navigation"),
            LLMControl(id: "contact_support_button", title: "Contact Support", kind: "button"),
            LLMControl(id: "rate_app_button", title: "Rate on the App Store", kind: "button")
        ]
    }

    public static func libraryControls() -> [LLMControl] {
        [
            LLMControl(id: "library_search_field", title: "Search your library", kind: "search"),
            LLMControl(id: "library_options_button", title: "Library filters and sorting", kind: "button"),
            LLMControl(id: "library_create_button", title: "Create a new guide", kind: "button"),
            LLMControl(id: "library_layout_picker", title: "Library Layout", kind: "picker"),
            LLMControl(id: "library_options_done_button", title: "Library Options Done", kind: "button"),
            LLMControl(id: "library_filter_all", title: "Filter: All", kind: "button"),
            LLMControl(id: "library_filter_favorites", title: "Filter: Favorites", kind: "button"),
            LLMControl(id: "library_filter_recent", title: "Filter: Recent", kind: "button"),
            LLMControl(id: "library_filter_drafts", title: "Filter: Drafts", kind: "button"),
            LLMControl(id: "library_sort_recently_updated", title: "Sort: Recently Updated", kind: "button"),
            LLMControl(id: "library_sort_recently_created", title: "Sort: Recently Created", kind: "button"),
            LLMControl(id: "library_sort_title", title: "Sort: Title", kind: "button"),
            LLMControl(id: "library_sort_author", title: "Sort: Author", kind: "button"),
            LLMControl(id: "library_empty_primary_button", title: "Create Guide or Clear Search", kind: "button"),
            // Dynamic pattern for items
            LLMControl(id: "library_item_*", title: "Library item (by UUID)", kind: "navigation")
        ]
    }

    public static func generationControls() -> [LLMControl] {
        [
            LLMControl(id: "generation_cancel_button", title: "Cancel generation", kind: "button"),
            LLMControl(id: "generation_choose_file_button", title: "Choose file", kind: "button"),
            LLMControl(id: "generation_generate_button", title: "Generate Guide", kind: "button"),
            LLMControl(id: "generation_provider_picker", title: "AI Provider", kind: "picker"),
            LLMControl(id: "generation_mode_picker", title: "Analysis Depth", kind: "picker"),
            LLMControl(id: "generation_tone_picker", title: "Writing Style", kind: "picker"),
            LLMControl(id: "generation_format_picker", title: "Output Format", kind: "picker"),
            LLMControl(id: "generation_summary_type_picker", title: "Summary Length", kind: "picker"),
            LLMControl(id: "generation_audio_speed_slider", title: "Playback Speed", kind: "slider"),
            LLMControl(id: "generation_progress_ring", title: "Generation Progress", kind: "progress"),
            LLMControl(id: "generation_view_guide_button", title: "View Guide", kind: "navigation"),
            LLMControl(id: "generation_save_to_library_button", title: "Save to Library", kind: "button"),
            LLMControl(id: "generation_try_again_button", title: "Try Again", kind: "button")
        ]
    }

    public static func guideControls() -> [LLMControl] {
        [
            LLMControl(id: "guide_bookmarks_button", title: "Bookmarks", kind: "button"),
            LLMControl(id: "guide_more_menu", title: "More options", kind: "menu"),
            LLMControl(id: "guide_export_pdf_button", title: "Export as PDF", kind: "button"),
            LLMControl(id: "guide_export_audio_button", title: "Export Audio Only", kind: "button"),
            LLMControl(id: "guide_export_bundle_button", title: "Export PDF + Audio Bundle", kind: "button"),
            LLMControl(id: "guide_regenerate_audio_button", title: "Regenerate Narration", kind: "button"),
            LLMControl(id: "guide_delete_audio_button", title: "Delete Narration", kind: "button"),
            LLMControl(id: "guide_generate_with_default_button", title: "Generate Narration", kind: "button"),
            LLMControl(id: "guide_regenerate_content_button", title: "Regenerate Content", kind: "button"),
            LLMControl(id: "guide_regenerate_audio_only_button", title: "Regenerate Audio Only", kind: "button"),
            LLMControl(id: "guide_delete_button", title: "Delete Guide", kind: "button"),
            // Dynamic patterns
            LLMControl(id: "guide_toc_*", title: "Navigate to TOC entry (by section id)", kind: "button"),
            LLMControl(id: "audio_speed_menu", title: "Audio Speed Menu", kind: "menu"),
            LLMControl(id: "audio_play_pause_button", title: "Play/Pause Audio", kind: "button"),
            LLMControl(id: "audio_generate_button", title: "Generate/Retry Audio", kind: "button"),
            LLMControl(id: "audio_progress_view", title: "Audio Progress", kind: "progress")
        ]
    }

    // MARK: - Dynamic pattern docs

    private static func dynamicPatternControls() -> [LLMControl] {
        [
            LLMControl(id: "theme_option_*", title: "Theme option (by name)", kind: "button"),
            LLMControl(id: "accent_option_*", title: "Accent option (by name)", kind: "button"),
            LLMControl(id: "library_item_*", title: "Library item (by UUID)", kind: "navigation"),
            LLMControl(id: "guide_toc_*", title: "Navigate to TOC entry (by section id)", kind: "button")
        ]
    }
}

// MARK: - Top-level helpers for LLMs

public func LLMDescribeAllControls() -> [LLMControl] { LLMUIRegistry.allControls() }
public func LLMDescribeSettingsControls() -> [LLMControl] { LLMUIRegistry.settingsControls() }
public func LLMDescribeLibraryControls() -> [LLMControl] { LLMUIRegistry.libraryControls() }
public func LLMDescribeGenerationControls() -> [LLMControl] { LLMUIRegistry.generationControls() }
public func LLMDescribeGuideControls() -> [LLMControl] { LLMUIRegistry.guideControls() }
