// 第18回で保存の境界に足した引数（エディタの管理役・保存の範囲）を、既存テストの呼び出しのために補う入口。
// 補うのは引数だけで、受付での取得と複製の回数は変えない（スナップショットを余分に作らず、要素に注入した偽物もそのまま通す）。
// 新しいテストは、管理役・保存の範囲を明示して渡す。

import UIKit
@testable import GLogo

/// 要素自身のセッションから画像を返す、保存の範囲の代わり。
/// 第18回より前に、選定・加工・合成が要素の API（originalImage・getFilteredImageForce・draw(in:)）から受け取っていた形と同じ。
struct ElementSessionImages: SaveImageReading {
    func originalImage(of element: ImageElement) -> UIImage? {
        element.originalImage
    }

    func filteredImage(of element: ImageElement) -> UIImage? {
        element.getFilteredImageForce()
    }

    func drawingImage(of element: ImageElement) -> UIImage? {
        // 以前の合成が、加工済みの画像を得られなかった画像要素で使った draw(in:) と同じ画像
        element.renderSession.drawingImage(of: element)
    }
}

extension ImageSelectionService {
    func selectHighestResolutionImageElement(from elements: [ImageElement]) -> ImageElement? {
        selectHighestResolutionImageElement(from: elements, images: ElementSessionImages())
    }
}

extension ImageProcessingService {
    func applyFilters(to imageElement: ImageElement) -> UIImage? {
        applyFilters(to: imageElement, images: ElementSessionImages())
    }

    func makeCompositeImage(baseElement: ImageElement, project: LogoProject) -> UIImage? {
        makeCompositeImage(baseElement: baseElement, project: project, images: ElementSessionImages())
    }
}

extension SaveImageCoordinator {
    // アプリの管理役と同じ実装（要素のセッションを返す）を渡す。スナップショットは本体の入口で1つだけ作る。

    @MainActor
    func save(
        project: LogoProject,
        completion: @escaping @MainActor @Sendable (PhotoLibrarySaveResult) -> Void
    ) {
        save(project: project, renderSessions: ImageRenderSessionStore(), completion: completion)
    }

    @MainActor
    func saveComposite(
        project: LogoProject,
        completion: @escaping @MainActor @Sendable (PhotoLibrarySaveResult) -> Void
    ) {
        saveComposite(project: project, renderSessions: ImageRenderSessionStore(), completion: completion)
    }
}

extension ImageSaveViewModel {
    func save(
        project: LogoProject,
        prepare: () -> Void,
        completion: @escaping @MainActor @Sendable (PhotoLibrarySaveResult) -> Void
    ) {
        save(project: project, renderSessions: ImageRenderSessionStore(), prepare: prepare, completion: completion)
    }

    func saveComposite(
        project: LogoProject,
        prepare: () -> Void,
        completion: @escaping @MainActor @Sendable (PhotoLibrarySaveResult) -> Void
    ) {
        saveComposite(project: project, renderSessions: ImageRenderSessionStore(), prepare: prepare, completion: completion)
    }
}
