import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @ObservedObject private var kokoroModelManager = KokoroModelManager.shared

    @AppStorage(PremiumUI.themeStorageKey) private var themePreference = PremiumTheme.system.rawValue
    @AppStorage(PremiumUI.accentStorageKey) private var accentPreference = PremiumAccent.gold.rawValue

    @State private var searchText = ""

    @AppStorage("settings_expand_generation") private var expandGeneration = true
    @AppStorage("settings_expand_api") private var expandAPI = true
    @AppStorage("settings_expand_audio") private var expandAudio = true
    @AppStorage("settings_expand_appearance") private var expandAppearance = true
    @AppStorage("settings_expand_about") private var expandAbout = true
    @State private var showResetAlert = false

    @AppStorage(MegaTranscriptNarratorPreferences.selectedVoiceNameKey)
    private var selectedVoiceName = "Arthur"

    private var audioStatus: String {
        if KokoroModelStore.isInstalled {
            let voiceID = UserDefaults.standard.string(
                forKey: KokoroVoiceRegistry.selectedVoiceStorageKey
            ) ?? KokoroVoiceRegistry.defaultVoice.voiceID
            let voice = KokoroVoiceRegistry.voice(byVoiceID: voiceID)
                ?? KokoroVoiceRegistry.defaultVoice
            return "Kokoro · \(voice.name)"
        }
        return selectedVoiceName
    }

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
                        keywords: ["api", "configuration", "keys", "claude", "openrouter", "minimax"],
                        dynamicValues: [apiConfigurationStatus]
                    ) {
                        PremiumSettingsCard(
                            title: "API CONFIGURATION",
                            icon: "lock.fill",
                            accentColor: accentColor,
                            isExpanded: $expandAPI
                        ) {
                            PremiumSettingsNavigationRow(
                                title: "API Access",
                                value: apiConfigurationStatus
                            ) {
                                APIConfigurationView()
                            }
                        }
                    }

                    if matchesSection(
                        title: "Audio & Narration",
                        keywords: ["audio", "voice", "narration", "playback", "kokoro", "offline", "free", "mega transcript", "arthur", "liam"],
                        dynamicValues: [audioStatus]
                    ) {
                        PremiumSettingsCard(
                            title: "AUDIO & NARRATION",
                            icon: "waveform",
                            accentColor: accentColor,
                            isExpanded: $expandAudio
                        ) {
                            PremiumSettingsNavigationRow(
                                title: "Audio Settings",
                                value: audioStatus
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
                                        UISelectionFeedbackGenerator().selectionChanged()
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
                                        UISelectionFeedbackGenerator().selectionChanged()
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
                .padding(.bottom, 96)
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
            KeychainService.shared.hasOpenRouterApiKey,
            MiniMaxOAuthService.hasStoredCredentials
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
            keywords: ["api", "configuration", "keys", "claude", "openai", "openrouter", "minimax"],
            dynamicValues: [apiConfigurationStatus]
        ) &&
        !matchesSection(
            title: "Audio & Narration",
            keywords: ["audio", "voice", "narration", "playback", "kokoro", "offline", "mega transcript", "liam"],
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

        // Audio defaults — provider order is fixed, so only playback speed and
        // the auto-generate toggle are user-configurable.
        if let speed = PlaybackSpeed.allCases.first { environment.userSettings.playbackSpeed = speed }
        environment.userSettings.autoGenerateAudio = false

        environment.saveSettings()
        UISelectionFeedbackGenerator().selectionChanged()
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
                        UISelectionFeedbackGenerator().selectionChanged()
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
                        UISelectionFeedbackGenerator().selectionChanged()
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
                        UISelectionFeedbackGenerator().selectionChanged()
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
    @ObservedObject private var minimax = MiniMaxOAuthService.shared
    @AppStorage(OpenRouterConfig.modelStorageKey) private var openRouterModel = OpenRouterConfig.defaultModel
    @State private var minimaxError: String?

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
                                    UISelectionFeedbackGenerator().selectionChanged()
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
                if minimax.isSignedIn {
                    HStack {
                        Text("MiniMax")
                        Spacer()
                        Text("Signed in")
                            .foregroundStyle(PremiumUI.forest)
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(PremiumUI.forest)
                    }
                    .listRowBackground(PremiumUI.card)

                    Button(role: .destructive) {
                        minimax.signOut()
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    } label: {
                        Text("Sign out of MiniMax")
                    }
                    .listRowBackground(PremiumUI.card)
                } else if let code = minimax.pendingCode {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Approve this code in your browser:")
                            .font(PremiumUI.ui(13, .semibold))
                            .foregroundStyle(PremiumUI.secondaryText)

                        Text(code.userCode)
                            .font(.system(.title2, design: .monospaced).weight(.bold))
                            .foregroundStyle(PremiumUI.ink)
                            .textSelection(.enabled)

                        if let url = code.bestVerificationURL {
                            Link(destination: url) {
                                Label("Open verification page", systemImage: "safari")
                            }
                        }

                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Waiting for approval…")
                                .font(PremiumUI.ui(13))
                                .foregroundStyle(PremiumUI.secondaryText)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(PremiumUI.card)
                } else {
                    Button {
                        Task {
                            do {
                                try await minimax.signIn()
                            } catch let error as MiniMaxOAuthError {
                                minimaxError = error.errorDescription
                            } catch {
                                minimaxError = error.localizedDescription
                            }
                        }
                    } label: {
                        Label("Sign in with MiniMax", systemImage: "person.crop.circle")
                    }
                    .listRowBackground(PremiumUI.card)
                }
            } header: {
                Text("MiniMax (OAuth)")
            } footer: {
                Text("Sign in with MiniMax to generate guides with the \(MiniMaxOAuthConfig.defaultModel) model. Sign-in opens MiniMax in your browser to approve a code — no password is entered in the app. Then select MiniMax under Generation → AI Provider. Tokens are stored in the iOS Keychain.")
            }
        }
        .premiumSettingsList(title: "API Configuration")
        .alert(
            "MiniMax sign-in failed",
            isPresented: Binding(
                get: { minimaxError != nil },
                set: { if !$0 { minimaxError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(minimaxError ?? "")
        }
    }
}

// MARK: - Audio Settings

struct AudioSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @ObservedObject private var kokoroModelManager = KokoroModelManager.shared

    @AppStorage(KokoroVoiceRegistry.selectedVoiceStorageKey)
    private var kokoroVoiceID = KokoroVoiceRegistry.defaultVoice.voiceID

    @AppStorage(MegaTranscriptNarratorPreferences.selectedVoiceNameKey)
    private var megaVoiceName = "Arthur"

    // Local mirror of the Keychain-backed narration token so edits redraw the row.
    @State private var narrationToken: String = KokoroTTSClient.currentAPIKey() ?? ""

    // Liam narration self-test state.
    @State private var isTestingNarration = false
    @State private var narrationDiagnostics: NarrationDiagnostics?

    private func savedSuffix(for key: String) -> String? {
        guard key.count >= 4 else { return nil }
        return "Saved \u{2022}\u{2022}\u{2022}\u{2022}" + key.suffix(4)
    }

    private func diagnosticRow(_ label: String, _ ok: Bool, _ detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .foregroundStyle(ok ? Color.green : Color.red)
            Text(label)
            Spacer()
            Text(detail)
                .font(.footnote)
                .foregroundStyle(PremiumUI.secondaryText)
                .multilineTextAlignment(.trailing)
        }
    }

    private var selectedKokoroVoice: KokoroVoice {
        KokoroVoiceRegistry.voice(byVoiceID: kokoroVoiceID)
            ?? KokoroVoiceRegistry.defaultVoice
    }

    var body: some View {
        List {
            Section {
                kokoroModelStatus

                if KokoroModelStore.isInstalled {
                    NavigationLink {
                        KokoroVoiceSelectionView()
                            .environmentObject(environment)
                    } label: {
                        HStack {
                            Text("Offline Voice")
                            Spacer()
                            Text(selectedKokoroVoice.name)
                                .foregroundStyle(PremiumUI.secondaryText)
                        }
                    }
                }
            } header: {
                Text("Kokoro On-Device Voice (Primary)")
            } footer: {
                Text("Download once, then generate premium narration privately on this iPhone with no API key or per-use charge. The installed model uses about 182 MB.")
            }

            Section {
                NavigationLink {
                    MegaTranscriptDeveloperSettingsView()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Mega Transcript")
                            Text(KeychainMegaTranscriptCredentialStore.shared.hasAPIKey ? "API key configured" : "Developer key not configured")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(megaVoiceName)
                            .foregroundStyle(PremiumUI.secondaryText)
                    }
                }
            } header: {
                Text("First Cloud Fallback")
            } footer: {
                Text("If offline Kokoro is unavailable, Mega Transcript is tried next. Configure its key, choose another narrator, generate a paid preview, or clear its narration cache here.")
            }

            Section {
                HStack {
                    Text("Fallback Voice")
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
                Text("Playback & Final Fallback")
            } footer: {
                Text("The fixed route is offline Kokoro with \(selectedKokoroVoice.name), Mega Transcript with \(megaVoiceName), then Liam as the final fallback.")
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
                Text("Required only when Liam is used as the final fallback. Stored securely in the iOS Keychain on this device only.")
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
                Text("When on, narration is generated after a guide finishes using offline Kokoro first, then Mega Transcript and Liam. Kokoro needs no credential after its one-time model download.")
            }

            Section {
                Button {
                    Task {
                        isTestingNarration = true
                        narrationDiagnostics = nil
                        narrationDiagnostics = await KokoroNarrationService.shared.runDiagnostics()
                        isTestingNarration = false
                    }
                } label: {
                    HStack {
                        Text(isTestingNarration ? "Testing…" : "Test Liam Fallback")
                        Spacer()
                        if isTestingNarration { ProgressView() }
                    }
                }
                .disabled(isTestingNarration)
                .listRowBackground(PremiumUI.card)

                if let diag = narrationDiagnostics {
                    diagnosticRow("Liam Token", diag.tokenPresent, diag.tokenPresent ? "Present" : "Missing")
                        .listRowBackground(PremiumUI.card)
                    diagnosticRow("Liam Gateway", diag.healthOK, diag.healthDetail)
                        .listRowBackground(PremiumUI.card)
                    diagnosticRow("Liam Synthesis", diag.singleChunkOK, diag.singleChunkDetail)
                        .listRowBackground(PremiumUI.card)
                    diagnosticRow("Liam Assembly", diag.assemblyOK, diag.assemblyDetail)
                        .listRowBackground(PremiumUI.card)
                }
            } header: {
                Text("Diagnostics")
            } footer: {
                Text("Tests the Liam cloud fallback. Kokoro readiness and voice selection are shown at the top; Mega Transcript status appears in First Cloud Fallback.")
            }
        }
        .premiumSettingsList(title: "Audio & Narration")
    }

    @ViewBuilder
    private var kokoroModelStatus: some View {
        switch kokoroModelManager.state {
        case .notInstalled:
            Label("Not downloaded", systemImage: "arrow.down.circle")
            Button("Download Kokoro Model") {
                kokoroModelManager.install()
            }

        case .preparing:
            Label("Preparing download…", systemImage: "hourglass")
            ProgressView()

        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 8) {
                Text("Downloading… \(Int(progress * 100))%")
                ProgressView(value: progress)
            }
            Button("Cancel", role: .cancel) {
                kokoroModelManager.cancelInstall()
            }

        case .verifying:
            Label("Verifying model integrity…", systemImage: "checkmark.shield")
            ProgressView()

        case .extracting:
            Label("Installing model…", systemImage: "archivebox")
            ProgressView()

        case .installed:
            Label("Ready for offline narration", systemImage: "checkmark.circle.fill")
                .foregroundStyle(PremiumUI.forest)
            Button("Remove Downloaded Model", role: .destructive) {
                try? kokoroModelManager.deleteModel()
            }

        case .failed(let message):
            Label("Download failed", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Try Download Again") {
                kokoroModelManager.install()
            }
        }
    }
}

// MARK: - Kokoro Voice Selection

struct KokoroVoiceSelectionView: View {
    @EnvironmentObject private var environment: AppEnvironment

    @AppStorage(KokoroVoiceRegistry.selectedVoiceStorageKey)
    private var selectedVoiceID = KokoroVoiceRegistry.defaultVoice.voiceID

    @State private var previewingVoiceID: String?
    @State private var isLoadingPreview = false
    @State private var previewError: String?

    var body: some View {
        List {
            Section {
                ForEach(KokoroVoiceRegistry.allVoices) { voice in
                    KokoroVoiceSettingsRow(
                        voice: voice,
                        isSelected: selectedVoiceID == voice.voiceID,
                        isPreviewing: previewingVoiceID == voice.voiceID,
                        isLoading: isLoadingPreview && previewingVoiceID == voice.voiceID,
                        isPreviewEnabled: KokoroModelStore.isInstalled,
                        onSelect: { select(voice) },
                        onPreview: { preview(voice) }
                    )
                }
            } header: {
                Text("Kokoro On-Device Voices")
            } footer: {
                Text(KokoroModelStore.isInstalled
                     ? "Tap a voice to select it, then play a completely offline preview."
                     : "Download the Kokoro model in Audio Settings to enable previews.")
            }
        }
        .premiumSettingsList(title: "Offline Voice")
        .onDisappear {
            AudioPlaybackManager.shared.stop()
        }
        .alert(
            "Preview failed",
            isPresented: Binding(
                get: { previewError != nil },
                set: { if !$0 { previewError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { previewError = nil }
        } message: {
            Text(previewError ?? "")
        }
    }

    private func select(_ voice: KokoroVoice) {
        selectedVoiceID = voice.voiceID
        environment.userSettings.selectedVoiceID = voice.voiceID
        environment.saveSettings()
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func preview(_ voice: KokoroVoice) {
        guard KokoroModelStore.isInstalled, !isLoadingPreview else { return }
        AudioPlaybackManager.shared.stop()

        if previewingVoiceID == voice.voiceID {
            previewingVoiceID = nil
            return
        }

        previewingVoiceID = voice.voiceID
        isLoadingPreview = true

        Task {
            do {
                let text = "Hello, I'm \(voice.name). I'll narrate your Insight Atlas guides privately and completely offline."
                let audio = try await KokoroAudioService.shared.generateAudio(
                    text: text,
                    voiceID: voice.voiceID
                )

                await MainActor.run {
                    isLoadingPreview = false
                    do {
                        try AudioPlaybackManager.shared.play(audio) {
                            previewingVoiceID = nil
                        }
                    } catch {
                        previewingVoiceID = nil
                        previewError = error.localizedDescription
                    }
                }
            } catch {
                await MainActor.run {
                    isLoadingPreview = false
                    previewingVoiceID = nil
                    previewError = error.localizedDescription
                }
            }
        }
    }
}

struct KokoroVoiceSettingsRow: View {
    let voice: KokoroVoice
    let isSelected: Bool
    let isPreviewing: Bool
    let isLoading: Bool
    let isPreviewEnabled: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(voice.name)
                            .font(.body.weight(.medium))

                        if voice.voiceID == KokoroVoiceRegistry.defaultVoice.voiceID {
                            Text("DEFAULT")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(PremiumUI.gold.opacity(0.2))
                                .foregroundStyle(PremiumUI.goldDark)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }

                    Text(voice.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onPreview) {
                if isLoading {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Image(systemName: isPreviewing ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(isPreviewing ? Color.red : PremiumUI.gold)
                }
            }
            .buttonStyle(.plain)
            .disabled(!isPreviewEnabled)
            .opacity(isPreviewEnabled ? 1 : 0.5)
            .accessibilityLabel(isPreviewEnabled
                                ? (isPreviewing ? "Stop preview" : "Play preview")
                                : "Preview unavailable")

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(PremiumUI.gold)
            }
        }
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
                        UISelectionFeedbackGenerator().selectionChanged()
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
                    UISelectionFeedbackGenerator().selectionChanged()
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
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
        }
    }
}

struct PremiumSearchField: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(PremiumUI.secondaryText)
            TextField(placeholder, text: $text)
                .font(PremiumUI.ui(16))
                .foregroundColor(PremiumUI.ink)
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(PremiumUI.secondaryText.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(PremiumUI.card)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(PremiumUI.divider, lineWidth: 1)
        )
    }
}
