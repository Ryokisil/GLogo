// 保存対象のベース画像を選ぶ処理の境界を定義する。

import Foundation

/// ベース画像要素の選択ロジックの抽象。解像度は、保存の範囲（`images`）から受け取った元画像で比べる。
protocol ImageSelecting: Sendable {
    func selectBaseImageElement(from elements: [ImageElement], images: any SaveImageReading) -> ImageElement?
    func selectHighestResolutionImageElement(from elements: [ImageElement], images: any SaveImageReading) -> ImageElement?
}
