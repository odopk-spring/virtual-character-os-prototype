import SwiftUI
import UIKit

/// 单条消息气泡。assistant 左侧白底+尖角，user 右侧绿底+尖角。
struct ChatBubbleView: View {
    let message: ChatMessage
    let availableWidth: CGFloat
    var characterAvatarImage: UIImage? = nil
    var voiceSettings: VoiceSettings = .disabled
    var voicePlayback: VoicePlaybackCoordinator? = nil
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

    private var voiceBubbleWidth: CGFloat {
        min(max(availableWidth * 0.46, 158), 220)
    }

    private var isAssistantPlaceholder: Bool {
        guard message.role == .assistant,
              message.status == .sending else {
            return false
        }
        let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "..." || trimmed == "…"
    }

    private var usesVoiceBubble: Bool {
        voiceSettings.isEnabled
            && message.role == .assistant
            && message.status == .sent
            && narrationText == nil
            && !isSelectionMode
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
            if usesVoiceBubble {
                voiceBubbleContent
            } else {
                textBubbleContent
            }

            if message.status == .failed {
                Text(message.errorMessage ?? "发送失败")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.leading, 4)
            }
        }
    }

    private var textBubbleContent: some View {
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
                messageActions
            }
    }

    private var voiceBubbleContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Button {
                    voicePlayback?.togglePlayback(for: message, settings: voiceSettings)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.08))
                            .frame(width: 32, height: 32)
                        Image(systemName: voiceButtonIcon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("播放语音")

                voiceWaveform

                Text("语音")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(width: voiceBubbleWidth, alignment: .leading)
            .background(
                ChatBubbleShape(
                    side: .left,
                    cornerRadius: ChatUIStyle.bubbleCornerRadius,
                    tailWidth: tailW,
                    tailHeight: tailH,
                    tailOffset: tailOff
                )
                .fill(.thinMaterial)
            )
            .overlay(
                ChatBubbleShape(
                    side: .left,
                    cornerRadius: ChatUIStyle.bubbleCornerRadius,
                    tailWidth: tailW,
                    tailHeight: tailH,
                    tailOffset: tailOff
                )
                .fill(Color.white.opacity(0.18))
            )
            .overlay(
                ChatBubbleShape(
                    side: .left,
                    cornerRadius: ChatUIStyle.bubbleCornerRadius,
                    tailWidth: tailW,
                    tailHeight: tailH,
                    tailOffset: tailOff
                )
                .stroke(Color.white.opacity(0.45), lineWidth: 0.6)
            )

            Text(message.content)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: min(bubbleMaxWidth, voiceBubbleWidth + 28), alignment: .leading)
                .padding(.leading, 4)

            if let error = voicePlayback?.errorMessage(for: message.id) {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.leading, 4)
            }
        }
        .frame(maxWidth: bubbleMaxWidth, alignment: .leading)
        .contextMenu {
            messageActions
        }
    }

    private var voiceButtonIcon: String {
        guard let voicePlayback else { return "play.fill" }
        if voicePlayback.isLoading(messageID: message.id) {
            return "hourglass"
        }
        return voicePlayback.isPlaying(messageID: message.id) ? "stop.fill" : "play.fill"
    }

    private var voiceWaveform: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<12, id: \.self) { index in
                Capsule()
                    .fill(Color.primary.opacity(waveOpacity(for: index)))
                    .frame(width: 3, height: waveHeight(for: index))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func waveHeight(for index: Int) -> CGFloat {
        let pattern: [CGFloat] = [9, 15, 20, 12, 24, 17, 11, 21, 14, 19, 10, 16]
        return pattern[index % pattern.count]
    }

    private func waveOpacity(for index: Int) -> Double {
        guard let voicePlayback,
              voicePlayback.isPlaying(messageID: message.id) else {
            return index % 2 == 0 ? 0.28 : 0.18
        }
        return index % 2 == 0 ? 0.62 : 0.38
    }

    @ViewBuilder
    private var messageActions: some View {
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
