// 第18回で保存の境界に足した引数（エディタの管理役・保存の範囲）と、第26回で足した背景画像の取得先を、
// 既存テストの呼び出しのために補う入口。
// 補うのは引数だけで、受付での取得と複製の回数は変えない（スナップショットを余分に作らず、要素に注入した偽物もそのまま通す）。
// 新しいテストは、管理役・保存の範囲・取得先を明示して渡す。

import UIKit
@testable import GLogo

/// 要素の依存でセッションを作り、そこから画像を返す、保存の範囲の代わり（複製も元画像の固定もしない）。
/// 第18回より前に、選定・加工・合成が要素自身から画像を受け取っていた形に近い。
/// 第21回で要素がセッションを持たなくなったため、この補助の中で要素ごとにセッションを作って持つ。
/// 補助は呼び出しごとに作るため、キャッシュは呼び出しをまたがず、エディタの管理役のキャッシュや編集中の状態も見ない
/// （それに頼るテストは、管理役や保存の範囲を明示して渡す）。
final class ElementSessionImages: SaveImageReading {
    private var sessions: [ObjectIdentifier: (element: ImageElement, session: ImageRenderSession)] = [:]

    func originalImage(of element: ImageElement) -> UIImage? {
        session(of: element).originalImage(of: element)
    }

    func filteredImage(of element: ImageElement) -> UIImage? {
        session(of: element).filteredImage(of: element)
    }

    func drawingImage(of element: ImageElement) -> UIImage? {
        // 以前の合成が、加工済みの画像を得られなかった画像要素で描いた画像と同じ選び方
        session(of: element).drawingImage(of: element)
    }

    /// 背景画像は固定しない（第26回より前に、この補助を使うテストが背景画像を描いていなかった形と同じ）。
    /// 背景画像を描くテストは、保存の範囲（`SaveProjectSnapshot`）を渡す。
    var backgroundImage: UIImage? { nil }

    private func session(of element: ImageElement) -> ImageRenderSession {
        if let entry = sessions[ObjectIdentifier(element)], entry.element === element {
            return entry.session
        }
        let session = ImageRenderSession(sourceResolver: element.sourceResolver, previewService: element.previewService)
        sessions[ObjectIdentifier(element)] = (element, session)
        return session
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

extension SaveProjectSnapshot {
    /// 第26回で足した背景画像の取得先に、アプリと同じ実装を補う（受付での取得の回数と時点は変えない）。
    @MainActor
    convenience init(project: LogoProject, renderSessions: any ImageRenderSessionReading) {
        self.init(
            project: project, renderSessions: renderSessions,
            backgroundImages: AppComposition.makeBackgroundImageLoader()
        )
    }
}

extension SaveImageCoordinator {
    /// 第26回で足した背景画像の取得先に、アプリと同じ実装を補う。
    init(
        policy: SaveImagePolicy = SaveImagePolicy(),
        selectionService: any ImageSelecting = ImageSelectionService(),
        processingService: any ImageProcessing,
        writer: any PhotoLibraryWriting
    ) {
        self.init(
            policy: policy, selectionService: selectionService, processingService: processingService,
            writer: writer, backgroundImages: AppComposition.makeBackgroundImageLoader()
        )
    }

    // アプリと同じ実装の新しい管理役を渡す（元画像は、その管理役が要素の依存で取得する）。スナップショットは本体の入口で1つだけ作る。
    // 呼び出し側のテストは、エディタの管理役のキャッシュや編集中の状態に頼らない（頼るテストは、管理役を明示して渡す）。

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
