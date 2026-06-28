import SwiftUI

/// 底部输入栏。参考即时通讯布局：左侧圆形按钮 + 白色输入框 + 右侧图标按钮。
struct ChatInputBar: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部分割线
            Rectangle()
                .fill(ChatUIStyle.hairlineColor)
                .frame(height: 0.5)

            HStack(spacing: 8) {
                // 左侧：语音按钮
                Button(action: {}) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.gray)
                        .frame(width: ChatUIStyle.iconTouchArea, height: ChatUIStyle.iconTouchArea)
                }

                // 中间：输入框
                TextField("", text: $text)
                    .font(.system(size: 16))
                    .padding(.horizontal, 12)
                    .frame(height: ChatUIStyle.inputFieldHeight)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: ChatUIStyle.inputFieldCornerRadius))
                    .disabled(isLoading)
                    .onSubmit {
                        if hasText { onSend() }
                    }

                // 右侧：表情 + 发送/加号
                Button(action: {}) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 22))
                        .foregroundStyle(.gray)
                        .frame(width: ChatUIStyle.iconTouchArea, height: ChatUIStyle.iconTouchArea)
                }

                if hasText {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.blue)
                    }
                    .disabled(isLoading)
                } else {
                    Button(action: {}) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 26))
                            .foregroundStyle(.gray)
                            .frame(width: ChatUIStyle.iconTouchArea, height: ChatUIStyle.iconTouchArea)
                    }
                }
            }
            .padding(.horizontal, 10)
            .frame(height: ChatUIStyle.inputBarHeight)
        }
        .background(ChatUIStyle.inputBarBackground)
    }
}
