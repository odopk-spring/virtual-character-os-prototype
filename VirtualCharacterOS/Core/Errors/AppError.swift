import Foundation

/// 应用层统一错误类型。每个 case 提供 userMessage 用于 UI 展示。
enum AppError: Error, Equatable {
    case providerNotConfigured
    case invalidBaseURL(String)
    case missingAPIKey
    case network(String)
    case decoding(String)
    case provider(String)
    case storage(String)
    case unknown(String)

    /// 面向用户展示的错误信息。不包含 API Key、token 或内部堆栈。
    var userMessage: String {
        switch self {
        case .providerNotConfigured:
            return "尚未配置 API 服务商。请在设置中填写 Base URL 和 Model。"
        case .invalidBaseURL(let url):
            return "API 地址无效：\(url)。请检查设置中的 Base URL。"
        case .missingAPIKey:
            return "尚未设置 API Key。请在设置中填写并保存。"
        case .network(let detail):
            return "网络连接失败：\(detail)。请检查网络后重试。"
        case .decoding(let detail):
            return "解析回复时出错：\(detail)。可以尝试重发消息。"
        case .provider(let detail):
            return "API 服务商返回错误：\(detail)。请检查 API Key 和账户余额。"
        case .storage(let detail):
            return "本地存储出错：\(detail)。请确保设备有足够空间。"
        case .unknown(let detail):
            return "发生未知错误：\(detail)。请重试或重启 App。"
        }
    }
}
