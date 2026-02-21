//
// 概要：写真ライブラリへの権限確認と保存実行（PHPhotoLibrary のラッパー）。
//

import Photos
import UIKit
import ImageIO
import UniformTypeIdentifiers

struct PhotoLibraryWriter: PhotoLibraryWriting {
    /// 現在の権限状態を返す
    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: accessLevel)
    }

    /// 権限リクエストを行う（結果はハンドラで受け取る）
    func requestAuthorization(for accessLevel: PHAccessLevel, handler: @escaping (PHAuthorizationStatus) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: accessLevel, handler: handler)
    }

    /// 写真ライブラリに画像を書き込む
    func performSave(of image: UIImage, format: SaveImageFormat) async throws {
        let imageData = try makeImageData(from: image, format: format)
        let options = PHAssetResourceCreationOptions()
        options.uniformTypeIdentifier = format.utType.identifier

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: imageData, options: options)
        }
    }

    private func makeImageData(from image: UIImage, format: SaveImageFormat) throws -> Data {
        switch format {
        case .png:
            if let data = image.pngData() {
                return data
            }
        case .heic:
            if let data = makeHEICData(from: image) {
                return data
            }
        }

        throw SaveImageError.encodingFailed
    }

    private func makeHEICData(from image: UIImage) -> Data? {
        guard let cgImage = makeCGImage(from: image) else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            SaveImageFormat.heic.utType.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        let properties = [kCGImageDestinationLossyCompressionQuality: 1.0] as CFDictionary
        CGImageDestinationAddImage(destination, cgImage, properties)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private func makeCGImage(from image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cgImage = image.cgImage {
            return cgImage
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }.cgImage
    }
}
