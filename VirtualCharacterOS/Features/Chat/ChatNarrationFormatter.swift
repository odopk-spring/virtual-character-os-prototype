import Foundation

enum ChatNarrationFormatter {
    static let settingsKey = "ChatSettings.allowsNarrationBlocks"

    static func narrationText(from message: ChatMessage) -> String? {
        guard message.role == .assistant else { return nil }
        return narrationText(from: message.content)
    }

    static func narrationText(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return nil }

        let pairs: [(Character, Character)] = [
            ("*", "*"),
            ("（", "）"),
            ("(", ")"),
            ("【", "】")
        ]

        for pair in pairs {
            guard trimmed.first == pair.0, trimmed.last == pair.1 else { continue }
            let inner = String(trimmed.dropFirst().dropLast())
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !inner.isEmpty, inner.count <= 80 else { continue }
            return inner
        }

        return nil
    }

    static func splitNarrationSegments(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var result: [String] = []
        var buffer = ""
        var index = trimmed.startIndex

        while index < trimmed.endIndex {
            if let marker = marker(at: index, in: trimmed),
               buffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let close = trimmed[index...].dropFirst().firstIndex(of: marker.close) {
                let candidate = String(trimmed[index...close])
                if narrationText(from: candidate) != nil {
                    appendIfNotEmpty(buffer, to: &result)
                    result.append(candidate)
                    buffer = ""
                    index = trimmed.index(after: close)
                    continue
                }
            }

            buffer.append(trimmed[index])
            index = trimmed.index(after: index)
        }

        appendIfNotEmpty(buffer, to: &result)
        return result.isEmpty ? [trimmed] : result
    }

    static func removingNarrationMarkup(from text: String) -> String {
        var segments: [String] = []
        for segment in splitNarrationSegments(text) {
            if narrationText(from: segment) == nil {
                segments.append(removeInlineNarrationMarkers(segment))
            }
        }

        let cleaned = segments
            .joined(separator: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? removeInlineNarrationMarkers(text) : cleaned
    }

    private static func removeInlineNarrationMarkers(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(
            of: #"\*[^*\n]{1,80}\*"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"（[^（）\n]{1,80}）"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\([^()\n]{1,80}\)"#,
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"【[^【】\n]{1,80}】"#,
            with: "",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func appendIfNotEmpty(_ text: String, to result: inout [String]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            result.append(trimmed)
        }
    }

    private static func marker(at index: String.Index, in text: String) -> (open: Character, close: Character)? {
        switch text[index] {
        case "*": return ("*", "*")
        case "（": return ("（", "）")
        case "(": return ("(", ")")
        case "【": return ("【", "】")
        default: return nil
        }
    }
}
