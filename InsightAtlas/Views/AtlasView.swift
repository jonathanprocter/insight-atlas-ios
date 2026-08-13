import SwiftUI

/// Atlas — connected personal knowledge across the library.
///
/// Shell-pass placeholder: establishes the editorial header and an on-brand
/// empty state. The full experience (concept cards, relationships, "Worth
/// revisiting") is built in a dedicated pass once the concept/link data model
/// exists.
struct AtlasView: View {
    @EnvironmentObject private var dataManager: DataManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    PremiumComingSoonPanel(
                        icon: "globe.americas",
                        title: "Your atlas is forming",
                        message: "As your library grows, Insight Atlas will connect the concepts, authors, and frameworks your guides share — so the collection compounds in value."
                    )
                    .padding(.horizontal, 18)
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(PremiumUI.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Atlas")
                .font(PremiumUI.display(34, .bold, relativeTo: .largeTitle))
                .foregroundStyle(PremiumUI.ink)
            Text("The ideas your library is building.")
                .font(PremiumUI.ui(15, .regular, relativeTo: .subheadline))
                .foregroundStyle(PremiumUI.secondaryText)
        }
        .padding(.horizontal, 18)
    }
}

/// Listen — private narrated listening queue.
///
/// Quiet, on-brand empty-state panel used by the shell placeholder screens.
struct PremiumComingSoonPanel: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(PremiumUI.slate)
                .frame(width: 56, height: 56)
                .background(PremiumUI.searchFill, in: Circle())

            Text(title)
                .font(PremiumUI.display(20, .semibold, relativeTo: .title3))
                .foregroundStyle(PremiumUI.ink)
                .multilineTextAlignment(.center)

            Text(message)
                .font(PremiumUI.ui(14, .regular, relativeTo: .footnote))
                .foregroundStyle(PremiumUI.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .background(PremiumUI.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(PremiumUI.divider, lineWidth: 0.5)
        )
    }
}

#Preview("Atlas") {
    AtlasView()
        .environmentObject(DataManager.shared)
}
