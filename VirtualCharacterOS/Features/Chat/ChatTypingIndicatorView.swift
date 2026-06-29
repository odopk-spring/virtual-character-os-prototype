import SwiftUI

/// 顶部轻量输入状态。只表达聊天状态，不使用系统 loading 样式。
struct ChatTypingIndicatorView: View {
    @State private var dotPhase = 0

    private let timer = Timer.publish(every: 0.45, on: .main, in: .common).autoconnect()

    private var dots: String {
        switch dotPhase {
        case 1: return "."
        case 2: return ".."
        case 3: return "…"
        default: return ""
        }
    }

    var body: some View {
        Text("对方输入中\(dots)")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .monospacedDigit()
            .frame(width: 104, alignment: .center)
            .onReceive(timer) { _ in
                dotPhase = (dotPhase + 1) % 4
            }
            .onAppear {
                dotPhase = 0
            }
        }
}

#Preview {
    ChatTypingIndicatorView()
        .padding()
        .background(ChatUIStyle.chatBackground)
}
