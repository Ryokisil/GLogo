// 要素の変形値（位置・サイズ・回転）と、同時に進行できるジェスチャーの種別を定義する。

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
}

/// 同時に進行できる累積ジェスチャーの種別。
enum ElementGestureTransformKind: Hashable {
    case move, magnify, rotate
}
