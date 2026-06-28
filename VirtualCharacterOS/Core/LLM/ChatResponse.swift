import Foundation

/// App 内部统一回复模型。不绑定特定 Provider 格式。
struct ChatResponse: Equatable {
    var id: String?
    var content: String
    var model: String?
    var createdAt: Date

    init(
        id: String? = nil,
        content: String,
        model: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.model = model
        self.createdAt = createdAt
    }
}
