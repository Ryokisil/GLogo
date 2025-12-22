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
        // 1. 識別子・ファイル名からプロキシを探す
        let candidates: [String] = [fileName, identifier].compactMap { $0 }
        for key in candidates {
            if let proxy = AssetManager.shared.loadProxyImage(named: key) {
                return proxy
            }
        }

        // 2. 元画像パスに _proxy があれば利用
        if let path = originalPath {
            let proxyPath = (path as NSString).deletingPathExtension + "_proxy.png"
            if let proxy = UIImage(contentsOfFile: proxyPath) {
                return proxy
            }
        }

        // 3. 必要に応じてオンメモリでプロキシ生成
        if let original = originalImageProvider() {
            let mp = (original.size.width * original.size.height) / 1_000_000.0
            if mp > highResThresholdMP {
                return resizeImage(original, targetLongSide: proxyTargetLongSide)
            }
            return original
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

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized
    }
}
