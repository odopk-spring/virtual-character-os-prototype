import Foundation

/// 单条请求消息。复用 ChatMessage 中的 MessageRole。
struct ChatRequestMessage: Codable, Equatable {
    var role: MessageRole
    var content: String
}

/// App 内部调用模型时的请求。不绑定 OpenAI 或其他特定格式。
struct ChatRequest: Equatable {
    var messages: [ChatRequestMessage]
    var temperature: Double?
    var maxOutputTokens: Int?
    var maxTokens: Int?

    init(
        messages: [ChatRequestMessage],
        temperature: Double? = nil,
        maxOutputTokens: Int? = nil,
        maxTokens: Int? = nil
    ) {
        self.messages = messages
        self.temperature = temperature
        self.maxOutputTokens = maxOutputTokens
        self.maxTokens = maxTokens
    }
}
