import Foundation

/// 计算当前 active branch 的可见消息。
/// 使用"引用历史消息"方案：子分支继承父分支中 root 之前的历史。
struct BranchMessageResolver {

    /// 计算 active branch 的完整可见消息。
    /// - Parameters:
    ///   - activeBranch: 当前 active branch
    ///   - allBranches: 所有分支
    ///   - allMessages: 全量消息
    /// - Returns: 可见消息，按 createdAt 升序
    static func visibleMessages(
        activeBranch: ConversationBranch,
        allBranches: [ConversationBranch],
        allMessages: [ChatMessage]
    ) -> [ChatMessage] {
        // 主线或非子分支 → 只返回自己的消息
        guard let parentBranchID = activeBranch.parentBranchID,
              let rootMessageID = activeBranch.rootMessageID else {
            return allMessages.filter { $0.branchID == activeBranch.id }
        }

        // 找到 rootMessageID 对应消息
        guard let rootMessage = allMessages.first(where: { $0.id == rootMessageID }) else {
            // root 消息找不到 → fallback 到 own messages
            return allMessages.filter { $0.branchID == activeBranch.id }
        }

        // inherited: 父分支中 createdAt <= rootMessage.createdAt 的消息
        let inherited = allMessages.filter {
            $0.branchID == parentBranchID && $0.createdAt <= rootMessage.createdAt
        }

        // own: 当前分支自己的消息
        let own = allMessages.filter { $0.branchID == activeBranch.id }

        // 合并去重 + 按时间排序
        var seen = Set<UUID>()
        var result: [ChatMessage] = []
        for msg in (inherited + own).sorted(by: { $0.createdAt < $1.createdAt }) {
            if seen.insert(msg.id).inserted {
                result.append(msg)
            }
        }
        return result
    }
}
