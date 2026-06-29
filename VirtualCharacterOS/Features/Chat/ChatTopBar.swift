import SwiftUI

/// 聊天页顶部导航栏。参考即时通讯：56pt 高、居中标题、左右图标按钮、底部分割线。
struct ChatTopBar: View {
    let characterName: String
    let subtitle: String
    let isTyping: Bool
    let onSettingsTap: () -> Void
    let onBranchTap: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // 左侧：分支切换入口
                if let onBranchTap {
                    Button(action: onBranchTap) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: ChatUIStyle.iconTouchArea, height: ChatUIStyle.iconTouchArea)
                    }
                } else {
                    Color.clear
                        .frame(width: ChatUIStyle.iconTouchArea, height: ChatUIStyle.iconTouchArea)
                }

                Spacer()

                // 中间：角色名 / typing 状态，同一位置替换，避免消息列表跳动。
                ZStack {
                    if isTyping {
                        ChatTypingIndicatorView()
                            .transition(.opacity)
                    } else {
                        Text(characterName)
                            .font(.system(size: ChatUIStyle.topBarTitleSize, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .transition(.opacity)
                    }
                }
                .frame(width: 160, height: ChatUIStyle.iconTouchArea)
                .animation(.easeInOut(duration: 0.18), value: isTyping)

                Spacer()

                // 右侧：设置入口
                Button(action: onSettingsTap) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: ChatUIStyle.iconTouchArea, height: ChatUIStyle.iconTouchArea)
                }
            }
            .frame(height: ChatUIStyle.topBarHeight)
            .padding(.horizontal, 6)

            // 底部分割线
            Rectangle()
                .fill(ChatUIStyle.hairlineColor)
                .frame(height: 0.5)
        }
        .background(ChatUIStyle.chatBackground)
    }
}
