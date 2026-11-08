//
//  ImageSourceResolver.swift
//  GLogo
//
//  ImageElement の画像ソースおよび編集用プロキシ解決を担当する UseCase。
//

import UIKit

/// `ImageElement` 向けの既定画像ソース解決 UseCase
final class ImageSourceResolver: ImageSourceResolving {
    private let assetRepository: EditingImageLoading

    /// UseCase を初期化する。
    /// - Parameters:
    ///   - assetRepository: 編集用プロキシ解決に使うリポジトリ
    /// - Returns: なし
    init(assetRepository: EditingImageLoading) {
        self.assetRepository = assetRepository
    }

    func resolveOriginalImage(
        imageData: Data?,
        fileName: String?,
        url: URL?,
        path: String?
    ) -> UIImage? {
        if let path = path {
            return UIImage(contentsOfFile: path)
        }
        if let url = url {
            if url.isFileURL {
                return UIImage(contentsOfFile: url.path)
            }
            // 非ファイルURLは対象外（将来の拡張時に検討）
            return nil
        }
        if let fileName = fileName {
            return UIImage(named: fileName)
        }
        if let imageData = imageData {
            return UIImage(data: imageData)
        }
        return nil
    }

    func resolveEditingImage(
        identifier: String?,
        fileName: String?,
        originalPath: String?,
        originalImageProvider: () -> UIImage?,
        proxyTargetLongSide: CGFloat,
        highResThresholdMP: CGFloat
    ) -> UIImage? {
        if let resolved = assetRepository.loadEditingImage(
            identifier: identifier,
            fileName: fileName,
            originalPath: originalPath,
            originalImageProvider: originalImageProvider,
            proxyTargetLongSide: proxyTargetLongSide,
            highResThresholdMP: highResThresholdMP
        ) {
            return resolved
        }

        return originalImageProvider()
    }
}
