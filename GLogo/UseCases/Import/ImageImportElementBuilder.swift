// ImageElementの生成を担当するビルダー。
// importOrderを反映し、必要ならcanvasSizeを持たせて初期化する。
// imageRoleに応じたzIndexもここで決定し、UI側の判断を持ち込まない。

import UIKit

// MARK: - Image Element Builder
struct ImageImportElementBuilder {
    private let elementFactory: ImageElementFactory

    init(
        sourceResolver: any ImageSourceResolving = ImageSourceResolver(),
        previewService: any ImagePreviewing = ImagePreviewService.shared
    ) {
        elementFactory = ImageElementFactory(sourceResolver: sourceResolver, previewService: previewService)
    }

    func build(from source: ImageImportSource, context: ImageImportContext) -> ImageElement? {
        guard let imageData = source.resolveImageData() else { return nil }

        let imageElement = elementFactory.makeElement(
            imageData: imageData,
            canvasSize: context.canvasSize ?? ImageElement.defaultCanvasSize,
            importOrder: context.existingImageCount + 1
        )

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
