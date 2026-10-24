//
// 概要：UIImageのorientationを反映したピクセル寸法を提供する。
//

import UIKit

extension UIImage {
    /// UIImageのorientation適用後の表示方向における実ピクセルサイズ
    var orientedPixelSize: CGSize {
        CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
    }
}
