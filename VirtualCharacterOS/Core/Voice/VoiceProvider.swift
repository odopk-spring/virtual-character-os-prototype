import Foundation

protocol VoiceProvider: Sendable {
    func speechAudioURL(
        for text: String,
        settings: VoiceSettings,
        readMode: String
    ) async throws -> URL
}

enum VoicePlaybackError: LocalizedError {
    case disabled
    case missingConfiguration
    case invalidServerURL
    case insecureServerURL
    case emptyText
    case emptyAudio
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .disabled:
            return "语音已关闭。"
        case .missingConfiguration:
            return "请先在设置里填写语音服务地址和 voiceId。"
        case .invalidServerURL:
            return "语音服务地址无效。"
        case .insecureServerURL:
            return "语音服务地址需要使用 HTTPS；本地开发可用 localhost 或 127.0.0.1。"
        case .emptyText:
            return "没有可播放的文本。"
        case .emptyAudio:
            return "语音服务没有返回音频。"
        case .serverError(let statusCode):
            return "语音服务请求失败（\(statusCode)）。"
        }
    }
}
