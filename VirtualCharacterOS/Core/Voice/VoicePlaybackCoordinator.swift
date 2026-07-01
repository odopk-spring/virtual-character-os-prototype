import AVFoundation
import Foundation

@MainActor
@Observable
final class VoicePlaybackCoordinator: NSObject, AVSpeechSynthesizerDelegate {
    private let provider: any VoiceProvider
    private var player: AVPlayer?
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var isOnDeviceSpeaking = false
    private var playbackEndObserver: NSObjectProtocol?

    var activeMessageID: UUID?
    var loadingMessageID: UUID?
    var errorMessage: String?

    init(provider: any VoiceProvider = LocalServerVoiceProvider()) {
        self.provider = provider
        super.init()
        speechSynthesizer.delegate = self
    }

    func isPlaying(messageID: UUID) -> Bool {
        activeMessageID == messageID
            && (player?.timeControlStatus == .playing || isOnDeviceSpeaking)
    }

    func isLoading(messageID: UUID) -> Bool {
        loadingMessageID == messageID
    }

    func errorMessage(for messageID: UUID) -> String? {
        activeMessageID == messageID ? errorMessage : nil
    }

    func showUnavailable(reason: String, for messageID: UUID) {
        stop()
        activeMessageID = messageID
        loadingMessageID = nil
        errorMessage = reason
    }

    func togglePlayback(for message: ChatMessage, settings: VoiceSettings) {
        if activeMessageID == message.id,
           (player?.timeControlStatus == .playing || isOnDeviceSpeaking) {
            stop()
            return
        }

        stop()
        activeMessageID = message.id
        loadingMessageID = message.id
        Task {
            await play(message: message, settings: settings)
        }
    }

    func stop() {
        player?.pause()
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        isOnDeviceSpeaking = false
        player = nil
        activeMessageID = nil
        loadingMessageID = nil
        errorMessage = nil
        removePlaybackEndObserver()
    }

    private func play(message: ChatMessage, settings: VoiceSettings) async {
        guard activeMessageID == message.id else { return }

        guard let text = VoiceTextExtractor.readableText(from: message, settings: settings) else {
            loadingMessageID = nil
            errorMessage = VoicePlaybackError.emptyText.localizedDescription
            return
        }

        do {
            switch settings.engine {
            case .onDevice:
                try playOnDevice(text: text, messageID: message.id, settings: settings)
            case .localServer:
                let audioURL = try await provider.speechAudioURL(
                    for: text,
                    settings: settings,
                    readMode: ChatNarrationFormatter.narrationText(from: message) == nil ? "chat" : "narration"
                )
                guard activeMessageID == message.id else { return }
                try configurePlaybackAudioSession()

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

    private func playOnDevice(text: String, messageID: UUID, settings: VoiceSettings) throws {
        guard activeMessageID == messageID else { return }
        try configurePlaybackAudioSession()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = preferredChineseVoice()
        utterance.rate = Float(0.48 * settings.speed)
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        speechSynthesizer.speak(utterance)
        errorMessage = nil
        scheduleOnDevicePlaybackStartCheck(messageID: messageID)
    }

    private func configurePlaybackAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true)
    }

    private func preferredChineseVoice() -> AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice(language: "zh-CN")
            ?? AVSpeechSynthesisVoice(language: "zh-Hans")
            ?? AVSpeechSynthesisVoice.speechVoices().first {
                $0.language.hasPrefix("zh")
            }
    }

    private func scheduleOnDevicePlaybackStartCheck(messageID: UUID) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard activeMessageID == messageID,
                  loadingMessageID == messageID,
                  !isOnDeviceSpeaking else {
                return
            }

            if speechSynthesizer.isSpeaking {
                isOnDeviceSpeaking = true
                loadingMessageID = nil
                scheduleOnDevicePlaybackFinishCheck(messageID: messageID)
            } else {
                loadingMessageID = nil
                errorMessage = VoicePlaybackError.speechStartFailed.localizedDescription
            }
        }
    }

    private func scheduleOnDevicePlaybackFinishCheck(messageID: UUID) {
        Task { @MainActor in
            while activeMessageID == messageID, isOnDeviceSpeaking {
                try? await Task.sleep(nanoseconds: 250_000_000)
                if !speechSynthesizer.isSpeaking {
                    stop()
                    return
                }
            }
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didStart utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            guard let activeMessageID = self.activeMessageID else { return }
            self.isOnDeviceSpeaking = true
            self.loadingMessageID = nil
            self.errorMessage = nil
            self.scheduleOnDevicePlaybackFinishCheck(messageID: activeMessageID)
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            guard self.isOnDeviceSpeaking else { return }
            self.stop()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            guard self.isOnDeviceSpeaking else { return }
            self.stop()
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
