import Foundation

enum VoicePlaybackAvailability: Equatable {
    case playable(label: String)
    case unavailable(reason: String)

    var isPlayable: Bool {
        if case .playable = self { return true }
        return false
    }
}

enum VoiceTextExtractor {
    static func availability(
        from message: ChatMessage,
        settings: VoiceSettings
    ) -> VoicePlaybackAvailability {
        guard message.role == .assistant, message.status == .sent else {
            return .unavailable(reason: "这条消息还不能播放。")
        }

        if ChatNarrationFormatter.narrationText(from: message) != nil,
           !settings.readsNarration {
            return .unavailable(reason: "旁白朗读已关闭。")
        }

        guard readableText(from: message, settings: settings) != nil else {
            return .unavailable(reason: "没有可朗读的文本。")
        }

        switch settings.engine {
        case .onDevice:
            return .playable(label: "iPhone 本地")
        case .localServer:
            guard settings.hasPlayableConfiguration else {
                return .playable(label: "本地回退")
            }
            guard settings.serverBaseURL != nil else {
                return .playable(label: "本地回退")
            }
            return .playable(label: "TTS 服务")
        }
    }

    static func readableText(from message: ChatMessage, settings: VoiceSettings) -> String? {
        guard message.role == .assistant, message.status == .sent else { return nil }

        if let narration = ChatNarrationFormatter.narrationText(from: message) {
            return settings.readsNarration ? trimmedNonEmpty(narration) : nil
        }

        return trimmedNonEmpty(message.content)
    }

    private static func trimmedNonEmpty(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
