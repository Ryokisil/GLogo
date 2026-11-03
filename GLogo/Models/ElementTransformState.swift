// 要素の変形値を保持し、座標入力からプレビューの変形値を計算する。

import CoreGraphics

/// 画像データ等を複製せず、変形に必要な値だけを保存するスナップショット。
struct ElementTransformState {
    var position: CGPoint
    var size: CGSize
    var rotation: CGFloat

    init(_ element: LogoElement) {
        position = element.position
        size = element.size
        rotation = element.rotation
    }

    /// 開始値からの累積移動を使う。回転中心は現在の配置を使用する既存仕様を維持する。
    func applying(_ type: ElementManipulationType, from start: CGPoint, to point: CGPoint,
                  current: ElementTransformState) -> ElementTransformState {
        var result = current
        let dx = point.x - start.x
        let dy = point.y - start.y
        switch type {
        case .move:
            result.position = CGPoint(x: position.x + dx, y: position.y + dy)
        case .resize:
            result.size = CGSize(width: max(10, size.width + dx), height: max(10, size.height + dy))
        case .rotate:
            let center = CGPoint(x: current.position.x + current.size.width / 2,
                                 y: current.position.y + current.size.height / 2)
            let delta = atan2(point.y - center.y, point.x - center.x)
                - atan2(start.y - center.y, start.x - center.x)
            result.rotation = rotation + delta
        case .none:
            break
        }
        return result
    }
}

/// 座標入力による変形操作の種別。
enum ElementManipulationType {
    case none, move, resize, rotate
}

/// 同時に進行できる累積ジェスチャーの種別。
enum ElementGestureTransformKind: Hashable {
    case move, magnify, rotate
}
