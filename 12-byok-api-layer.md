# 12 — BYOK 与 API 架构

## 12.1 设计原则

1. **用户拥有 API Key**：App 不提供模型服务，用户用自己的 Key
2. **Key 安全第一**：Keychain 存储，永不上传（除非用户授权云端模式）
3. **多 Provider 兼容**：一次配置，适配多种 API
4. **隐私优先**：API 调用直连模型服务商，App 不做代理

## 12.2 Provider Adapter 架构

```swift
// 统一协议
protocol LLMProvider {
    var name: String { get }
    var baseURL: String { get }
    var supportsStreaming: Bool { get }
    var supportsToolCall: Bool { get }
    var supportsImageInput: Bool { get }
    var supportsJSONMode: Bool { get }
    var supportsThinking: Bool { get }
    var defaultModel: String { get }
    var contextWindowSize: Int { get }
    
    func buildRequest(
        messages: [ChatMessage],
        model: String,
        temperature: Double,
        maxTokens: Int,
        stream: Bool
    ) throws -> URLRequest
    
    func adaptPrompt(_ prompt: AssembledContext) -> [ChatMessage]
    func parseResponse(_ data: Data) throws -> ChatResponse
    func parseStreamChunk(_ data: Data) throws -> ChatChunk
}

// 各 Provider 实现
class OpenAIProvider: LLMProvider { ... }
class AnthropicProvider: LLMProvider { ... }
class DeepSeekProvider: LLMProvider { ... }   // OpenAI 兼容但有差异
class GeminiProvider: LLMProvider { ... }
class OpenRouterProvider: LLMProvider { ... }
class CustomProvider: LLMProvider { ... }      // 自定义 Base URL
```

## 12.3 支持的 Provider 详情

| Provider | 兼容性 | 流式 | 图片 | JSON Mode | Thinking | 备注 |
|----------|--------|------|------|-----------|----------|------|
| OpenAI | 原生 | ✅ | ✅ | ✅ | ❌ | GPT-4o, GPT-4.1 等 |
| Anthropic | 原生 | ✅ | ✅ | ❌ | ✅ | Claude 系列，需独立适配 |
| DeepSeek | OpenAI 兼容 | ✅ | ❌ | ✅ | ❌ | 性价比高，推荐给用户 |
| Gemini | 原生 | ✅ | ✅ | ✅ | ✅ | 需独立适配 |
| OpenRouter | OpenAI 兼容 | ✅ | 视模型 | 视模型 | ❌ | 统一网关 |
| 自定义 | OpenAI 兼容 | 视服务 | 视服务 | 视服务 | ❌ | 用户自设 Base URL |

### 用户推荐策略（MVP 阶段的建议文案）

```
推荐模型选择：

💰 性价比首选：DeepSeek V3
   - 成本极低（约 ¥0.001/千token）
   - 中文优秀
   - 适合日常聊天

🎯 最佳体验：Claude (Anthropic)
   - 真实感表现最佳
   - 更少"AI 感"
   - 适合深度对话

⚡ 稳定可靠：GPT-4o (OpenAI)
   - 生态最成熟
   - 速度快
   - 适合高频使用
```

## 12.4 Prompt 适配（关键）

不同模型对 system prompt 的处理不同，需要适配：

```swift
// Anthropic: system 是独立参数
func adaptForAnthropic(_ context: AssembledContext) -> AnthropicRequest {
    return AnthropicRequest(
        system: buildSystemString(context),  // 所有 system 层面的指令
        messages: context.recentConversation, // 仅对话
        ...
    )
}

// OpenAI/DeepSeek: system 是 messages 中的一条
func adaptForOpenAI(_ context: AssembledContext) -> [ChatMessage] {
    return [
        ChatMessage(role: "system", content: buildSystemString(context)),
        // ... 然后是最近的对话消息
    ] + context.recentConversation
}

// 差异处理：
// - Anthropic 不支持 system 中的 "name" 字段
// - OpenAI 的 system 和 user 在 context window 中权重不同
// - DeepSeek 对长 system prompt 可能效果下降
```

## 12.5 API Key 存储（安全）

```swift
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    func saveAPIKey(provider: String, key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.yourapp.byok",
            kSecAttrAccount as String: provider,
            kSecValueData as String: key.data(using: .utf8)!
        ]
        SecItemDelete(query as CFDictionary) // 删除旧的
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }
    
    func getAPIKey(provider: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.yourapp.byok",
            kSecAttrAccount as String: provider,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.readFailed(status: status)
        }
        return key
    }
    
    func deleteAPIKey(provider: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.yourapp.byok",
            kSecAttrAccount as String: provider
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }
}

// ❌ 绝对禁止的做法
// UserDefaults.standard.set(apiKey, forKey: "api_key")  // 明文存储，不安全
```

## 12.6 流式输出

```swift
func streamChat(
    provider: LLMProvider,
    request: URLRequest
) -> AsyncThrowingStream<ChatChunk, Error> {
    return AsyncThrowingStream { continuation in
        Task {
            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                // 检查 HTTP 状态
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode != 200 {
                    throw APIError.httpError(httpResponse.statusCode)
                }
                
                var buffer = ""
                for try await line in bytes.lines {
                    // SSE 格式：data: {...}
                    guard line.hasPrefix("data: ") else { continue }
                    let jsonStr = String(line.dropFirst(6))
                    if jsonStr == "[DONE]" { break }
                    
                    if let data = jsonStr.data(using: .utf8),
                       let chunk = try? provider.parseStreamChunk(data) {
                        continuation.yield(chunk)
                    }
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}
```

## 12.7 错误处理与重试

```swift
enum APIError: Error {
    case networkError(Error)
    case httpError(Int)
    case rateLimited(retryAfter: TimeInterval?)
    case authError                    // 401 - API Key 无效
    case contextOverflow             // 上下文超限
    case billingIssue                // 余额不足
    case serverError(Int)            // 5xx
    case decodingError(Error)
    case timeout
}

func handleError(_ error: APIError, retryCount: Int) -> RetryStrategy {
    switch error {
    case .networkError:
        return retryCount < 2 ? .retry(after: 1) : .fail
    case .rateLimited(let wait):
        return retryCount < 1 ? .retry(after: wait ?? 5) : .fail
    case .serverError:
        return retryCount < 1 ? .retry(after: 3) : .fail
    case .authError, .billingIssue:
        return .fail  // 不重试，提示用户检查 API Key
    case .contextOverflow:
        return .fail  // 不重试，缩小 context 后重新请求
    case .timeout:
        return retryCount < 1 ? .retry(after: 2) : .fail
    default:
        return .fail
    }
}
```

## 12.8 隐私说明（用户界面）

```
API Key 与隐私

🔒 本地模式（默认）
你的 API Key 仅存储在设备的 Keychain 中。
调用模型 API 时，App 直接从你的设备连接模型服务商。
你的 API Key 不会上传到我们的任何服务器。

☁️ 云端生活模式（可选）
如果你想使用稳定的主动消息功能，需要将 API Key 
加密上传到我们的服务器。我们会使用端到端加密，
服务器无法解密你的 Key。只有你的设备可以解密。
你随时可以撤销授权并删除服务器上的数据。

📊 API 调用统计
App 会显示你的 API 调用次数和预估费用。
这些数据仅在本地，我们不会收集。
```

## 12.9 Token 统计与成本预估

```swift
struct TokenUsage: Codable {
    var date: Date
    var provider: String
    var model: String
    var promptTokens: Int
    var completionTokens: Int
    var totalTokens: Int
    var estimatedCost: Double  // 人民币
}

// 在设置页面向用户展示
// 本月 API 调用：1,245 次
// 本月 Token 消耗：约 350,000
// 本月预估费用：约 ¥0.42（以 DeepSeek V3 为例）
```
