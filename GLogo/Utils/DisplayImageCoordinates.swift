// 表示方向の画像座標を、マスク合成で共通に利用する。

import UIKit
import CoreImage
import ImageIO

enum DisplayImageCoordinates {
    /// UIImage の向きは CGImage に含まれないため、表示座標への変換を明示する。
    /// UIImage.Orientation と EXIF の rawValue は異なるので直接変換しない。
    static func ciImage(from image: UIImage) -> CIImage? {
        guard let rawImage = image.cgImage.map({ CIImage(cgImage: $0) }) ?? image.ciImage else {
            return nil
        }
        let orientation: CGImagePropertyOrientation
        switch image.imageOrientation {
        case .up: orientation = .up
        case .down: orientation = .down
        case .left: orientation = .left
        case .right: orientation = .right
        case .upMirrored: orientation = .upMirrored
        case .downMirrored: orientation = .downMirrored
        case .leftMirrored: orientation = .leftMirrored
        case .rightMirrored: orientation = .rightMirrored
        @unknown default: return nil
        }
        let orientedImage = rawImage.oriented(orientation)
        return orientedImage.transformed(by: CGAffineTransform(
            translationX: -orientedImage.extent.minX,
            y: -orientedImage.extent.minY
        ))
    }
}
