//
//  FilterPreviewUseCase.swift
//  GLogo
//
//  概要:
//  フィルタープリセットのプレビュー画像生成を担当します。
//  選択画像を小サイズ化し、filter + manual 調整の合成結果をサムネイルとして返します。
//

import Foundation
import UIKit

/// フィルタープレビュー生成ユースケース
enum FilterPreviewUseCase {

    /// プリセットのプレビュー画像を生成（filter + manual を合成）
    /// - Parameters:
    ///   - sourceImage: プレビュー元の画像
    ///   - toneCurveData: 現在要素のトーンカーブ
    ///   - manualSaturation: manual 側の彩度
    ///   - manualBrightness: manual 側の明度
    ///   - manualContrast: manual 側のコントラスト
    ///   - manualHighlights: manual 側のハイライト
    ///   - manualShadows: manual 側のシャドウ
    ///   - manualBlacks: manual 側の黒レベル
    ///   - manualWhites: manual 側の白レベル
    ///   - manualWarmth: manual 側の色温度
    ///   - manualVibrance: manual 側のヴィブランス
    ///   - manualHue: manual 側の色相
    ///   - manualSharpness: manual 側のシャープネス
    ///   - manualGaussianBlur: manual 側のガウシアンブラー
    ///   - manualTintColor: manual 側のティントカラー
    ///   - manualTintIntensity: manual 側のティント強度
    ///   - backgroundBlurRadius: 背景ぼかし半径
    ///   - backgroundBlurMaskData: 背景ぼかしマスク
    ///   - preset: 適用するフィルタープリセット
    ///   - targetSize: サムネイルサイズ
    /// - Returns: プレビュー画像。生成に失敗した場合は nil
    static func generatePreview(
        sourceImage: UIImage,
        toneCurveData: ToneCurveData,
        manualSaturation: CGFloat,
        manualBrightness: CGFloat,
        manualContrast: CGFloat,
        manualHighlights: CGFloat,
        manualShadows: CGFloat,
        manualBlacks: CGFloat,
        manualWhites: CGFloat,
        manualWarmth: CGFloat,
        manualVibrance: CGFloat,
        manualHue: CGFloat,
        manualSharpness: CGFloat,
        manualGaussianBlur: CGFloat,
        manualTintColor: UIColor?,
        manualTintIntensity: CGFloat,
        backgroundBlurRadius: CGFloat,
        backgroundBlurMaskData: Data?,
        preset: FilterPreset,
        targetSize: CGSize
    ) async -> UIImage? {
        let preparedImage = resizedImage(sourceImage, targetSize: targetSize)
        let params = makePreviewParams(
            toneCurveData: toneCurveData,
            manualSaturation: manualSaturation,
            manualBrightness: manualBrightness,
            manualContrast: manualContrast,
            manualHighlights: manualHighlights,
            manualShadows: manualShadows,
            manualBlacks: manualBlacks,
            manualWhites: manualWhites,
            manualWarmth: manualWarmth,
            manualVibrance: manualVibrance,
            manualHue: manualHue,
            manualSharpness: manualSharpness,
            manualGaussianBlur: manualGaussianBlur,
            manualTintColor: manualTintColor,
            manualTintIntensity: manualTintIntensity,
            backgroundBlurRadius: backgroundBlurRadius,
            backgroundBlurMaskData: backgroundBlurMaskData,
            preset: preset
        )

        return await ImageElement.previewService.applyFiltersAsync(
            to: preparedImage,
            params: params,
            quality: .preview
        )
    }

    /// プレビュー適用用のフィルターパラメータを生成（filter + manual 合成）
    private static func makePreviewParams(
        toneCurveData: ToneCurveData,
        manualSaturation: CGFloat,
        manualBrightness: CGFloat,
        manualContrast: CGFloat,
        manualHighlights: CGFloat,
        manualShadows: CGFloat,
        manualBlacks: CGFloat,
        manualWhites: CGFloat,
        manualWarmth: CGFloat,
        manualVibrance: CGFloat,
        manualHue: CGFloat,
        manualSharpness: CGFloat,
        manualGaussianBlur: CGFloat,
        manualTintColor: UIColor?,
        manualTintIntensity: CGFloat,
        backgroundBlurRadius: CGFloat,
        backgroundBlurMaskData: Data?,
        preset: FilterPreset
    ) -> ImageFilterParams {
        let recipe = preset.recipe

        // 乗算系: filter_val * manual_val
        let saturation = (recipe.saturation ?? 1.0) * manualSaturation
        let contrast = (recipe.contrast ?? 1.0) * manualContrast

        // 加算系: filter_val + manual_val
        let brightness = (recipe.brightness ?? 0.0) + manualBrightness
        let highlights = (recipe.highlights ?? 0.0) + manualHighlights
        let shadows = (recipe.shadows ?? 0.0) + manualShadows
        let blacks = manualBlacks
        let whites = manualWhites
        let warmth = manualWarmth
        let vibrance = manualVibrance
        let hue = (recipe.hue ?? 0.0) + manualHue
        let sharpness = (recipe.sharpness ?? 0.0) + manualSharpness
        let gaussianBlurRadius = (recipe.gaussianBlur ?? 0.0) + manualGaussianBlur

        // ティント: filter が設定されていれば filter 側を使用
        let tintColor: UIColor?
        let tintIntensity: CGFloat
        if recipe.affectsTint {
            tintColor = recipe.tintColorHex.flatMap { UIColor(hex: $0) }
            tintIntensity = recipe.tintIntensity ?? 0.0
        } else {
            tintColor = manualTintColor
            tintIntensity = manualTintIntensity
        }

        return ImageFilterParams(
            toneCurveData: toneCurveData,
            saturation: saturation,
            brightness: brightness,
            contrast: contrast,
            highlights: highlights,
            shadows: shadows,
            blacks: blacks,
            whites: whites,
            warmth: warmth,
            vibrance: vibrance,
            hue: hue,
            sharpness: sharpness,
            gaussianBlurRadius: gaussianBlurRadius,
            tintColor: tintColor,
            tintIntensity: tintIntensity,
            backgroundBlurRadius: backgroundBlurRadius,
            backgroundBlurMaskData: backgroundBlurMaskData
        )
    }

    /// プレビュー用に画像を縮小
    /// - Parameters:
    ///   - image: 縮小対象の画像
    ///   - targetSize: 目標サイズ
    /// - Returns: 縮小後の画像
    private static func resizedImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let safeWidth = max(1, targetSize.width)
        let safeHeight = max(1, targetSize.height)
        let maxPixelSize = max(safeWidth, safeHeight) * 2

        let sourceSize = image.size
        let maxSourceSide = max(sourceSize.width, sourceSize.height)
        guard maxSourceSide > maxPixelSize else { return image }

        let ratio = maxPixelSize / maxSourceSide
        let resizedSize = CGSize(
            width: max(1, floor(sourceSize.width * ratio)),
            height: max(1, floor(sourceSize.height * ratio))
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: resizedSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: resizedSize))
        }
    }
}
