import Foundation

struct ChatGPTVoice: UnifiedVoice {
    let voiceID: String
    let name: String
    let description: String

    var id: String { voiceID }
    var provider: VoiceProvider { .chatgptVoice }
    var previewText: String { VoicePreviewScript.primary }
}

enum ChatGPTVoiceRegistry {
    static let allVoices: [ChatGPTVoice] = [
        .init(voiceID: "alloy", name: "Alloy", description: "Balanced and versatile"),
        .init(voiceID: "ash", name: "Ash", description: "Clear and conversational"),
        .init(voiceID: "ballad", name: "Ballad", description: "Warm and expressive"),
        .init(voiceID: "cedar", name: "Cedar", description: "Grounded and composed"),
        .init(voiceID: "coral", name: "Coral", description: "Bright and engaging"),
        .init(voiceID: "echo", name: "Echo", description: "Smooth and reflective"),
        .init(voiceID: "marin", name: "Marin", description: "Natural long-form narration"),
        .init(voiceID: "sage", name: "Sage", description: "Calm and thoughtful"),
        .init(voiceID: "shimmer", name: "Shimmer", description: "Light and articulate"),
        .init(voiceID: "verse", name: "Verse", description: "Dynamic and polished")
    ]

    static let defaultVoice = ChatGPTVoice(
        voiceID: "marin",
        name: "Marin",
        description: "Natural long-form narration"
    )

    static func voice(byID id: String) -> ChatGPTVoice? {
        allVoices.first { $0.voiceID == id }
    }

    static func isValidVoiceID(_ id: String) -> Bool {
        voice(byID: id) != nil
    }
}
