import SwiftUI

struct CharacterEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var subtitle: String = ""
    @State private var basePersonality: String = ""
    @State private var relationshipContext: String = ""
    @State private var showResetConfirm: Bool = false
    @State private var errorMessage: String?

    private let store: any CharacterProfileStore

    init(store: any CharacterProfileStore) {
        self.store = store
    }

    var body: some View {
        Form {
            // MARK: - Basic Info

            Section {
                TextField("角色名", text: $name)
                    .autocorrectionDisabled()
                HStack {
                    Text("\(name.count)/20")
                        .font(.caption)
                        .foregroundStyle(name.count > 20 ? .red : .secondary)
                    Spacer()
                }

                TextField("副标题", text: $subtitle)
                    .autocorrectionDisabled()
                HStack {
                    Text("\(subtitle.count)/40")
                        .font(.caption)
                        .foregroundStyle(subtitle.count > 40 ? .red : .secondary)
                    Spacer()
                }
            } header: {
                Text("角色基本信息")
            }

            // MARK: - Personality

            Section {
                TextEditor(text: $basePersonality)
                    .frame(minHeight: 100)
                    .font(.body)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                HStack {
                    Text("\(basePersonality.count)/1000")
                        .font(.caption)
                        .foregroundStyle(basePersonality.count > 1000 ? .red : .secondary)
                    Spacer()
                }
            } header: {
                Text("基础人格")
            } footer: {
                Text("描述角色的年龄、职业、性格、兴趣、说话方式等。")
            }

            // MARK: - Relationship

            Section {
                TextEditor(text: $relationshipContext)
                    .frame(minHeight: 100)
                    .font(.body)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                HStack {
                    Text("\(relationshipContext.count)/1000")
                        .font(.caption)
                        .foregroundStyle(relationshipContext.count > 1000 ? .red : .secondary)
                    Spacer()
                }
            } header: {
                Text("关系上下文")
            } footer: {
                Text("描述角色与用户的关系、相处方式、边界等。角色档案会影响对话风格，但不能覆盖真实感和安全边界（不默认恋爱、不使用亲密称呼、不欺骗真人）。")
            }

            // MARK: - Actions

            Section {
                Button("保存角色档案") {
                    save()
                }
                .frame(maxWidth: .infinity)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Section {
                Button("恢复默认角色", role: .destructive) {
                    showResetConfirm = true
                }
            }
        }
        .navigationTitle("编辑角色档案")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadProfile() }
        .alert("确认恢复默认", isPresented: $showResetConfirm) {
            Button("取消", role: .cancel) {}
            Button("确认恢复", role: .destructive) {
                do {
                    try store.resetProfile()
                    loadProfile()
                    dismiss()
                } catch {
                    errorMessage = "恢复失败，请重试。"
                }
            }
        } message: {
            Text("将恢复到默认角色「林晓 · 项目搭档 · 设计师」，当前编辑的内容将丢失。")
        }
        .alert("提示", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Private

    private func loadProfile() {
        let profile = (try? store.loadProfile()) ?? CharacterProfile.defaultProfile()
        name = profile.name
        subtitle = profile.subtitle
        basePersonality = profile.basePersonality
        relationshipContext = profile.relationshipContext
    }

    private func save() {
        let profile = CharacterProfile(
            name: name,
            subtitle: subtitle,
            basePersonality: basePersonality,
            relationshipContext: relationshipContext
        )
        do {
            try store.saveProfile(profile)
            dismiss()
        } catch {
            errorMessage = "保存失败，请重试。"
        }
    }
}
