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

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        createdAt: Date = Date(),
        status: MessageStatus = .sent,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.status = status
        self.errorMessage = errorMessage
    }
}
