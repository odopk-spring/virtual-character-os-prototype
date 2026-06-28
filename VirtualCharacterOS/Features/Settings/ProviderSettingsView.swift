import SwiftUI
import PhotosUI

struct ProviderSettingsView: View {
    @State private var viewModel = ProviderSettingsViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        Form {
            // MARK: - Provider Info

            Section("服务商") {
                TextField("Provider Name", text: $viewModel.providerName)
                    .autocorrectionDisabled()

                TextField("Base URL", text: $viewModel.baseURL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()

                TextField("Model Name", text: $viewModel.modelName)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }

            // MARK: - API Key

            Section("API Key") {
                SecureField("输入 API Key", text: $viewModel.apiKeyInput)
                    .autocorrectionDisabled()

                HStack {
                    Text("状态")
                    Spacer()
                    if viewModel.hasSavedKey {
                        Label("已保存", systemImage: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("未设置", systemImage: "exclamationmark.shield")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: - Character Supplement

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("可补充说话风格、近期状态、关系边界、禁忌话术等。不要填写 API Key 或隐私敏感信息。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $viewModel.characterSupplement)
                        .frame(minHeight: 120)
                        .font(.body)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )

                    HStack {
                        Text("\(viewModel.characterSupplement.count)/1000")
                            .font(.caption)
                            .foregroundStyle(viewModel.characterSupplement.count > 1000 ? .red : .secondary)
                        Spacer()
                        Button("保存设定") {
                            viewModel.saveCharacterSupplement()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            } header: {
                Text("角色补充设定")
            }

            // MARK: - Character Avatar

            Section {
                HStack {
                    Spacer()
                    if let avatar = viewModel.avatarImage {
                        Image(uiImage: avatar)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.7))
                                .frame(width: 80, height: 80)
                            Image(systemName: "sparkles")
                                .font(.system(size: 32))
                                .foregroundStyle(.white)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 4)

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("选择头像", systemImage: "photo")
                }

                if viewModel.hasCustomAvatar {
                    Button("清除头像", role: .destructive) {
                        viewModel.deleteAvatar()
                    }
                }
            } header: {
                Text("角色头像")
            }

            // MARK: - Character Profile

            Section {
                NavigationLink {
                    CharacterEditorView(store: try! FileCharacterProfileStore())
                } label: {
                    Label("编辑角色档案", systemImage: "person.text.rectangle")
                }
            } header: {
                Text("角色档案")
            }

            // MARK: - Memory

            Section {
                NavigationLink {
                    MemoryListView()
                } label: {
                    Label("记忆管理", systemImage: "brain.head.profile")
                }
            } header: {
                Text("角色记忆")
            }

            // MARK: - Actions

            Section {
                Button("保存配置") {
                    viewModel.save()
                }
                .frame(maxWidth: .infinity)

                if viewModel.hasSavedKey {
                    Button("清除 API Key", role: .destructive) {
                        viewModel.clearAPIKey()
                    }
                }
            }
        }
        .navigationTitle("API 设置")
        .alert("提示", isPresented: $viewModel.showAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage)
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    viewModel.saveAvatar(from: data)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProviderSettingsView()
    }
}
