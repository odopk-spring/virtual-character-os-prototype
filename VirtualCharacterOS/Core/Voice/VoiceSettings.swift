import Foundation

enum VoiceEngine: String, CaseIterable, Identifiable, Sendable {
    case onDevice
    case localServer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .onDevice:
            return "iPhone 本地语音"
        case .localServer:
            return "本地/私有 TTS 服务"
        }
    }
}

struct VoiceSettings: Equatable, Sendable {
    var isEnabled: Bool
    var engine: VoiceEngine
    var serverBaseURLString: String
    var voiceID: String
    var speed: Double
    var readsNarration: Bool

    var serverBaseURL: URL? {
        URL(string: Self.normalizedServerBaseURLString(serverBaseURLString))
    }

    var hasPlayableConfiguration: Bool {
        serverBaseURL != nil && !voiceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static let disabled = VoiceSettings(
        isEnabled: false,
        engine: .onDevice,
        serverBaseURLString: "",
        voiceID: "",
        speed: 1.0,
        readsNarration: false
    )

    static func load(defaults: UserDefaults = .standard) -> VoiceSettings {
        let savedSpeed = defaults.double(forKey: speedKey)
        let engineRaw = defaults.string(forKey: engineKey) ?? ""
        return VoiceSettings(
            isEnabled: defaults.bool(forKey: enabledKey),
            engine: VoiceEngine(rawValue: engineRaw) ?? .onDevice,
            serverBaseURLString: defaults.string(forKey: serverBaseURLKey) ?? "",
            voiceID: defaults.string(forKey: voiceIDKey) ?? "",
            speed: savedSpeed > 0 ? savedSpeed : 1.0,
            readsNarration: defaults.bool(forKey: readsNarrationKey)
        )
    }

    func save(defaults: UserDefaults = .standard) {
        defaults.set(isEnabled, forKey: Self.enabledKey)
        defaults.set(engine.rawValue, forKey: Self.engineKey)
        defaults.set(Self.normalizedServerBaseURLString(serverBaseURLString), forKey: Self.serverBaseURLKey)
        defaults.set(voiceID.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Self.voiceIDKey)
        defaults.set(speed, forKey: Self.speedKey)
        defaults.set(readsNarration, forKey: Self.readsNarrationKey)
    }

    private static func normalizedServerBaseURLString(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        guard trimmed.range(of: "^[A-Za-z][A-Za-z0-9+.-]*://", options: .regularExpression) == nil else {
            return trimmed
        }
        return "http://\(trimmed)"
    }

    static let enabledKey = "VoiceSettings.enabled"
    static let engineKey = "VoiceSettings.engine"
    static let serverBaseURLKey = "VoiceSettings.serverBaseURL"
    static let voiceIDKey = "VoiceSettings.voiceID"
    static let speedKey = "VoiceSettings.speed"
    static let readsNarrationKey = "VoiceSettings.readsNarration"
}
