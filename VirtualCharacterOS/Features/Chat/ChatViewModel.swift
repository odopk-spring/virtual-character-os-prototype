import Foundation
import SwiftUI

@MainActor
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    var character: CharacterProfile

    private let store: any MessageStore
    private let profileStore: any CharacterProfileStore
    private let branchStore: any BranchStore
    private let contextBuilder: ContextBuilder
    private let provider: any LLMProvider
    private(set) var activeBranchID: UUID

    init(
        store: any MessageStore,
        profileStore: any CharacterProfileStore = try! FileCharacterProfileStore(),
        branchStore: any BranchStore = try! FileBranchStore(),
        contextBuilder: ContextBuilder = ContextBuilder(),
        provider: any LLMProvider = OpenAICompatibleProvider()
    ) {
        self.store = store
        self.profileStore = profileStore
        self.branchStore = branchStore
        self.character = Self.readCharacterProfile(store: profileStore)
        self.contextBuilder = contextBuilder
        self.provider = provider
        self.activeBranchID = ActiveBranchStore.getActiveBranchID()

        // 确保迁移完成（幂等）
        if let msgStore = store as? FileMessageStore,
           let brStore = branchStore as? FileBranchStore {
            try? BranchMigration.migrateIfNeeded(
                messageStore: msgStore,
                branchStore: brStore
            )
        }

        loadMessages()
        touchBranchActivation()
    }

    func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }

        let userMessage = ChatMessage(
            role: .user, content: trimmed, status: .sent,
            branchID: activeBranchID
        )
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
            id: assistantID, role: .assistant, content: "", status: .sending,
            branchID: activeBranchID
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
        let capturedBranchID = activeBranchID
        Task { @MainActor in
            await callLLM(assistantID: capturedID, branchID: capturedBranchID)
        }
    }

    func loadMessages() {
        do { messages = try loadVisibleMessagesForActiveBranch() }
        catch { messages = []; errorMessage = "加载消息失败" }
    }

    func reloadMessages() {
        loadMessages()
    }

    /// 重新加载角色档案（从编辑器返回时调用）。
    func reloadCharacterProfile() {
        character = Self.readCharacterProfile(store: profileStore)
    }

    // MARK: - Branch Operations

    /// 从指定消息创建新分支并切换。
    func createBranch(from message: ChatMessage) {
        let now = Date()

        // 读取当前分支信息
        let allBranches = (try? branchStore.loadBranches()) ?? []
        let parentBranch = allBranches.first(where: { $0.id == activeBranchID })

        // 将旧 active branch 设为非 active
        if let oldIdx = allBranches.firstIndex(where: { $0.id == activeBranchID }) {
            var old = allBranches[oldIdx]
            old.isActive = false
            try? branchStore.updateBranch(old)
        }

        // 创建新分支
        let dateStr = DateFormatter()
        dateStr.locale = Locale(identifier: "zh_CN")
        dateStr.dateFormat = "MM-dd HH:mm"
        let newBranch = ConversationBranch(
            id: UUID(),
            title: "分支 \(dateStr.string(from: now))",
            rootMessageID: message.id,
            parentBranchID: activeBranchID,
            createdAt: now,
            updatedAt: now,
            rootMessageCreatedAt: message.createdAt,
            parentBranchCreatedAt: parentBranch?.createdAt ?? now,
            lastMessageAt: message.createdAt,
            lastActivatedAt: now,
            isActive: true
        )

        do {
            try branchStore.saveBranch(newBranch)
        } catch {
            errorMessage = "创建分支失败"
            return
        }

        // 切换 active branch
        activeBranchID = newBranch.id
        ActiveBranchStore.setActiveBranchID(newBranch.id)

        // 重新加载可见消息
        loadMessages()
    }

    // MARK: - Branch Switcher

    /// 所有分支列表。
    var allBranches: [ConversationBranch] {
        (try? branchStore.loadBranches()) ?? []
    }

    /// 被其他分支作为 parentBranchID 引用的分支 ID 集合。
    var childBranchIDs: Set<UUID> {
        let branches = allBranches
        return Set(branches.compactMap { $0.parentBranchID })
    }

    /// 各分支的可见消息数（近似）。
    var branchMessageCounts: [UUID: Int] {
        let branches = allBranches
        let allMessages = (try? store.loadMessages()) ?? []
        var counts: [UUID: Int] = [:]
        for branch in branches {
            counts[branch.id] = BranchMessageResolver.visibleMessages(
                activeBranch: branch,
                allBranches: branches,
                allMessages: allMessages
            ).count
        }
        return counts
    }

    /// 切换到指定分支。
    func switchBranch(to branchID: UUID) {
        guard branchID != activeBranchID else { return }
        let now = Date()

        var branches = (try? branchStore.loadBranches()) ?? []
        // 旧 active → inactive
        if let oldIdx = branches.firstIndex(where: { $0.id == activeBranchID }) {
            branches[oldIdx].isActive = false
            try? branchStore.updateBranch(branches[oldIdx])
        }
        // 新 → active + touch
        if let newIdx = branches.firstIndex(where: { $0.id == branchID }) {
            branches[newIdx].isActive = true
            branches[newIdx].lastActivatedAt = now
            try? branchStore.updateBranch(branches[newIdx])
        }
        activeBranchID = branchID
        ActiveBranchStore.setActiveBranchID(branchID)
        loadMessages()
    }

    /// 重命名分支。
    func renameBranch(id: UUID, title: String) {
        let trimmed = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard !trimmed.isEmpty else { return }
        var branches = (try? branchStore.loadBranches()) ?? []
        if let idx = branches.firstIndex(where: { $0.id == id }) {
            branches[idx].title = trimmed
            branches[idx].updatedAt = Date()
            try? branchStore.updateBranch(branches[idx])
        }
    }

    /// 删除分支（不删 messages.json 消息）。
    func deleteBranch(id: UUID) {
        // 不删 active branch / main branch
        guard id != activeBranchID else { return }
        guard id != ConversationBranch.mainBranchID else { return }
        // 不删被引用的 parent branch
        guard !childBranchIDs.contains(id) else { return }
        try? branchStore.deleteBranch(id: id)
    }

    // MARK: - LLM Call

    private func callLLM(assistantID: UUID, branchID: UUID) async {
        do {
            let branchMessages = try loadVisibleMessagesForActiveBranch()
            let supplement = Self.readCharacterSupplement()
            let memories = Self.readManualMemories()
            let worldBook = Self.readWorldBookEntries()
            let requestMessages = contextBuilder.buildRequestMessages(
                recentMessages: branchMessages, character: character,
                characterSupplement: supplement,
                manualMemories: memories,
                worldBookEntries: worldBook
            )

            #if DEBUG
            let summary = contextBuilder.buildContextBudgetSummary(
                recentMessages: branchMessages,
                manualMemories: memories,
                characterSupplement: supplement,
                worldBookEntries: worldBook
            )
            print("[ContextBudget] msgs=\(summary.recentMessageCount) mems=\(summary.manualMemoryInjectedCount)/\(summary.manualMemoryInputCount) wb=\(summary.worldBookInjectedCount)/\(summary.worldBookInputCount) wbChars=\(summary.worldBookSectionChars) sup=\(summary.characterSupplementChars) memChars=\(summary.memorySectionChars) prompt=\(summary.systemPromptTotalChars)")
            #endif

            let config = Self.readConfig()
            let request = ChatRequest(messages: requestMessages, temperature: 0.8, maxTokens: 500)
            let response = try await provider.send(request, config: config)

            let raw = response.content
            let chunks = splitAssistantReply(raw)

            // 第一条 chunk 复用占位消息（带 branchID 保护）
            let firstChunk = chunks[0]
            try await Task.sleep(nanoseconds: typingDelayNanoseconds(for: firstChunk))
            var first = ChatMessage(id: assistantID, role: .assistant,
                                     content: firstChunk, status: .sent,
                                     branchID: branchID)
            try store.updateMessage(first, branchID: branchID)
            if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[idx] = first
            }

            // 后续 chunk 创建新气泡（带 branchID）
            for i in 1..<chunks.count {
                let chunk = chunks[i]
                let bubbleID = UUID()
                let bubble = ChatMessage(id: bubbleID, role: .assistant,
                                          content: "", status: .sending,
                                          branchID: branchID)
                try store.saveMessage(bubble)
                messages.append(bubble)

                try await Task.sleep(nanoseconds: bubbleDelayNanoseconds(for: chunk))

                var updated = ChatMessage(id: bubbleID, role: .assistant,
                                           content: chunk, status: .sent,
                                           branchID: branchID)
                try store.updateMessage(updated, branchID: branchID)
                if let idx = messages.firstIndex(where: { $0.id == bubbleID }) {
                    messages[idx] = updated
                }
            }

            // 成功 → 更新 active branch 时间锚点
            let now = Date()
            updateBranchTimestamps(lastMessageAt: now)
        } catch let error as AppError {
            failMessage(id: assistantID, message: error.userFacingMessage, branchID: branchID)
        } catch {
            failMessage(id: assistantID, message: "发生未知错误，请重试。", branchID: branchID)
        }
        isLoading = false
    }

    private func failMessage(id: UUID, message: String, branchID: UUID) {
        var failed = ChatMessage(id: id, role: .assistant, content: "", status: .failed,
                                  branchID: branchID)
        failed.errorMessage = message
        try? store.updateMessage(failed, branchID: branchID)
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

    /// 读取角色档案。失败回退默认角色。
    static func readCharacterProfile(store: any CharacterProfileStore) -> CharacterProfile {
        return (try? store.loadProfile()) ?? CharacterProfile.defaultProfile()
    }

    /// 读取手动记忆。读取失败时降级为空数组，不阻断聊天。
    static func readManualMemories() -> [MemoryItem] {
        guard let store = try? FileMemoryStore() else { return [] }
        return (try? store.loadMemories()) ?? []
    }

    /// 读取世界书条目。读取失败降级为空数组。
    static func readWorldBookEntries() -> [WorldBookEntry] {
        guard let store = try? FileWorldBookStore() else { return [] }
        return (try? store.loadEntries()) ?? []
    }

    /// 读取 active branch 可见消息（含继承历史 + 自有消息）。
    private func loadVisibleMessagesForActiveBranch() throws -> [ChatMessage] {
        let branches = (try? branchStore.loadBranches()) ?? []
        let activeBranch = branches.first(where: { $0.id == activeBranchID })
            ?? ConversationBranch.main(now: Date())

        let allMessages = try store.loadMessages()
        return BranchMessageResolver.visibleMessages(
            activeBranch: activeBranch,
            allBranches: branches,
            allMessages: allMessages
        )
    }

    // MARK: - Branch Timestamps

    /// 分支被激活/加载时更新 lastActivatedAt。
    private func touchBranchActivation() {
        let now = Date()
        do {
            var branches = try branchStore.loadBranches()
            if let idx = branches.firstIndex(where: { $0.id == activeBranchID }) {
                branches[idx].lastActivatedAt = now
                try branchStore.updateBranch(branches[idx])
            }
        } catch {
            // 非阻断：时间锚点更新失败不影响聊天
        }
    }

    /// 新消息成功后更新 updatedAt 和 lastMessageAt。
    private func updateBranchTimestamps(lastMessageAt: Date) {
        do {
            var branches = try branchStore.loadBranches()
            if let idx = branches.firstIndex(where: { $0.id == activeBranchID }) {
                branches[idx].updatedAt = lastMessageAt
                branches[idx].lastMessageAt = lastMessageAt
                try branchStore.updateBranch(branches[idx])
            }
        } catch {
            // 非阻断
        }
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
