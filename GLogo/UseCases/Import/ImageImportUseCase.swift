
// 画像インポートの組み立て手順を統括するユースケース。
// SourceとContextからImageElementを生成し、初期配置まで完了した状態を返す。
// ViewModel側はUIの受け口として呼び出すだけにし、生成ロジックはここに閉じる。

import UIKit

// MARK: - Image Import Use Case
struct ImageImportUseCase {
    private let elementBuilder: ImageImportElementBuilder
    private let placementCalculator: ImageImportPlacementCalculator

    init(
        elementBuilder: ImageImportElementBuilder = ImageImportElementBuilder(),
        placementCalculator: ImageImportPlacementCalculator = ImageImportPlacementCalculator()
    ) {
        self.elementBuilder = elementBuilder
        self.placementCalculator = placementCalculator
    }

    func makeImageElement(from source: ImageImportSource, context: ImageImportContext) -> ImageElement? {
        guard let element = elementBuilder.build(from: source, context: context) else { return nil }
        element.position = placementCalculator.centeredPosition(for: element, viewportSize: context.viewportSize)
        return element
    }
}
