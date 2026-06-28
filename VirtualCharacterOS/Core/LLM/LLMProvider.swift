import Foundation

/// LLM Provider 抽象协议。每个 Provider 实现一种 API 格式。
protocol LLMProvider {
    /// 人类可读的 Provider 标识，如 "OpenAI"、"DeepSeek"。
    var providerName: String { get }

    /// 发送聊天请求并返回统一格式的回复。
    /// - Parameters:
    ///   - request: App 内部 ChatRequest
    ///   - config: Provider 配置（Base URL / Model Name / Keychain 引用）
    /// - Returns: App 内部 ChatResponse
    func send(
        _ request: ChatRequest,
        config: ProviderConfig
    ) async throws -> ChatResponse
}
