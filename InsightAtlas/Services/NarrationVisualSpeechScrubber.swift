//
//  NarrationVisualSpeechScrubber.swift
//  InsightAtlas
//
//  Governance Lock 3 / audio-visual bridge: listeners must never hear phrases
//  that point at on-screen diagrams. Scrub MiniMax (and fallback) scripts
//  before cache/speak so a model slip cannot defeat the editorial policy.
//

import Foundation

enum NarrationVisualSpeechScrubber {

    /// Case-insensitive phrases that imply a visible figure the listener cannot see.
    private static let forbiddenPhrases: [String] = [
        "as you can see",
        "as you can see in the diagram",
        "as shown in the diagram",
        "as shown in the chart",
        "as shown in the figure",
        "as shown in the graph",
        "the diagram shows",
        "the chart shows",
        "the figure shows",
        "the graph shows",
        "this diagram",
        "this chart",
        "this figure",
        "this graph",
        "look at the diagram",
        "look at the chart",
        "look at the figure",
        "in the diagram above",
        "in the chart above",
        "in the figure above",
        "see the diagram",
        "see the chart",
        "see the figure",
        "shown in the diagram",
        "shown in the chart",
        "shown in the figure",
    ]

    static func scrub(_ text: String) -> String {
        var result = text
        for phrase in forbiddenPhrases.sorted(by: { $0.count > $1.count }) {
            result = result.replacingOccurrences(
                of: phrase,
                with: "",
                options: [.caseInsensitive]
            )
        }
        // Collapse leftover double spaces / empty clauses from removals.
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        result = result.replacingOccurrences(of: " ,", with: ",")
        result = result.replacingOccurrences(of: " .", with: ".")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
