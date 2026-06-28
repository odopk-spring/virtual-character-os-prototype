import SwiftUI

struct ProviderSettingsView: View {
    @State private var viewModel = ProviderSettingsViewModel()

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
    }
}

#Preview {
    NavigationStack {
        ProviderSettingsView()
    }
}
