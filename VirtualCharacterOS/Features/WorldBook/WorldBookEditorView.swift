import SwiftUI

struct WorldBookEditorView: View {
    let viewModel: WorldBookViewModel
    let existingEntry: WorldBookEntry?

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var keywordsText: String = ""
    @State private var category: WorldBookCategory = .other
    @State private var isEnabled: Bool = true
    @State private var priority: Int = 0

    private var isEditing: Bool { existingEntry != nil }

    var body: some View {
        Form {
            Section {
                TextField("标题", text: $title)
                    .autocorrectionDisabled()
                HStack {
                    Text("\(title.count)/80")
                        .font(.caption)
                        .foregroundStyle(title.count > 80 ? .red : .secondary)
                    Spacer()
                }

                TextEditor(text: $content)
                    .frame(minHeight: 120)
                    .font(.body)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                HStack {
                    Text("\(content.count)/1500")
                        .font(.caption)
                        .foregroundStyle(content.count > 1500 ? .red : .secondary)
                    Spacer()
                }
            } header: {
                Text(isEditing ? "编辑条目" : "新增条目")
            }

            Section {
                TextField("关键词（逗号分隔）", text: $keywordsText)
                    .autocorrectionDisabled()

                Picker("分类", selection: $category) {
                    ForEach(WorldBookCategory.allCases) { cat in
                        Label(cat.rawValue, systemImage: cat.iconName)
                            .tag(cat)
                    }
                }

                Toggle("启用", isOn: $isEnabled)

                HStack {
                    Text("优先级")
                    Spacer()
                    TextField("", value: $priority, format: .number)
                        .keyboardType(.numberPad)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                    Stepper("", value: $priority, in: -10...10)
                        .labelsHidden()
                }
            } header: {
                Text("属性")
            } footer: {
                Text("关键词用于后续触发匹配。优先级越高越靠前。")
            }

            Section {
                Button(isEditing ? "保存修改" : "添加条目") {
                    viewModel.save(
                        title: title,
                        content: content,
                        keywordsText: keywordsText,
                        category: category,
                        isEnabled: isEnabled,
                        priority: priority,
                        existingID: existingEntry?.id
                    )
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let existing = existingEntry {
                Section {
                    Button("删除这条条目", role: .destructive) {
                        viewModel.deleteEntry(id: existing.id)
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "编辑条目" : "新增条目")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
        }
        .onAppear {
            if let existing = existingEntry {
                title = existing.title
                content = existing.content
                keywordsText = existing.keywords.joined(separator: ", ")
                category = existing.category
                isEnabled = existing.isEnabled
                priority = existing.priority
            }
        }
    }
}
