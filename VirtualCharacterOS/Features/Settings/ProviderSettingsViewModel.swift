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
    var characterSupplement: String = ""
    var avatarImage: UIImage?
    var allowsNarrationBlocks: Bool
    var replyLengthLevel: ContextBuilder.ReplyLengthLevel
    var voiceEnabled: Bool
    var voiceEngine: VoiceEngine
    var voiceServerBaseURL: String
    var voiceID: String
    var voiceSpeed: Double
    var voiceReadsNarration: Bool

    // MARK: - 内部依赖

    private let keychain: KeychainStore
    private var keychainAccount: String

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
        self.characterSupplement = defaults.string(forKey: Self.characterSupplementKey) ?? ""
        self.avatarImage = AvatarStore.loadImage()
        self.allowsNarrationBlocks = defaults.bool(forKey: ChatNarrationFormatter.settingsKey)
        let levelRaw = defaults.string(forKey: Self.replyLengthLevelKey) ?? ""
        self.replyLengthLevel = ContextBuilder.ReplyLengthLevel(rawValue: levelRaw) ?? .normal
        let voiceSettings = VoiceSettings.load(defaults: defaults)
        self.voiceEnabled = voiceSettings.isEnabled
        self.voiceEngine = voiceSettings.engine
        self.voiceServerBaseURL = voiceSettings.serverBaseURLString
        self.voiceID = voiceSettings.voiceID
        self.voiceSpeed = voiceSettings.speed
        self.voiceReadsNarration = voiceSettings.readsNarration

        // 检查 Keychain 是否已有 Key
        refreshKeyStatus()
    }

    // MARK: - 用户操作

    func save() {
        // 0. 同步 Keychain account（用户可能改了 providerName）
        keychainAccount = providerName

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

    func saveCharacterSupplement() {
        let trimmed = characterSupplement.trimmingCharacters(in: .whitespacesAndNewlines)
        let clipped = String(trimmed.prefix(1000))
        UserDefaults.standard.set(clipped, forKey: Self.characterSupplementKey)
        characterSupplement = clipped
    }

    func saveChatDisplaySettings() {
        UserDefaults.standard.set(allowsNarrationBlocks, forKey: ChatNarrationFormatter.settingsKey)
        UserDefaults.standard.set(replyLengthLevel.rawValue, forKey: Self.replyLengthLevelKey)
    }

    func saveVoiceSettings() {
        VoiceSettings(
            isEnabled: voiceEnabled,
            engine: voiceEngine,
            serverBaseURLString: voiceServerBaseURL,
            voiceID: voiceID,
            speed: voiceSpeed,
            readsNarration: voiceReadsNarration
        ).save()
    }

    // MARK: - 角色头像

    var hasCustomAvatar: Bool { avatarImage != nil }

    /// 从 PhotosPicker 的 Data 保存头像。
    func saveAvatar(from imageData: Data) {
        guard let image = UIImage(data: imageData),
              let jpegData = AvatarStore.compressImage(image) else {
            alertMessage = "无法处理该图片，请重试。"
            showAlert = true
            return
        }
        do {
            try AvatarStore.save(jpegData)
            UserDefaults.standard.set("character-avatar.jpg", forKey: Self.avatarFilenameKey)
            avatarImage = UIImage(data: jpegData)
        } catch {
            alertMessage = "保存头像失败，请重试。"
            showAlert = true
        }
    }

    func deleteAvatar() {
        do {
            try AvatarStore.delete()
            UserDefaults.standard.removeObject(forKey: Self.avatarFilenameKey)
            avatarImage = nil
        } catch {
            alertMessage = "清除头像失败，请重试。"
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
    private static let characterSupplementKey = "CharacterSettings.supplement"
    private static let avatarFilenameKey = "CharacterSettings.avatarFilename"
    private static let replyLengthLevelKey = "ChatSettings.replyLengthLevel"
}
