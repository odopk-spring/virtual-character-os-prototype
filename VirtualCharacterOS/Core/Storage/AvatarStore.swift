import Foundation
import UIKit

/// 本地角色头像存储。单角色，固定文件名，不上传。
struct AvatarStore: Sendable {
    private static let avatarFilename = "character-avatar.jpg"

    // MARK: - Paths

    private static func avatarsDirectory() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = appSupport
            .appendingPathComponent("VirtualCharacterOS")
            .appendingPathComponent("Avatars")
        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true
            )
        }
        return folder
    }

    static func avatarURL() throws -> URL {
        try avatarsDirectory().appendingPathComponent(avatarFilename)
    }

    // MARK: - Public API

    /// 检查是否有自定义头像文件。
    static func hasCustomAvatar() -> Bool {
        guard let url = try? avatarURL() else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// 保存 JPEG 数据到本地。调用前应已完成压缩。
    static func save(_ jpegData: Data) throws {
        let url = try avatarURL()
        // 原子写入，防止写一半崩溃导致文件损坏
        let tempURL = url.appendingPathExtension("tmp")
        try jpegData.write(to: tempURL, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tempURL, to: url)
    }

    /// 加载头像图片。
    static func loadImage() -> UIImage? {
        guard let url = try? avatarURL(),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return UIImage(data: data)
    }

    /// 删除头像文件。
    static func delete() throws {
        let url = try avatarURL()
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Image Processing

    /// 将 UIImage 压缩并限制尺寸，返回适合存储的 JPEG Data。
    /// - Parameters:
    ///   - image: 原始图片
    ///   - maxSize: 最大边长，默认 512
    ///   - quality: JPEG 压缩质量，默认 0.8
    /// - Returns: JPEG Data
    static func compressImage(
        _ image: UIImage,
        maxSize: CGFloat = 512,
        quality: CGFloat = 0.8
    ) -> Data? {
        let resized = resizeImage(image, maxSize: maxSize)
        return resized.jpegData(compressionQuality: quality)
    }

    // MARK: - Private

    private static func resizeImage(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let originalSize = image.size
        let width = originalSize.width
        let height = originalSize.height

        // 已符合限制则不缩放
        guard width > maxSize || height > maxSize else { return image }

        let ratio = min(maxSize / width, maxSize / height)
        let newSize = CGSize(width: width * ratio, height: height * ratio)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
