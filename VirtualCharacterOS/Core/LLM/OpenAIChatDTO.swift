import Foundation

// MARK: - OpenAI-compatible Request DTO

struct OpenAIChatCompletionRequest: Codable {
    var model: String
    var messages: [OpenAIMessage]
    var temperature: Double?
    var max_tokens: Int?

    init(
        model: String,
        messages: [OpenAIMessage],
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.max_tokens = maxTokens
    }

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case max_tokens
    }
}

struct OpenAIMessage: Codable {
    var role: String
    var content: String
}

// MARK: - OpenAI-compatible Response DTO

struct OpenAIChatCompletionResponse: Codable {
    var id: String?
    var model: String?
    var choices: [Choice]

    struct Choice: Codable {
        var index: Int?
        var message: OpenAIMessage?
        var finish_reason: String?
    }
}

// MARK: - Mapping Extensions

extension OpenAIChatCompletionRequest {
    /// 从 App 内部 ChatRequest + ProviderConfig 构建 OpenAI 兼容请求体。
    static func from(
        _ request: ChatRequest,
        config: ProviderConfig
    ) -> OpenAIChatCompletionRequest {
        let messages = request.messages.map { msg in
            OpenAIMessage(role: msg.role.rawValue, content: msg.content)
        }
        return OpenAIChatCompletionRequest(
            model: config.modelName,
            messages: messages,
            temperature: request.temperature,
            maxTokens: request.maxOutputTokens ?? request.maxTokens
        )
    }
}

extension ChatResponse {
    /// 从 OpenAI 兼容回复转换为 App 内部 ChatResponse。
    static func from(_ response: OpenAIChatCompletionResponse) -> ChatResponse {
        let content = response.choices.first?.message?.content ?? ""
        return ChatResponse(
            id: response.id,
            content: content,
            model: response.model
        )
    }
}
