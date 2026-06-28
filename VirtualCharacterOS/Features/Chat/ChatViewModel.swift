import Foundation
import SwiftUI

@Observable
final class ChatViewModel {
    // MARK: - 发布属性

    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    let character: CharacterProfile

    // MARK: - 依赖

    private let store: any MessageStore

    // MARK: - 初始化

    init(store: any MessageStore, character: CharacterProfile = .defaultProfile()) {
        self.store = store
        self.character = character
        loadMessages()
    }

    // MARK: - 用户操作

    func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userMessage = ChatMessage(
            role: .user,
            content: trimmed,
            status: .sending
        )
        messages.append(userMessage)
        inputText = ""
        isLoading = true
        errorMessage = nil

        do {
            try store.saveMessage(userMessage)
            // 更新状态为 sent
            var sent = userMessage
            sent.status = .sent
            if let idx = messages.firstIndex(where: { $0.id == userMessage.id }) {
                messages[idx] = sent
            }
            try store.updateMessage(sent)
        } catch {
            var failed = userMessage
            failed.status = .failed
            failed.errorMessage = "保存失败"
            if let idx = messages.firstIndex(where: { $0.id == userMessage.id }) {
                messages[idx] = failed
            }
            errorMessage = "消息保存失败"
            isLoading = false
            return
        }

        // 生成占位回复（明确标记为本地占位，不伪装真实模型回复）
        let placeholder = ChatMessage(
            role: .assistant,
            content: "[本地占位回复] 我看到了。真正的模型回复将在接入 API 后替换此消息。",
            status: .sent
        )
        messages.append(placeholder)

        do {
            try store.saveMessage(placeholder)
        } catch {
            errorMessage = "保存占位回复失败"
        }

        isLoading = false
    }

    func loadMessages() {
        do {
            messages = try store.loadMessages()
        } catch {
            messages = []
            errorMessage = "加载消息失败"
        }
    }
}
