import SwiftUI

struct ChatView: View {
    @State private var viewModel: ChatViewModel
    @State private var showSettings: Bool = false
    @State private var characterAvatar: UIImage?

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
                                    characterAvatarImage: characterAvatar
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
    }
}

// MARK: - Background

private let chatBackground = Color(red: 0.93, green: 0.93, blue: 0.93)

#Preview {
    ChatView(store: try! FileMessageStore())
}
