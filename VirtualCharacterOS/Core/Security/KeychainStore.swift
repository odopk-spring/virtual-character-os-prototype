import Foundation
import Security

/// Keychain 操作错误。仅包含 OSStatus code，不包含 Key 内容。
enum KeychainError: Error, Equatable {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
    case itemNotFound
    case unexpectedData
}

/// API Key 的 Keychain 存储层。不依赖第三方库，不使用 UserDefaults。
struct KeychainStore {
    private let service: String

    /// 初始化。service 建议使用固定值以确保 App 删除后 Keychain 数据被系统清除。
    init(service: String = "VirtualCharacterOS.APIKeys") {
        self.service = service
    }

    // MARK: - Public API

    /// 保存 API Key。如果已存在同 account 的 Key，先删除再保存。
    func saveAPIKey(_ key: String, providerName: String) throws {
        // 先删除旧值，避免 duplicate item
        try? deleteAPIKey(providerName: providerName)

        guard let data = key.data(using: .utf8) else {
            throw KeychainError.unexpectedData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: providerName,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// 读取 API Key。如果不存在返回 nil。
    func readAPIKey(providerName: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: providerName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let key = String(data: data, encoding: .utf8) else {
                throw KeychainError.unexpectedData
            }
            return key
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.readFailed(status)
        }
    }

    /// 删除 API Key。如果 item 不存在，视为成功（幂等）。
    func deleteAPIKey(providerName: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: providerName
        ]

        let status = SecItemDelete(query as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw KeychainError.deleteFailed(status)
        }
    }

    /// 检查是否已保存 API Key。
    func hasAPIKey(providerName: String) -> Bool {
        return (try? readAPIKey(providerName: providerName)) != nil
    }
}
