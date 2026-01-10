import SwiftUI

// MARK: - Improved Settings View

struct ImprovedSettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                InsightAtlasColors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: InsightAtlasSpacing.lg) {
                        // Search bar
                        SearchBar(text: $searchText, placeholder: "Search")
                            .padding(.horizontal)
                        
                        // Settings sections
                        SettingsSection(
                            title: "GENERATION",
                            icon: "brain",
                            iconColor: InsightAtlasColors.gold
                        ) {
                            SettingsNavigationRow(
                                title: "AI Provider",
                                value: viewModel.aiProvider,
                                destination: AIProviderSettingsView()
                            )
                            
                            SettingsNavigationRow(
                                title: "Generation Mode",
                                value: viewModel.generationMode,
                                destination: GenerationModeSettingsView()
                            )
                            
                            SettingsNavigationRow(
                                title: "Output Tone",
                                value: viewModel.outputTone,
                                destination: OutputToneSettingsView()
                            )
                            
                            SettingsNavigationRow(
                                title: "Default Format",
                                value: viewModel.defaultFormat,
                                destination: DefaultFormatSettingsView()
                            )
                        }
                        
                        SettingsSection(
                            title: "API CONFIGURATION",
                            icon: "lock.fill",
                            iconColor: InsightAtlasColors.burgundy
                        ) {
                            SettingsNavigationRow(
                                title: "Manage API Keys",
                                destination: APIConfigurationView()
                            )
                        }
                        
                        SettingsSection(
                            title: "APPEARANCE",
                            icon: "paintpalette.fill",
                            iconColor: InsightAtlasColors.coral
                        ) {
                            SettingsNavigationRow(
                                title: "Theme",
                                value: viewModel.theme,
                                destination: ThemeSettingsView()
                            )
                            
                            SettingsNavigationRow(
                                title: "Accent Color",
                                destination: AccentColorSettingsView()
                            )
                        }
                        
                        SettingsSection(
                            title: "ABOUT & SUPPORT",
                            icon: "info.circle.fill",
                            iconColor: InsightAtlasColors.gold
                        ) {
                            SettingsInfoRow(
                                title: "Version",
                                value: "1.0.0"
                            )
                            
                            SettingsNavigationRow(
                                title: "Help & Tutorials",
                                destination: HelpView()
                            )
                            
                            SettingsNavigationRow(
                                title: "Privacy Policy",
                                destination: PrivacyPolicyView()
                            )
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(InsightAtlasColors.heading)
                    .tracking(0.5)
            }
            .padding(.horizontal, InsightAtlasSpacing.md)
            .padding(.bottom, InsightAtlasSpacing.xs)
            
            // Section content card
            VStack(spacing: 0) {
                content
            }
            .background(InsightAtlasColors.card)
            .cornerRadius(InsightAtlasRadius.large)
            .overlay(
                RoundedRectangle(cornerRadius: InsightAtlasRadius.large)
                    .stroke(InsightAtlasColors.rule, lineWidth: 0.5)
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(iconColor)
                    .frame(width: 4)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Settings Navigation Row

struct SettingsNavigationRow<Destination: View>: View {
    let title: String
    var value: String? = nil
    let destination: Destination
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack {
                Text(title)
                    .font(InsightAtlasTypography.body)
                    .foregroundColor(InsightAtlasColors.heading)
                
                Spacer()
                
                if let value = value {
                    Text(value)
                        .font(InsightAtlasTypography.bodySmall)
                        .foregroundColor(InsightAtlasColors.muted)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(InsightAtlasColors.muted)
            }
            .padding(.horizontal, InsightAtlasSpacing.md)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Info Row

struct SettingsInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(InsightAtlasTypography.body)
                .foregroundColor(InsightAtlasColors.heading)
            
            Spacer()
            
            Text(value)
                .font(InsightAtlasTypography.bodySmall)
                .foregroundColor(InsightAtlasColors.muted)
        }
        .padding(.horizontal, InsightAtlasSpacing.md)
        .padding(.vertical, 14)
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(InsightAtlasColors.muted)
                .font(.system(size: 14))
            
            TextField(placeholder, text: $text)
                .font(InsightAtlasTypography.body)
                .foregroundColor(InsightAtlasColors.heading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(InsightAtlasColors.backgroundAlt)
        .cornerRadius(10)
    }
}

// MARK: - Settings ViewModel

class SettingsViewModel: ObservableObject {
    @Published var aiProvider: String = "Claude"
    @Published var generationMode: String = "Standard"
    @Published var outputTone: String = "Professional"
    @Published var defaultFormat: String = "Full Guide"
    @Published var theme: String = "System"
}

// MARK: - Placeholder Views (to be implemented)

struct AIProviderSettingsView: View {
    var body: some View {
        Text("AI Provider Settings")
    }
}

struct GenerationModeSettingsView: View {
    var body: some View {
        Text("Generation Mode Settings")
    }
}

struct OutputToneSettingsView: View {
    var body: some View {
        Text("Output Tone Settings")
    }
}

struct DefaultFormatSettingsView: View {
    var body: some View {
        Text("Default Format Settings")
    }
}

struct APIConfigurationView: View {
    var body: some View {
        Text("API Configuration")
    }
}

struct ThemeSettingsView: View {
    var body: some View {
        Text("Theme Settings")
    }
}

struct AccentColorSettingsView: View {
    var body: some View {
        Text("Accent Color Settings")
    }
}

struct HelpView: View {
    var body: some View {
        Text("Help & Tutorials")
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        Text("Privacy Policy")
    }
}

// MARK: - Preview

#Preview {
    ImprovedSettingsView()
}
