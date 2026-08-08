import SwiftUI

/// The destinations surfaced by the premium bottom navigation.
enum AppTab: String, CaseIterable, Identifiable {
    case library
    case listen
    case atlas
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .library:  return "Library"
        case .listen:   return "Listen"
        case .atlas:    return "Atlas"
        case .settings: return "Settings"
        }
    }

    /// SF Symbol for the destination; filled variant while active.
    func icon(isSelected: Bool) -> String {
        switch self {
        case .library:  return isSelected ? "books.vertical.fill" : "books.vertical"
        case .listen:   return isSelected ? "headphones.circle.fill" : "headphones"
        case .atlas:    return isSelected ? "globe.americas.fill" : "globe.americas"
        case .settings: return isSelected ? "gearshape.fill" : "gearshape"
        }
    }
}

/// The app's custom bottom navigation for compact width.
///
/// Deliberately *not* a translucent glass pill: a solid porcelain surface with
/// a single hairline top border, matching the premium spec. The active
/// destination is rendered in Deep Slate with a small coral indicator beneath
/// it; inactive destinations use graphite. Metallic gold is reserved for
/// signature moments elsewhere and never appears here.
struct PremiumTabBar: View {
    @Binding var selection: AppTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                item(for: tab)
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 8)
        .background(
            PremiumUI.card
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(PremiumUI.divider)
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func item(for tab: AppTab) -> some View {
        let isSelected = tab == selection

        return Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                selection = tab
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: tab.icon(isSelected: isSelected))
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .frame(height: 24)

                Text(tab.title)
                    .font(PremiumUI.ui(11, isSelected ? .semibold : .medium, relativeTo: .caption2))

                // Coral indicator — signature of the active destination.
                Capsule()
                    .fill(isSelected ? PremiumUI.coral : Color.clear)
                    .frame(width: 16, height: 2.5)
            }
            .foregroundStyle(isSelected ? PremiumUI.slate : PremiumUI.secondaryText)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

#Preview {
    struct Harness: View {
        @State private var tab: AppTab = .library
        var body: some View {
            VStack {
                Spacer()
                PremiumTabBar(selection: $tab)
            }
            .background(PremiumUI.background)
        }
    }
    return Harness()
}
