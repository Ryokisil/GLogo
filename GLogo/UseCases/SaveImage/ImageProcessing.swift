// 保存用のフィルター適用・合成処理の境界を定義する。

import UIKit

/// 画像フィルタ適用・合成処理の抽象。画像要素の画像は、保存の範囲（`images`）から受け取る。
protocol ImageProcessing: Sendable {
    func applyFilters(to imageElement: ImageElement, images: any SaveImageReading) -> UIImage?
    func makeCompositeImage(baseElement: ImageElement, project: LogoProject, images: any SaveImageReading) -> UIImage?
}
