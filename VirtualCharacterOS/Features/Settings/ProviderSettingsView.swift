import SwiftUI
import PhotosUI

struct ProviderSettingsView: View {
    @State private var viewModel = ProviderSettingsViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var voiceSelfTest = VoicePlaybackCoordinator()
    @State private var voiceSelfTestMessageID = UUID()
    var onHistoryTap: (() -> Void)? = nil

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

            // MARK: - Chat Display

            Section {
                Toggle("显示动作 / 心理旁白", isOn: $viewModel.allowsNarrationBlocks)
                Text("关闭时严格压制 *动作描写*、（心理活动）和旁白格式；开启后聊天与旁白分段输出，旁白以居中半透明小字显示。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("回复长度", selection: $viewModel.replyLengthLevel) {
                    Text("简短").tag(ContextBuilder.ReplyLengthLevel.short)
                    Text("标准").tag(ContextBuilder.ReplyLengthLevel.normal)
                    Text("详细").tag(ContextBuilder.ReplyLengthLevel.long)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("聊天显示")
            }

            // MARK: - Voice

            Section {
                Toggle("语音消息", isOn: $viewModel.voiceEnabled)

                if viewModel.voiceEnabled {
                    Picker("语音引擎", selection: $viewModel.voiceEngine) {
                        ForEach(VoiceEngine.allCases) { engine in
                            Text(engine.title).tag(engine)
                        }
                    }

                    if viewModel.voiceEngine == .localServer {
                        TextField("TTS Server URL", text: $viewModel.voiceServerBaseURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        TextField("Voice ID", text: $viewModel.voiceID)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("语速")
                            Spacer()
                            Text(String(format: "%.1fx", viewModel.voiceSpeed))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $viewModel.voiceSpeed, in: 0.7...1.3, step: 0.1)
                    }

                    Toggle("朗读旁白", isOn: $viewModel.voiceReadsNarration)

                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            runOnDeviceVoiceSelfTest()
                        } label: {
                            Label(voiceSelfTestButtonTitle, systemImage: voiceSelfTestButtonIcon)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)

                        Text("自检只调用 iPhone 本地语音，不经过聊天气泡、旁白识别或本地 TTS 服务。")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let error = voiceSelfTest.errorMessage(for: voiceSelfTestMessageID) {
                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }

                    Text(viewModel.voiceEngine == .onDevice ? "开启后，assistant 正文会显示为语音条；点击播放时由 iPhone 本地语音直接朗读，文字转录仍显示在语音条下方。" : "开启后，assistant 正文会显示为语音条；点击播放时请求你的 TTS 服务生成音频，文字转录仍显示在语音条下方。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("角色语音")
            }

            // MARK: - Chat History

            Section {
                Button {
                    onHistoryTap?()
                } label: {
                    Label("聊天记录", systemImage: "clock.arrow.circlepath")
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } header: {
                Text("聊天记录")
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

            // MARK: - WorldBook

            Section {
                NavigationLink {
                    WorldBookListView()
                } label: {
                    Label("世界书管理", systemImage: "books.vertical")
                }
            } header: {
                Text("世界书")
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
        .onChange(of: viewModel.allowsNarrationBlocks) { _, _ in
            viewModel.saveChatDisplaySettings()
        }
        .onChange(of: viewModel.replyLengthLevel) { _, _ in
            viewModel.saveChatDisplaySettings()
        }
        .onChange(of: viewModel.voiceEnabled) { _, _ in
            viewModel.saveVoiceSettings()
        }
        .onChange(of: viewModel.voiceEngine) { _, _ in
            viewModel.saveVoiceSettings()
        }
        .onChange(of: viewModel.voiceServerBaseURL) { _, _ in
            viewModel.saveVoiceSettings()
        }
        .onChange(of: viewModel.voiceID) { _, _ in
            viewModel.saveVoiceSettings()
        }
        .onChange(of: viewModel.voiceSpeed) { _, _ in
            viewModel.saveVoiceSettings()
        }
        .onChange(of: viewModel.voiceReadsNarration) { _, _ in
            viewModel.saveVoiceSettings()
        }
    }

    private var voiceSelfTestButtonTitle: String {
        if voiceSelfTest.isLoading(messageID: voiceSelfTestMessageID) {
            return "正在测试 iPhone 本地语音"
        }
        if voiceSelfTest.isPlaying(messageID: voiceSelfTestMessageID) {
            return "停止测试语音"
        }
        return "测试 iPhone 本地语音"
    }

    private var voiceSelfTestButtonIcon: String {
        if voiceSelfTest.isLoading(messageID: voiceSelfTestMessageID) {
            return "hourglass"
        }
        if voiceSelfTest.isPlaying(messageID: voiceSelfTestMessageID) {
            return "stop.fill"
        }
        return "speaker.wave.2.fill"
    }

    private func runOnDeviceVoiceSelfTest() {
        let message = ChatMessage(
            id: voiceSelfTestMessageID,
            role: .assistant,
            content: "这是一段 iPhone 本地语音测试。",
            status: .sent
        )
        let settings = VoiceSettings(
            isEnabled: true,
            engine: .onDevice,
            serverBaseURLString: "",
            voiceID: "",
            speed: viewModel.voiceSpeed,
            readsNarration: false
        )
        voiceSelfTest.togglePlayback(for: message, settings: settings)
    }
}

#Preview {
    NavigationStack {
        ProviderSettingsView()
    }
}
