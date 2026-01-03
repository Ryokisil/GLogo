import UIKit

// 画像インポートの一連の流れを統括するコーディネータ。
// ViewModelから渡された入力と表示条件を使い、UseCase群を組み合わせて
// ImageElementの生成と初期配置までを完了させる。
// UI操作（追加・選択・通知）はViewModelに残す。

struct ImageImportCoordinator {
    private let useCase: ImageImportUseCase

    init(useCase: ImageImportUseCase = ImageImportUseCase()) {
        self.useCase = useCase
    }

    func importImage(
        source: ImageImportSource,
        project: LogoProject,
        viewportSize: CGSize,
        assetIdentifier: String?,
        canvasSize: CGSize? = nil
    ) -> ImageImportResult? {
        let currentImageCount = project.elements.compactMap { $0 as? ImageElement }.count
        let context = ImageImportContext(
            existingImageCount: currentImageCount,
            viewportSize: viewportSize,
            canvasSize: canvasSize,
            assetIdentifier: assetIdentifier
        )

        guard let element = useCase.makeImageElement(from: source, context: context) else {
            return nil
        }

        return ImageImportResult(element: element, assetIdentifier: assetIdentifier)
    }
}
