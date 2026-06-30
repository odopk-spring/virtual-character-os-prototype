import Foundation

struct LocalServerVoiceProvider: VoiceProvider {
    private let cache: AudioCache
    private let session: URLSession

    init(cache: AudioCache = AudioCache(), session: URLSession = .shared) {
        self.cache = cache
        self.session = session
    }

    func speechAudioURL(
        for text: String,
        settings: VoiceSettings,
        readMode: String = "chat"
    ) async throws -> URL {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard settings.isEnabled else { throw VoicePlaybackError.disabled }
        guard !trimmedText.isEmpty else { throw VoicePlaybackError.emptyText }
        guard settings.hasPlayableConfiguration else { throw VoicePlaybackError.missingConfiguration }
        guard let baseURL = settings.serverBaseURL else { throw VoicePlaybackError.invalidServerURL }
        guard baseURL.scheme?.lowercased() == "https" else { throw VoicePlaybackError.insecureServerURL }

        let key = cache.cacheKey(text: trimmedText, settings: settings, readMode: readMode)
        if let cached = cache.existingAudioURL(for: key) {
            return cached
        }

        let endpoint = baseURL.appendingPathComponent("v1").appendingPathComponent("tts")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(
            LocalServerTTSRequest(
                text: trimmedText,
                voiceID: settings.voiceID.trimmingCharacters(in: .whitespacesAndNewlines),
                format: "mp3",
                speed: settings.speed,
                style: "natural",
                readMode: readMode
            )
        )

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw VoicePlaybackError.serverError(-1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw VoicePlaybackError.serverError(http.statusCode)
        }
        guard !data.isEmpty else {
            throw VoicePlaybackError.emptyAudio
        }

        return try cache.storeAudio(data, for: key)
    }
}

private struct LocalServerTTSRequest: Encodable {
    let text: String
    let voiceID: String
    let format: String
    let speed: Double
    let style: String
    let readMode: String

    enum CodingKeys: String, CodingKey {
        case text
        case voiceID = "voice_id"
        case format
        case speed
        case style
        case readMode = "read_mode"
    }
}
