// 背景ぼかし描画の境界を、既存の Core Image フィルター処理で実装する。

import UIKit

/// 編集画面の描画と同じフィルター処理を使い、手動編集のプレビューと仕上がりを一致させる。
struct CoreImageBackgroundBlurRenderer: BackgroundBlurRendering {
    func applyBackgroundBlur(to image: UIImage, maskData: Data, radius: CGFloat) -> UIImage? {
        ImageFilterUtility.applyBackgroundBlur(to: image, maskData: maskData, radius: radius)
    }
}
