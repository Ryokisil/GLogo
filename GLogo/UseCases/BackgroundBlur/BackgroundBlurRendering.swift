// マスクを使って背景だけをぼかす描画の境界を定義する。

import UIKit

/// 前景マスクの外側をぼかした画像を生成する能力。実装は Core Image の処理を持つ。
protocol BackgroundBlurRendering {
    /// - Parameters:
    ///   - image: ぼかし対象の元画像
    ///   - maskData: 前景マスクのPNGデータ
    ///   - radius: 背景ぼかし半径
    /// - Returns: 生成できなかった場合は `nil`
    func applyBackgroundBlur(to image: UIImage, maskData: Data, radius: CGFloat) -> UIImage?
}
