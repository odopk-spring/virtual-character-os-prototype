import Foundation

/// 世界书条目分类。
enum WorldBookCategory: String, Codable, CaseIterable, Identifiable {
    case character = "角色"
    case location = "地点"
    case organization = "组织"
    case concept = "概念"
    case event = "事件"
    case rule = "规则"
    case other = "其他"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .character: return "person.2"
        case .location: return "mappin.and.ellipse"
        case .organization: return "building.2"
        case .concept: return "lightbulb"
        case .event: return "calendar"
        case .rule: return "list.clipboard"
        case .other: return "book.pages"
        }
    }
}

/// 单条世界书条目。手动 CRUD，不自动抽取。
struct WorldBookEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var content: String
    var keywords: [String]
    var category: WorldBookCategory
    var isEnabled: Bool
    var priority: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        keywords: [String] = [],
        category: WorldBookCategory = .other,
        isEnabled: Bool = true,
        priority: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.keywords = keywords
        self.category = category
        self.isEnabled = isEnabled
        self.priority = priority
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// 应用字段长度限制。
    func applyingLengthLimits() -> WorldBookEntry {
        var copy = self
        copy.title = String(copy.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        copy.content = String(copy.content.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1500))
        copy.keywords = copy.keywords
            .map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30)) }
            .filter { !$0.isEmpty }
            .prefix(20)
            .map { $0 } // ArraySlice → Array
        return copy
    }
}
