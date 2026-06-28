import Foundation

/// OpenAI-compatible 非流式 Provider。实现 LLMProvider 协议。
/// 仅 MVP 0 非流式请求，不做 streaming / retry / tool calling。
struct OpenAICompatibleProvider: LLMProvider {
    let providerName: String
    private let keychain: KeychainStore
    private let session: URLSession

    init(
        providerName: String = "OpenAI-compatible",
        keychain: KeychainStore = KeychainStore(),
        session: URLSession = .shared
    ) {
        self.providerName = providerName
        self.keychain = keychain
        self.session = session
    }

    // MARK: - LLMProvider

    func send(_ request: ChatRequest, config: ProviderConfig) async throws -> ChatResponse {
        // 1. 验证配置
        guard !config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.invalidBaseURL("Base URL 为空")
        }
        guard !config.modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.providerNotConfigured
        }

        // 2. 读取 API Key
        guard let apiKey = try keychain.readAPIKey(providerName: config.providerName),
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.missingAPIKey
        }

        // 3. 构建 URL
        let url = try makeChatCompletionsURL(baseURL: config.baseURL)

        // 4. 构建请求体
        let body = OpenAIChatCompletionRequest.from(request, config: config)
        let bodyData = try JSONEncoder().encode(body)

        // 5. 构建 HTTP 请求
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = bodyData
        urlRequest.timeoutInterval = 30

        // 6. 发送请求
        let (data, response) = try await session.data(for: urlRequest)

        // 7. 检查 HTTP 状态
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.network("无效的 HTTP 响应")
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw AppError.provider("API Key 无效 (401)")
        case 429:
            throw AppError.provider("请求过于频繁，请稍后重试 (429)")
        case 500...599:
            throw AppError.provider("服务器错误 (\(httpResponse.statusCode))")
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            let preview = String(body.prefix(200))
            throw AppError.provider("HTTP \(httpResponse.statusCode): \(preview)")
        }

        // 8. 解码
        do {
            let openAIResponse = try JSONDecoder().decode(
                OpenAIChatCompletionResponse.self, from: data
            )
            return ChatResponse.from(openAIResponse)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? ""
            let preview = String(body.prefix(200))
            throw AppError.decoding("\(preview)")
        }
    }

    // MARK: - Private

    /// 拼接 chat/completions 路径。如果 baseURL 已以 /chat/completions 结尾则不重复拼接。
    private func makeChatCompletionsURL(baseURL: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let parsed = URL(string: trimmed) else {
            throw AppError.invalidBaseURL("无法解析 Base URL: \(trimmed)")
        }

        var path = parsed.absoluteString

        // 如果已以 /chat/completions 结尾，直接使用
        if path.hasSuffix("/chat/completions") {
            guard let url = URL(string: path) else {
                throw AppError.invalidBaseURL("URL 构造失败")
            }
            return url
        }

        // 去掉末尾多余斜杠后拼接
        if !path.hasSuffix("/") {
            path += "/"
        }
        path += "chat/completions"

        guard let url = URL(string: path) else {
            throw AppError.invalidBaseURL("URL 拼接失败: \(path)")
        }
        return url
    }
}
