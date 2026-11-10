// 選択中の要素と種類を保持し、要素種別ごとの機能別 ViewModel を組み立てて画面へ提供する。

import Foundation
import UIKit
import Combine

/// 要素編集ビューモデル - 選択された要素の編集機能を提供
@MainActor
class ElementViewModel: ObservableObject {
    // MARK: - プロパティ

    /// 現在編集中の要素
    @Published private(set) var element: LogoElement?

    /// 要素の種類
    @Published private(set) var elementType: LogoElementType?

    /// テキストの表示状態と操作開始値は機能別 ViewModel が所有する。
    let textEditing: TextEditingViewModel

    /// フレームの色・幅・角丸半径の編集状態を所有する。
    let imageFrame: ImageFrameViewModel

    /// 図形の選択参照と操作受付を所有する。
    let shapeEditing: ShapeEditingViewModel

    /// 画像要素（キャスト済み）
    @Published private(set) var imageElement: ImageElement?

    /// 購読の保持
    private var cancellables = Set<AnyCancellable>()

    /// 画像調整とフィルターは表示状態を分け、再描画の順序だけを共有する。
    let imageAdjustment: ImageAdjustmentViewModel
    let filters: FilterPanelViewModel

    /// AI 状態は共有の子から読み、パネル向けに変更通知だけを転送する。
    let aiTools: AIToolsViewModel
    var isProcessingAI: Bool { aiTools.isProcessingAI }
    var isProcessingUpscale: Bool { aiTools.isProcessingUpscale }
    var lastUpscaleErrorMessage: String? { aiTools.lastUpscaleErrorMessage }
    var lastBackgroundRemovalErrorMessage: String? { aiTools.lastBackgroundRemovalErrorMessage }
    var lastBackgroundBlurErrorMessage: String? { aiTools.lastBackgroundBlurErrorMessage }
    var isRealESRGANAvailable: Bool { aiTools.isRealESRGANAvailable }

    /// 高画質化をまだ実行できるかどうか
    var canRequestUpscale: Bool {
        guard let imageElement else { return false }
        return !imageElement.hasAppliedUpscale
    }

    /// Canvas と共有する変形状態。
    let transform: ElementTransformViewModel

    // MARK: - イニシャライザ

    /// - Parameters:
    ///   - editorViewModel: 編集全体の所有者
    ///   - imageRefresh: 調整とフィルターで共有する描画の更新。予約の取り消しを共有する
    ///   - frameImageRefresh: フレーム用の描画の更新。調整・フィルターとは共有しない
    ///   - metadataStore: フレームと調整のメタデータ記録の保存先
    init(
        editorViewModel: EditorViewModel,
        imageRefresh: ImageRenderRefreshUseCase,
        frameImageRefresh: ImageRenderRefreshUseCase,
        metadataStore: any ImageMetadataStoring
    ) {
        aiTools = editorViewModel.aiTools
        transform = editorViewModel.transform
        textEditing = TextEditingViewModel(
            editor: editorViewModel.textEdits,
            selection: editorViewModel.$selectedElement.eraseToAnyPublisher()
        )
        shapeEditing = ShapeEditingViewModel(
            edits: editorViewModel.shapeEdits,
            selection: editorViewModel.$selectedElement.eraseToAnyPublisher()
        )
        imageFrame = ImageFrameViewModel(
            editor: editorViewModel.imageEdits,
            refresh: frameImageRefresh,
            metadataEdits: ImageMetadataEditUseCase(store: metadataStore),
            selection: editorViewModel.$selectedElement.eraseToAnyPublisher()
        )

        imageAdjustment = ImageAdjustmentViewModel(
            edits: editorViewModel.imageEdits, refresh: imageRefresh,
            metadataEdits: ImageMetadataEditUseCase(store: metadataStore),
            selection: editorViewModel.$selectedElement.eraseToAnyPublisher()
        )
        filters = FilterPanelViewModel(
            edits: editorViewModel.imageEdits, refresh: imageRefresh,
            renderSessions: editorViewModel.renderSessions,
            selection: editorViewModel.$selectedElement.eraseToAnyPublisher()
        )

        // EditorはMainActor上で通知する。次の操作が旧要素を編集しないよう同期反映する。
        editorViewModel.$selectedElement
            .sink { [weak self] selectedElement in
                self?.updateElement(selectedElement)
            }
            .store(in: &cancellables)

        aiTools.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - メソッド

    /// 要素の更新
    private func updateElement(_ element: LogoElement?) {
        self.element = element

        // 要素の種類に基づいて適切な要素にキャスト
        if element is TextElement {
            self.elementType = .text
            self.imageElement = nil
        } else if element is ShapeElement {
            self.elementType = .shape
            self.imageElement = nil
        } else if let imageElement = element as? ImageElement {
            self.elementType = .image
            self.imageElement = imageElement
        } else {
            self.elementType = nil
            self.imageElement = nil
        }
    }

    // MARK: - 背景除去・背景ぼかし

    /// AI背景除去をリクエスト（ワンタップ）
    func requestAIBackgroundRemoval() {
        guard let imageElement = imageElement else { return }
        aiTools.requestAIBackgroundRemoval(for: imageElement)
    }

    /// AI背景ぼかしをリクエスト
    func requestAIBackgroundBlur() {
        guard let imageElement = imageElement else { return }
        aiTools.requestAIBackgroundBlur(for: imageElement)
    }

    /// 高画質化を要求する
    /// - Parameters: なし
    /// - Returns: なし
    func requestImageUpscale() {
        guard let imageElement = imageElement else { return }
        aiTools.requestImageUpscale(for: imageElement)
    }

    /// 高画質化エラー表示をクリアする
    /// - Parameters: なし
    /// - Returns: なし
    func clearUpscaleError() {
        aiTools.clearUpscaleError()
    }

    /// AI 背景除去エラーメッセージをクリア（AI 状態の所有者へ委譲）
    func clearBackgroundRemovalError() {
        aiTools.clearBackgroundRemovalError()
    }

    /// AI 背景ぼかしエラーメッセージをクリア（AI 状態の所有者へ委譲）
    func clearBackgroundBlurError() {
        aiTools.clearBackgroundBlurError()
    }

    /// 背景ぼかしマスク編集をリクエスト
    func requestBackgroundBlurMaskEdit() {
        guard let imageElement = imageElement else { return }
        aiTools.requestBackgroundBlurMaskEdit(for: imageElement)
    }

    /// 背景ぼかしマスクを削除（AI 状態の所有者へ委譲）
    func removeBackgroundBlurMask() {
        guard let imageElement = imageElement else { return }
        aiTools.removeBackgroundBlurMask(from: imageElement)
    }

}
