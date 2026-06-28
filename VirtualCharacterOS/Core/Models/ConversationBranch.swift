import Foundation

/// 对话分支。支持 Timeline Branching / Conversation Restore。
/// MVP 仅建立数据地基，不接入 Runtime 和 UI。
struct ConversationBranch: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String

    // MARK: - 分支结构

    /// 从哪条消息分叉。default branch 为 nil。
    var rootMessageID: UUID?
    /// 从哪个 branch 分叉。default branch 为 nil。
    var parentBranchID: UUID?

    // MARK: - 基础时间

    var createdAt: Date
    var updatedAt: Date

    // MARK: - Time Awareness 预留字段

    /// rootMessageID 对应消息的 createdAt。用于表达"这是从某个旧时间点重新展开的分支"。
    var rootMessageCreatedAt: Date?
    /// 父分支创建时间，供后续审计和时间推理。
    var parentBranchCreatedAt: Date?
    /// 当前分支最后一条消息时间。用于计算"距离上次聊天多久"。
    var lastMessageAt: Date?
    /// 上次被切换为 active 的真实时间。用于区分"分支被重新打开"和"分支内最后聊天"。
    var lastActivatedAt: Date?

    // MARK: - 状态

    /// activeBranchID 以 UserDefaults 为准；isActive 作为 UI 和审计冗余标记。
    var isActive: Bool

    // MARK: - Init

    init(
        id: UUID = UUID(),
        title: String,
        rootMessageID: UUID? = nil,
        parentBranchID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        rootMessageCreatedAt: Date? = nil,
        parentBranchCreatedAt: Date? = nil,
        lastMessageAt: Date? = nil,
        lastActivatedAt: Date? = nil,
        isActive: Bool = false
    ) {
        self.id = id
        self.title = title
        self.rootMessageID = rootMessageID
        self.parentBranchID = parentBranchID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.rootMessageCreatedAt = rootMessageCreatedAt
        self.parentBranchCreatedAt = parentBranchCreatedAt
        self.lastMessageAt = lastMessageAt
        self.lastActivatedAt = lastActivatedAt
        self.isActive = isActive
    }
}

// MARK: - Main Branch

extension ConversationBranch {
    /// 固定 mainBranchID，用于默认分支和旧消息兼容。
    static let mainBranchID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    /// 创建默认主线分支。
    static func main(
        now: Date = Date(),
        oldestMessageAt: Date? = nil,
        newestMessageAt: Date? = nil
    ) -> ConversationBranch {
        ConversationBranch(
            id: mainBranchID,
            title: "主线",
            createdAt: oldestMessageAt ?? now,
            updatedAt: newestMessageAt ?? now,
            lastMessageAt: newestMessageAt,
            lastActivatedAt: now,
            isActive: true
        )
    }
}
