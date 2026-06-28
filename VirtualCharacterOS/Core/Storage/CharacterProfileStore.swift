import Foundation

/// 角色档案本地持久化协议。
protocol CharacterProfileStore: Sendable {
    func loadProfile() throws -> CharacterProfile
    func saveProfile(_ profile: CharacterProfile) throws
    func resetProfile() throws
}

/// JSON 文件实现。文件不存在时返回默认角色。
final class FileCharacterProfileStore: CharacterProfileStore {
    private let fileURL: URL

    /// 默认路径：Application Support/VirtualCharacterOS/character-profile.json
    init(directory: URL? = nil) throws {
        if let directory {
            self.fileURL = directory.appendingPathComponent("character-profile.json")
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
            self.fileURL = folder.appendingPathComponent("character-profile.json")
        }
    }

    // MARK: - CharacterProfileStore

    func loadProfile() throws -> CharacterProfile {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return CharacterProfile.defaultProfile()
        }
        let data = try Data(contentsOf: fileURL)
        var profile = try JSONDecoder().decode(CharacterProfile.self, from: data)
        profile = profile.applyingLengthLimits()
        return profile
    }

    func saveProfile(_ profile: CharacterProfile) throws {
        let limited = profile.applyingLengthLimits()
        let data = try JSONEncoder().encode(limited)
        let tempURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: tempURL, options: .atomic)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
        } else {
            try FileManager.default.moveItem(at: tempURL, to: fileURL)
        }
    }

    func resetProfile() throws {
        let defaultProfile = CharacterProfile.defaultProfile()
        try saveProfile(defaultProfile)
    }
}
