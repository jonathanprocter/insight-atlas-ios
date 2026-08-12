import SwiftUI

/// A single trailing action revealed by swiping a `SwipeActionsRow`.
struct SwipeRowAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let tint: Color
    /// Destructive actions are rendered last with a red tint by convention.
    let handler: () -> Void

    init(title: String, icon: String, tint: Color, handler: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.handler = handler
    }
}

/// A drag-to-reveal container that adds trailing swipe actions to arbitrary
/// content, for use *outside* of a `List` (where `.swipeActions` is unavailable).
///
/// The content is expected to be opaque so the action strip stays hidden until
/// the row is swiped. Swiping left reveals the actions; tapping the exposed
/// content (or invoking an action) snaps it closed.
struct SwipeActionsRow<Content: View>: View {
    let actions: [SwipeRowAction]
    @ViewBuilder var content: Content

    @State private var offset: CGFloat = 0
    @GestureState private var dragTranslation: CGFloat = 0

    private let buttonWidth: CGFloat = 76
    private var revealWidth: CGFloat { CGFloat(actions.count) * buttonWidth }
    private var currentOffset: CGFloat { max(-revealWidth, min(0, offset + dragTranslation)) }
    private var isOpen: Bool { offset != 0 }

    var body: some View {
        ZStack(alignment: .trailing) {
            actionStrip
            content
                .background(AnalysisTheme.bgCard)
                .offset(x: currentOffset)
                .overlay(
                    // While open, intercept taps on the content to close instead
                    // of activating whatever it wraps (e.g. a NavigationLink).
                    Color.clear
                        .contentShape(Rectangle())
                        .allowsHitTesting(isOpen)
                        .onTapGesture { close() }
                        .offset(x: currentOffset)
                )
                .gesture(dragGesture)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var actionStrip: some View {
        HStack(spacing: 0) {
            ForEach(actions) { action in
                Button {
                    close()
                    action.handler()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: action.icon)
                            .font(.system(size: 20, weight: .semibold))
                        Text(action.title)
                            .font(PremiumUI.ui(11, .semibold, relativeTo: .caption))
                    }
                    .foregroundStyle(.white)
                    .frame(width: buttonWidth)
                    .frame(maxHeight: .infinity)
                    .background(action.tint)
                }
                .buttonStyle(.plain)
            }
        }
        // Reveal in step with the drag so buttons don't float ahead of the row.
        .frame(width: revealWidth)
        .opacity(currentOffset < 0 ? 1 : 0)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .updating($dragTranslation) { value, state, _ in
                // Only track predominantly-horizontal drags so vertical
                // scrolling of the parent list is preserved.
                if abs(value.translation.width) > abs(value.translation.height) {
                    state = value.translation.width
                }
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let combined = offset + value.translation.width
                let shouldOpen = combined < -revealWidth * 0.4
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    offset = shouldOpen ? -revealWidth : 0
                }
            }
    }

    private func close() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            offset = 0
        }
    }
}
