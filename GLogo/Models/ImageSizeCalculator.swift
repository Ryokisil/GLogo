// キャンバスに対する画像要素の配置サイズを、画像I/Oなしで計算する。

import CoreGraphics

/// 初期化・画像差し替え・履歴復元で共通のサイズ規則。
enum ImageSizeCalculator {
    /// 長辺をキャンバス短辺の15%に合わせ、各辺の最小値を1にする。
    /// UIImage.size相当の寸法を受け取り、拡大も含めて既存の配置規則を維持する。
    static func fittedSize(imageSize: CGSize, canvasSize: CGSize) -> CGSize {
        let maxSize = min(canvasSize.width, canvasSize.height) * 0.15
        let newSize: CGSize
        if imageSize.width > imageSize.height {
            let aspectRatio = imageSize.height / imageSize.width
            newSize = CGSize(width: maxSize, height: maxSize * aspectRatio)
        } else {
            let aspectRatio = imageSize.width / imageSize.height
            newSize = CGSize(width: maxSize * aspectRatio, height: maxSize)
        }
        return CGSize(width: max(1, newSize.width), height: max(1, newSize.height))
    }
}
