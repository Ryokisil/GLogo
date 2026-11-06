// 画像要素の編集値30項目（調整値・トーンカーブ・ティント・背景ぼかし・フィルター・フレーム）を、
// Revert や画像差し替えの Undo の前後で比べるためのテスト用の記録。

import UIKit
@testable import GLogo

/// 編集値30項目を項目のまとまりごとに読み出した値。
/// 色は RGBA の16進表記で比べ、復元時の色変換の有無に左右されないようにする。
struct ImageEditStateRecord: Equatable {
    struct Frame: Equatable {
        var isShown: Bool
        var color: String
        var width: CGFloat
        var style: ImageFrameStyle
        var isRounded: Bool
        var cornerRadius: CGFloat
    }

    /// 17項目の調整値とティント強度。
    var adjustments: [String: CGFloat]
    var toneCurve: ToneCurveData
    var tintColor: String?
    var backgroundBlurRadius: CGFloat
    var backgroundBlurMaskData: Data?
    var filterRecipe: FilterRecipe?
    var filterPresetId: String?
    var frame: Frame

    init(_ element: ImageElement) {
        adjustments = [
            "saturation": element.saturationAdjustment,
            "brightness": element.brightnessAdjustment,
            "contrast": element.contrastAdjustment,
            "highlights": element.highlightsAdjustment,
            "shadows": element.shadowsAdjustment,
            "blacks": element.blacksAdjustment,
            "whites": element.whitesAdjustment,
            "warmth": element.warmthAdjustment,
            "vibrance": element.vibranceAdjustment,
            "hue": element.hueAdjustment,
            "sharpness": element.sharpnessAdjustment,
            "gaussianBlurRadius": element.gaussianBlurRadius,
            "vignette": element.vignetteAdjustment,
            "bloom": element.bloomAdjustment,
            "grain": element.grainAdjustment,
            "fade": element.fadeAdjustment,
            "chromaticAberration": element.chromaticAberrationAdjustment,
            "tintIntensity": element.tintIntensity
        ]
        toneCurve = element.toneCurveData
        tintColor = element.tintColor?.rgbaHexString
        backgroundBlurRadius = element.backgroundBlurRadius
        backgroundBlurMaskData = element.backgroundBlurMaskData
        filterRecipe = element.appliedFilterRecipe
        filterPresetId = element.appliedFilterPresetId
        frame = Frame(
            isShown: element.showFrame,
            color: element.frameColor.rgbaHexString,
            width: element.frameWidth,
            style: element.frameStyle,
            isRounded: element.roundedCorners,
            cornerRadius: element.cornerRadius
        )
    }

    /// 30項目すべてを既定値と異なる値にする。
    /// 保存形式の固定テストは、ティントが赤・フレームがシアンであることを前提に RGBA 成分を書く。
    static func applyDistinctValues(to element: ImageElement) {
        element.saturationAdjustment = 0.31
        element.brightnessAdjustment = 0.12
        element.contrastAdjustment = 1.23
        element.highlightsAdjustment = 0.14
        element.shadowsAdjustment = 0.15
        element.blacksAdjustment = 0.16
        element.whitesAdjustment = 0.17
        element.warmthAdjustment = 18
        element.vibranceAdjustment = 0.19
        element.hueAdjustment = 20
        element.sharpnessAdjustment = 0.21
        element.gaussianBlurRadius = 2.2
        element.vignetteAdjustment = 0.23
        element.bloomAdjustment = 0.24
        element.grainAdjustment = 0.25
        element.fadeAdjustment = 0.26
        element.chromaticAberrationAdjustment = 0.27
        var curve = ToneCurveData()
        curve.rgbPoints[1] = CurvePoint(input: 0.5, output: 0.62)
        element.toneCurveData = curve
        element.tintColor = .red
        element.tintIntensity = 0.28
        element.backgroundBlurRadius = 29
        element.backgroundBlurMaskData = Data([1, 2, 3])
        element.appliedFilterRecipe = FilterCatalog.vintageWarm.recipe
        element.appliedFilterPresetId = FilterCatalog.vintageWarm.id
        element.showFrame = true
        element.frameColor = .cyan
        element.frameWidth = 12
        element.frameStyle = .badge
        element.roundedCorners = true
        element.cornerRadius = 24
    }
}
