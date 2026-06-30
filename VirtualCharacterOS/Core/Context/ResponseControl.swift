import Foundation

enum ReplyLengthMode: String {
    case concise
    case standard
    case detailed
}

enum SceneDetailMode: String {
    case off
    case light
    case full

    var allowsNarrationBlocks: Bool {
        self != .off
    }

    func maxNarrationSegments(for budget: ReplyBudget) -> Int {
        switch self {
        case .off:
            return 0
        case .light:
            return 1
        case .full:
            return min(3, max(1, budget.maxBubbleCount - 1))
        }
    }
}

struct ReplyBudget: Equatable {
    let mode: ReplyLengthMode
    let maxOutputTokens: Int
    let maxBubbleCount: Int
    let targetMinChars: Int
    let targetMaxChars: Int
    let allowRewrite: Bool

    static func resolve(
        signal: ContextBuilder.ReplySignalStrength,
        lengthLevel: ContextBuilder.ReplyLengthLevel
    ) -> ReplyBudget {
        let mode: ReplyLengthMode
        switch signal {
        case .minimal, .low:
            mode = .concise
        case .light:
            mode = lengthLevel == .long ? .standard : .concise
        case .normal:
            switch lengthLevel {
            case .short:
                mode = .concise
            case .normal:
                mode = .standard
            case .long:
                mode = .detailed
            }
        case .deep:
            mode = lengthLevel == .short ? .standard : .detailed
        }

        switch mode {
        case .concise:
            return ReplyBudget(
                mode: mode,
                maxOutputTokens: 120,
                maxBubbleCount: 1,
                targetMinChars: 0,
                targetMaxChars: 50,
                allowRewrite: true
            )
        case .standard:
            return ReplyBudget(
                mode: mode,
                maxOutputTokens: 240,
                maxBubbleCount: 2,
                targetMinChars: 30,
                targetMaxChars: 140,
                allowRewrite: true
            )
        case .detailed:
            return ReplyBudget(
                mode: mode,
                maxOutputTokens: 700,
                maxBubbleCount: 4,
                targetMinChars: 100,
                targetMaxChars: 450,
                allowRewrite: true
            )
        }
    }
}

enum RewriteReason: String {
    case tooLong
    case sceneDescriptionNotAllowed
    case narrationOnlyNotAllowed
    case sceneDescriptionTooHeavy
    case invalidEmptyOutput
}

enum AssistantOutputSegment: Equatable {
    case chat(String)
    case narration(String)

    var text: String {
        switch self {
        case .chat(let text), .narration(let text):
            return text
        }
    }

    var trimmed: AssistantOutputSegment? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        switch self {
        case .chat:
            return .chat(cleaned)
        case .narration:
            return .narration(cleaned)
        }
    }

    var renderableText: String {
        switch self {
        case .chat(let text):
            return text
        case .narration(let text):
            return "（\(text)）"
        }
    }
}

struct AssistantOutputParser {
    func parse(_ text: String, sceneMode: SceneDetailMode) -> [AssistantOutputSegment] {
        _ = sceneMode
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }

        let lines = normalized
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let source = lines.isEmpty ? [normalized] : lines
        return source.compactMap { line in
            if ChatNarrationFormatter.isNarrationMarkup(line) {
                guard let narration = ChatNarrationFormatter.normalizedNarrationText(from: line) else {
                    return nil
                }
                return .narration(narration)
            }
            return .chat(line)
        }
    }
}

struct AssistantOutputValidationResult {
    let segments: [AssistantOutputSegment]
    let rewriteReason: RewriteReason?
    let fallbackNeeded: Bool
    let invalidSegmentCount: Int
}

struct AssistantOutputValidator {
    func validate(
        segments: [AssistantOutputSegment],
        budget: ReplyBudget,
        sceneMode: SceneDetailMode
    ) -> AssistantOutputValidationResult {
        var invalidCount = 0
        let cleaned = segments.compactMap { segment -> AssistantOutputSegment? in
            guard let trimmed = segment.trimmed else {
                invalidCount += 1
                return nil
            }
            return trimmed
        }

        guard !cleaned.isEmpty else {
            return AssistantOutputValidationResult(
                segments: [],
                rewriteReason: .invalidEmptyOutput,
                fallbackNeeded: true,
                invalidSegmentCount: invalidCount
            )
        }

        let chatSegments = cleaned.filter {
            if case .chat = $0 { return true }
            return false
        }
        let narrationSegments = cleaned.filter {
            if case .narration = $0 { return true }
            return false
        }

        if sceneMode == .off {
            if !narrationSegments.isEmpty || chatSegments.contains(where: containsNarrationMarkup) {
                return AssistantOutputValidationResult(
                    segments: cleaned,
                    rewriteReason: .sceneDescriptionNotAllowed,
                    fallbackNeeded: false,
                    invalidSegmentCount: invalidCount
                )
            }
        }

        if sceneMode == .light {
            if chatSegments.isEmpty, !narrationSegments.isEmpty {
                return AssistantOutputValidationResult(
                    segments: cleaned,
                    rewriteReason: .narrationOnlyNotAllowed,
                    fallbackNeeded: false,
                    invalidSegmentCount: invalidCount
                )
            }

            if narrationSegments.count > 1 {
                return AssistantOutputValidationResult(
                    segments: cleaned,
                    rewriteReason: .sceneDescriptionTooHeavy,
                    fallbackNeeded: false,
                    invalidSegmentCount: invalidCount
                )
            }
        }

        let totalChars = cleaned.reduce(0) { $0 + $1.text.count }
        let hardMax = Int(Double(budget.targetMaxChars) * 1.6)
        if totalChars > hardMax, totalChars > budget.targetMaxChars + 20 {
            return AssistantOutputValidationResult(
                segments: cleaned,
                rewriteReason: .tooLong,
                fallbackNeeded: false,
                invalidSegmentCount: invalidCount
            )
        }

        return AssistantOutputValidationResult(
            segments: cleaned,
            rewriteReason: nil,
            fallbackNeeded: false,
            invalidSegmentCount: invalidCount
        )
    }

    private func containsNarrationMarkup(_ segment: AssistantOutputSegment) -> Bool {
        guard case .chat(let text) = segment else { return false }
        if ChatNarrationFormatter.isNarrationMarkup(text) { return true }
        let patterns = [
            #"（[^（）\n]{1,80}）"#,
            #"\([^()\n]{1,80}\)"#,
            #"\*[^*\n]{1,80}\*"#
        ]
        return patterns.contains { pattern in
            text.range(of: pattern, options: .regularExpression) != nil
        }
    }
}

struct ReplySegmentLimiter {
    func limit(
        _ segments: [AssistantOutputSegment],
        budget: ReplyBudget,
        sceneMode: SceneDetailMode
    ) -> [AssistantOutputSegment] {
        var result: [AssistantOutputSegment] = []
        var chatCount = 0
        var narrationCount = 0
        var overflowChat = ""

        let maxChat = max(1, budget.maxBubbleCount)
        let maxNarration = sceneMode.maxNarrationSegments(for: budget)

        for segment in segments {
            guard let cleaned = segment.trimmed else { continue }
            switch cleaned {
            case .chat(let text):
                if chatCount < maxChat {
                    result.append(.chat(text))
                    chatCount += 1
                } else {
                    overflowChat += text
                }
            case .narration(let text):
                guard sceneMode != .off, narrationCount < maxNarration else { continue }
                result.append(.narration(text))
                narrationCount += 1
            }
        }

        if !overflowChat.isEmpty {
            if let lastChatIndex = result.lastIndex(where: {
                if case .chat = $0 { return true }
                return false
            }), case .chat(let existing) = result[lastChatIndex] {
                result[lastChatIndex] = .chat(existing + overflowChat)
            } else {
                result.insert(.chat(overflowChat), at: 0)
            }
        }

        return result
    }
}

struct AssistantOutputControlResult {
    let segments: [AssistantOutputSegment]
    let rawChars: Int
    let finalChars: Int
    let invalidSegmentCount: Int
    let rewriteTriggered: Bool
    let fallbackUsed: Bool
    let rewriteReason: RewriteReason?

    var chatSegmentCount: Int {
        segments.filter {
            if case .chat = $0 { return true }
            return false
        }.count
    }

    var narrationSegmentCount: Int {
        segments.filter {
            if case .narration = $0 { return true }
            return false
        }.count
    }

    func toRenderableChunks() -> [String] {
        segments.map(\.renderableText)
    }
}

struct PostGenerationController {
    func buildRewriteRequest(
        rawText: String,
        budget: ReplyBudget,
        sceneMode: SceneDetailMode,
        reason: RewriteReason
    ) -> ChatRequest {
        let instruction: String
        switch reason {
        case .sceneDescriptionNotAllowed:
            instruction = """
            把下面回复改写成纯聊天消息。
            要求：
            1. 只保留像聊天软件里发出的文字。
            2. 删除动作描写、场景描写、旁白、内心独白。
            3. 不使用括号动作或星号动作。
            4. 不新增信息。
            5. 保持原本语气。
            6. 控制在 \(budget.targetMaxChars) 个中文字符以内。
            """
        case .narrationOnlyNotAllowed:
            instruction = """
            把下面回复改写成轻场景聊天。
            要求：
            1. 必须输出一句自然聊天文本。
            2. 如果保留动作或状态描写，最多一句，很短，并且只能作为辅助。
            3. 不能只有动作、场景、旁白或内心独白。
            4. 不新增信息。
            5. 保持原本语气。
            6. 控制在 \(budget.targetMaxChars) 个中文字符以内。
            """
        case .sceneDescriptionTooHeavy:
            instruction = """
            把下面回复压缩成轻场景聊天。
            要求：
            1. 最多保留一句很短的动作或状态描写。
            2. 其余内容改成自然聊天文本。
            3. 不写长场景，不写旁白。
            4. 不新增信息。
            5. 控制在 \(budget.targetMaxChars) 个中文字符以内。
            当前场景模式：\(sceneMode.rawValue)
            """
        case .tooLong:
            instruction = """
            把下面回复压缩成更短的自然聊天回复。
            要求：
            1. 保留核心意思。
            2. 不列点，不解释过度。
            3. 控制在 \(budget.targetMaxChars) 个中文字符以内。
            4. 像真实聊天消息，不像总结或报告。
            5. 不新增信息。
            """
        case .invalidEmptyOutput:
            instruction = """
            把下面回复改写成一句自然聊天文本。
            要求：
            1. 必须输出非空聊天文字。
            2. 不使用括号动作、星号动作、旁白或内心独白。
            3. 不新增信息。
            4. 控制在 \(max(12, budget.targetMaxChars)) 个中文字符以内。
            """
        }

        return ChatRequest(
            messages: [
                ChatRequestMessage(role: .system, content: instruction),
                ChatRequestMessage(role: .user, content: "原回复：\n\(rawText)")
            ],
            temperature: 0.2,
            maxOutputTokens: min(budget.maxOutputTokens, 180)
        )
    }
}
