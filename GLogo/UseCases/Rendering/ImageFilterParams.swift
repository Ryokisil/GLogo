// 描画サービスへ渡すフィルターパラメータの値型。

import UIKit

/// フィルタ適用に必要なパラメータをまとめた構造体
struct ImageFilterParams {
    /// トーンカーブデータ
    let toneCurveData: ToneCurveData
    /// 彩度
    let saturation: CGFloat
    /// 明度
    let brightness: CGFloat
    /// コントラスト
    let contrast: CGFloat
    /// ハイライト補正
    let highlights: CGFloat
    /// シャドウ補正
    let shadows: CGFloat
    /// 黒レベル補正
    let blacks: CGFloat
    /// 白レベル補正
    let whites: CGFloat
    /// 色温度補正
    let warmth: CGFloat
    /// ヴィブランス補正
    let vibrance: CGFloat
    /// 色相（度数）
    let hue: CGFloat
    /// シャープネス
    let sharpness: CGFloat
    /// ガウシアンブラー半径
    let gaussianBlurRadius: CGFloat
    /// ビネット強度
    let vignetteIntensity: CGFloat
    /// ブルーム強度
    let bloomIntensity: CGFloat
    /// グレイン強度
    let grainIntensity: CGFloat
    /// フェード強度
    let fadeIntensity: CGFloat
    /// 色収差強度
    let chromaticAberrationIntensity: CGFloat
    /// ティントカラー
    let tintColor: UIColor?
    /// ティント強度
    let tintIntensity: CGFloat
    /// 背景ぼかし半径
    let backgroundBlurRadius: CGFloat
    /// 背景ぼかしマスクデータ（PNG形式）
    let backgroundBlurMaskData: Data?

    /// 便利イニシャライザ（背景ぼかしパラメータなしの場合）
    init(
        toneCurveData: ToneCurveData,
        saturation: CGFloat,
        brightness: CGFloat,
        contrast: CGFloat,
        highlights: CGFloat,
        shadows: CGFloat,
        blacks: CGFloat = 0.0,
        whites: CGFloat = 0.0,
        warmth: CGFloat = 0.0,
        vibrance: CGFloat = 0.0,
        hue: CGFloat,
        sharpness: CGFloat,
        gaussianBlurRadius: CGFloat,
        vignetteIntensity: CGFloat = 0.0,
        bloomIntensity: CGFloat = 0.0,
        grainIntensity: CGFloat = 0.0,
        fadeIntensity: CGFloat = 0.0,
        chromaticAberrationIntensity: CGFloat = 0.0,
        tintColor: UIColor?,
        tintIntensity: CGFloat,
        backgroundBlurRadius: CGFloat = 0.0,
        backgroundBlurMaskData: Data? = nil
    ) {
        self.toneCurveData = toneCurveData
        self.saturation = saturation
        self.brightness = brightness
        self.contrast = contrast
        self.highlights = highlights
        self.shadows = shadows
        self.blacks = blacks
        self.whites = whites
        self.warmth = warmth
        self.vibrance = vibrance
        self.hue = hue
        self.sharpness = sharpness
        self.gaussianBlurRadius = gaussianBlurRadius
        self.vignetteIntensity = vignetteIntensity
        self.bloomIntensity = bloomIntensity
        self.grainIntensity = grainIntensity
        self.fadeIntensity = fadeIntensity
        self.chromaticAberrationIntensity = chromaticAberrationIntensity
        self.tintColor = tintColor
        self.tintIntensity = tintIntensity
        self.backgroundBlurRadius = backgroundBlurRadius
        self.backgroundBlurMaskData = backgroundBlurMaskData
    }
}
