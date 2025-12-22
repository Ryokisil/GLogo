
// ImageElementの生成を担当するビルダー。
// importOrderを反映し、必要ならcanvasSizeを持たせて初期化する。
// imageRoleに応じたzIndexもここで決定し、UI側の判断を持ち込まない。

import UIKit

// MARK: - Image Element Builder
struct ImageImportElementBuilder {
    func build(from source: ImageImportSource, context: ImageImportContext) -> ImageElement? {
        guard let imageData = source.resolveImageData() else { return nil }

        let importOrder = context.existingImageCount + 1
        let imageElement: ImageElement
        if let canvasSize = context.canvasSize {
            imageElement = ImageElement(imageData: imageData, canvasSize: canvasSize, importOrder: importOrder)
        } else {
            imageElement = ImageElement(imageData: imageData, importOrder: importOrder)
        }

        imageElement.originalImageIdentifier = context.assetIdentifier ?? UUID().uuidString
        applyRoleZIndex(to: imageElement)
        return imageElement
    }

    private func applyRoleZIndex(to element: ImageElement) {
        if element.imageRole == .base {
            element.zIndex = ElementPriority.image.rawValue - 10
        } else {
            element.zIndex = ElementPriority.image.rawValue + 10
        }
    }
}
