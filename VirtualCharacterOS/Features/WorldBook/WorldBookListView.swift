import SwiftUI

struct WorldBookListView: View {
    @State private var viewModel = WorldBookViewModel()
    @State private var showEditor = false
    @State private var editingEntry: WorldBookEntry?

    var body: some View {
        List {
            if viewModel.sortedEntries.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("还没有世界书条目")
                            .foregroundStyle(.secondary)
                        Text("添加世界观、地点、组织、术语、事件等背景设定，丰富角色的知识库。")
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
                    ForEach(viewModel.sortedEntries) { entry in
                        Button {
                            editingEntry = entry
                            showEditor = true
                        } label: {
                            WorldBookRowView(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        viewModel.deleteEntry(at: offsets)
                    }
                }
            }
        }
        .navigationTitle("世界书")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editingEntry = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                WorldBookEditorView(
                    viewModel: viewModel,
                    existingEntry: editingEntry
                )
            }
        }
        .onChange(of: showEditor) { _, newValue in
            if !newValue {
                viewModel.loadEntries()
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

private struct WorldBookRowView: View {
    let entry: WorldBookEntry

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(entry.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(entry.isEnabled ? .primary : .secondary)
                Spacer()
                Text("P\(entry.priority)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.category.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
            Text(entry.content)
                .font(.subheadline)
                .foregroundStyle(entry.isEnabled ? .secondary : .tertiary)
                .lineLimit(2)
            if !entry.keywords.isEmpty {
                Text(entry.keywords.prefix(5).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .lineLimit(1)
            }
            Text(dateFormatter.string(from: entry.updatedAt))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .opacity(entry.isEnabled ? 1.0 : 0.5)
    }
}
