// 画像要素の初期状態への Revert、画像内容の差し替え、並び順の変更を記録する履歴イベント。

import UIKit

/// 画像要素を初期状態へ戻すイベント（UndoでRevert前状態へ復元可能）
struct ImageRevertedToInitialStateEvent: EditorEvent {
    let elementId: UUID
    private let beforeState: ImageEditState
    /// メタデータ履歴の巻き戻し先。適用（Redo を含む）のときだけ使う
    private let metadataStore: any ImageMetadataStoring

    var description: String {
        "画像を初期状態に戻しました"
    }

    /// 適用（Redo を含む）では、調整値の初期化に伴う失効（表示画像・プレビュー元画像）と、
    /// 初期状態への戻しに伴う失効（表示画像・元画像）を合わせて行う。プロキシは残す。
    var renderInvalidationsAfterApply: [ImageRenderInvalidation] {
        [
            ImageRenderInvalidation(elementId: elementId, scope: .cache(.adjustments)),
            ImageRenderInvalidation(elementId: elementId, scope: .cache(.revert))
        ]
    }

    /// 巻き戻し（Undo）では、編集値を戻すだけなので表示画像だけを失効させる（元画像・プロキシ・プレビュー元画像は残す）。
    var renderInvalidationsAfterRevert: [ImageRenderInvalidation] {
        [ImageRenderInvalidation(elementId: elementId, scope: .cache(.rendered))]
    }

    /// 初期化
    /// - Parameters:
    ///   - element: Revert対象画像要素
    ///   - metadataStore: メタデータ履歴の巻き戻し先
    init(element: ImageElement, metadataStore: any ImageMetadataStoring) {
        self.elementId = element.id
        self.beforeState = element.editState
        self.metadataStore = metadataStore
    }

    /// Revert操作を適用する
    /// - Parameters:
    ///   - project: 対象プロジェクト
    /// - Returns: なし
    func apply(to project: LogoProject) {
        guard let element = project.element(for: elementId, as: ImageElement.self) else {
            return
        }
        ImageElementMetadataRevertUseCase(store: metadataStore).revertToInitialState(element)
    }

    /// Revert適用前の状態に戻す。メタデータの保存先は操作せず、編集値の復元と表示の失効だけを行う。
    /// - Parameters:
    ///   - project: 対象プロジェクト
    /// - Returns: なし
    func revert(from project: LogoProject) {
        guard let element = project.element(for: elementId, as: ImageElement.self) else {
            return
        }
        element.applyEditState(beforeState)
    }
}

/// 画像内容差し替えイベント（手動背景除去・高画質化の結果適用）
struct ImageContentReplacedEvent: EditorEvent {
    /// 差し替え前の画像ソース。Undo で `restoreImageSource` に渡す。
    private struct Source {
        let imageData: Data?
        let fileName: String?
        let url: URL?
        let path: String?
        let originalIdentifier: String?
        let hasAppliedUpscale: Bool
    }

    let elementId: UUID
    private let oldSource: Source
    /// 差し替え前の編集値。差し替えでは初期スナップショットへ戻すため、Undo で戻す値として記録する。
    private let oldEditState: ImageEditState
    let newImageData: Data
    let newOriginalImageIdentifier: String
    let newHasAppliedUpscale: Bool

    var description: String {
        return "画像内容を差し替えました"
    }

    /// 適用では画像ソースが変わるため、要素の4つのキャッシュと、描画サービスの共有のキャッシュを消す。
    var renderInvalidationsAfterApply: [ImageRenderInvalidation] {
        [ImageRenderInvalidation(elementId: elementId, scope: .sourceChange)]
    }

    /// 巻き戻しでも画像ソースが戻るため、適用と同じ範囲を消す。
    var renderInvalidationsAfterRevert: [ImageRenderInvalidation] {
        renderInvalidationsAfterApply
    }

    /// 差し替え前の画像ソースと編集値を、対象の画像要素から記録する
    /// - Parameters:
    ///   - element: 差し替え対象の画像要素
    ///   - newImageData: 差し替え後の画像データ
    ///   - newOriginalImageIdentifier: 差し替え後の画像識別子
    ///   - newHasAppliedUpscale: 差し替え後に高画質化済みとして扱うかどうか
    init(element: ImageElement, newImageData: Data, newOriginalImageIdentifier: String, newHasAppliedUpscale: Bool) {
        elementId = element.id
        oldSource = Source(
            imageData: element.imageData,
            fileName: element.imageFileName,
            url: element.originalImageURL,
            path: element.originalImagePath,
            originalIdentifier: element.originalImageIdentifier,
            hasAppliedUpscale: element.hasAppliedUpscale
        )
        oldEditState = element.editState
        self.newImageData = newImageData
        self.newOriginalImageIdentifier = newOriginalImageIdentifier
        self.newHasAppliedUpscale = newHasAppliedUpscale
    }

    /// 画像内容を差し替える
    /// - Parameters:
    ///   - project: 対象プロジェクト
    /// - Returns: なし
    func apply(to project: LogoProject) {
        guard let element = project.element(for: elementId, as: ImageElement.self) else {
            return
        }
        // 背景除去の適用ではレイアウトサイズを維持する
        let preservedSize = element.size
        element.replaceImageSource(
            with: newImageData,
            resetAdjustments: true,
            originalIdentifier: newOriginalImageIdentifier,
            hasAppliedUpscale: newHasAppliedUpscale
        )
        element.size = preservedSize
    }

    /// 画像内容を元に戻す
    /// - Parameters:
    ///   - project: 対象プロジェクト
    /// - Returns: なし
    func revert(from project: LogoProject) {
        guard let element = project.element(for: elementId, as: ImageElement.self) else {
            return
        }
        // Undo時も適用前のレイアウトサイズを維持する
        let preservedSize = element.size

        element.restoreImageSource(
            imageData: oldSource.imageData,
            fileName: oldSource.fileName,
            url: oldSource.url,
            path: oldSource.path,
            originalIdentifier: oldSource.originalIdentifier,
            hasAppliedUpscale: oldSource.hasAppliedUpscale
        )
        element.size = preservedSize

        // 差し替えで初期スナップショットへ戻した30項目を、すべて差し替え前の値へ戻す。
        // 描画キャッシュは、巻き戻しの直後に履歴が消す（renderInvalidationsAfterRevert）。
        element.applyEditState(oldEditState)
    }
}

/// 画像要素の並び順一括変更イベント（画像一覧レールでのドラッグ並べ替え用）
struct ImageOrderChangedEvent: EditorEvent {
    /// 変更対象: (要素ID, 旧zIndex, 新zIndex)
    let changes: [(elementId: UUID, oldZIndex: Int, newZIndex: Int)]

    var description: String {
        return "画像の並び順を変更しました"
    }

    func apply(to project: LogoProject) {
        for change in changes {
            guard let element = project.element(for: change.elementId) else { continue }
            element.zIndex = change.newZIndex
        }
    }

    func revert(from project: LogoProject) {
        for change in changes {
            guard let element = project.element(for: change.elementId) else { continue }
            element.zIndex = change.oldZIndex
        }
    }
}
