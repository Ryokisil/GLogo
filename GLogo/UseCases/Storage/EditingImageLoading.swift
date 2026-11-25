// 編集用プロキシを含む画像取得の境界を定義する。

import UIKit

/// 編集用プロキシを含む画像取得の能力。実装はディスクI/Oとリサイズを担い、Modelから切り離す。
/// 取得の境界（`ImageSourceResolving`）から共有して使うため、Sendable を求める。
protocol EditingImageLoading: Sendable {
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
