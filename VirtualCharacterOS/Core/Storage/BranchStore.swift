import Foundation

// MARK: - Protocol

/// 对话分支持久化协议。
protocol BranchStore: Sendable {
    func loadBranches() throws -> [ConversationBranch]
    func saveBranch(_ branch: ConversationBranch) throws
    func updateBranch(_ branch: ConversationBranch) throws
    func deleteBranch(id: UUID) throws
    func clearBranches() throws
}

// MARK: - File Implementation

/// JSON 文件实现。与 messages/memories/profile/worldbook 分离。
final class FileBranchStore: BranchStore {
    private let fileURL: URL

    /// 默认路径：Application Support/VirtualCharacterOS/branches.json
    init(directory: URL? = nil) throws {
        if let directory {
            self.fileURL = directory.appendingPathComponent("branches.json")
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
            self.fileURL = folder.appendingPathComponent("branches.json")
        }
    }

    // MARK: - BranchStore

    func loadBranches() throws -> [ConversationBranch] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([ConversationBranch].self, from: data)
    }

    func saveBranch(_ branch: ConversationBranch) throws {
        var branches = try loadBranches()
        branches.append(branch)
        try writeAtomic(branches)
    }

    func updateBranch(_ branch: ConversationBranch) throws {
        var branches = try loadBranches()
        guard let index = branches.firstIndex(where: { $0.id == branch.id }) else {
            throw AppError.storage("分支未找到: \(branch.id)")
        }
        branches[index] = branch
        try writeAtomic(branches)
    }

    func deleteBranch(id: UUID) throws {
        var branches = try loadBranches()
        branches.removeAll(where: { $0.id == id })
        try writeAtomic(branches)
    }

    func clearBranches() throws {
        try writeAtomic([])
    }

    // MARK: - Private

    private func writeAtomic(_ branches: [ConversationBranch]) throws {
        let data = try JSONEncoder().encode(branches)
        let tempURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: tempURL, options: .atomic)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
        } else {
            try FileManager.default.moveItem(at: tempURL, to: fileURL)
        }
    }
}

// MARK: - Active Branch Store

/// activeBranchID 读写 helper。主源 UserDefaults，branches.json 作为冗余。
enum ActiveBranchStore {
    static let key = "ChatSettings.activeBranchID"
    static let migrationKey = "ChatSettings.branchMigrationV1Complete"

    static func getActiveBranchID() -> UUID {
        let defaults = UserDefaults.standard
        if let uuidString = defaults.string(forKey: key),
           let uuid = UUID(uuidString: uuidString) {
            return uuid
        }
        return ConversationBranch.mainBranchID
    }

    static func setActiveBranchID(_ id: UUID) {
        UserDefaults.standard.set(id.uuidString, forKey: key)
    }

    static var isMigrationComplete: Bool {
        UserDefaults.standard.bool(forKey: migrationKey)
    }

    static func markMigrationComplete() {
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}
