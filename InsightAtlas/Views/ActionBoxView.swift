import SwiftUI

/// View for displaying Action Boxes with practical implementation steps
/// - Important: This is a legacy view. Use `PremiumActionBoxView` from AnalysisComponents.swift instead,
///   which follows the AnalysisTheme design system and matches the premium brand colors.
@available(*, deprecated, message: "Use PremiumActionBoxView from AnalysisComponents.swift instead")
struct ActionBoxView: View {

    let actionBox: ActionBox?
    let content: String?

    init(actionBox: ActionBox) {
        self.actionBox = actionBox
        self.content = nil
    }

    init(content: String) {
        self.actionBox = nil
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)

                Text("APPLY IT")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(1)
                    .foregroundStyle(.green)

                if let box = actionBox {
                    Text(": \(box.conceptName)")
                        .font(.headline)
                }

                Spacer()
            }

            Divider()

            // Actions
            if let box = actionBox {
                ForEach(box.actions) { action in
                    actionStepView(action)
                }
            } else if let content = content {
                Text(content)
                    .font(.body)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green, lineWidth: 2)
                .background(Color.green.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        )
    }

    private func actionStepView(_ action: ActionStep) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(action.number)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.green)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(action.instruction)
                    .font(.body)

                if let timeframe = action.timeframe {
                    Text(timeframe)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
        }
    }
}

// Preview commented out to avoid deprecation warnings
// Use PremiumActionBoxView from AnalysisComponents.swift instead
/*
#Preview("Legacy ActionBoxView - Deprecated") {
    // Note: This preview intentionally uses the deprecated ActionBoxView for demonstration purposes
    ScrollView {
        VStack(spacing: 20) {
            // First example
            let actionBox1 = ActionBox(
                conceptName: "Don't Make Assumptions",
                actions: [
                    ActionStep(number: 1, instruction: "Notice when you're filling information gaps with stories—catch the phrase \"they probably...\" in your thinking", timeframe: nil),
                    ActionStep(number: 2, instruction: "Ask one clarifying question today instead of assuming you know someone's intention", timeframe: "Today"),
                    ActionStep(number: 3, instruction: "When you feel offended, pause and ask: \"Do I actually know this is true, or am I assuming?\"", timeframe: nil),
                    ActionStep(number: 4, instruction: "In your next important conversation, state your needs directly rather than expecting the other person to \"just know\"", timeframe: "This week"),
                    ActionStep(number: 5, instruction: "Practice saying \"I don't know\" when you genuinely don't—resist the urge to fill gaps", timeframe: nil)
                ]
            )
            ActionBoxView(actionBox: actionBox1)

            // Second example
            let actionBox2 = ActionBox(
                conceptName: "Be Impeccable with Your Word",
                actions: [
                    ActionStep(number: 1, instruction: "Before speaking, ask yourself: Is this true? Is it kind? Is it necessary?", timeframe: nil),
                    ActionStep(number: 2, instruction: "Catch yourself when you're about to gossip and redirect the conversation", timeframe: nil),
                    ActionStep(number: 3, instruction: "Make one promise today and keep it—no matter how small", timeframe: "Today")
                ]
            )
            ActionBoxView(actionBox: actionBox2)
        }
        .padding()
    }
}
*/
