// 保存用のフィルター適用・合成処理の境界を定義する。

import UIKit

/// 画像フィルタ適用・合成処理の抽象
protocol ImageProcessing: Sendable {
    func applyFilters(to imageElement: ImageElement) -> UIImage?
    func makeCompositeImage(baseElement: ImageElement, project: LogoProject) -> UIImage?
}
