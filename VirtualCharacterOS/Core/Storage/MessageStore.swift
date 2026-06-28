import Foundation

/// 本地消息持久化协议。MVP 0 仅支持单角色消息。
protocol MessageStore: Sendable {
    func loadMessages() throws -> [ChatMessage]
    func saveMessage(_ message: ChatMessage) throws
    func updateMessage(_ message: ChatMessage) throws
    func clearMessages() throws
    /// 全量替换消息（迁移专用）。
    func replaceAllMessages(_ messages: [ChatMessage]) throws
}

/// JSON 文件实现。零第三方依赖，数据仅存 App sandbox，不进 iCloud。
final class FileMessageStore: MessageStore {
    private let fileURL: URL

    /// 默认存储路径：Application Support / VirtualCharacterOS / messages.json
    init(directory: URL? = nil) throws {
        if let directory {
            self.fileURL = directory.appendingPathComponent("messages.json")
        } else {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let folder = appSupport.appendingPathComponent("VirtualCharacterOS")
            if !FileManager.default.fileExists(atPath: folder.path) {
                try FileManager.default.createDirectory(
                    at: folder,
                    withIntermediateDirectories: true
                )
            }
            self.fileURL = folder.appendingPathComponent("messages.json")
        }
    }

    // MARK: - MessageStore

    func loadMessages() throws -> [ChatMessage] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([ChatMessage].self, from: data)
    }

    func saveMessage(_ message: ChatMessage) throws {
        var messages = try loadMessages()
        messages.append(message)
        try writeAtomic(messages)
    }

    func updateMessage(_ message: ChatMessage) throws {
        var messages = try loadMessages()
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else {
            throw AppError.storage("消息未找到: \(message.id)")
        }
        messages[index] = message
        try writeAtomic(messages)
    }

    func clearMessages() throws {
        try writeAtomic([])
    }

    func replaceAllMessages(_ messages: [ChatMessage]) throws {
        try writeAtomic(messages)
    }

    // MARK: - Private

    private func writeAtomic(_ messages: [ChatMessage]) throws {
        let data = try JSONEncoder().encode(messages)
        let tempURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: tempURL, options: .atomic)
        try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
    }
}
