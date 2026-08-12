import SwiftUI

/// The overflow menu presented from the compact-width header's hamburger button.
///
/// Complements the bottom tab bar rather than duplicating it: quick appearance
/// toggles (theme + accent) plus jump-off points that don't warrant a tab of
/// their own (Settings, Help, About).
struct OverflowMenuView: View {
    @Binding var themePreference: String
    @Binding var accentPreference: String

    /// Switches the app's active tab; used to jump to Settings from the menu.
    let onSelectTab: (AppTab) -> Void

    @Environment(\.dismiss) private var dismiss

    private var versionText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            List {
                appearanceSection
                actionsSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(PremiumUI.background)
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PremiumUI.accent(from: accentPreference))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                themePicker
                accentPicker
            }
            .padding(.vertical, 4)
            .listRowBackground(PremiumUI.card)
        } header: {
            Text("Appearance")
        }
    }

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Theme")
                .font(PremiumUI.ui(13, .semibold))
                .foregroundStyle(PremiumUI.secondaryText)

            Picker("Theme", selection: $themePreference) {
                ForEach(PremiumTheme.allCases) { theme in
                    Label(theme.rawValue, systemImage: theme.icon)
                        .tag(theme.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var accentPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accent")
                .font(PremiumUI.ui(13, .semibold))
                .foregroundStyle(PremiumUI.secondaryText)

            HStack(spacing: 14) {
                ForEach(PremiumAccent.allCases) { accent in
                    Button {
                        accentPreference = accent.rawValue
                    } label: {
                        Circle()
                            .fill(accent.color)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle()
                                    .strokeBorder(PremiumUI.ink, lineWidth: 2)
                                    .padding(-3)
                                    .opacity(accentPreference == accent.rawValue ? 1 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accent.rawValue)
                    .accessibilityAddTraits(accentPreference == accent.rawValue ? .isSelected : [])
                }
                Spacer()
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                dismiss()
                onSelectTab(.settings)
            } label: {
                OverflowMenuRow(icon: "gearshape", title: "Settings")
            }
            .buttonStyle(.plain)
            .listRowBackground(PremiumUI.card)

            NavigationLink {
                HelpTutorialsView()
            } label: {
                OverflowMenuRow(icon: "questionmark.circle", title: "Help & Tutorials")
            }
            .listRowBackground(PremiumUI.card)
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                OverflowMenuRow(icon: "info.circle", title: "Insight Atlas")
                Spacer()
                Text("Version \(versionText)")
                    .font(PremiumUI.ui(14))
                    .foregroundStyle(PremiumUI.secondaryText)
            }
            .listRowBackground(PremiumUI.card)
        }
    }
}

/// A single tappable row in the overflow menu: leading accent-tinted glyph + title.
private struct OverflowMenuRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PremiumUI.gold)
                .frame(width: 28)

            Text(title)
                .font(PremiumUI.ui(16, .medium))
                .foregroundStyle(PremiumUI.ink)
        }
        .padding(.vertical, 2)
    }
}
