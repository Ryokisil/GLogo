// フィルタープリセットのレシピと手動調整値から、描画に渡すパラメータを合成する。

import UIKit

/// 編集画面の描画とプリセットのサムネイルで同じ合成規則を使うための唯一の入口。
/// 規則を2か所で持つと、調整値の追加時に片方だけ更新され見た目がずれるため、ここに集約する。
enum ImageFilterParamsComposer {
    /// - Parameters:
    ///   - values: 要素に設定された手動調整値
    ///   - recipe: 適用中（サムネイルでは候補）のプリセットのレシピ。未適用なら nil
    /// - Returns: 描画サービスへ渡すパラメータ
    static func compose(_ values: ImageAdjustmentValues, recipe: FilterRecipe?) -> ImageFilterParams {
        // 乗算系: レシピ値 × 手動値（既定値 1.0 同士で 1.0）
        let saturation = (recipe?.saturation ?? 1.0) * values.saturation
        let contrast = (recipe?.contrast ?? 1.0) * values.contrast

        // 加算系: レシピ値 + 手動値（既定値 0.0 同士で 0.0）
        let brightness = (recipe?.brightness ?? 0.0) + values.brightness
        let highlights = (recipe?.highlights ?? 0.0) + values.highlights
        let shadows = (recipe?.shadows ?? 0.0) + values.shadows
        let hue = (recipe?.hue ?? 0.0) + values.hue
        let sharpness = (recipe?.sharpness ?? 0.0) + values.sharpness
        let gaussianBlurRadius = (recipe?.gaussianBlur ?? 0.0) + values.gaussianBlurRadius

        // ティント: レシピがティントを持つ場合はレシピ側で置き換える
        let tintColor: UIColor?
        let tintIntensity: CGFloat
        if let recipe, recipe.affectsTint {
            tintColor = recipe.tintColorHex.flatMap { UIColor(hex: $0) }
            tintIntensity = recipe.tintIntensity ?? 0.0
        } else {
            tintColor = values.tintColor
            tintIntensity = values.tintIntensity
        }

        // レシピに項目がない値は手動値をそのまま使う。既定引数に頼らず全項目を明示する。
        return ImageFilterParams(
            toneCurveData: values.toneCurveData,
            saturation: saturation,
            brightness: brightness,
            contrast: contrast,
            highlights: highlights,
            shadows: shadows,
            blacks: values.blacks,
            whites: values.whites,
            warmth: values.warmth,
            vibrance: values.vibrance,
            hue: hue,
            sharpness: sharpness,
            gaussianBlurRadius: gaussianBlurRadius,
            vignetteIntensity: values.vignette,
            bloomIntensity: values.bloom,
            grainIntensity: values.grain,
            fadeIntensity: values.fade,
            chromaticAberrationIntensity: values.chromaticAberration,
            tintColor: tintColor,
            tintIntensity: tintIntensity,
            backgroundBlurRadius: values.backgroundBlurRadius,
            backgroundBlurMaskData: values.backgroundBlurMaskData
        )
    }
}
