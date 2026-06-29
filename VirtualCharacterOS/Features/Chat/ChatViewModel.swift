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
    var isTypingIndicatorVisible: Bool {
        isLoading && typingIndicatorBranchID == activeBranchID
    }

    var isSelectionMode: Bool = false
    var selectedMessageIDs: Set<UUID> = []

    private let store: any MessageStore
    private let profileStore: any CharacterProfileStore
    private let branchStore: any BranchStore
    private let hiddenStore: any HiddenMessageStore
    private let contextBuilder: ContextBuilder
    private let provider: any LLMProvider
    private(set) var activeBranchID: UUID
    private var typingIndicatorBranchID: UUID?

    init(
        store: any MessageStore,
        profileStore: any CharacterProfileStore = try! FileCharacterProfileStore(),
        branchStore: any BranchStore = try! FileBranchStore(),
        hiddenStore: any HiddenMessageStore = try! FileHiddenMessageStore(),
        contextBuilder: ContextBuilder = ContextBuilder(),
        provider: any LLMProvider = OpenAICompatibleProvider()
    ) {
        self.store = store
        self.profileStore = profileStore
        self.branchStore = branchStore
        self.hiddenStore = hiddenStore
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
        typingIndicatorBranchID = activeBranchID
        errorMessage = nil

        let capturedID = assistantID
        let capturedBranchID = activeBranchID
        Task { @MainActor in
            await callLLM(assistantID: capturedID, branchID: capturedBranchID)
        }
    }

    func loadMessages() {
        do {
            messages = try filteredVisibleMessages(for: activeBranchID)
        } catch {
            messages = []; errorMessage = "加载消息失败"
        }
    }

    func reloadMessages() {
        loadMessages()
    }

    // MARK: - Selection & Hide

    func enterSelectionMode(from messageID: UUID) {
        guard !isSelectionMode else { return }
        isSelectionMode = true
        selectedMessageIDs = [messageID]
    }

    func exitSelectionMode() {
        isSelectionMode = false
        selectedMessageIDs = []
    }

    func toggleMessageSelection(_ id: UUID) {
        guard isSelectionMode else { return }
        if selectedMessageIDs.contains(id) {
            selectedMessageIDs.remove(id)
        } else {
            selectedMessageIDs.insert(id)
        }
    }

    func hideSelectedMessages() {
        let toHide = selectedMessageIDs.filter { id in
            guard let msg = messages.first(where: { $0.id == id }) else { return false }
            return msg.status == .sent
        }
        guard !toHide.isEmpty else {
            exitSelectionMode()
            return
        }
        do {
            try hiddenStore.hideMessages(Set(toHide), branchID: activeBranchID)
        } catch {
            errorMessage = "隐藏失败，请重试。"
            return
        }
        let hiddenSet = Set(toHide)
        messages.removeAll(where: { hiddenSet.contains($0.id) })
        exitSelectionMode()
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

        // 创建新分支（命名规则：分支·父分支名称）
        let parentTitle = parentBranch?.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseTitle = "分支·\(parentTitle?.isEmpty == false ? parentTitle! : "主线")"
        let branchTitle = Self.makeUniqueBranchTitle(base: baseTitle, existing: allBranches)

        let newBranch = ConversationBranch(
            id: UUID(),
            title: branchTitle,
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

        // Fork-time hidden inheritance: 子分支继承父分支中属于继承历史范围的 hidden IDs
        inheritHiddenStateForChild(childBranchID: newBranch.id, parentBranchID: activeBranchID, rootMessageCreatedAt: message.createdAt)

        // 切换 active branch
        activeBranchID = newBranch.id
        ActiveBranchStore.setActiveBranchID(newBranch.id)

        // 重新加载可见消息
        loadMessages()
    }

    /// 子分支继承父分支在 fork 时刻、且属于子分支可见历史范围的 hidden IDs。
    private func inheritHiddenStateForChild(childBranchID: UUID, parentBranchID: UUID, rootMessageCreatedAt: Date) {
        guard let parentHiddenIDs = try? hiddenStore.loadHiddenMessageIDs(branchID: parentBranchID),
              !parentHiddenIDs.isEmpty else { return }

        // 只继承 rootMessageCreatedAt 及之前的父分支消息（子分支可见历史范围）
        let allMessages = (try? store.loadMessages()) ?? []
        let inheritableIDs = Set(allMessages
            .filter { $0.branchID == parentBranchID && $0.createdAt <= rootMessageCreatedAt }
            .map { $0.id })

        let childHiddenIDs = parentHiddenIDs.intersection(inheritableIDs)
        guard !childHiddenIDs.isEmpty else { return }
        try? hiddenStore.hideMessages(childHiddenIDs, branchID: childBranchID)
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
            let branchMessages = try filteredVisibleMessages(for: branchID)
            let supplement = Self.readCharacterSupplement()
            let memories = Self.readManualMemories()
            let worldBook = Self.readWorldBookEntries()
            let allowsNarrationBlocks = Self.readAllowsNarrationBlocks()
            let replySignal = contextBuilder.replySignal(
                for: branchMessages.last(where: { $0.role == .user && $0.status == .sent })
            )
            let requestMessages = contextBuilder.buildRequestMessages(
                recentMessages: branchMessages, character: character,
                characterSupplement: supplement,
                manualMemories: memories,
                worldBookEntries: worldBook,
                allowsNarrationBlocks: allowsNarrationBlocks
            )

            #if DEBUG
            let summary = contextBuilder.buildContextBudgetSummary(
                recentMessages: branchMessages,
                manualMemories: memories,
                characterSupplement: supplement,
                worldBookEntries: worldBook
            )
            print("[ContextBudget] msgs=\(summary.recentMessageCount) mems=\(summary.manualMemoryInjectedCount)/\(summary.manualMemoryInputCount) wbRules=\(summary.worldBookRuleCount) wbTrig=\(summary.worldBookTriggeredCount) wb=\(summary.worldBookInjectedCount)/\(summary.worldBookInputCount) wbChars=\(summary.worldBookSectionChars) sup=\(summary.characterSupplementChars) memChars=\(summary.memorySectionChars) signal=\(summary.replySignal.rawValue) prompt=\(summary.systemPromptTotalChars)")
            #endif

            let config = Self.readConfig()
            let request = ChatRequest(messages: requestMessages, temperature: 0.8, maxTokens: 500)
            let response = try await provider.send(request, config: config)

            let raw = response.content
            let chunks = splitAssistantReply(
                raw,
                allowsNarrationBlocks: allowsNarrationBlocks,
                replySignal: replySignal
            )

            // 第一条 chunk 复用占位消息（带 branchID 保护）
            let firstChunk = chunks[0]
            try await Task.sleep(nanoseconds: assistantBubbleDelay(for: firstChunk, index: 0, total: chunks.count))
            let first = ChatMessage(id: assistantID, role: .assistant,
                                    content: firstChunk, status: .sent,
                                    branchID: branchID)
            try store.updateMessage(first, branchID: branchID)
            if activeBranchID == branchID,
               let idx = messages.firstIndex(where: { $0.id == assistantID }) {
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
                if activeBranchID == branchID {
                    messages.append(bubble)
                }

                try await Task.sleep(nanoseconds: assistantBubbleDelay(for: chunk, index: i, total: chunks.count))

                let updated = ChatMessage(id: bubbleID, role: .assistant,
                                          content: chunk, status: .sent,
                                          branchID: branchID)
                try store.updateMessage(updated, branchID: branchID)
                if activeBranchID == branchID,
                   let idx = messages.firstIndex(where: { $0.id == bubbleID }) {
                    messages[idx] = updated
                }
            }

            try await Task.sleep(nanoseconds: finalTypingIndicatorDelayNanoseconds())

            // 成功 → 更新 active branch 时间锚点
            let now = Date()
            updateBranchTimestamps(branchID: branchID, lastMessageAt: now)
        } catch let error as AppError {
            failMessage(id: assistantID, message: error.userFacingMessage, branchID: branchID)
        } catch {
            failMessage(id: assistantID, message: "发生未知错误，请重试。", branchID: branchID)
        }
        isLoading = false
        typingIndicatorBranchID = nil
    }

    private func failMessage(id: UUID, message: String, branchID: UUID) {
        var failed = ChatMessage(id: id, role: .assistant, content: "", status: .failed,
                                  branchID: branchID)
        failed.errorMessage = message
        try? store.updateMessage(failed, branchID: branchID)
        if activeBranchID == branchID,
           let idx = messages.firstIndex(where: { $0.id == id }) {
            messages[idx] = failed
            errorMessage = message
        }
    }

    /// 分气泡投放延迟：首条带思考停顿，后续按文本长度模拟更接近真人的输入节奏。
    private func assistantBubbleDelay(for text: String, index: Int, total: Int) -> UInt64 {
        let base = index == 0 ? 0.8 : 0.9
        let lengthCap = index == 0 ? 1.4 : 1.9
        let totalPadding = total == 1 ? 0.0 : min(Double(total - 1) * 0.08, 0.24)
        let lengthFactor = min(Double(text.count) * 0.035 + totalPadding, lengthCap)
        let maxSeconds = index == 0 ? 2.2 : 2.8
        let seconds = min(max(base + lengthFactor, 0.6), maxSeconds)
        return UInt64(seconds * 1_000_000_000)
    }

    private func finalTypingIndicatorDelayNanoseconds() -> UInt64 {
        UInt64(0.22 * 1_000_000_000)
    }

    /// 将模型回复拆成少量气泡；不强制多气泡，优先保留自然语义边界。
    private func splitAssistantReply(
        _ text: String,
        allowsNarrationBlocks: Bool,
        replySignal: ContextBuilder.ReplySignalStrength
    ) -> [String] {
        let prepared = allowsNarrationBlocks
            ? text
            : ChatNarrationFormatter.removingNarrationMarkup(from: text)
        let cleaned = normalizeAssistantReply(prepared)
        guard !cleaned.isEmpty else { return [cleaned] }

        let narrationAwareSegments = allowsNarrationBlocks
            ? ChatNarrationFormatter.splitNarrationSegments(cleaned)
            : [cleaned]
        let newlineSegments = narrationAwareSegments.flatMap { segment in
            ChatNarrationFormatter.narrationText(from: segment) == nil
                ? splitByNewlineBlocks(segment)
                : [segment]
        }
        let semanticSegments = newlineSegments.flatMap { segment in
            ChatNarrationFormatter.narrationText(from: segment) == nil
                ? splitBySemanticBreakpoints(segment)
                : [segment]
        }
        let sentenceSegments = semanticSegments.flatMap { segment in
            ChatNarrationFormatter.narrationText(from: segment) == nil
                ? splitLongSegmentBySentencePunctuation(segment)
                : [segment]
        }
        let merged = mergeTinyReplyFragments(sentenceSegments)

        // 旁白不计入聊天气泡配额，单独限制
        var chatSegments: [String] = []
        var narrationSegments: [String] = []
        for seg in merged {
            if ChatNarrationFormatter.narrationText(from: seg) != nil {
                narrationSegments.append(seg)
            } else {
                chatSegments.append(seg)
            }
        }

        let maxChat = maxBubbleCount(for: replySignal)
        let maxNarr = 4
        let limitedChat = limitReplySegments(chatSegments, maxCount: maxChat)
        let limitedNarr = limitReplySegments(narrationSegments, maxCount: maxNarr)

        // 按原始顺序交错合并
        var result: [String] = []
        var ci = 0, ni = 0
        for seg in merged {
            if ChatNarrationFormatter.narrationText(from: seg) != nil {
                if ni < limitedNarr.count { result.append(limitedNarr[ni]); ni += 1 }
            } else {
                if ci < limitedChat.count { result.append(limitedChat[ci]); ci += 1 }
            }
        }

        let questionSuppressed = dropGenericTrailingQuestionIfNeeded(
            result,
            replySignal: replySignal
        )
        let tutorialSuppressed = dropGenericTutorialTailIfNeeded(
            questionSuppressed,
            replySignal: replySignal
        )

        return tutorialSuppressed.isEmpty ? [cleaned] : tutorialSuppressed
    }

    private func maxBubbleCount(for signal: ContextBuilder.ReplySignalStrength) -> Int {
        switch signal {
        case .minimal, .low:
            return 1
        case .light, .normal:
            return 2
        case .deep:
            return 3
        }
    }

    private func dropGenericTrailingQuestionIfNeeded(
        _ segments: [String],
        replySignal: ContextBuilder.ReplySignalStrength
    ) -> [String] {
        switch replySignal {
        case .minimal, .low, .light:
            break
        case .normal, .deep:
            return segments
        }

        guard segments.count > 1,
              let last = segments.last,
              isGenericTrailingQuestion(last) else {
            return segments
        }
        return Array(segments.dropLast())
    }

    private func isGenericTrailingQuestion(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "?", with: "？")
        return Self.genericTrailingQuestions.contains(normalized)
    }

    private func dropGenericTutorialTailIfNeeded(
        _ segments: [String],
        replySignal: ContextBuilder.ReplySignalStrength
    ) -> [String] {
        switch replySignal {
        case .minimal, .low, .light:
            break
        case .normal, .deep:
            return segments
        }

        guard segments.count > 1,
              let last = segments.last,
              isGenericTutorialTail(last) else {
            return segments
        }
        return Array(segments.dropLast())
    }

    private func isGenericTutorialTail(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "?", with: "？")
            .replacingOccurrences(of: "!", with: "！")
        return Self.genericTutorialTails.contains(normalized)
    }

    /// 去掉文本内部的换行，只保留单行气泡。
    private func collapseLines(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: "")
    }

    private func normalizeAssistantReply(_ text: String) -> String {
        var cleaned = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        while cleaned.contains("\n\n\n") {
            cleaned = cleaned.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return cleaned
    }

    private func splitByNewlineBlocks(_ text: String) -> [String] {
        guard text.contains("\n") else { return [text] }

        let paragraphs = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if paragraphs.count > 1 {
            return paragraphs.map { collapseLines($0) }
        }

        let lines = text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard lines.count > 1 else { return [collapseLines(text)] }
        return lines.map { collapseLines($0) }
    }

    private func splitBySemanticBreakpoints(_ text: String) -> [String] {
        var segments = [text]
        var pass = 0
        var didSplit = true

        while didSplit && pass < 3 {
            didSplit = false
            pass += 1

            var next: [String] = []
            for segment in segments {
                if let split = semanticSplitCandidate(segment) {
                    next.append(contentsOf: split)
                    didSplit = true
                } else {
                    next.append(segment)
                }
            }
            segments = next
        }

        return segments
    }

    private func semanticSplitCandidate(_ text: String) -> [String]? {
        guard text.count >= 28 else { return nil }

        for keyword in Self.semanticReplyBreakpoints {
            var searchRange = text.startIndex..<text.endIndex
            while let range = text.range(of: keyword, range: searchRange) {
                let before = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let after = String(text[range.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)

                if shouldSplitSemanticSegment(keyword: keyword, before: before, after: after) {
                    return [before, after]
                }

                guard range.upperBound < text.endIndex else { break }
                searchRange = range.upperBound..<text.endIndex
            }
        }

        return nil
    }

    private func shouldSplitSemanticSegment(keyword: String, before: String, after: String) -> Bool {
        guard !before.isEmpty, !after.isEmpty else { return false }
        guard !Self.connectorOnlyFragments.contains(before),
              !Self.connectorOnlyFragments.contains(after) else {
            return false
        }

        if keyword == "那" {
            return before.count >= 18 && after.count >= 12
        }

        let minBefore = ["我刚才", "下次"].contains(keyword) ? 6 : 8
        let minAfter = 10
        return before.count >= minBefore && after.count >= minAfter
    }

    private func splitLongSegmentBySentencePunctuation(_ text: String) -> [String] {
        guard text.count > 44 else { return [text] }

        var result: [String] = []
        var current = ""

        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            current.append(character)
            let nextIndex = text.index(after: index)
            if character == "…",
               nextIndex < text.endIndex,
               text[nextIndex] == "…" {
                index = nextIndex
                continue
            }

            if Self.strongSentencePunctuation.contains(character) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    result.append(trimmed)
                }
                current = ""
            }
            index = nextIndex
        }

        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            result.append(tail)
        }

        return result.count > 1 ? result : [text]
    }

    private func mergeTinyReplyFragments(_ segments: [String]) -> [String] {
        let cleaned = segments
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !cleaned.isEmpty else { return [] }

        var merged: [String] = []
        var index = 0

        while index < cleaned.count {
            let segment = cleaned[index]

            if ChatNarrationFormatter.narrationText(from: segment) != nil {
                merged.append(segment)
                index += 1
                continue
            }

            if shouldMergeWithNeighbor(segment),
               index + 1 < cleaned.count {
                let combined = segment + cleaned[index + 1]
                merged.append(combined)
                index += 2
                continue
            }

            if shouldMergeWithNeighbor(segment),
               let last = merged.popLast() {
                merged.append(last + segment)
                index += 1
                continue
            }

            if let last = merged.last,
               shouldAvoidConsecutiveShortBubbles(last, segment) {
                merged[merged.count - 1] = last + segment
            } else {
                merged.append(segment)
            }
            index += 1
        }

        return merged
    }

    private func shouldMergeWithNeighbor(_ text: String) -> Bool {
        if Self.connectorOnlyFragments.contains(text) {
            return true
        }
        if Self.allowedShortStandaloneReplies.contains(text) {
            return false
        }
        return text.count < 6
    }

    private func shouldAvoidConsecutiveShortBubbles(_ left: String, _ right: String) -> Bool {
        left.count <= 6 && right.count <= 6 && (left + right).count <= 14
    }

    private func limitReplySegments(_ segments: [String], maxCount: Int) -> [String] {
        guard segments.count > maxCount else { return segments }

        var limited = Array(segments.prefix(maxCount - 1))
        let tail = segments.dropFirst(maxCount - 1).joined()
        if !tail.isEmpty {
            limited.append(tail)
        }
        return limited
    }

    private static let semanticReplyBreakpoints = [
        "我刚才", "不过", "但是", "而且", "不然", "所以", "下次",
        "其实", "还有", "然后", "反正", "算了", "那"
    ]

    private static let strongSentencePunctuation: Set<Character> = [
        "。", "！", "？", "；", "…", "~"
    ]

    private static let connectorOnlyFragments: Set<String> = [
        "不过", "但是", "而且", "不然", "所以", "那", "其实", "还有", "然后", "反正", "算了"
    ]

    private static let allowedShortStandaloneReplies: Set<String> = [
        "嗯", "好", "可以", "我懂", "行", "对", "没用"
    ]

    private static let genericTrailingQuestions: Set<String> = [
        "你呢？",
        "你觉得呢？",
        "你想聊聊吗？",
        "要不要继续说说？",
        "可以跟我说说吗？",
        "你还有什么想聊的吗？",
        "那你现在感觉怎么样？",
        "你平时也会这样吗？",
        "你是怎么做到的？",
        "需要我帮你分析一下吗？"
    ]

    private static let genericTutorialTails: Set<String> = [
        "你可以试试看。",
        "你可以试试看",
        "可以先休息一下。",
        "可以先休息一下",
        "希望对你有帮助。",
        "希望对你有帮助",
        "如果你愿意，我可以继续帮你分析。",
        "如果你愿意，我可以继续帮你分析",
        "我可以帮你一起拆解。",
        "我可以帮你一起拆解",
        "慢慢来就好。",
        "慢慢来就好"
    ]

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

    static func readAllowsNarrationBlocks() -> Bool {
        UserDefaults.standard.bool(forKey: ChatNarrationFormatter.settingsKey)
    }

    /// 生成去重后的分支默认名。base 格式为 "分支·父名称"，同名已存在则追加数字后缀。
    static func makeUniqueBranchTitle(base: String, existing: [ConversationBranch]) -> String {
        let trimmed = String(base.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        let occupied = Set(existing.map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) })
        guard occupied.contains(trimmed) else { return trimmed }
        for i in 2...99 {
            let candidate = "\(trimmed) \(i)"
            if !occupied.contains(candidate) { return candidate }
        }
        return trimmed // fallback
    }

    /// 统一过滤：BranchMessageResolver visible - hidden = 最终可见消息。
    /// ChatView.display / ContextBuilder.input / HistoryBrowser 使用同一逻辑。
    func filteredVisibleMessages(for branchID: UUID) throws -> [ChatMessage] {
        let visible = try loadVisibleMessages(for: branchID)
        let hiddenIDs = (try? hiddenStore.loadHiddenMessageIDs(branchID: branchID)) ?? []
        return visible.filter { !hiddenIDs.contains($0.id) && $0.status == .sent }
    }

    /// 读取 active branch 可见消息（含继承历史 + 自有消息）。
    private func loadVisibleMessagesForActiveBranch() throws -> [ChatMessage] {
        try loadVisibleMessages(for: activeBranchID)
    }

    private func loadVisibleMessages(for branchID: UUID) throws -> [ChatMessage] {
        let branches = (try? branchStore.loadBranches()) ?? []
        let activeBranch = branches.first(where: { $0.id == branchID })
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
    private func updateBranchTimestamps(branchID: UUID, lastMessageAt: Date) {
        do {
            var branches = try branchStore.loadBranches()
            if let idx = branches.firstIndex(where: { $0.id == branchID }) {
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
