import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var environment: AppEnvironment
    
    var body: some View {
        NavigationStack {
            Form {
                Section("API Keys") {
                    SecureField("Claude API Key", text: Binding(
                        get: { KeychainService.shared.claudeApiKey ?? "" },
                        set: { environment.updateClaudeApiKey($0.isEmpty ? nil : $0) }
                    ))
                    
                    SecureField("OpenAI API Key", text: Binding(
                        get: { KeychainService.shared.openaiApiKey ?? "" },
                        set: { environment.updateOpenAIApiKey($0.isEmpty ? nil : $0) }
                    ))
                }
                
                Section("Preferences") {
                    Picker("Preferred Provider", selection: $environment.userSettings.preferredProvider) {
                        ForEach(AIProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    
                    Toggle("Auto-Generate Audio", isOn: $environment.userSettings.autoGenerateAudio)
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
