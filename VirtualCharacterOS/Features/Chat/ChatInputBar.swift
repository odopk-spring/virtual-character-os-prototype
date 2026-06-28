import SwiftUI

/// 底部输入栏。messaging-app inspired 布局：语音/表情占位 + 输入框 + 动态发送按钮。
struct ChatInputBar: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void

    private let barHeight: CGFloat = 54

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            // 左侧：语音按钮（仅占位，无功能）
            Button(action: {}) {
                Image(systemName: "mic.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(.gray)
            }

            // 输入框（Return 键也可发送）
            TextField("", text: $text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .disabled(isLoading)
                .onSubmit {
                    if hasText { onSend() }
                }

            // 表情按钮（仅占位）
            Button(action: {}) {
                Image(systemName: "face.smiling")
                    .font(.system(size: 24))
                    .foregroundStyle(.gray)
            }

            // 动态：有文字时显示发送按钮，否则显示加号占位
            if hasText {
                Button(action: onSend) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.blue)
                }
                .disabled(isLoading)
            } else {
                Button(action: {}) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(.gray)
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: barHeight)
        .background(.regularMaterial)
    }
}
