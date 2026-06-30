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
                maxOutputTokens: 80,
                maxBubbleCount: 1,
                targetMinChars: 0,
                targetMaxChars: 40,
                allowRewrite: true
            )
        case .standard:
            return ReplyBudget(
                mode: mode,
                maxOutputTokens: 180,
                maxBubbleCount: 2,
                targetMinChars: 30,
                targetMaxChars: 120,
                allowRewrite: true
            )
        case .detailed:
            return ReplyBudget(
                mode: mode,
                maxOutputTokens: 600,
                maxBubbleCount: 4,
                targetMinChars: 100,
                targetMaxChars: 420,
                allowRewrite: true
            )
        }
    }
}

enum RewriteReason: String {
    case tooLong
    case sceneDescriptionNotAllowed
    case sceneDescriptionTooHeavy
}

struct PostGenerationController {
    func needsRewrite(
        rawText: String,
        budget: ReplyBudget,
        sceneMode: SceneDetailMode
    ) -> RewriteReason? {
        guard budget.allowRewrite else { return nil }

        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if sceneMode == .off, containsSceneDescription(trimmed) {
            return .sceneDescriptionNotAllowed
        }

        if sceneMode == .light, sceneDescriptionHitCount(trimmed) > 1 {
            return .sceneDescriptionTooHeavy
        }

        let hardMax = Int(Double(budget.targetMaxChars) * 1.6)
        if trimmed.count > hardMax, trimmed.count > budget.targetMaxChars + 20 {
            return .tooLong
        }

        return nil
    }

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

    private func containsSceneDescription(_ text: String) -> Bool {
        isStandaloneNarrationMarkup(text) || sceneDescriptionHitCount(text) > 0
    }

    private func sceneDescriptionHitCount(_ text: String) -> Int {
        var count = 0
        if containsBracketedSceneDescription(text) { count += 1 }
        if containsThirdPersonAction(text) { count += 1 }
        count += Self.narrativeMarkers.filter { text.contains($0) }.count
        return count
    }

    private func containsBracketedSceneDescription(_ text: String) -> Bool {
        let patterns = [
            #"（[^（）\n]{1,50}）"#,
            #"\([^()\n]{1,50}\)"#,
            #"\*[^*\n]{1,50}\*"#
        ]

        for pattern in patterns {
            guard let range = text.range(of: pattern, options: .regularExpression) else {
                continue
            }
            let segment = String(text[range])
            if pattern.hasPrefix(#"\*"#) {
                return true
            }
            if Self.sceneActionMarkers.contains(where: { segment.contains($0) }) {
                return true
            }
        }
        return false
    }

    private func isStandaloneNarrationMarkup(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return false }

        let pairs: [(Character, Character)] = [
            ("*", "*"),
            ("（", "）"),
            ("(", ")"),
            ("【", "】")
        ]

        return pairs.contains { pair in
            trimmed.first == pair.0 && trimmed.last == pair.1
        }
    }

    private func containsThirdPersonAction(_ text: String) -> Bool {
        let hasSubject = Self.thirdPersonSubjects.contains { text.contains($0) }
        guard hasSubject else { return false }
        return Self.sceneActionMarkers.contains { text.contains($0) }
    }

    private static let thirdPersonSubjects = ["她", "他", "对方", "林晓"]

    private static let sceneActionMarkers = [
        "笑了笑", "低头", "抬头", "靠近", "走到", "看着你",
        "叹了口气", "沉默了一下", "放下", "转过头", "伸手"
    ]

    private static let narrativeMarkers = [
        "空气里", "房间里", "窗外", "她的声音", "他的声音",
        "他站在", "镜头", "场景", "旁白", "内心"
    ]
}
