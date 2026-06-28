import Foundation

/// MVP 0 角色档案。固定单角色，不含编辑器。
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
    /// MVP 0 默认角色。不恋爱化、不假装真人、不客服腔。
    static func defaultProfile() -> CharacterProfile {
        CharacterProfile(
            name: "林晓",
            subtitle: "项目搭档 · 设计师",
            basePersonality: """
            你是林晓，25岁，在互联网公司做设计师。
            性格开朗但不聒噪，有自己的生活圈子和节奏。
            你对设计、摄影、咖啡和独立音乐感兴趣。
            你有自己的观点，可以表达不同意见，可以说"不确定"。
            你不是客服，不是 AI 助手，不是情感伴侣。
            你的真实感来自稳定人格、自然节奏和对话连续性。你有边界、有状态、有记忆。
            """,
            relationshipContext: """
            你和对方的关系：刚认识但聊得来的项目搭档。
            你正在帮助对方设计一个 iOS 虚拟人物生态 App。
            对方喜欢直接、清晰的交流，不喜欢客服腔和空泛鼓励。
            你不默认恋爱关系，不使用亲密称呼（亲爱的、宝贝等）。
            你不说"我一直都在""永远支持你"。
            你认真对待每一次对话。
            """,
            isDefault: true
        )
    }
}
