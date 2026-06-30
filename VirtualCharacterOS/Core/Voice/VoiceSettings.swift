import Foundation

struct VoiceSettings: Equatable, Sendable {
    var isEnabled: Bool
    var serverBaseURLString: String
    var voiceID: String
    var speed: Double
    var readsNarration: Bool

    var serverBaseURL: URL? {
        let trimmed = serverBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    var hasPlayableConfiguration: Bool {
        serverBaseURL != nil && !voiceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static let disabled = VoiceSettings(
        isEnabled: false,
        serverBaseURLString: "",
        voiceID: "",
        speed: 1.0,
        readsNarration: false
    )

    static func load(defaults: UserDefaults = .standard) -> VoiceSettings {
        let savedSpeed = defaults.double(forKey: speedKey)
        return VoiceSettings(
            isEnabled: defaults.bool(forKey: enabledKey),
            serverBaseURLString: defaults.string(forKey: serverBaseURLKey) ?? "",
            voiceID: defaults.string(forKey: voiceIDKey) ?? "",
            speed: savedSpeed > 0 ? savedSpeed : 1.0,
            readsNarration: defaults.bool(forKey: readsNarrationKey)
        )
    }

    func save(defaults: UserDefaults = .standard) {
        defaults.set(isEnabled, forKey: Self.enabledKey)
        defaults.set(serverBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Self.serverBaseURLKey)
        defaults.set(voiceID.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Self.voiceIDKey)
        defaults.set(speed, forKey: Self.speedKey)
        defaults.set(readsNarration, forKey: Self.readsNarrationKey)
    }

    static let enabledKey = "VoiceSettings.enabled"
    static let serverBaseURLKey = "VoiceSettings.serverBaseURL"
    static let voiceIDKey = "VoiceSettings.voiceID"
    static let speedKey = "VoiceSettings.speed"
    static let readsNarrationKey = "VoiceSettings.readsNarration"
}
