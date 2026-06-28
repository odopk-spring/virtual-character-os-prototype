import SwiftUI
import UIKit

/// 单条消息气泡。用户右侧绿色、角色左侧白色。
struct ChatBubbleView: View {
    let message: ChatMessage
    let availableWidth: CGFloat
    var characterAvatarImage: UIImage? = nil
    var onRestore: ((ChatMessage) -> Void)? = nil

    private let avatarSize: CGFloat = 40

    private var bubbleMaxWidth: CGFloat {
        availableWidth * 0.68
    }

    /// assistant 空 sending placeholder 不渲染，由顶部 indicator 表达 typing 状态。
    private var isEmptyAssistantPlaceholder: Bool {
        message.role == .assistant &&
        message.status == .sending &&
        message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        if isEmptyAssistantPlaceholder {
            Color.clear.frame(height: 0)
        } else {
            HStack(alignment: .top, spacing: 8) {
                if message.role == .assistant {
                    AvatarView(role: .assistant, size: avatarSize, customImage: characterAvatarImage)
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
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = message.content
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                    if message.status == .sent {
                        Button {
                            onRestore?(message)
                        } label: {
                            Label("从这里重新开始", systemImage: "arrow.triangle.branch")
                        }
                    }
                }

            if message.status == .failed {
                Text(message.errorMessage ?? "发送失败")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.leading, 4)
            }
            if message.status == .sending {
                Text("...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
    var customImage: UIImage? = nil

    var body: some View {
        if let image = customImage, role == .assistant {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
                    .frame(width: size, height: size)

                Image(systemName: iconName)
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(.white)
            }
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
