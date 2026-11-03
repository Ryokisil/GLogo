// 保存対象のベース画像を選ぶ処理の境界を定義する。

import Foundation

/// ベース画像要素の選択ロジックの抽象
protocol ImageSelecting: Sendable {
    func selectBaseImageElement(from elements: [ImageElement]) -> ImageElement?
    func selectHighestResolutionImageElement(from elements: [ImageElement]) -> ImageElement?
}
