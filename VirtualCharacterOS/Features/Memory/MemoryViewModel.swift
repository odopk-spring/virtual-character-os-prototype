import Foundation
import SwiftUI

/// 记忆管理页的状态管理。
@Observable
final class MemoryViewModel {
    var memories: [MemoryItem] = []
    var errorMessage: String?

    private let store: any MemoryStore

    init(store: any MemoryStore = try! FileMemoryStore()) {
        self.store = store
        loadMemories()
    }

    /// 按 pinned 优先 + 最近更新排序。
    var sortedMemories: [MemoryItem] {
        memories.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
    }

    // MARK: - Actions

    func loadMemories() {
        do {
            memories = try store.loadMemories()
        } catch {
            memories = []
            errorMessage = "加载记忆失败"
        }
    }

    func saveMemory(_ memory: MemoryItem) {
        do {
            if memories.contains(where: { $0.id == memory.id }) {
                try store.updateMemory(memory)
                if let idx = memories.firstIndex(where: { $0.id == memory.id }) {
                    memories[idx] = memory
                }
            } else {
                try store.saveMemory(memory)
                memories.append(memory)
            }
        } catch {
            errorMessage = "保存记忆失败"
        }
    }

    func deleteMemory(at offsets: IndexSet) {
        // 从排序列表中映射回原始 id
        let sorted = sortedMemories
        let idsToDelete = offsets.map { sorted[$0].id }
        for id in idsToDelete {
            try? store.deleteMemory(id: id)
            memories.removeAll(where: { $0.id == id })
        }
    }

    func deleteMemory(id: UUID) {
        try? store.deleteMemory(id: id)
        memories.removeAll(where: { $0.id == id })
    }

    /// 在新增/编辑后统一保存入口。更新 updatedAt。
    func save(title: String, content: String, category: MemoryCategory, isPinned: Bool, existingID: UUID?) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedContent.isEmpty else {
            errorMessage = "标题和内容不能为空"
            return
        }

        let now = Date()
        let item: MemoryItem
        if let existingID {
            // 编辑已有记忆
            let existing = memories.first(where: { $0.id == existingID })
            item = MemoryItem(
                id: existingID,
                title: trimmedTitle,
                content: trimmedContent,
                category: category,
                createdAt: existing?.createdAt ?? now,
                updatedAt: now,
                isPinned: isPinned
            )
        } else {
            // 新增记忆
            item = MemoryItem(
                title: trimmedTitle,
                content: trimmedContent,
                category: category,
                updatedAt: now,
                isPinned: isPinned
            )
        }
        saveMemory(item)
    }
}
