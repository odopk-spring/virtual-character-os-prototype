import Foundation
import SwiftUI

@MainActor
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    let character: CharacterProfile

    private let store: any MessageStore
    private let contextBuilder: ContextBuilder
    private let provider: any LLMProvider

    init(
        store: any MessageStore,
        character: CharacterProfile = .defaultProfile(),
        contextBuilder: ContextBuilder = ContextBuilder(),
        provider: any LLMProvider = OpenAICompatibleProvider()
    ) {
        self.store = store
        self.character = character
        self.contextBuilder = contextBuilder
        self.provider = provider
        loadMessages()
    }

    func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }

        let userMessage = ChatMessage(role: .user, content: trimmed, status: .sent)
        do {
            try store.saveMessage(userMessage)
            messages.append(userMessage)
        } catch {
            errorMessage = "消息保存失败"
            return
        }
        inputText = ""

        let assistantID = UUID()
        let assistantPlaceholder = ChatMessage(
            id: assistantID, role: .assistant, content: "", status: .sending
        )
        do {
            try store.saveMessage(assistantPlaceholder)
            messages.append(assistantPlaceholder)
        } catch {
            errorMessage = "消息保存失败"
            return
        }
        isLoading = true
        errorMessage = nil

        let capturedID = assistantID
        // Swift 6: @MainActor 上下文内直接 await，不需要 Task {}
        Task { @MainActor in
            await callLLM(assistantID: capturedID)
        }
    }

    func loadMessages() {
        do { messages = try store.loadMessages() }
        catch { messages = []; errorMessage = "加载消息失败" }
    }

    // MARK: - LLM Call

    private func callLLM(assistantID: UUID) async {
        do {
            let allMessages = try store.loadMessages()
            let requestMessages = contextBuilder.buildRequestMessages(
                recentMessages: allMessages, character: character
            )
            let config = Self.readConfig()
            let request = ChatRequest(messages: requestMessages, temperature: 0.8, maxTokens: 500)
            let response = try await provider.send(request, config: config)

            let updated = ChatMessage(
                id: assistantID, role: .assistant,
                content: response.content, status: .sent
            )
            try store.updateMessage(updated)
            if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[idx] = updated
            }
        } catch let error as AppError {
            failMessage(id: assistantID, message: error.userFacingMessage)
        } catch {
            failMessage(id: assistantID, message: "发生未知错误，请重试。")
        }
        isLoading = false
    }

    private func failMessage(id: UUID, message: String) {
        var failed = ChatMessage(id: id, role: .assistant, content: "", status: .failed)
        failed.errorMessage = message
        try? store.updateMessage(failed)
        if let idx = messages.firstIndex(where: { $0.id == id }) {
            messages[idx] = failed
        }
        errorMessage = message
    }

    private static func readConfig() -> ProviderConfig {
        let d = UserDefaults.standard
        return ProviderConfig(
            baseURL: d.string(forKey: "ProviderSettings.baseURL") ?? "",
            modelName: d.string(forKey: "ProviderSettings.modelName") ?? "",
            providerName: d.string(forKey: "ProviderSettings.providerName") ?? "OpenAI-compatible",
            apiKeyStoredInKeychain: false
        )
    }
}

// MARK: - Error helper

private extension AppError {
    var userFacingMessage: String {
        switch self {
        case .provider:
            return "模型服务返回错误，请检查配置或稍后再试。"
        default:
            return userMessage
        }
    }
}
