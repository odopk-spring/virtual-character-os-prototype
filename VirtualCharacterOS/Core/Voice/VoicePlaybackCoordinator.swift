import AVFoundation
import Foundation

@MainActor
@Observable
final class VoicePlaybackCoordinator {
    private let provider: any VoiceProvider
    private var player: AVPlayer?
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var playbackEndObserver: NSObjectProtocol?

    var activeMessageID: UUID?
    var loadingMessageID: UUID?
    var errorMessage: String?

    init(provider: any VoiceProvider = LocalServerVoiceProvider()) {
        self.provider = provider
    }

    func isPlaying(messageID: UUID) -> Bool {
        activeMessageID == messageID
            && (player?.timeControlStatus == .playing || speechSynthesizer.isSpeaking)
    }

    func isLoading(messageID: UUID) -> Bool {
        loadingMessageID == messageID
    }

    func errorMessage(for messageID: UUID) -> String? {
        activeMessageID == messageID ? errorMessage : nil
    }

    func togglePlayback(for message: ChatMessage, settings: VoiceSettings) {
        if activeMessageID == message.id,
           player?.timeControlStatus == .playing {
            stop()
            return
        }

        Task {
            await play(message: message, settings: settings)
        }
    }

    func stop() {
        player?.pause()
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        player = nil
        activeMessageID = nil
        loadingMessageID = nil
        errorMessage = nil
        removePlaybackEndObserver()
    }

    private func play(message: ChatMessage, settings: VoiceSettings) async {
        stop()
        activeMessageID = message.id
        loadingMessageID = message.id

        guard let text = VoiceTextExtractor.readableText(from: message, settings: settings) else {
            loadingMessageID = nil
            errorMessage = VoicePlaybackError.emptyText.localizedDescription
            return
        }

        do {
            switch settings.engine {
            case .onDevice:
                playOnDevice(text: text, messageID: message.id, settings: settings)
            case .localServer:
                let audioURL = try await provider.speechAudioURL(
                    for: text,
                    settings: settings,
                    readMode: ChatNarrationFormatter.narrationText(from: message) == nil ? "chat" : "narration"
                )
                guard activeMessageID == message.id else { return }
                try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
                try? AVAudioSession.sharedInstance().setActive(true)

                let item = AVPlayerItem(url: audioURL)
                observePlaybackEnd(for: item)
                player = AVPlayer(playerItem: item)
                player?.play()
                loadingMessageID = nil
                errorMessage = nil
            }
        } catch {
            guard activeMessageID == message.id else { return }
            loadingMessageID = nil
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "语音播放失败。"
        }
    }

    private func playOnDevice(text: String, messageID: UUID, settings: VoiceSettings) {
        guard activeMessageID == messageID else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = Float(0.48 * settings.speed)
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        speechSynthesizer.speak(utterance)
        loadingMessageID = nil
        errorMessage = nil
        scheduleOnDevicePlaybackRefresh(messageID: messageID, text: text)
    }

    private func scheduleOnDevicePlaybackRefresh(messageID: UUID, text: String) {
        let estimatedSeconds = min(max(Double(text.count) * 0.18, 1.2), 90)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(estimatedSeconds * 1_000_000_000))
            if activeMessageID == messageID, !speechSynthesizer.isSpeaking {
                stop()
            }
        }
    }

    private func observePlaybackEnd(for item: AVPlayerItem) {
        removePlaybackEndObserver()
        playbackEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.stop()
            }
        }
    }

    private func removePlaybackEndObserver() {
        if let playbackEndObserver {
            NotificationCenter.default.removeObserver(playbackEndObserver)
            self.playbackEndObserver = nil
        }
    }

}
