// 画像要素の生成で使う画像の読み取りを、技術実装から切り離す境界。

import CoreGraphics
import Foundation

/// 画像要素の生成時に、入力データから配置サイズの計算に使う寸法を読み取る。
protocol ImageInitializationLoading {
    /// - Returns: 画像としてデコードできない場合は nil
    func imageSize(imageData: Data) -> CGSize?
}
