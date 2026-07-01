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
    case speechStartFailed
    case serverError(Int)
    case network(URLError)

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
        case .speechStartFailed:
            return "iPhone 本地语音没有开始播放。请确认系统音量、音频输出设备，并重新安装最新构建后再试。"
        case .serverError(let statusCode):
            return "语音服务请求失败（\(statusCode)）。"
        case .network(let error):
            switch error.code {
            case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
                return "连不上语音服务。真机测试请用 Mac 的局域网 IP，并用 --host 0.0.0.0 启动服务。"
            case .timedOut:
                return "语音服务响应超时。"
            case .appTransportSecurityRequiresSecureConnection:
                return "当前地址被 iOS 网络安全策略拦截，请使用 localhost、局域网 IP 或 HTTPS。"
            default:
                return "语音服务网络错误：\(error.localizedDescription)"
            }
        }
    }
}
