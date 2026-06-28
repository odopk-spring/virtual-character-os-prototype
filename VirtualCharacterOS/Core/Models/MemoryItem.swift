import Foundation

/// 记忆分类。用于 UI 筛选和提示。
enum MemoryCategory: String, Codable, CaseIterable, Identifiable {
    case user = "关于用户"
    case character = "关于角色"
    case project = "项目相关"
    case preference = "偏好与习惯"
    case boundary = "边界与禁忌"
    case other = "其他"

    var id: String { rawValue }

    /// SF Symbol 图标名
    var iconName: String {
        switch self {
        case .user: return "person.text.rectangle"
        case .character: return "sparkles"
        case .project: return "folder"
        case .preference: return "heart.text.square"
        case .boundary: return "hand.raised"
        case .other: return "note"
        }
    }
}

/// 单条手动记忆。不包含自动抽取字段，不包含 embedding。
struct MemoryItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var content: String
    var category: MemoryCategory
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        category: MemoryCategory = .other,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.category = category
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
    }
}
