import Foundation
import SwiftUI

/// Provider Settings 页面的状态管理。API Key 仅走 KeychainStore，
/// 其他配置字段走 @AppStorage。
@Observable
final class ProviderSettingsViewModel {
    // MARK: - 发布属性

    var providerName: String
    var baseURL: String
    var modelName: String
    var apiKeyInput: String = ""
    var hasSavedKey: Bool = false
    var showAlert: Bool = false
    var alertMessage: String = ""

    // MARK: - 内部依赖

    private let keychain: KeychainStore
    private let keychainAccount: String

    // MARK: - 初始化

    init(keychain: KeychainStore = KeychainStore()) {
        self.keychain = keychain

        // 从本地配置加载其他字段（非 Key），用局部变量避免 init 中 self 访问顺序问题
        let defaults = UserDefaults.standard
        let savedProviderName = defaults.string(forKey: Self.providerNameKey) ?? "OpenAI-compatible"
        self.providerName = savedProviderName
        self.baseURL = defaults.string(forKey: Self.baseURLKey) ?? ""
        self.modelName = defaults.string(forKey: Self.modelNameKey) ?? ""
        self.keychainAccount = savedProviderName

        // 检查 Keychain 是否已有 Key
        refreshKeyStatus()
    }

    // MARK: - 用户操作

    func save() {
        // 1. 保存 Key 到 Keychain
        let trimmedKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty {
            do {
                try keychain.saveAPIKey(trimmedKey, providerName: keychainAccount)
            } catch {
                alertMessage = "保存 API Key 失败，请重试。"
                showAlert = true
                return
            }
        }

        // 2. 保存其他字段到 UserDefaults（不含 Key）
        let defaults = UserDefaults.standard
        defaults.set(providerName, forKey: Self.providerNameKey)
        defaults.set(baseURL, forKey: Self.baseURLKey)
        defaults.set(modelName, forKey: Self.modelNameKey)

        // 3. 清空输入框，刷新状态
        apiKeyInput = ""
        refreshKeyStatus()
    }

    func clearAPIKey() {
        do {
            try keychain.deleteAPIKey(providerName: keychainAccount)
            refreshKeyStatus()
        } catch {
            alertMessage = "清除 API Key 失败，请重试。"
            showAlert = true
        }
    }

    // MARK: - 内部

    private func refreshKeyStatus() {
        hasSavedKey = keychain.hasAPIKey(providerName: keychainAccount)
    }

    // MARK: - UserDefaults Keys

    private static let providerNameKey = "ProviderSettings.providerName"
    private static let baseURLKey = "ProviderSettings.baseURL"
    private static let modelNameKey = "ProviderSettings.modelName"
}
