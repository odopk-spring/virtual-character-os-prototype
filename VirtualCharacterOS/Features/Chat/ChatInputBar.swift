import SwiftUI

/// 底部输入栏。参考即时通讯布局：左侧圆形按钮 + 白色输入框 + 右侧图标按钮。
struct ChatInputBar: View {
    let isLoading: Bool
    let onSend: (String) -> Void

    @State private var text: String = ""

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
                TextField("输入消息", text: $text)
                    .font(.system(size: 16))
                    .foregroundStyle(Color(red: 17/255, green: 17/255, blue: 17/255))
                    .tint(.blue)
                    .padding(.horizontal, 12)
                    .frame(height: ChatUIStyle.inputFieldHeight)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: ChatUIStyle.inputFieldCornerRadius))
                    .onSubmit {
                        sendCurrentText()
                    }

                // 右侧：表情 + 发送/加号
                Button(action: {}) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 22))
                        .foregroundStyle(.gray)
                        .frame(width: ChatUIStyle.iconTouchArea, height: ChatUIStyle.iconTouchArea)
                }

                Button(action: {
                    sendCurrentText()
                }) {
                    Image(systemName: hasText ? "arrow.up.circle.fill" : "plus.circle")
                        .font(.system(size: 26))
                        .foregroundStyle(hasText ? .blue : .gray)
                        .frame(width: ChatUIStyle.iconTouchArea, height: ChatUIStyle.iconTouchArea)
                }
                .disabled(isLoading && hasText)
            }
            .padding(.horizontal, 10)
            .frame(height: ChatUIStyle.inputBarHeight)
        }
        .background(ChatUIStyle.inputBarBackground)
    }

    private func sendCurrentText() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }
        text = ""
        onSend(trimmed)
    }
}
