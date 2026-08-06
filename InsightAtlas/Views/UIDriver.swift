import Foundation

public extension Notification.Name {
    static let UIDriverCommand = Notification.Name("UIDriverCommand")
}

public enum UIDriverKeys {
    public static let command = "command"
    public static let payload = "payload"
}

public enum UIDriverCommand: String {
    case showGenerationView
    case showLibraryOptions
    case navigateToLibraryItem
    case navigateToGuideSection
    case toggleGuideAudio
    case generateGuideAudio
    case showVoicePicker
    case showRegenerateOptions
    case exportGuide // payload: ["itemId": UUID, "format": String]
    case deleteGuide // payload: ["itemId": UUID]
    case showChatGPTSignIn
    case signOutChatGPT
}

public enum UIDriverExporterFormat: String {
    case pdfOnly
    case audioOnly
    case bundled
    case htmlOnly
    case htmlWithAudio
}

public struct UIDriver {
    public static func post(_ command: UIDriverCommand, payload: [String: Any]? = nil) {
        var info: [String: Any] = [UIDriverKeys.command: command.rawValue]
        if let payload { info[UIDriverKeys.payload] = payload }
        NotificationCenter.default.post(name: .UIDriverCommand, object: nil, userInfo: info)
    }
}
