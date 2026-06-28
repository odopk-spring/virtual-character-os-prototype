import Foundation

/// API Provider 配置。不包含 API Key 明文——Key 由 Keychain 管理。
struct ProviderConfig: Identifiable, Codable, Equatable {
    var id: UUID
    var baseURL: String
    var modelName: String
    var providerName: String

    /// 标记 API Key 是否已存入 Keychain。不存储 Key 原文。
    var apiKeyStoredInKeychain: Bool

    init(
        id: UUID = UUID(),
        baseURL: String,
        modelName: String,
        providerName: String,
        apiKeyStoredInKeychain: Bool = false
    ) {
        self.id = id
        self.baseURL = baseURL
        self.modelName = modelName
        self.providerName = providerName
        self.apiKeyStoredInKeychain = apiKeyStoredInKeychain
    }
}

// MARK: - Default Config

extension ProviderConfig {
    /// MVP 0 默认 Provider 配置（DeepSeek 兼容 OpenAI 接口，推荐给新用户）。
    static func defaultConfig() -> ProviderConfig {
        ProviderConfig(
            baseURL: "https://api.deepseek.com/v1",
            modelName: "deepseek-chat",
            providerName: "DeepSeek",
            apiKeyStoredInKeychain: false
        )
    }
}
