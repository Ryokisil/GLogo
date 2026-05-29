//
//  ImageSourceResolver.swift
//  GLogo
//
//  ImageElement の画像ソースおよび編集用プロキシ解決を担当する UseCase。
//

import UIKit

/// `ImageElement` が保持する画像参照から表示・編集用画像を解決するプロトコル
protocol ImageSourceResolving {
    /// 元画像を優先順位付きで解決する。
    /// - Parameters:
    ///   - imageData: 直接保持している画像データ
    ///   - fileName: アセット名
    ///   - url: 元画像URL
    ///   - path: 元画像ファイルパス
    /// - Returns: 解決した元画像。利用可能なソースがない場合は nil
    func resolveOriginalImage(
        imageData: Data?,
        fileName: String?,
        url: URL?,
        path: String?
    ) -> UIImage?

    /// 編集用プロキシを含めた画像を解決する。
    /// - Parameters:
    ///   - identifier: オリジナル画像の識別子
    ///   - fileName: アセット名
    ///   - originalPath: 元画像ファイルパス
    ///   - originalImageProvider: 元画像を必要時に提供するクロージャ
    ///   - proxyTargetLongSide: プロキシ生成時の長辺ピクセル
    ///   - highResThresholdMP: プロキシ生成を行う解像度しきい値
    /// - Returns: 編集に使用する画像。解決できない場合は nil
    func resolveEditingImage(
        identifier: String?,
        fileName: String?,
        originalPath: String?,
        originalImageProvider: () -> UIImage?,
        proxyTargetLongSide: CGFloat,
        highResThresholdMP: CGFloat
    ) -> UIImage?
}

/// `ImageElement` 向けの既定画像ソース解決 UseCase
final class ImageSourceResolver: ImageSourceResolving {
    private let assetRepository: ImageAssetRepositoryProtocol

    /// UseCase を初期化する。
    /// - Parameters:
    ///   - assetRepository: 編集用プロキシ解決に使うリポジトリ
    /// - Returns: なし
    init(assetRepository: ImageAssetRepositoryProtocol = ImageAssetRepository.shared) {
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
