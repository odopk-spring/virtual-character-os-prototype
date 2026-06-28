import Foundation

/// 世界书本地持久化协议。
protocol WorldBookStore: Sendable {
    func loadEntries() throws -> [WorldBookEntry]
    func saveEntry(_ entry: WorldBookEntry) throws
    func updateEntry(_ entry: WorldBookEntry) throws
    func deleteEntry(id: UUID) throws
    func clearEntries() throws
}

/// JSON 文件实现。与 messages/memories/profile 分离存储。
final class FileWorldBookStore: WorldBookStore {
    private let fileURL: URL

    /// 默认路径：Application Support/VirtualCharacterOS/worldbook.json
    init(directory: URL? = nil) throws {
        if let directory {
            self.fileURL = directory.appendingPathComponent("worldbook.json")
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
            self.fileURL = folder.appendingPathComponent("worldbook.json")
        }
    }

    // MARK: - WorldBookStore

    func loadEntries() throws -> [WorldBookEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([WorldBookEntry].self, from: data)
    }

    func saveEntry(_ entry: WorldBookEntry) throws {
        var entries = try loadEntries()
        entries.append(entry)
        try writeAtomic(entries)
    }

    func updateEntry(_ entry: WorldBookEntry) throws {
        var entries = try loadEntries()
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            throw AppError.storage("世界书条目未找到: \(entry.id)")
        }
        entries[index] = entry
        try writeAtomic(entries)
    }

    func deleteEntry(id: UUID) throws {
        var entries = try loadEntries()
        entries.removeAll(where: { $0.id == id })
        try writeAtomic(entries)
    }

    func clearEntries() throws {
        try writeAtomic([])
    }

    // MARK: - Private

    private func writeAtomic(_ entries: [WorldBookEntry]) throws {
        let data = try JSONEncoder().encode(entries)
        let tempURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: tempURL, options: .atomic)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
        } else {
            try FileManager.default.moveItem(at: tempURL, to: fileURL)
        }
    }
}
