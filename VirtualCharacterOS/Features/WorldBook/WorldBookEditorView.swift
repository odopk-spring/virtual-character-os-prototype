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
    @State private var isSuggestingKeywords = false
    @State private var suggestionMessage: String?
    @State private var suggestionErrorMessage: String?

    private var isEditing: Bool { existingEntry != nil }
    private let keywordSuggestionService = WorldBookKeywordSuggestionService()

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

                Button {
                    Task {
                        await generateKeywordSuggestions()
                    }
                } label: {
                    HStack {
                        if isSuggestingKeywords {
                            ProgressView()
                                .controlSize(.small)
                            Text("生成中…")
                        } else {
                            Image(systemName: "sparkles")
                            Text("生成推荐关键词")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isSuggestingKeywords)

                if let suggestionMessage {
                    Text(suggestionMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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
        .alert("提示", isPresented: .init(
            get: { suggestionErrorMessage != nil },
            set: { if !$0 { suggestionErrorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(suggestionErrorMessage ?? "")
        }
    }

    @MainActor
    private func generateKeywordSuggestions() async {
        guard !isSuggestingKeywords else { return }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty || !trimmedContent.isEmpty else {
            suggestionMessage = nil
            suggestionErrorMessage = "请先填写标题或内容"
            return
        }

        isSuggestingKeywords = true
        suggestionMessage = nil
        suggestionErrorMessage = nil
        defer { isSuggestingKeywords = false }

        do {
            let suggestions = try await keywordSuggestionService.suggestKeywords(
                title: trimmedTitle,
                content: trimmedContent
            )
            appendSuggestedKeywords(suggestions)
            suggestionMessage = "已填入推荐关键词"
        } catch WorldBookKeywordSuggestionError.emptyInput {
            suggestionErrorMessage = "请先填写标题或内容"
        } catch WorldBookKeywordSuggestionError.providerNotConfigured, AppError.missingAPIKey {
            suggestionErrorMessage = "请先配置 Provider 和 API Key"
        } catch WorldBookKeywordSuggestionError.emptyResponse,
                WorldBookKeywordSuggestionError.noUsableKeywords {
            suggestionErrorMessage = "没有解析到可用关键词"
        } catch {
            suggestionErrorMessage = "生成失败，请稍后重试"
        }
    }

    private func appendSuggestedKeywords(_ suggestions: [String]) {
        var seen = Set<String>()
        var merged: [String] = []

        for keyword in currentKeywordList() + suggestions {
            let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  seen.insert(trimmed.lowercased()).inserted else {
                continue
            }
            merged.append(trimmed)
            if merged.count >= 20 { break }
        }

        keywordsText = merged.joined(separator: ", ")
    }

    private func currentKeywordList() -> [String] {
        keywordsText
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "、", with: ",")
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
