// フィルターパネルの選択参照、プリセット操作とプレビュー要求を管理する。

import Combine
import UIKit

/// 選択と画面通知を所有し、編集ルールと描画は UseCase へ委譲する。
@MainActor
final class FilterPanelViewModel: ObservableObject {
    @Published private(set) var imageElement: ImageElement?
    private let edits: ImageEditUseCase
    /// 調整と共有する描画の更新。共有関係をテストで照合するため内部公開にしている。
    let imageRenderRefreshUseCase: ImageRenderRefreshUseCase
    private let imageEditingSessionUseCase = ImageEditingSessionUseCase()
    private var selectionObservation: AnyCancellable?
    private let filterPresetUseCase = FilterPresetUseCase()
    /// サムネイルの元画像と描画サービスの受け取り先
    private let renderSessions: any ImageRenderSessionReading

    var appliedFilterPresetId: String? { imageElement?.appliedFilterPresetId }

    /// refresh は画像調整とフィルターで共有する。selection は MainActor 上で同期通知する。
    init(
        edits: ImageEditUseCase,
        refresh: ImageRenderRefreshUseCase,
        renderSessions: any ImageRenderSessionReading,
        selection: AnyPublisher<LogoElement?, Never>
    ) {
        self.edits = edits
        imageRenderRefreshUseCase = refresh
        self.renderSessions = renderSessions
        selectionObservation = selection.sink { [weak self] element in
            self?.updateSelection(element as? ImageElement)
        }
    }

    private func updateSelection(_ element: ImageElement?) {
        imageRenderRefreshUseCase.cancelInvalidRefresh()
        if imageElement !== element {
            if let imageElement { imageEditingSessionUseCase.endEditing(imageElement) }
            imageRenderRefreshUseCase.cancelScheduledRefresh()
        }
        imageElement = element
    }

    // MARK: - フィルタープリセット適用

    /// フィルタープリセットを適用（レシピを ImageElement に直接設定）
    /// - Parameter preset: 適用するフィルタープリセット
    func applyFilterPreset(_ preset: FilterPreset) {
        guard let imageElement = imageElement else { return }
        guard let plan = filterPresetUseCase.makeApplyPlan(
            preset: preset,
            for: imageElement
        ) else { return }

        edits.applyEvent(plan.event)
        refreshImageAfterFilterPresetChange(imageElement)
    }

    /// フィルタープリセットを解除（manual 調整値は維持）
    func resetFilterPresets() {
        guard let imageElement = imageElement else { return }
        guard let plan = filterPresetUseCase.makeResetPlan(for: imageElement) else { return }

        edits.applyEvent(plan.event)
        refreshImageAfterFilterPresetChange(imageElement)
    }

    /// プリセット変更直後は軽量プレビューを即時表示し、後段で高品質版へ差し替える
    /// - Parameter imageElement: 更新対象の画像要素
    private func refreshImageAfterFilterPresetChange(_ imageElement: ImageElement) {
        imageEditingSessionUseCase.beginEditing(imageElement)
        edits.updateImageElement(imageElement)
        objectWillChange.send()

        imageRenderRefreshUseCase.scheduleFullQualityRefresh(for: imageElement, edits: edits) { [weak self] in
            guard let self, self.imageElement === imageElement else { return }
            self.edits.updateImageElement(imageElement)
            self.objectWillChange.send()
        }
    }

    /// フィルタープリセットのプレビュー画像を生成
    /// - Parameters:
    ///   - preset: プレビューを生成するフィルタープリセット
    ///   - targetSize: サムネイルの目標サイズ
    /// - Returns: 生成したプレビュー画像。生成失敗時は nil
    func generateFilterPreview(for preset: FilterPreset, targetSize: CGSize) async -> UIImage? {
        guard let imageElement = imageElement,
              let sourceImage = renderSessions.originalImage(of: imageElement) else {
            return nil
        }

        return await FilterPreviewUseCase.generatePreview(
            sourceImage: sourceImage,
            adjustments: imageElement.adjustmentValues,
            preset: preset,
            targetSize: targetSize,
            previewService: renderSessions.previewService(of: imageElement)
        )
    }

}
