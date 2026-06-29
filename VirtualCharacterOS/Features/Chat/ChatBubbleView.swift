import SwiftUI
import UIKit

/// 单条消息气泡。assistant 左侧白底+尖角，user 右侧绿底+尖角。
struct ChatBubbleView: View {
    let message: ChatMessage
    let availableWidth: CGFloat
    var characterAvatarImage: UIImage? = nil
    var onRestore: ((ChatMessage) -> Void)? = nil
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onSelect: ((ChatMessage) -> Void)? = nil

    private var narrationText: String? {
        ChatNarrationFormatter.narrationText(from: message)
    }

    private let tailW: CGFloat = ChatUIStyle.bubbleTailWidth
    private let tailH: CGFloat = ChatUIStyle.bubbleTailHeight
    private let tailOff: CGFloat = ChatUIStyle.bubbleTailTopOffset

    private var bubbleMaxWidth: CGFloat {
        availableWidth * ChatUIStyle.bubbleMaxWidthRatio
    }

    private var isAssistantPlaceholder: Bool {
        guard message.role == .assistant,
              message.status == .sending else {
            return false
        }
        let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "..." || trimmed == "…"
    }

    var body: some View {
        if isAssistantPlaceholder {
            Color.clear.frame(height: 0)
        } else if let narrationText {
            narrationBlock(narrationText)
        } else if isSelectionMode && message.status == .sent {
            HStack(spacing: 10) {
                selectionIndicator
                simplifiedContent
                if message.role == .user { Spacer(minLength: 0) }
            }
            .padding(.horizontal, ChatUIStyle.pageHorizontalPadding)
            .contentShape(Rectangle())
            .onTapGesture { onSelect?(message) }
        } else {
            HStack(alignment: .top, spacing: ChatUIStyle.avatarToBubbleGap) {
                if message.role == .assistant {
                    avatarView(for: .assistant)
                    bubbleContent
                        .padding(.leading, tailW)
                    Spacer(minLength: 36)
                } else {
                    Spacer(minLength: 36)
                    bubbleContent
                        .padding(.trailing, tailW)
                    avatarView(for: .user)
                }
            }
            .padding(.horizontal, ChatUIStyle.pageHorizontalPadding)
        }
    }

    private func narrationBlock(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 48)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.thinMaterial.opacity(0.82))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = text
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                    if message.status == .sent, !isSelectionMode {
                        Button {
                            onSelect?(message)
                        } label: {
                            Label("选择", systemImage: "checkmark.circle")
                        }
                    }
                }
            Spacer(minLength: 48)
        }
        .padding(.horizontal, ChatUIStyle.pageHorizontalPadding)
    }

    private var selectionIndicator: some View {
        ZStack {
            Circle()
                .stroke(isSelected ? .blue : .gray.opacity(0.5), lineWidth: 2)
                .frame(width: 24, height: 24)
            if isSelected {
                Circle()
                    .fill(.blue)
                    .frame(width: 14, height: 14)
            }
        }
    }

    private var simplifiedContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(message.content)
                .font(.system(size: ChatUIStyle.bubbleFontSize))
                .foregroundStyle(ChatUIStyle.bubbleText)
                .padding(.horizontal, ChatUIStyle.bubbleHorizontalPadding)
                .padding(.vertical, ChatUIStyle.bubbleVerticalPadding)
                .background(bubbleColor)
                .clipShape(RoundedRectangle(cornerRadius: ChatUIStyle.bubbleCornerRadius))
                .frame(maxWidth: bubbleMaxWidth, alignment: message.role == .user ? .trailing : .leading)
        }
    }

    // MARK: - Bubble

    private var bubbleContent: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
            Text(message.content)
                .font(.system(size: ChatUIStyle.bubbleFontSize))
                .foregroundStyle(ChatUIStyle.bubbleText)
                .padding(.horizontal, ChatUIStyle.bubbleHorizontalPadding)
                .padding(.vertical, ChatUIStyle.bubbleVerticalPadding)
                .background(
                    ChatBubbleShape(
                        side: message.role == .assistant ? .left : .right,
                        cornerRadius: ChatUIStyle.bubbleCornerRadius,
                        tailWidth: tailW,
                        tailHeight: tailH,
                        tailOffset: tailOff
                    )
                    .fill(bubbleColor)
                )
                .frame(maxWidth: bubbleMaxWidth, alignment: message.role == .user ? .trailing : .leading)
                .contextMenu {
                    if message.status == .sent, !isSelectionMode {
                        Button {
                            onSelect?(message)
                        } label: {
                            Label("选择", systemImage: "checkmark.circle")
                        }
                    }
                    Button {
                        UIPasteboard.general.string = message.content
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                    if message.status == .sent, !isSelectionMode {
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
        }
    }

    private var bubbleColor: Color {
        switch message.role {
        case .user:    return ChatUIStyle.userBubble
        case .assistant: return ChatUIStyle.assistantBubble
        case .system:  return Color(.systemGray5)
        }
    }

    // MARK: - Avatar

    private func avatarView(for role: MessageRole) -> some View {
        let size = ChatUIStyle.avatarSize
        let cr = ChatUIStyle.avatarCornerRadius

        if let image = characterAvatarImage, role == .assistant {
            return AnyView(
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: cr))
            )
        } else {
            return AnyView(
                ZStack {
                    RoundedRectangle(cornerRadius: cr)
                        .fill(avatarBg(for: role))
                        .frame(width: size, height: size)
                    Image(systemName: avatarIcon(for: role))
                        .font(.system(size: size * 0.5))
                        .foregroundStyle(.white)
                }
            )
        }
    }

    private func avatarBg(for role: MessageRole) -> Color {
        switch role {
        case .user:      return Color(red: 91/255, green: 152/255, blue: 222/255)
        case .assistant: return Color(red: 240/255, green: 154/255, blue: 84/255).opacity(0.85)
        case .system:    return .gray
        }
    }

    private func avatarIcon(for role: MessageRole) -> String {
        switch role {
        case .user:      return "person.fill"
        case .assistant: return "sparkles"
        case .system:    return "gearshape.fill"
        }
    }
}
