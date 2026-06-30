import Foundation

enum VoiceTextExtractor {
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
