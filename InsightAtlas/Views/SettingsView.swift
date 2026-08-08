import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    @AppStorage(PremiumUI.themeStorageKey) private var themePreference = PremiumTheme.system.rawValue
    @AppStorage(PremiumUI.accentStorageKey) private var accentPreference = PremiumAccent.gold.rawValue

    @State private var searchText = ""

    @AppStorage("settings_expand_generation") private var expandGeneration = true
    @AppStorage("settings_expand_api") private var expandAPI = true
    @AppStorage("settings_expand_audio") private var expandAudio = true
    @AppStorage("settings_expand_appearance") private var expandAppearance = true
    @AppStorage("settings_expand_about") private var expandAbout = true
    @State private var showResetAlert = false

    /// Narration uses a single fixed voice (Liam); shown for the Audio row value.
    private var selectedVoiceName: String { "Liam" }

    private var accentColor: Color {
        PremiumUI.accent(from: accentPreference)
    }

    private var versionText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Settings")
                            .font(PremiumUI.display(34, .bold))
                            .foregroundStyle(PremiumUI.ink)
                        Spacer()
                        Menu {
                            Button(role: .destructive) {
                                showResetAlert = true
                            } label: {
                                Label("Reset All Settings", systemImage: "arrow.counterclockwise")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(PremiumUI.ink)
                                .accessibilityLabel("More options")
                        }
                    }

                    PremiumSearchField(
                        text: $searchText,
                        placeholder: "Search settings"
                    )

                    if matchesSection(
                        title: "Generation",
                        keywords: ["ai provider", "generation mode", "tone", "format", "summary"],
                        dynamicValues: [
                            environment.userSettings.preferredProvider.displayName,
                            environment.userSettings.preferredMode.displayName,
                            environment.userSettings.preferredTone.displayName,
                            environment.userSettings.preferredFormat.displayName,
                            environment.userSettings.preferredSummaryType.displayName
                        ]
                    ) {
                        PremiumSettingsCard(
                            title: "GENERATION",
                            icon: "brain.head.profile",
                            accentColor: accentColor,
                            isExpanded: $expandGeneration
                        ) {
                            PremiumSettingsNavigationRow(
                                title: "AI Provider",
                                value: environment.userSettings.preferredProvider.displayName
                            ) {
                                AIProviderSettingsView()
                            }

                            PremiumSettingsDivider()

                            PremiumSettingsNavigationRow(
                                title: "Generation Mode",
                                value: environment.userSettings.preferredMode.displayName
                            ) {
                                GenerationModeSettingsView()
                            }

                            PremiumSettingsDivider()

                            PremiumSettingsNavigationRow(
                                title: "Output Tone",
                                value: environment.userSettings.preferredTone.displayName
                            ) {
                                OutputToneSettingsView()
                            }

                            PremiumSettingsDivider()

                            PremiumSettingsNavigationRow(
                                title: "Default Format",
                                value: environment.userSettings.preferredFormat.displayName
                            ) {
                                DefaultFormatSettingsView()
                            }
                        }
                    }

                    if matchesSection(
                        title: "API Configuration",
                        keywords: ["api", "configuration", "keys", "claude", "openai", "openrouter", "chatgpt"],
                        dynamicValues: [apiConfigurationStatus]
                    ) {
                        PremiumSettingsCard(
                            title: "API CONFIGURATION",
                            icon: "lock.fill",
                            accentColor: accentColor,
                            isExpanded: $expandAPI
                        ) {
                            PremiumSettingsNavigationRow(
                                title: "Manage API Keys",
                                value: apiConfigurationStatus
                            ) {
                                APIConfigurationView()
                            }
                        }
                    }

                    if matchesSection(
                        title: "Audio & Narration",
                        keywords: ["audio", "voice", "narration", "playback", "elevenlabs", "openai"],
                        dynamicValues: [selectedVoiceName]
                    ) {
                        PremiumSettingsCard(
                            title: "AUDIO & NARRATION",
                            icon: "waveform",
                            accentColor: accentColor,
                            isExpanded: $expandAudio
                        ) {
                            PremiumSettingsNavigationRow(
                                title: "Audio Settings",
                                value: selectedVoiceName
                            ) {
                                AudioSettingsView()
                            }

                            PremiumSettingsDivider()

                            PremiumSettingsToggleRow(
                                title: "Auto-generate Audio",
                                isOn: $environment.userSettings.autoGenerateAudio,
                                accentColor: accentColor
                            )
                            .onChange(of: environment.userSettings.autoGenerateAudio) {
                                environment.saveSettings()
                            }
                        }
                    }

                    if matchesSection(
                        title: "Appearance",
                        keywords: ["appearance", "theme", "light", "dark", "system", "accent", "color", "contrast", "sepia"],
                        dynamicValues: [themePreference, accentPreference]
                    ) {
                        PremiumSettingsCard(
                            title: "APPEARANCE",
                            icon: "paintpalette.fill",
                            accentColor: accentColor,
                            isExpanded: $expandAppearance
                        ) {
                            PremiumSettingsNavigationRow(
                                title: "Theme",
                                value: themePreference
                            ) {
                                ThemeSettingsView()
                            }

                            PremiumSettingsDivider()

                            PremiumSettingsNavigationRow(
                                title: "Accent Color",
                                value: accentPreference
                            ) {
                                AccentColorSettingsView()
                            }

                            PremiumSettingsDivider()

                            PremiumSettingsToggleRow(
                                title: "Increase Contrast",
                                isOn: Binding(
                                    get: { UserDefaults.standard.bool(forKey: "insight_atlas_high_contrast") },
                                    set: { newValue in
                                        UserDefaults.standard.set(newValue, forKey: "insight_atlas_high_contrast")
                                        PremiumHaptics.selection()
                                    }
                                ),
                                accentColor: accentColor
                            )

                            PremiumSettingsDivider()

                            PremiumSettingsToggleRow(
                                title: "Sepia Reading Mode",
                                isOn: Binding(
                                    get: { UserDefaults.standard.bool(forKey: "insight_atlas_sepia_mode") },
                                    set: { newValue in
                                        UserDefaults.standard.set(newValue, forKey: "insight_atlas_sepia_mode")
                                        PremiumHaptics.selection()
                                    }
                                ),
                                accentColor: accentColor
                            )
                        }
                    }

                    if matchesSection(
                        title: "About & Support",
                        keywords: ["about", "support", "version", "help", "tutorials", "privacy", "rate", "contact"],
                        dynamicValues: [versionText]
                    ) {
                        PremiumSettingsCard(
                            title: "ABOUT & SUPPORT",
                            icon: "info.circle.fill",
                            accentColor: accentColor,
                            isExpanded: $expandAbout
                        ) {
                            PremiumSettingsInfoRow(
                                title: "Version",
                                value: versionText
                            )

                            PremiumSettingsDivider()

                            PremiumSettingsNavigationRow(title: "Help & Tutorials") {
                                HelpTutorialsView()
                            }

                            PremiumSettingsDivider()

                            PremiumSettingsNavigationRow(title: "Privacy Policy") {
                                PrivacyPolicySettingsView()
                            }

                            PremiumSettingsDivider()

                            PremiumSettingsNavigationRow(title: "System Info") {
                                SystemInfoView()
                            }

                            PremiumSettingsDivider()

                            Button {
                                if let url = URL(string: "mailto:support@example.com") { UIApplication.shared.open(url) }
                            } label: {
                                HStack {
                                    Text("Contact Support")
                                        .font(PremiumUI.ui(16, .medium))
                                        .foregroundStyle(PremiumUI.ink)
                                    Spacer()
                                    Image(systemName: "envelope")
                                        .foregroundStyle(PremiumUI.secondaryText.opacity(0.7))
                                }
                            }
                            .buttonStyle(.plain)

                            PremiumSettingsDivider()

                            Button {
                                if let url = URL(string: "itms-apps://itunes.apple.com/app/id000000000?action=write-review") { UIApplication.shared.open(url) }
                            } label: {
                                HStack {
                                    Text("Rate on the App Store")
                                        .font(PremiumUI.ui(16, .medium))
                                        .foregroundStyle(PremiumUI.ink)
                                    Spacer()
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(PremiumUI.secondaryText.opacity(0.7))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !searchText.isEmpty && noSectionMatches {
                        ContentUnavailableView.search(text: searchText)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 44)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(PremiumUI.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .tint(accentColor)
            .alert("Reset all settings?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    resetAllSettings()
                }
            } message: {
                Text("This will restore defaults for appearance, generation, and audio settings. API keys are not removed.")
            }
        }
    }

    private var apiConfigurationStatus: String {
        let configuredCount = [
            KeychainService.shared.hasClaudeApiKey,
            KeychainService.shared.hasOpenAIApiKey
        ].filter { $0 }.count

        switch configuredCount {
        case 0: return "Not Configured"
        case 1: return "1 Configured"
        default: return "Configured"
        }
    }

    private var noSectionMatches: Bool {
        !matchesSection(
            title: "Generation",
            keywords: ["ai provider", "generation mode", "tone", "format", "summary"],
            dynamicValues: [
                environment.userSettings.preferredProvider.displayName,
                environment.userSettings.preferredMode.displayName,
                environment.userSettings.preferredTone.displayName,
                environment.userSettings.preferredFormat.displayName,
                environment.userSettings.preferredSummaryType.displayName
            ]
        ) &&
        !matchesSection(
            title: "API Configuration",
            keywords: ["api", "configuration", "keys", "claude", "openai", "openrouter", "chatgpt"],
            dynamicValues: [apiConfigurationStatus]
        ) &&
        !matchesSection(
            title: "Audio & Narration",
            keywords: ["audio", "voice", "narration", "playback", "elevenlabs", "openai"],
            dynamicValues: [selectedVoiceName]
        ) &&
        !matchesSection(
            title: "Appearance",
            keywords: ["appearance", "theme", "light", "dark", "system", "accent", "color", "contrast", "sepia"],
            dynamicValues: [themePreference, accentPreference]
        ) &&
        !matchesSection(
            title: "About & Support",
            keywords: ["about", "support", "version", "help", "tutorials", "privacy", "rate", "contact"],
            dynamicValues: [versionText]
        )
    }

    private func matchesSection(title: String, keywords: [String], dynamicValues: [String] = []) -> Bool {
        guard !searchText.isEmpty else { return true }
        let haystack = ([title] + keywords + dynamicValues)
            .joined(separator: " ")
            .lowercased()
        return haystack.contains(searchText.lowercased())
    }

    private func resetAllSettings() {
        // Appearance
        themePreference = PremiumTheme.system.rawValue
        accentPreference = PremiumAccent.gold.rawValue
        UserDefaults.standard.set(false, forKey: "insight_atlas_high_contrast")
        UserDefaults.standard.set(false, forKey: "insight_atlas_sepia_mode")

        // Generation defaults (best-effort using first cases)
        if let provider = AIProvider.allCases.first { environment.userSettings.preferredProvider = provider }
        if let mode = GenerationMode.allCases.first { environment.userSettings.preferredMode = mode }
        if let tone = ToneMode.allCases.first { environment.userSettings.preferredTone = tone }
        if let format = OutputFormat.allCases.first { environment.userSettings.preferredFormat = format }
        if let summary = SummaryType.allCases.first { environment.userSettings.preferredSummaryType = summary }

        // Audio defaults — narration is Liam-only, so only playback speed and
        // the auto-generate toggle are user-configurable.
        if let speed = PlaybackSpeed.allCases.first { environment.userSettings.playbackSpeed = speed }
        environment.userSettings.autoGenerateAudio = false

        environment.saveSettings()
        PremiumHaptics.selection()
    }
}

struct PremiumSettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let accentColor: Color
    var isExpanded: Binding<Bool>? = nil
    @ViewBuilder let content: Content

    init(
        title: String,
        icon: String,
        accentColor: Color,
        isExpanded: Binding<Bool>? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.accentColor = accentColor
        self.isExpanded = isExpanded
        self.content = content()
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accentColor)

            Text(title.uppercased())
                .font(PremiumUI.ui(13, .bold))
                .foregroundStyle(PremiumUI.ink)
                .tracking(0.2)

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .contentShape(Rectangle())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let isExpanded {
                DisclosureGroup(isExpanded: isExpanded) {
                    content
                } label: {
                    header
                }
                .padding(.bottom, 4)
                .animation(.snappy, value: isExpanded.wrappedValue)
            } else {
                header
                content
            }
        }
        .background(PremiumUI.card)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: 13,
                bottomLeadingRadius: 13,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
            .fill(accentColor)
            .frame(width: 6)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(accentColor.opacity(0.8), lineWidth: 0.8)
        }
        .shadow(color: PremiumUI.cardShadow.opacity(0.55), radius: 5, x: 0, y: 2)
    }
}

struct PremiumSettingsNavigationRow<Destination: View>: View {
    let title: String
    var value: String?
    @ViewBuilder let destination: Destination

    init(
        title: String,
        value: String? = nil,
        @ViewBuilder destination: () -> Destination
    ) {
        self.title = title
        self.value = value
        self.destination = destination()
    }

    var body: some View {
        NavigationLink {
            destination
                .toolbar(.visible, for: .navigationBar)
        } label: {
            HStack(spacing: 10) {
                Text(title)
                    .font(PremiumUI.ui(16, .medium))
                    .foregroundStyle(PremiumUI.ink)

                Spacer(minLength: 8)

                if let value {
                    Text(value)
                        .font(PremiumUI.ui(13))
                        .foregroundStyle(PremiumUI.secondaryText)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PremiumUI.secondaryText.opacity(0.7))
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct PremiumSettingsInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(PremiumUI.ui(16, .medium))
                .foregroundStyle(PremiumUI.ink)

            Spacer()

            Text(value)
                .font(PremiumUI.ui(14))
                .foregroundStyle(PremiumUI.secondaryText)
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 42)
    }
}

struct PremiumSettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    let accentColor: Color

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(PremiumUI.ui(16, .medium))
                .foregroundStyle(PremiumUI.ink)
        }
        .tint(accentColor)
        .padding(.horizontal, 18)
        .frame(minHeight: 48)
    }
}

struct PremiumSettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(PremiumUI.divider)
            .frame(height: 0.7)
            .padding(.leading, 18)
    }
}

// MARK: - Generation Settings

struct AIProviderSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        PremiumChoiceList(
            title: "AI Provider",
            footer: "Choose the provider used by default for new guides.",
            choices: AIProvider.allCases.map {
                PremiumChoice(id: $0.rawValue, title: $0.displayName)
            },
            selectedID: environment.userSettings.preferredProvider.rawValue
        ) { id in
            guard let provider = AIProvider(rawValue: id) else { return }
            environment.userSettings.preferredProvider = provider
            environment.saveSettings()
        }
    }
}

struct GenerationModeSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        PremiumChoiceList(
            title: "Generation Mode",
            footer: "Deep Research creates a longer, more thoroughly sourced guide.",
            choices: GenerationMode.allCases.map {
                PremiumChoice(id: $0.rawValue, title: $0.displayName)
            },
            selectedID: environment.userSettings.preferredMode.rawValue
        ) { id in
            guard let mode = GenerationMode(rawValue: id) else { return }
            environment.userSettings.preferredMode = mode
            environment.saveSettings()
        }
    }
}

struct OutputToneSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        PremiumChoiceList(
            title: "Output Tone",
            footer: "This controls the default language style used in generated guides.",
            choices: ToneMode.allCases.map {
                PremiumChoice(id: $0.rawValue, title: $0.displayName)
            },
            selectedID: environment.userSettings.preferredTone.rawValue
        ) { id in
            guard let tone = ToneMode(rawValue: id) else { return }
            environment.userSettings.preferredTone = tone
            environment.saveSettings()
        }
    }
}

struct DefaultFormatSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        List {
            Section("Output Format") {
                ForEach(OutputFormat.allCases, id: \.self) { format in
                    Button {
                        environment.userSettings.preferredFormat = format
                        environment.saveSettings()
                        PremiumHaptics.selection()
                    } label: {
                        PremiumChoiceRow(
                            title: format.displayName,
                            subtitle: format.description,
                            isSelected: environment.userSettings.preferredFormat == format
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(PremiumUI.card)
                }
            }

            Section("Summary Length") {
                ForEach(SummaryType.allCases, id: \.self) { summaryType in
                    Button {
                        environment.userSettings.preferredSummaryType = summaryType
                        environment.saveSettings()
                        PremiumHaptics.selection()
                    } label: {
                        PremiumChoiceRow(
                            title: summaryType.displayName,
                            isSelected: environment.userSettings.preferredSummaryType == summaryType
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(PremiumUI.card)
                }
            }
        }
        .premiumSettingsList(title: "Default Format")
    }
}

struct PremiumChoice: Identifiable {
    let id: String
    let title: String
    var subtitle: String?
}

struct PremiumChoiceList: View {
    let title: String
    let footer: String
    let choices: [PremiumChoice]
    let selectedID: String
    let onSelect: (String) -> Void

    var body: some View {
        List {
            Section {
                ForEach(choices) { choice in
                    Button {
                        onSelect(choice.id)
                        PremiumHaptics.selection()
                    } label: {
                        PremiumChoiceRow(
                            title: choice.title,
                            subtitle: choice.subtitle,
                            isSelected: selectedID == choice.id
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(PremiumUI.card)
                }
            } footer: {
                Text(footer)
            }
        }
        .premiumSettingsList(title: title)
    }
}

struct PremiumChoiceRow: View {
    let title: String
    var subtitle: String?
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(PremiumUI.ui(16, .medium))
                    .foregroundStyle(PremiumUI.ink)

                if let subtitle {
                    Text(subtitle)
                        .font(PremiumUI.ui(13))
                        .foregroundStyle(PremiumUI.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 19))
                    .foregroundStyle(PremiumUI.gold)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - API Configuration

struct APIConfigurationView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @ObservedObject private var chatgpt = ChatGPTOAuthService.shared
    @AppStorage("insight_atlas_use_chatgpt_oauth") private var useChatGPTOAuth = false
    @AppStorage(ChatGPTOAuthConfig.modelStorageKey) private var chatgptModel = ChatGPTOAuthConfig.defaultModel
    @AppStorage(OpenRouterConfig.modelStorageKey) private var openRouterModel = OpenRouterConfig.defaultModel
    @State private var showChatGPTSignIn = false

    private func savedSuffix(for key: String?) -> String? {
        guard let key, key.count >= 4 else { return nil }
        return "Saved \u{2022}\u{2022}\u{2022}\u{2022}" + key.suffix(4)
    }

    var body: some View {
        List {
            Section {
                SecureFieldRow(
                    label: "Claude",
                    placeholder: "Anthropic API Key",
                    text: Binding(
                        get: { KeychainService.shared.claudeApiKey ?? "" },
                        set: { environment.updateClaudeApiKey($0.isEmpty ? nil : $0) }
                    ),
                    hasValue: KeychainService.shared.hasClaudeApiKey,
                    savedSuffix: savedSuffix(for: KeychainService.shared.claudeApiKey)
                )
                .listRowBackground(PremiumUI.card)

                SecureFieldRow(
                    label: "OpenAI",
                    placeholder: "OpenAI API Key",
                    text: Binding(
                        get: { KeychainService.shared.openaiApiKey ?? "" },
                        set: { environment.updateOpenAIApiKey($0.isEmpty ? nil : $0) }
                    ),
                    hasValue: KeychainService.shared.hasOpenAIApiKey,
                    savedSuffix: savedSuffix(for: KeychainService.shared.openaiApiKey)
                )
                .listRowBackground(PremiumUI.card)

                SecureFieldRow(
                    label: "OpenRouter",
                    placeholder: "OpenRouter API Key (sk-or-...)",
                    text: Binding(
                        get: { KeychainService.shared.openRouterApiKey ?? "" },
                        set: { KeychainService.shared.openRouterApiKey = $0.isEmpty ? nil : $0 }
                    ),
                    hasValue: KeychainService.shared.hasOpenRouterApiKey,
                    savedSuffix: savedSuffix(for: KeychainService.shared.openRouterApiKey)
                )
                .listRowBackground(PremiumUI.card)

                // OpenRouter model selector — OpenRouter exposes many models
                // behind one key; pick a suggestion or type any valid slug.
                VStack(alignment: .leading, spacing: 6) {
                    Text("OpenRouter Model")
                        .font(PremiumUI.ui(13, .semibold))
                        .foregroundStyle(PremiumUI.secondaryText)

                    HStack(spacing: 8) {
                        TextField(OpenRouterConfig.defaultModel, text: $openRouterModel)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .submitLabel(.done)
                            .font(PremiumUI.ui(15, .regular))
                            .foregroundStyle(PremiumUI.ink)

                        Menu {
                            ForEach(OpenRouterConfig.candidateModels, id: \.self) { model in
                                Button {
                                    openRouterModel = model
                                    PremiumHaptics.selection()
                                } label: {
                                    if openRouterModel == model {
                                        Label(model, systemImage: "checkmark")
                                    } else {
                                        Text(model)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(PremiumUI.gold)
                                .frame(width: 32, height: 32)
                        }
                        .accessibilityLabel("Choose an OpenRouter model")
                    }
                }
                .listRowBackground(PremiumUI.card)
            } header: {
                Text("AI Providers")
            } footer: {
                Text("API keys are stored in the iOS Keychain and are not included in app settings backups. To generate via OpenRouter, also select it under Generation → AI Provider. OpenRouter bills separately from OpenAI and can reach OpenAI, Anthropic (incl. Claude Opus), Google, and Meta models with one key.")
            }

            Section {
                if chatgpt.isSignedIn {
                    HStack {
                        Text("ChatGPT")
                        Spacer()
                        Text("Signed in")
                            .foregroundStyle(PremiumUI.forest)
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(PremiumUI.forest)
                    }
                    .listRowBackground(PremiumUI.card)

                    Toggle("Use for guide generation", isOn: $useChatGPTOAuth)
                        .tint(PremiumUI.gold)
                        .listRowBackground(PremiumUI.card)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Codex Model")
                            .font(PremiumUI.ui(13, .semibold))
                            .foregroundStyle(PremiumUI.secondaryText)

                        HStack(spacing: 8) {
                            TextField(ChatGPTOAuthConfig.defaultModel, text: $chatgptModel)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .submitLabel(.done)
                                .font(PremiumUI.ui(15, .regular))
                                .foregroundStyle(PremiumUI.ink)

                            Menu {
                                ForEach(ChatGPTOAuthConfig.candidateModels, id: \.self) { model in
                                    Button {
                                        chatgptModel = model
                                        PremiumHaptics.selection()
                                    } label: {
                                        if chatgptModel == model {
                                            Label(model, systemImage: "checkmark")
                                        } else {
                                            Text(model)
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(PremiumUI.gold)
                                    .frame(width: 32, height: 32)
                            }
                            .accessibilityLabel("Choose a suggested Codex model")
                        }
                    }
                    .listRowBackground(PremiumUI.card)

                    Button(role: .destructive) {
                        chatgpt.signOut()
                        useChatGPTOAuth = false
                        PremiumHaptics.notification(.warning)
                    } label: {
                        Text("Sign out of ChatGPT")
                    }
                    .listRowBackground(PremiumUI.card)
                } else {
                    Button {
                        showChatGPTSignIn = true
                    } label: {
                        Label("Sign in with ChatGPT", systemImage: "person.crop.circle")
                    }
                    .listRowBackground(PremiumUI.card)
                }
            } header: {
                Text("ChatGPT Subscription (Beta)")
            } footer: {
                Text("Unofficial: routes guide generation through your ChatGPT subscription via the Codex backend. While enabled, it overrides the AI Provider selection above. This is not supported by OpenAI, may violate its Terms of Service, and could rate-limit or ban your account. Use at your own risk. Note: this covers guide text only — audio narration is generated separately with the Liam voice and requires the narration token in Audio & Narration. If generation fails with a \"model is not supported\" error, try a different Codex Model above (tap the ▾ for suggestions); which models work depends on your ChatGPT plan.")
            }
        }
        .premiumSettingsList(title: "API Configuration")
        .sheet(isPresented: $showChatGPTSignIn) {
            ChatGPTSignInSheet()
        }
    }
}

// MARK: - Audio Settings

struct AudioSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    // Local mirror of the Keychain-backed narration token so edits redraw the row.
    @State private var narrationToken: String = KokoroTTSClient.currentAPIKey() ?? ""

    private func savedSuffix(for key: String) -> String? {
        guard key.count >= 4 else { return nil }
        return "Saved \u{2022}\u{2022}\u{2022}\u{2022}" + key.suffix(4)
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Voice")
                    Spacer()
                    Text("Liam")
                        .foregroundStyle(PremiumUI.secondaryText)
                }

                Picker("Playback Speed", selection: $environment.userSettings.playbackSpeed) {
                    ForEach(PlaybackSpeed.allCases, id: \.self) { speed in
                        Text(speed.displayName).tag(speed)
                    }
                }
                .onChange(of: environment.userSettings.playbackSpeed) {
                    environment.saveSettings()
                }
            } header: {
                Text("Narration")
            } footer: {
                Text("Narration is generated with the Liam voice. The voice is fixed and not selectable.")
            }

            Section {
                SecureFieldRow(
                    label: "Narration Token",
                    placeholder: "Liam narration token",
                    text: Binding(
                        get: { narrationToken },
                        set: { newValue in
                            narrationToken = newValue
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.isEmpty {
                                try? KokoroTTSClient.removeAPIKey()
                            } else {
                                try? KokoroTTSClient.storeAPIKey(trimmed)
                            }
                        }
                    ),
                    hasValue: !narrationToken.isEmpty,
                    savedSuffix: savedSuffix(for: narrationToken)
                )
                .listRowBackground(PremiumUI.card)
            } header: {
                Text("Liam Narration")
            } footer: {
                Text("Required to generate narration. Stored securely in the iOS Keychain on this device only.")
            }

            Section {
                Toggle(
                    "Auto-generate Audio",
                    isOn: $environment.userSettings.autoGenerateAudio
                )
                .tint(PremiumUI.gold)
                .onChange(of: environment.userSettings.autoGenerateAudio) {
                    environment.saveSettings()
                }
            } footer: {
                Text("When on, narration is generated automatically after a guide finishes. Requires the Liam narration token above.")
            }
        }
        .premiumSettingsList(title: "Audio & Narration")
    }
}

// MARK: - Appearance Settings

struct ThemeSettingsView: View {
    @AppStorage(PremiumUI.themeStorageKey) private var selection = PremiumTheme.system.rawValue

    // The app is currently locked to light mode (see ContentView's
    // `.preferredColorScheme(.light)`), so Dark and System would be no-ops.
    // Only surface the option that actually takes effect to avoid misleading
    // the user; dark-mode tokens already exist for when the lock is lifted.
    private let availableThemes: [PremiumTheme] = PremiumTheme.allCases

    var body: some View {
        List {
            Section {
                PremiumSettingsCard(
                    title: "Preview",
                    icon: "paintpalette.fill",
                    accentColor: PremiumUI.gold
                ) {
                    PremiumSettingsInfoRow(title: "Body Text", value: "Looks like this")
                    PremiumSettingsDivider()
                    PremiumSettingsToggleRow(title: "A Toggle", isOn: .constant(true), accentColor: PremiumUI.gold)
                }
                .listRowBackground(PremiumUI.card)
            }

            Section {
                ForEach(availableThemes) { theme in
                    Button {
                        selection = theme.rawValue
                        PremiumHaptics.selection()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: theme.icon)
                                .frame(width: 24)
                                .foregroundStyle(PremiumUI.gold)

                            Text(theme.rawValue)
                                .foregroundStyle(PremiumUI.ink)

                            Spacer()

                            if selection == theme.rawValue {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(PremiumUI.gold)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(PremiumUI.card)
                }
            }
        }
        .premiumSettingsList(title: "Theme")
    }
}

struct AccentColorSettingsView: View {
    @AppStorage(PremiumUI.accentStorageKey) private var selection = PremiumAccent.gold.rawValue

    var body: some View {
        List {
            Section {
                PremiumSettingsCard(
                    title: "Preview",
                    icon: "paintpalette.fill",
                    accentColor: PremiumUI.accent(from: selection)
                ) {
                    PremiumSettingsInfoRow(title: "Body Text", value: "Looks like this")
                    PremiumSettingsDivider()
                    PremiumSettingsToggleRow(title: "A Toggle", isOn: .constant(true), accentColor: PremiumUI.accent(from: selection))
                }
                .listRowBackground(PremiumUI.card)
            }

            ForEach(PremiumAccent.allCases) { accent in
                Button {
                    selection = accent.rawValue
                    PremiumHaptics.selection()
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(accent.color)
                            .frame(width: 24, height: 24)

                        Text(accent.rawValue)
                            .foregroundStyle(PremiumUI.ink)

                        Spacer()

                        if selection == accent.rawValue {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .foregroundStyle(accent.color)
                        }
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(PremiumUI.card)
            }
        }
        .premiumSettingsList(title: "Accent Color")
    }
}

// MARK: - Help and Privacy

struct HelpTutorialsView: View {
    var body: some View {
        List {
            PremiumHelpRow(
                icon: "doc.badge.plus",
                title: "Create a Guide",
                text: "Open Library, tap the plus button, then select a PDF or EPUB."
            )
            PremiumHelpRow(
                icon: "line.3.horizontal.decrease",
                title: "Find Saved Guides",
                text: "Search by title, author, or guide content. Use filters for favorites, recent guides, and drafts."
            )
            PremiumHelpRow(
                icon: "hand.draw",
                title: "Quick Actions",
                text: "In list view, swipe a guide to favorite, export, or delete it."
            )
            PremiumHelpRow(
                icon: "square.and.arrow.up",
                title: "Export",
                text: "Export a completed guide as a PDF from its swipe action or context menu."
            )
        }
        .premiumSettingsList(title: "Help & Tutorials")
    }
}

struct PrivacyPolicySettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label("Privacy by Design", systemImage: "hand.raised.fill")
                    .font(PremiumUI.display(24, .bold))
                    .foregroundStyle(PremiumUI.ink)

                Text("Insight Atlas stores API keys in the iOS Keychain. Saved guides and generated media remain in the app’s local storage unless you choose to export or share them.")

                Text("When you generate a guide, the selected AI provider receives the source content required to fulfill that request under that provider’s terms and privacy policy.")

                Text("Insight Atlas does not display, log, or intentionally transmit your API keys outside the provider requests you initiate.")
            }
            .font(PremiumUI.ui(16))
            .foregroundStyle(PremiumUI.secondaryText)
            .padding(20)
        }
        .background(PremiumUI.background.ignoresSafeArea())
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

struct PremiumHelpRow: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PremiumUI.gold)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(PremiumUI.ui(16, .semibold))
                    .foregroundStyle(PremiumUI.ink)

                Text(text)
                    .font(PremiumUI.ui(14))
                    .foregroundStyle(PremiumUI.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(PremiumUI.card)
    }
}

private extension View {
    func premiumSettingsList(title: String) -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(PremiumUI.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .tint(PremiumUI.gold)
    }
}


// MARK: - Clean Secure Field Row

struct SecureFieldRow: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let hasValue: Bool
    var savedSuffix: String? = nil

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(label)
                        .fontWeight(.medium)

                    if hasValue {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(PremiumUI.gold)
                    }
                }

                if isVisible {
                    TextField(placeholder, text: $text)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } else {
                    SecureField(placeholder, text: $text)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }

                if let savedSuffix, savedSuffix.isEmpty == false {
                    Text(savedSuffix)
                        .font(PremiumUI.ui(12))
                        .foregroundStyle(PremiumUI.secondaryText)
                }
            }

            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
                    .font(.body)
                    .padding(8)
                    .contentShape(Rectangle())
                    .accessibilityLabel(isVisible ? "Hide key" : "Show key")
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview("Settings") {
    NavigationStack {
        SettingsView()
            .environmentObject(AppEnvironment.shared)
    }
}

struct SystemInfoView: View {
    var body: some View {
        List {
            PremiumSettingsInfoRow(title: "App Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-")
            PremiumSettingsDivider()
            PremiumSettingsInfoRow(title: "Build", value: Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "-")
            PremiumSettingsDivider()
            PremiumSettingsInfoRow(title: "Device", value: UIDevice.current.model)
            PremiumSettingsDivider()
            PremiumSettingsInfoRow(title: "iOS", value: UIDevice.current.systemVersion)
        }
        .premiumSettingsList(title: "System Info")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Copy") {
                    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
                    let build = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "-"
                    let summary = "App: \(version) (\(build))\nDevice: \(UIDevice.current.model)\niOS: \(UIDevice.current.systemVersion)"
                    UIPasteboard.general.string = summary
                    PremiumHaptics.selection()
                }
            }
        }
    }
}
