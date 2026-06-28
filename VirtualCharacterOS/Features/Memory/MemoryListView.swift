import SwiftUI

struct MemoryListView: View {
    @State private var viewModel = MemoryViewModel()
    @State private var showEditor = false
    @State private var editingMemory: MemoryItem?

    var body: some View {
        List {
            if viewModel.sortedMemories.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("还没有记忆记录")
                            .foregroundStyle(.secondary)
                        Text("添加关于用户偏好、项目背景、关系边界等记忆，让角色更了解你。")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            } else {
                Section {
                    ForEach(viewModel.sortedMemories) { memory in
                        Button {
                            editingMemory = memory
                            showEditor = true
                        } label: {
                            MemoryRowView(memory: memory)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        viewModel.deleteMemory(at: offsets)
                    }
                }
            }
        }
        .navigationTitle("记忆管理")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editingMemory = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                MemoryEditorView(
                    viewModel: viewModel,
                    existingMemory: editingMemory
                )
            }
        }
        .onChange(of: showEditor) { _, newValue in
            if !newValue {
                viewModel.loadMemories()
            }
        }
        .alert("提示", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// MARK: - Row

private struct MemoryRowView: View {
    let memory: MemoryItem

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if memory.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Text(memory.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Spacer()
                Text(memory.category.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
            Text(memory.content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(dateFormatter.string(from: memory.updatedAt))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
