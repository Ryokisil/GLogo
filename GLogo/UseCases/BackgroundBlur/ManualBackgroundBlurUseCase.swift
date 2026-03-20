//
//  ManualBackgroundBlurUseCase.swift
//  GLogo
//
//  概要:
//  手動背景ぼかし編集で使用するプレビュー生成と出力マスク整形を提供するユースケース。
//

import UIKit

/// 手動背景ぼかし編集用ユースケース
struct ManualBackgroundBlurUseCase {
    /// マスクから背景ぼかしプレビュー画像を生成する
    /// - Parameters:
    ///   - originalImage: ぼかし対象の元画像
    ///   - maskImage: 背景ぼかしマスク画像
    ///   - blurRadius: 背景ぼかし半径
    /// - Returns: 生成できた場合はプレビュー画像
    func makePreviewImage(
        originalImage: UIImage,
        maskImage: UIImage,
        blurRadius: CGFloat
    ) -> UIImage? {
        guard let maskData = maskImage.pngData() else {
            return originalImage
        }

        return ImageFilterUtility.applyBackgroundBlur(
            to: originalImage,
            maskData: maskData,
            radius: blurRadius
        )
    }

    /// 完了時に出力へ適用するマスク画像を生成する
    /// - Parameters:
    ///   - maskImage: 現在編集中のマスク画像
    ///   - isUsingProxyForEditing: 編集時に軽量画像を使用しているか
    ///   - fullResolutionImage: 完了時に合わせるフル解像度画像
    /// - Returns: フル解像度へ適用可能なマスク画像
    func makeOutputMaskImage(
        from maskImage: UIImage,
        isUsingProxyForEditing: Bool,
        fullResolutionImage: UIImage
    ) -> UIImage? {
        guard isUsingProxyForEditing else { return maskImage }
        return resizeMask(maskImage, toMatch: fullResolutionImage)
    }

    /// マスク画像をターゲット画像サイズへリサイズする
    /// - Parameters:
    ///   - mask: 元マスク
    ///   - targetImage: 目標サイズ基準画像
    /// - Returns: リサイズ後マスク
    private func resizeMask(_ mask: UIImage, toMatch targetImage: UIImage) -> UIImage {
        let targetSize = targetImage.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = targetImage.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { context in
            context.cgContext.interpolationQuality = .none
            mask.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
