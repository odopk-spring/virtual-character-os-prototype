import Foundation

/// 消息角色
enum MessageRole: String, Codable, CaseIterable {
    case user
    case assistant
    case system
}

/// 消息发送状态
enum MessageStatus: String, Codable, CaseIterable {
    case sending
    case sent
    case failed
}

/// 单条聊天消息。与 UI 绑定，不耦合数据库框架。
struct ChatMessage: Identifiable, Codable, Equatable {
    var id: UUID
    var role: MessageRole
    var content: String
    var createdAt: Date
    var status: MessageStatus
    var errorMessage: String?
    /// 归属分支。旧数据无此字段时自动补 mainBranchID。
    var branchID: UUID

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        createdAt: Date = Date(),
        status: MessageStatus = .sent,
        errorMessage: String? = nil,
        branchID: UUID = ConversationBranch.mainBranchID
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.status = status
        self.errorMessage = errorMessage
        self.branchID = branchID
    }

    // MARK: - Codable (兼容旧 messages.json 无 branchID)

    enum CodingKeys: String, CodingKey {
        case id, role, content, createdAt, status, errorMessage, branchID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(MessageRole.self, forKey: .role)
        content = try container.decode(String.self, forKey: .content)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        status = try container.decode(MessageStatus.self, forKey: .status)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        // 旧数据无 branchID → 默认 mainBranchID
        branchID = try container.decodeIfPresent(UUID.self, forKey: .branchID)
            ?? ConversationBranch.mainBranchID
    }
}
