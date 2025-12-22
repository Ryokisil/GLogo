
// ビューポート内の初期配置を計算する責務を持つ。
// ImageElementのサイズを考慮して、可視領域の中心付近に収まる座標を返す。
// 表示ロジックはここに集約し、ViewModelは配置の詳細を持たない。

import UIKit

// MARK: - Image Placement Calculator
struct ImageImportPlacementCalculator {
    func centeredPosition(for element: ImageElement, viewportSize: CGSize) -> CGPoint {
        let viewportCenter = CGPoint(
            x: viewportSize.width / 2,
            y: viewportSize.height / 4
        )

        return CGPoint(
            x: viewportCenter.x - element.size.width / 2,
            y: viewportCenter.y - element.size.height / 2
        )
    }
}
