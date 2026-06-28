import SwiftUI

struct ChatView: View {
    @State private var viewModel: ChatViewModel
    @State private var showSettings: Bool = false
    @State private var characterAvatar: UIImage?
    @State private var restoreTargetMessage: ChatMessage?

    init(store: any MessageStore) {
        _viewModel = State(initialValue: ChatViewModel(store: store))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏
            ChatTopBar(
                characterName: viewModel.character.name,
                subtitle: viewModel.character.subtitle
            ) {
                showSettings = true
            }

            // 错误横幅
            if let error = viewModel.errorMessage {
                HStack {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                    Spacer()
                    Button("×") { viewModel.errorMessage = nil }
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.red.opacity(0.85))
            }

            // 消息列表
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(viewModel.messages) { message in
                                ChatBubbleView(
                                    message: message,
                                    availableWidth: geometry.size.width,
                                    characterAvatarImage: characterAvatar,
                                    onRestore: { msg in restoreTargetMessage = msg }
                                )
                                .id(message.id)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .background(chatBackground)
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let last = viewModel.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            // 底部输入栏
            ChatInputBar(
                text: $viewModel.inputText,
                isLoading: viewModel.isLoading,
                onSend: { viewModel.sendMessage() }
            )
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                ProviderSettingsView()
            }
        }
        .onAppear {
            viewModel.loadMessages()
            viewModel.reloadCharacterProfile()
            characterAvatar = AvatarStore.loadImage()
        }
        .onChange(of: showSettings) { _, newValue in
            // 从设置页返回时刷新头像和角色档案
            if !newValue {
                viewModel.reloadCharacterProfile()
                characterAvatar = AvatarStore.loadImage()
            }
        }
        .navigationBarHidden(true)
        .alert("从这里重新开始", isPresented: .init(
            get: { restoreTargetMessage != nil },
            set: { if !$0 { restoreTargetMessage = nil } }
        )) {
            Button("取消", role: .cancel) { restoreTargetMessage = nil }
            Button("确认") {
                if let msg = restoreTargetMessage {
                    viewModel.createBranch(from: msg)
                }
                restoreTargetMessage = nil
            }
        } message: {
            Text("将从这条消息创建一个新分支。原对话会保留，之后的新消息会进入新分支。")
        }
    }
}

// MARK: - Background

private let chatBackground = Color(red: 0.93, green: 0.93, blue: 0.93)

#Preview {
    ChatView(store: try! FileMessageStore())
}
