//
//  ImageAssetRepository.swift
//  GLogo
//
//  画像／プロキシの解決を担当するリポジトリ。
//  モデル側でディスクI/Oやリサイズを行わないよう分離する。
//

import UIKit

/// 画像およびプロキシ画像の解決を行うプロトコル
protocol ImageAssetRepositoryProtocol {
    /// 編集用プロキシも含めた画像の取得
    /// - Parameters:
    ///   - identifier: オリジナル画像の識別子
    ///   - fileName: アセット名
    ///   - originalPath: ローカルファイルパス
    ///   - originalImageProvider: オリジナル画像を提供するクロージャ（必要時のみ評価）
    ///   - proxyTargetLongSide: プロキシ生成時の長辺ピクセル
    ///   - highResThresholdMP: プロキシ生成を行う解像度しきい値（MP）
    /// - Returns: プロキシまたはオリジナル画像
    func loadEditingImage(
        identifier: String?,
        fileName: String?,
        originalPath: String?,
        originalImageProvider: () -> UIImage?,
        proxyTargetLongSide: CGFloat,
        highResThresholdMP: CGFloat
    ) -> UIImage?
}

/// デフォルト実装。AssetManager を利用してプロキシを解決する。
final class ImageAssetRepository: ImageAssetRepositoryProtocol {
    static let shared = ImageAssetRepository()

    private init() {}

    func loadEditingImage(
        identifier: String?,
        fileName: String?,
        originalPath: String?,
        originalImageProvider: () -> UIImage?,
        proxyTargetLongSide: CGFloat,
        highResThresholdMP: CGFloat
    ) -> UIImage? {
        // 1. 可能なら常にオリジナルから編集用画像を解決する。
        //    P3/PQなどの非sRGB系は、編集中と確定後で入力画像が変わると見た目差が出やすいため、
        //    色再現の一貫性を優先して原寸オリジナルを使う。
        if let original = originalImageProvider() {
            if shouldPreferOriginalForEditing(original) {
                return original
            }

            let mp = (original.size.width * original.size.height) / 1_000_000.0
            if mp > highResThresholdMP {
                let resized = resizeImage(original, targetLongSide: proxyTargetLongSide)
                return resized
            }
            return original
        }

        // 2. オリジナルが取得できない場合のみ既存プロキシへフォールバック
        let candidates: [String] = [fileName, identifier].compactMap { $0 }
        for key in candidates {
            if let proxy = AssetManager.shared.loadProxyImage(named: key) {
                return proxy
            }
        }
        if let path = originalPath {
            let proxyPath = (path as NSString).deletingPathExtension + "_proxy.png"
            if let proxy = UIImage(contentsOfFile: proxyPath) {
                return proxy
            }
        }
        return nil
    }

    // MARK: - Helpers

    /// 高解像度画像をターゲット長辺まで縮小する（アスペクト比維持）
    /// - Parameters:
    ///   - image: 元画像
    ///   - targetLongSide: 縮小後の長辺ピクセル
    /// - Returns: 縮小後の画像。元が十分小さい場合はそのまま返す。
    private func resizeImage(_ image: UIImage, targetLongSide: CGFloat) -> UIImage? {
        let longSide = max(image.size.width, image.size.height)
        guard longSide > targetLongSide else { return image }
        let scale = targetLongSide / longSide
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        format.preferredRange = .extended
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// 編集時にオリジナル優先へ切り替えるべきか判定する
    /// - Parameters:
    ///   - image: 判定対象の画像
    /// - Returns: 非sRGB系（Display P3/PQなど）なら true
    private func shouldPreferOriginalForEditing(_ image: UIImage) -> Bool {
        guard let colorSpaceName = image.cgImage?.colorSpace?.name else { return false }
        let sRGB = CGColorSpace(name: CGColorSpace.sRGB)?.name
        let extendedSRGB = CGColorSpace(name: CGColorSpace.extendedSRGB)?.name
        return colorSpaceName != sRGB && colorSpaceName != extendedSRGB
    }
}
