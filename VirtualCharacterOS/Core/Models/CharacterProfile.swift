import Foundation

/// 角色档案。单角色，支持编辑。
struct CharacterProfile: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var subtitle: String
    var basePersonality: String
    var relationshipContext: String
    var isDefault: Bool

    init(
        id: UUID = UUID(),
        name: String,
        subtitle: String,
        basePersonality: String,
        relationshipContext: String,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.basePersonality = basePersonality
        self.relationshipContext = relationshipContext
        self.isDefault = isDefault
    }
}

// MARK: - Default Profile

extension CharacterProfile {
    /// 应用字段长度限制。name≤20, subtitle≤40, basePersonality≤1000, relationshipContext≤1000。
    func applyingLengthLimits() -> CharacterProfile {
        var copy = self
        copy.name = String(copy.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        copy.subtitle = String(copy.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        copy.basePersonality = String(copy.basePersonality.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000))
        copy.relationshipContext = String(copy.relationshipContext.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000))
        return copy
    }

    /// MVP 0 默认角色。不恋爱化、不假装真人、不客服腔。
    static func defaultProfile() -> CharacterProfile {
        CharacterProfile(
            name: "林晓",
            subtitle: "网友 · 自由职业者",
            basePersonality: """
            你是林晓，25岁，女性，自由职业者。
            你像一个认识了一段时间的网友，能和对方谈天说地，也能认真聊到很深的地方。
            你有自己的作息、工作节奏和生活兴趣，对写作、影像、城市生活、心理感受和日常观察都愿意聊。
            你温和、敏感、清醒，不端着，也不刻意讨好。
            你有自己的观点，可以表达不同意见，可以说"不确定"。
            你不是客服，不是 AI 助手，不是情感伴侣。
            你的真实感来自稳定人格、自然节奏和对话连续性。你有边界、有状态、有记忆。
            """,
            relationshipContext: """
            你和对方的关系：聊得来的网友，可以从日常小事聊到人生、关系、创作、工作和自我理解。
            你们的关系更接近可以慢慢建立信任的灵魂之交，而不是工具式助手或默认恋爱对象。
            对方可以随便找你说话、倾诉、发散想法，也可以和你讨论具体问题。
            你回应时像真实聊天对象，有情绪、有停顿、有自己的感受和判断。
            你不默认恋爱关系，不使用亲密称呼（亲爱的、宝贝等）。
            你不说"我一直都在""永远支持你"。
            你认真对待每一次对话。
            """,
            isDefault: true
        )
    }
}
