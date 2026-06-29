import SwiftUI

/// 消息选择模式工具条。替代 ChatTopBar 显示。
struct ChatSelectionToolbar: View {
    let selectedCount: Int
    let onCancel: () -> Void
    let onHide: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button("取消", action: onCancel)
                    .font(.system(size: 17))
                    .foregroundStyle(.primary)
                    .frame(width: 60, alignment: .leading)

                Spacer()

                Text("已选 \(selectedCount) 条")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Button("不显示", action: onHide)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(selectedCount > 0 ? .red : .secondary)
                    .disabled(selectedCount == 0)
                    .frame(width: 60, alignment: .trailing)
            }
            .frame(height: ChatUIStyle.topBarHeight)
            .padding(.horizontal, 12)

            Rectangle()
                .fill(ChatUIStyle.hairlineColor)
                .frame(height: 0.5)
        }
        .background(ChatUIStyle.chatBackground)
    }
}
