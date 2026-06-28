import Foundation

/// 本地记忆持久化协议。MVP 2 手动 CRUD，不自动抽取。
protocol MemoryStore: Sendable {
    func loadMemories() throws -> [MemoryItem]
    func saveMemory(_ memory: MemoryItem) throws
    func updateMemory(_ memory: MemoryItem) throws
    func deleteMemory(id: UUID) throws
    func clearMemories() throws
}

/// JSON 文件实现。与 MessageStore 分离存储。
final class FileMemoryStore: MemoryStore {
    private let fileURL: URL

    /// 默认路径：Application Support/VirtualCharacterOS/memories.json
    init(directory: URL? = nil) throws {
        if let directory {
            self.fileURL = directory.appendingPathComponent("memories.json")
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
            self.fileURL = folder.appendingPathComponent("memories.json")
        }
    }

    // MARK: - MemoryStore

    func loadMemories() throws -> [MemoryItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([MemoryItem].self, from: data)
    }

    func saveMemory(_ memory: MemoryItem) throws {
        var memories = try loadMemories()
        memories.append(memory)
        try writeAtomic(memories)
    }

    func updateMemory(_ memory: MemoryItem) throws {
        var memories = try loadMemories()
        guard let index = memories.firstIndex(where: { $0.id == memory.id }) else {
            throw AppError.storage("记忆未找到: \(memory.id)")
        }
        memories[index] = memory
        try writeAtomic(memories)
    }

    func deleteMemory(id: UUID) throws {
        var memories = try loadMemories()
        memories.removeAll(where: { $0.id == id })
        try writeAtomic(memories)
    }

    func clearMemories() throws {
        try writeAtomic([])
    }

    // MARK: - Private

    private func writeAtomic(_ memories: [MemoryItem]) throws {
        let data = try JSONEncoder().encode(memories)
        let tempURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: tempURL, options: .atomic)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
        } else {
            try FileManager.default.moveItem(at: tempURL, to: fileURL)
        }
    }
}
