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
