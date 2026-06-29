import Foundation

/// Branch-local 隐藏消息持久化。不删 messages.json，不存正文，不存 API Key。
protocol HiddenMessageStore: Sendable {
    func loadHiddenMessageIDs(branchID: UUID) throws -> Set<UUID>
    func hideMessages(_ messageIDs: Set<UUID>, branchID: UUID) throws
    func unhideMessages(_ messageIDs: Set<UUID>, branchID: UUID) throws
}

// MARK: - File Implementation

final class FileHiddenMessageStore: HiddenMessageStore {
    private let fileURL: URL

    init(directory: URL? = nil) throws {
        if let directory {
            self.fileURL = directory.appendingPathComponent("hidden-messages.json")
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
            self.fileURL = folder.appendingPathComponent("hidden-messages.json")
        }
    }

    // MARK: - HiddenMessageStore

    func loadHiddenMessageIDs(branchID: UUID) throws -> Set<UUID> {
        let file = try loadFile()
        return Set(file.hiddenByBranch[branchID.uuidString] ?? [])
    }

    func hideMessages(_ messageIDs: Set<UUID>, branchID: UUID) throws {
        var file = try loadFile()
        let key = branchID.uuidString
        var existing = file.hiddenByBranch[key] ?? []
        for id in messageIDs {
            if !existing.contains(id) { existing.append(id) }
        }
        file.hiddenByBranch[key] = existing
        try writeFile(file)
    }

    func unhideMessages(_ messageIDs: Set<UUID>, branchID: UUID) throws {
        var file = try loadFile()
        let key = branchID.uuidString
        file.hiddenByBranch[key]?.removeAll(where: { messageIDs.contains($0) })
        if file.hiddenByBranch[key]?.isEmpty == true {
            file.hiddenByBranch.removeValue(forKey: key)
        }
        try writeFile(file)
    }

    // MARK: - Private

    private func loadFile() throws -> HiddenMessagesFile {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return HiddenMessagesFile(hiddenByBranch: [:])
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(HiddenMessagesFile.self, from: data)
    }

    private func writeFile(_ file: HiddenMessagesFile) throws {
        let data = try JSONEncoder().encode(file)
        let tempURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: tempURL, options: .atomic)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
        } else {
            try FileManager.default.moveItem(at: tempURL, to: fileURL)
        }
    }
}

// MARK: - Codable Model

/// hidden-messages.json 的根结构。
struct HiddenMessagesFile: Codable, Equatable {
    /// key: branchID.uuidString, value: message ID 数组（Set<UUID> 不直接 Codable，用 Array 表达）
    var hiddenByBranch: [String: [UUID]]
}
