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
            let supplement = Self.readCharacterSupplement()
            let memories = Self.readManualMemories()
            let requestMessages = contextBuilder.buildRequestMessages(
                recentMessages: allMessages, character: character,
                characterSupplement: supplement,
                manualMemories: memories
            )
            let config = Self.readConfig()
            let request = ChatRequest(messages: requestMessages, temperature: 0.8, maxTokens: 500)
            let response = try await provider.send(request, config: config)

            let raw = response.content
            let chunks = splitAssistantReply(raw)

            // 第一条 chunk 复用占位消息
            let firstChunk = chunks[0]
            try await Task.sleep(nanoseconds: typingDelayNanoseconds(for: firstChunk))
            var first = ChatMessage(id: assistantID, role: .assistant,
                                     content: firstChunk, status: .sent)
            try store.updateMessage(first)
            if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[idx] = first
            }

            // 后续 chunk 创建新气泡
            for i in 1..<chunks.count {
                let chunk = chunks[i]
                let bubbleID = UUID()
                let bubble = ChatMessage(id: bubbleID, role: .assistant,
                                          content: "", status: .sending)
                try store.saveMessage(bubble)
                messages.append(bubble)

                try await Task.sleep(nanoseconds: bubbleDelayNanoseconds(for: chunk))

                var updated = ChatMessage(id: bubbleID, role: .assistant,
                                           content: chunk, status: .sent)
                try store.updateMessage(updated)
                if let idx = messages.firstIndex(where: { $0.id == bubbleID }) {
                    messages[idx] = updated
                }
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

    /// 根据回复长度计算打字延迟。0.04秒/字，clamp 到 0.6–4.0 秒。
    private func typingDelayNanoseconds(for text: String) -> UInt64 {
        let seconds = min(max(Double(text.count) * 0.04, 0.6), 4.0)
        return UInt64(seconds * 1_000_000_000)
    }

    /// 气泡间延迟。0.03秒/字，clamp 到 0.4–2.0 秒。
    private func bubbleDelayNanoseconds(for text: String) -> UInt64 {
        let seconds = min(max(Double(text.count) * 0.03, 0.4), 2.0)
        return UInt64(seconds * 1_000_000_000)
    }

    /// 将模型回复拆成最多 3 个气泡。短文本不拆分。
    private func splitAssistantReply(_ text: String) -> [String] {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 合并连续换行
        while cleaned.contains("\n\n\n") {
            cleaned = cleaned.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        // 短文本直接返回单气泡
        if cleaned.count <= 40 || !cleaned.contains("\n") {
            return [cleaned]
        }

        // 按空行拆分
        let paragraphs = cleaned
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // 段落数 ≤3 且含有效换行 → 直接返回（最多 3 段）
        if paragraphs.count > 1 && paragraphs.count <= 3 {
            return paragraphs.map { collapseLines($0) }
        }

        // 按换行拆
        let lines = cleaned
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if lines.count <= 3 {
            return lines.map { collapseLines($0) }
        }

        // 折半合并：前一半 → chunk 1，后一半 → chunk 2
        let mid = lines.count / 2
        let first = lines[0..<mid].joined(separator: "\n")
        let second = lines[mid...].joined(separator: "\n")
        return [collapseLines(first), collapseLines(second)]
    }

    /// 去掉文本内部的换行，只保留单行气泡。
    private func collapseLines(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: "")
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

    /// 读取用户补充的角色设定。为空时返回 nil。
    static func readCharacterSupplement() -> String? {
        let raw = UserDefaults.standard.string(forKey: "CharacterSettings.supplement") ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 读取手动记忆。读取失败时降级为空数组，不阻断聊天。
    static func readManualMemories() -> [MemoryItem] {
        guard let store = try? FileMemoryStore() else { return [] }
        return (try? store.loadMemories()) ?? []
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
