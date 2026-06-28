import Foundation

/// 一次性迁移：旧 messages.json → 分支化存储。
/// 条件：branches.json 不存在，或 migrationV1Complete != true。
enum BranchMigration {

    /// 执行迁移（如果需要）。幂等：重复调用不会产生多个 main branch。
    static func migrateIfNeeded(
        messageStore: FileMessageStore,
        branchStore: FileBranchStore
    ) throws {
        // 已迁移 → 跳过
        guard !ActiveBranchStore.isMigrationComplete else { return }

        let now = Date()

        // 加载现有消息
        let messages = (try? messageStore.loadMessages()) ?? []

        // 找出时间锚点
        let oldestAt = messages.map(\.createdAt).min()
        let newestAt = messages.map(\.createdAt).max()

        // 检查 branches.json 是否已有 main branch（幂等保护）
        let existingBranches = (try? branchStore.loadBranches()) ?? []
        let hasMainBranch = existingBranches.contains(where: { $0.id == ConversationBranch.mainBranchID })

        // 创建或确保 main branch 存在
        if !hasMainBranch {
            let mainBranch = ConversationBranch.main(
                now: now,
                oldestMessageAt: oldestAt,
                newestMessageAt: newestAt
            )
            if existingBranches.isEmpty {
                // branches.json 不存在或为空 → 创建新文件
                try branchStore.saveBranch(mainBranch)
            } else {
                // branches.json 存在但缺 main → 补充（异常恢复）
                try branchStore.saveBranch(mainBranch)
            }
        }

        // 为没有 branchID 的消息补 mainBranchID
        var needsRewrite = false
        var updatedMessages = messages
        for i in 0..<updatedMessages.count {
            if updatedMessages[i].branchID == ConversationBranch.mainBranchID {
                // 已有 branchID 且是 main → 可能已部分迁移，跳过
                continue
            }
            // 补 branchID
            updatedMessages[i].branchID = ConversationBranch.mainBranchID
            needsRewrite = true
        }

        // 写回 messages.json（仅当有变更）
        if needsRewrite {
            try messageStore.replaceAllMessages(updatedMessages)
        }

        // 确保 activeBranchID 已设置
        if ActiveBranchStore.getActiveBranchID() != ConversationBranch.mainBranchID {
            ActiveBranchStore.setActiveBranchID(ConversationBranch.mainBranchID)
        }

        // 标记迁移完成
        ActiveBranchStore.markMigrationComplete()
    }
}
