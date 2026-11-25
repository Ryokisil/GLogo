//
// 概要：ベース画像の選択ロジック。baseロール優先、なければ最大解像度（ピクセル数）を選ぶ。
//

import UIKit

struct ImageSelectionService: ImageSelecting {
    /// 最高解像度（ピクセル数最大）の画像要素を選ぶ。元画像は保存の範囲から受け取る
    func selectHighestResolutionImageElement(from elements: [ImageElement], images: any SaveImageReading) -> ImageElement? {
        var target: ImageElement?
        var maxPixelCount: CGFloat = 0

        for imageElement in elements {
            guard let cgImage = images.originalImage(of: imageElement)?.cgImage else { continue }
            let pixelCount = CGFloat(cgImage.width * cgImage.height)
            if pixelCount > maxPixelCount {
                maxPixelCount = pixelCount
                target = imageElement
            }
        }

        return target
    }

    /// baseロールがあれば優先し、なければ最高解像度を返す
    func selectBaseImageElement(from elements: [ImageElement], images: any SaveImageReading) -> ImageElement? {
        if let base = elements.first(where: { $0.imageRole == .base }) {
            return base
        }

        return selectHighestResolutionImageElement(from: elements, images: images)
    }
}
