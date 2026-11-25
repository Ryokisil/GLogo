// 画像要素に設定された手動の調整値を、描画やサムネイルへ渡す一組の値として表す。

import UIKit

/// フィルタープリセットと合成する前の手動調整値。
/// メモリ上の受け渡し専用で永続化しない。保存形式は `ImageElement` の CodingKeys が引き続き正となる。
/// 調整値を追加したときは、ここと `ImageFilterParamsComposer` を更新すれば描画とサムネイルの両方に反映される。
struct ImageAdjustmentValues: Equatable {
    var saturation: CGFloat
    var brightness: CGFloat
    var contrast: CGFloat
    var highlights: CGFloat
    var shadows: CGFloat
    var blacks: CGFloat
    var whites: CGFloat
    var warmth: CGFloat
    var vibrance: CGFloat
    var hue: CGFloat
    var sharpness: CGFloat
    var gaussianBlurRadius: CGFloat
    var vignette: CGFloat
    var bloom: CGFloat
    var grain: CGFloat
    var fade: CGFloat
    var chromaticAberration: CGFloat
    var toneCurveData: ToneCurveData
    var tintColor: UIColor?
    var tintIntensity: CGFloat
    var backgroundBlurRadius: CGFloat
    var backgroundBlurMaskData: Data?
}
