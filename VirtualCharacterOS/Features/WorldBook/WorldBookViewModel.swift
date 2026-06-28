import Foundation
import SwiftUI

/// 世界书管理页的状态管理。
@Observable
final class WorldBookViewModel {
    var entries: [WorldBookEntry] = []
    var errorMessage: String?

    private let store: any WorldBookStore

    init(store: any WorldBookStore = try! FileWorldBookStore()) {
        self.store = store
        loadEntries()
    }

    /// 按 priority 降序 → updatedAt 降序 → 禁用的排后。
    var sortedEntries: [WorldBookEntry] {
        entries.sorted {
            if $0.isEnabled != $1.isEnabled { return $0.isEnabled }
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            return $0.updatedAt > $1.updatedAt
        }
    }

    // MARK: - Actions

    func loadEntries() {
        do {
            entries = try store.loadEntries()
        } catch {
            entries = []
            errorMessage = "加载世界书失败"
        }
    }

    func saveEntry(_ entry: WorldBookEntry) {
        let limited = entry.applyingLengthLimits()
        do {
            if entries.contains(where: { $0.id == limited.id }) {
                try store.updateEntry(limited)
                if let idx = entries.firstIndex(where: { $0.id == limited.id }) {
                    entries[idx] = limited
                }
            } else {
                try store.saveEntry(limited)
                entries.append(limited)
            }
        } catch {
            errorMessage = "保存条目失败"
        }
    }

    func deleteEntry(at offsets: IndexSet) {
        let sorted = sortedEntries
        let ids = offsets.map { sorted[$0].id }
        for id in ids {
            try? store.deleteEntry(id: id)
            entries.removeAll(where: { $0.id == id })
        }
    }

    func deleteEntry(id: UUID) {
        try? store.deleteEntry(id: id)
        entries.removeAll(where: { $0.id == id })
    }

    /// 统一保存入口。
    func save(
        title: String, content: String, keywordsText: String,
        category: WorldBookCategory, isEnabled: Bool, priority: Int,
        existingID: UUID?
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedContent.isEmpty else {
            errorMessage = "标题和内容不能为空"
            return
        }

        let keywords = keywordsText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let now = Date()
        let item: WorldBookEntry
        if let existingID {
            let existing = entries.first(where: { $0.id == existingID })
            item = WorldBookEntry(
                id: existingID,
                title: trimmedTitle,
                content: trimmedContent,
                keywords: keywords,
                category: category,
                isEnabled: isEnabled,
                priority: priority,
                createdAt: existing?.createdAt ?? now,
                updatedAt: now
            )
        } else {
            item = WorldBookEntry(
                title: trimmedTitle,
                content: trimmedContent,
                keywords: keywords,
                category: category,
                isEnabled: isEnabled,
                priority: priority,
                updatedAt: now
            )
        }
        saveEntry(item)
    }
}
