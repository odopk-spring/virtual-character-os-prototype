import SwiftUI

struct ChatView: View {
    @State private var viewModel: ChatViewModel
    @State private var showSettings: Bool = false
    @State private var showBranchSwitcher: Bool = false
    @State private var showHistoryBrowser: Bool = false
    @State private var characterAvatar: UIImage?
    @State private var restoreTargetMessage: ChatMessage?
    @State private var showHideConfirm: Bool = false
    @State private var voiceSettings: VoiceSettings = .load()
    @State private var voicePlayback = VoicePlaybackCoordinator()

    init(store: any MessageStore) {
        _viewModel = State(initialValue: ChatViewModel(store: store))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏 / 选择工具栏
            if viewModel.isSelectionMode {
                ChatSelectionToolbar(
                    selectedCount: viewModel.selectedMessageIDs.count,
                    onCancel: { viewModel.exitSelectionMode() },
                    onHide: { showHideConfirm = true }
                )
            } else {
                ChatTopBar(
                    characterName: viewModel.character.name,
                    subtitle: viewModel.character.subtitle,
                    isTyping: viewModel.isTypingIndicatorVisible,
                    onSettingsTap: { showSettings = true },
                    onBranchTap: { showBranchSwitcher = true }
                )
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
                        LazyVStack(spacing: ChatUIStyle.rowVerticalSpacing) {
                            ForEach(viewModel.messages) { message in
                                ChatBubbleView(
                                    message: message,
                                    availableWidth: geometry.size.width,
                                    characterAvatarImage: characterAvatar,
                                    voiceSettings: voiceSettings,
                                    voicePlayback: voicePlayback,
                                    onRestore: { msg in restoreTargetMessage = msg },
                                    isSelectionMode: viewModel.isSelectionMode,
                                    isSelected: viewModel.selectedMessageIDs.contains(message.id),
                                    onSelect: { _ in viewModel.toggleMessageSelection(message.id) }
                                )
                                .id(message.id)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .background(ChatUIStyle.chatBackground)
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
                ProviderSettingsView(
                    onHistoryTap: {
                        showSettings = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showHistoryBrowser = true
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showHistoryBrowser) {
            NavigationStack {
                ChatHistoryDateBrowserView(
                    messages: (try? viewModel.filteredVisibleMessages(for: viewModel.activeBranchID)) ?? [],
                    branchName: viewModel.character.name
                )
            }
        }
        .sheet(isPresented: $showBranchSwitcher) {
            NavigationStack {
                BranchSwitcherView(
                    allBranches: viewModel.allBranches,
                    activeBranchID: viewModel.activeBranchID,
                    childBranchIDs: viewModel.childBranchIDs,
                    messageCounts: viewModel.branchMessageCounts,
                    onSwitch: { viewModel.switchBranch(to: $0) },
                    onRename: { viewModel.renameBranch(id: $0, title: $1) },
                    onDelete: { viewModel.deleteBranch(id: $0) }
                )
            }
        }
        .onAppear {
            viewModel.loadMessages()
            viewModel.reloadCharacterProfile()
            characterAvatar = AvatarStore.loadImage()
            voiceSettings = .load()
        }
        .onChange(of: showSettings) { _, newValue in
            // 从设置页返回时刷新头像和角色档案
            if !newValue {
                viewModel.reloadCharacterProfile()
                characterAvatar = AvatarStore.loadImage()
                voiceSettings = .load()
                if !voiceSettings.isEnabled {
                    voicePlayback.stop()
                }
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
        .alert("不显示这些消息？", isPresented: $showHideConfirm) {
            Button("取消", role: .cancel) { showHideConfirm = false }
            Button("不显示", role: .destructive) {
                viewModel.hideSelectedMessages()
                showHideConfirm = false
            }
        } message: {
            Text("这些消息只会在当前分支隐藏，不会从底层记录中删除，也不会影响其他分支。")
        }
    }
}

#Preview {
    ChatView(store: try! FileMessageStore())
}
