import SwiftUI

struct MemoryEditorView: View {
    let viewModel: MemoryViewModel
    let existingMemory: MemoryItem?

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var category: MemoryCategory = .other
    @State private var isPinned: Bool = false

    private var isEditing: Bool { existingMemory != nil }

    init(viewModel: MemoryViewModel, existingMemory: MemoryItem? = nil) {
        self.viewModel = viewModel
        self.existingMemory = existingMemory
    }

    var body: some View {
        Form {
            Section {
                TextField("标题", text: $title)
                    .autocorrectionDisabled()

                TextEditor(text: $content)
                    .frame(minHeight: 120)
                    .font(.body)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            } header: {
                Text(isEditing ? "编辑记忆" : "新增记忆")
            }

            Section {
                Picker("分类", selection: $category) {
                    ForEach(MemoryCategory.allCases) { cat in
                        Label(cat.rawValue, systemImage: cat.iconName)
                            .tag(cat)
                    }
                }

                Toggle("置顶", isOn: $isPinned)
            }

            Section {
                Button(isEditing ? "保存修改" : "添加记忆") {
                    viewModel.save(
                        title: title,
                        content: content,
                        category: category,
                        isPinned: isPinned,
                        existingID: existingMemory?.id
                    )
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            // 编辑模式下显示删除按钮
            if let existing = existingMemory {
                Section {
                    Button("删除这条记忆", role: .destructive) {
                        viewModel.deleteMemory(id: existing.id)
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "编辑记忆" : "新增记忆")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
        }
        .onAppear {
            if let existing = existingMemory {
                title = existing.title
                content = existing.content
                category = existing.category
                isPinned = existing.isPinned
            }
        }
    }
}
