import Foundation

// MARK: - Configuration

struct ChatGPTVoiceConfig: Equatable, Sendable {
    let endpoint: URL
    let model: String
    let defaultVoiceID: String
    let maximumTextChunkBytes: Int
    let maximumEventBytes: Int
    let sessionTimeout: TimeInterval
    let turnTimeout: TimeInterval

    static let `default` = ChatGPTVoiceConfig(
        endpoint: URL(string: "wss://api.openai.com/v1/live")!,
        model: "gpt-live-1-codex",
        defaultVoiceID: "marin",
        maximumTextChunkBytes: 500,
        maximumEventBytes: 1_000_000,
        sessionTimeout: 45,
        turnTimeout: 90
    )

    static let supportedModels = ["gpt-live-1-codex", "gpt-live-1-boulder-alpha"]
    static let supportedVoiceIDs = [
        "alloy", "ash", "ballad", "cedar", "coral",
        "echo", "marin", "sage", "shimmer", "verse"
    ]
}

struct ChatGPTVoiceRequestIDs: Equatable, Sendable {
    let realtimeSessionID: String
    let sessionID: String
    let threadID: String

    init(
        realtimeSessionID: String = UUID().uuidString,
        sessionID: String = UUID().uuidString,
        threadID: String = UUID().uuidString
    ) {
        self.realtimeSessionID = realtimeSessionID
        self.sessionID = sessionID
        self.threadID = threadID
    }
}

enum ChatGPTVoiceRole: String, Equatable, Sendable {
    case user
    case assistant
}

enum ChatGPTVoiceProtocolError: LocalizedError, Equatable {
    case invalidEndpoint
    case missingCredential
    case invalidConfiguration
    case invalidJSON
    case invalidEvent(String)
    case invalidBase64Audio
    case invalidPCMFrameAlignment
    case textCannotBeChunked

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "The ChatGPT Voice endpoint is invalid."
        case .missingCredential:
            return "The ChatGPT Voice credential is missing."
        case .invalidConfiguration:
            return "The ChatGPT Voice configuration is invalid."
        case .invalidJSON:
            return "ChatGPT Voice returned malformed JSON."
        case .invalidEvent(let type):
            return "ChatGPT Voice returned an invalid \(type) event."
        case .invalidBase64Audio:
            return "ChatGPT Voice returned malformed audio data."
        case .invalidPCMFrameAlignment:
            return "ChatGPT Voice returned an incomplete PCM audio frame."
        case .textCannotBeChunked:
            return "The narration text cannot be divided safely for ChatGPT Voice."
        }
    }
}

// MARK: - Outbound Requests

enum ChatGPTVoiceRequestBuilder {
    static func makeWebSocketRequest(
        token: String,
        accountID: String,
        requestIDs: ChatGPTVoiceRequestIDs,
        config: ChatGPTVoiceConfig
    ) throws -> URLRequest {
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !accountID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ChatGPTVoiceProtocolError.missingCredential
        }
        guard config.endpoint.scheme?.lowercased() == "wss",
              config.endpoint.host?.lowercased() == "api.openai.com",
              config.endpoint.path == "/v1/live",
              config.maximumTextChunkBytes > 0,
              config.maximumEventBytes > 0,
              config.sessionTimeout > 0,
              config.turnTimeout > 0 else {
            throw ChatGPTVoiceProtocolError.invalidEndpoint
        }

        guard var components = URLComponents(url: config.endpoint, resolvingAgainstBaseURL: false) else {
            throw ChatGPTVoiceProtocolError.invalidEndpoint
        }
        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "model" }
        queryItems.append(URLQueryItem(name: "model", value: config.model))
        components.queryItems = queryItems
        guard let url = components.url else {
            throw ChatGPTVoiceProtocolError.invalidEndpoint
        }

        var request = URLRequest(url: url, timeoutInterval: config.sessionTimeout)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(accountID, forHTTPHeaderField: "chatgpt-account-id")
        request.setValue("quicksilver=v2", forHTTPHeaderField: "OpenAI-Alpha")
        request.setValue(requestIDs.sessionID, forHTTPHeaderField: "session-id")
        request.setValue(requestIDs.threadID, forHTTPHeaderField: "thread-id")
        request.setValue(requestIDs.realtimeSessionID, forHTTPHeaderField: "x-session-id")
        return request
    }

    static func sessionUpdatePayload(
        voiceID: String,
        instructions: String
    ) throws -> Data {
        let resolvedVoice = ChatGPTVoiceConfig.supportedVoiceIDs.contains(voiceID)
            ? voiceID
            : ChatGPTVoiceConfig.default.defaultVoiceID
        let object: [String: Any] = [
            "type": "session.update",
            "session": [
                "instructions": instructions.trimmingCharacters(in: .whitespacesAndNewlines),
                "audio": ["output": ["voice": resolvedVoice]],
                "delegation": ["type": "client"]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: object)
    }

    static func speakableContextPayload(text: String) throws -> Data {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ChatGPTVoiceProtocolError.textCannotBeChunked
        }
        let object: [String: Any] = [
            "type": "session.context.append",
            "channel": "speakable",
            "content": [[
                "type": "input_text",
                "text": trimmed
            ]]
        ]
        return try JSONSerialization.data(withJSONObject: object)
    }
}

// MARK: - Text Chunking

enum ChatGPTVoiceTextChunker {
    static func chunks(_ text: String, maximumBytes: Int) throws -> [String] {
        guard maximumBytes > 0 else {
            throw ChatGPTVoiceProtocolError.invalidConfiguration
        }

        let normalized = text
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .joined(separator: " ")
        guard !normalized.isEmpty else {
            throw ChatGPTVoiceProtocolError.textCannotBeChunked
        }
        if normalized.lengthOfBytes(using: .utf8) <= maximumBytes {
            return [normalized]
        }

        var chunks: [String] = []
        var current = ""

        func appendCurrent() {
            guard !current.isEmpty else { return }
            chunks.append(current)
            current = ""
        }

        for word in normalized.split(separator: " ").map(String.init) {
            if word.lengthOfBytes(using: .utf8) > maximumBytes {
                appendCurrent()
                var oversizedChunk = ""
                for character in word {
                    let fragment = String(character)
                    guard fragment.lengthOfBytes(using: .utf8) <= maximumBytes else {
                        throw ChatGPTVoiceProtocolError.textCannotBeChunked
                    }
                    let candidate = oversizedChunk + fragment
                    if candidate.lengthOfBytes(using: .utf8) > maximumBytes {
                        chunks.append(oversizedChunk)
                        oversizedChunk = fragment
                    } else {
                        oversizedChunk = candidate
                    }
                }
                if !oversizedChunk.isEmpty {
                    chunks.append(oversizedChunk)
                }
                continue
            }

            let candidate = current.isEmpty ? word : "\(current) \(word)"
            if candidate.lengthOfBytes(using: .utf8) <= maximumBytes {
                current = candidate
            } else {
                appendCurrent()
                current = word
            }
        }
        appendCurrent()

        guard !chunks.isEmpty else {
            throw ChatGPTVoiceProtocolError.textCannotBeChunked
        }
        return chunks
    }
}

// MARK: - Inbound Events

enum ChatGPTVoiceInboundEvent: Equatable, Sendable {
    case sessionStarted
    case audio(Data)
    case transcriptDelta(role: ChatGPTVoiceRole, text: String)
    case turnDone(role: ChatGPTVoiceRole, transcript: String)
    case providerError(message: String, fatalAuthentication: Bool)
    case ignored(type: String)
}

enum ChatGPTVoiceEventParser {
    static func parse(_ payload: String) throws -> ChatGPTVoiceInboundEvent {
        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any],
              let type = dictionary["type"] as? String else {
            throw ChatGPTVoiceProtocolError.invalidJSON
        }

        switch type {
        case "session.started":
            return .sessionStarted

        case "output_audio.delta":
            guard let base64 = dictionary["audio"] as? String,
                  let audio = Data(base64Encoded: base64),
                  !audio.isEmpty else {
                throw ChatGPTVoiceProtocolError.invalidBase64Audio
            }
            return .audio(audio)

        case "input_transcript.added", "output_transcript.added":
            guard let item = dictionary["item"] as? [String: Any],
                  let text = item["text"] as? String else {
                throw ChatGPTVoiceProtocolError.invalidEvent(type)
            }
            return .transcriptDelta(
                role: type == "input_transcript.added" ? .user : .assistant,
                text: text
            )

        case "turn.done":
            guard let turn = dictionary["turn"] as? [String: Any],
                  let rawRole = turn["role"] as? String,
                  let role = ChatGPTVoiceRole(rawValue: rawRole),
                  let transcript = turn["transcript"] as? String else {
                throw ChatGPTVoiceProtocolError.invalidEvent(type)
            }
            return .turnDone(role: role, transcript: transcript)

        case "error":
            let error = dictionary["error"] as? [String: Any]
            let status = (dictionary["status"] as? NSNumber)?.intValue
                ?? (error?["status"] as? NSNumber)?.intValue
            let code = ((error?["code"] as? String) ?? (dictionary["code"] as? String) ?? "")
                .lowercased()
            let message = (error?["message"] as? String)
                ?? (dictionary["message"] as? String)
                ?? "ChatGPT Voice returned an unknown error."
            let fatalCodes = [
                "authentication_error", "invalid_api_key", "invalid_token", "token_expired"
            ]
            return .providerError(
                message: message,
                fatalAuthentication: status == 401 || fatalCodes.contains(code)
            )

        default:
            return .ignored(type: type)
        }
    }
}

// MARK: - PCM Validation

enum ChatGPTPCMValidator {
    static func validate(_ data: Data) throws {
        guard !data.isEmpty, data.count.isMultiple(of: MemoryLayout<Int16>.size) else {
            throw ChatGPTVoiceProtocolError.invalidPCMFrameAlignment
        }
    }
}
