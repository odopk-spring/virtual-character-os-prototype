import CryptoKit
import Foundation

struct AudioCache: Sendable {
    private let directoryName = "VoiceAudioCache"

    func existingAudioURL(for key: String) -> URL? {
        let url = audioURL(for: key)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func storeAudio(_ data: Data, for key: String) throws -> URL {
        let directory = try cacheDirectory()
        let url = directory.appendingPathComponent(filename(for: key))
        try data.write(to: url, options: [.atomic])
        return url
    }

    func cacheKey(text: String, settings: VoiceSettings, readMode: String) -> String {
        let raw = [
            settings.serverBaseURLString,
            settings.voiceID,
            String(format: "%.2f", settings.speed),
            readMode,
            text
        ].joined(separator: "|")
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func audioURL(for key: String) -> URL {
        let directory = (try? cacheDirectory()) ?? FileManager.default.temporaryDirectory
        return directory.appendingPathComponent(filename(for: key))
    }

    private func cacheDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent(directoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private func filename(for key: String) -> String {
        "\(key).mp3"
    }
}
