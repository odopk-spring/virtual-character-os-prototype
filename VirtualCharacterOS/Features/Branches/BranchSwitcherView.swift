import SwiftUI

struct BranchSwitcherView: View {
    let allBranches: [ConversationBranch]
    let activeBranchID: UUID
    let childBranchIDs: Set<UUID>  // 作为父分支被引用的 branch ID
    let messageCounts: [UUID: Int]

    let onSwitch: (UUID) -> Void
    let onRename: (UUID, String) -> Void
    let onDelete: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var renamingBranchID: UUID?
    @State private var renameText: String = ""
    @State private var deleteTarget: UUID?
    @State private var blockReason: String?

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f
    }()

    var body: some View {
        List {
            if allBranches.isEmpty {
                Section {
                    Text("没有对话分支")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(allBranches) { branch in
                        let isActive = branch.id == activeBranchID

                        if renamingBranchID == branch.id {
                            HStack {
                                TextField("分支名称", text: $renameText)
                                    .textFieldStyle(.plain)
                                Button("完成") {
                                    let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !trimmed.isEmpty {
                                        onRename(branch.id, trimmed)
                                    }
                                    renamingBranchID = nil
                                }
                                Button("取消") {
                                    renamingBranchID = nil
                                }
                            }
                        } else {
                            Button {
                                if !isActive {
                                    onSwitch(branch.id)
                                    dismiss()
                                }
                            } label: {
                                BranchRowView(
                                    branch: branch,
                                    isActive: isActive,
                                    messageCount: messageCounts[branch.id] ?? 0,
                                    dateFormatter: dateFormatter
                                )
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button("重命名") {
                                    renameText = branch.title
                                    renamingBranchID = branch.id
                                }
                                .tint(.blue)

                                Button("删除", role: .destructive) {
                                    let reason = deleteBlockReason(for: branch)
                                    if let reason {
                                        blockReason = reason
                                    } else {
                                        deleteTarget = branch.id
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("对话分支")
        .alert("确认删除", isPresented: .init(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("取消", role: .cancel) { deleteTarget = nil }
            Button("确认删除", role: .destructive) {
                if let id = deleteTarget {
                    onDelete(id)
                }
                deleteTarget = nil
            }
        } message: {
            Text("这只会删除分支入口，不会清除底层消息。该操作暂不可撤销。")
        }
        .alert("无法删除", isPresented: .init(
            get: { blockReason != nil },
            set: { if !$0 { blockReason = nil } }
        )) {
            Button("知道了", role: .cancel) { blockReason = nil }
        } message: {
            Text(blockReason ?? "")
        }
    }

    /// 判断分支是否可删除，返回 nil 表示可删，否则返回阻断原因。
    private func deleteBlockReason(for branch: ConversationBranch) -> String? {
        if branch.id == activeBranchID {
            return "当前正在使用的分支不能删除，请先切换到其他分支。"
        }
        if branch.id == ConversationBranch.mainBranchID {
            return "主线不能删除。"
        }
        if childBranchIDs.contains(branch.id) {
            return "该分支仍有子分支依赖，不能删除。"
        }
        return nil
    }
}

// MARK: - Row

private struct BranchRowView: View {
    let branch: ConversationBranch
    let isActive: Bool
    let messageCount: Int
    let dateFormatter: DateFormatter

    var body: some View {
        HStack {
            if isActive {
                Image(systemName: "checkmark")
                    .foregroundStyle(.blue)
                    .font(.system(size: 14, weight: .bold))
            } else {
                Color.clear
                    .frame(width: 14)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(branch.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                HStack(spacing: 8) {
                    if let lastMsg = branch.lastMessageAt {
                        Text(dateFormatter.string(from: lastMsg))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if messageCount > 0 {
                        Text("\(messageCount) 条消息")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
