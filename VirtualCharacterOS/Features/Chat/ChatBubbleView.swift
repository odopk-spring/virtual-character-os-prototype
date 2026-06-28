import SwiftUI

/// 单条消息气泡。用户右侧绿色、角色左侧白色。
struct ChatBubbleView: View {
    let message: ChatMessage
    let availableWidth: CGFloat

    private let avatarSize: CGFloat = 40

    private var bubbleMaxWidth: CGFloat {
        availableWidth * 0.68
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                AvatarView(role: .assistant, size: avatarSize)
                bubbleContent
                Spacer(minLength: bubbleMaxWidth * 0.1)
            } else {
                Spacer(minLength: bubbleMaxWidth * 0.1)
                bubbleContent
                AvatarView(role: .user, size: avatarSize)
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Bubble

    private var bubbleContent: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
            Text(message.content)
                .font(.body)
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(bubbleColor)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .frame(maxWidth: bubbleMaxWidth, alignment: message.role == .user ? .trailing : .leading)

            if message.status == .failed {
                Text(message.errorMessage ?? "发送失败")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.leading, 4)
            }
            if message.status == .sending {
                ProgressView()
                    .scaleEffect(0.7)
                    .padding(.leading, 4)
            }
        }
    }

    private var bubbleColor: Color {
        switch message.role {
        case .user:
            return Color(red: 0.58, green: 0.93, blue: 0.38) // chat green
        case .assistant:
            return .white
        case .system:
            return Color(.systemGray5)
        }
    }
}

// MARK: - Avatar

private struct AvatarView: View {
    let role: MessageRole
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
                .frame(width: size, height: size)

            Image(systemName: iconName)
                .font(.system(size: size * 0.5))
                .foregroundStyle(.white)
        }
    }

    private var backgroundColor: Color {
        switch role {
        case .user: return .blue.opacity(0.7)
        case .assistant: return .orange.opacity(0.7)
        case .system: return .gray
        }
    }

    private var iconName: String {
        switch role {
        case .user: return "person.fill"
        case .assistant: return "sparkles"
        case .system: return "gearshape.fill"
        }
    }
}
