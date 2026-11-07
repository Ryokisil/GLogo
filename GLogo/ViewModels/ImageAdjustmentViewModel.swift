// 画像調整の選択参照、開始値とプレビュー・確定の順序を管理する。

import Combine
import UIKit

/// 選択と画面通知を所有し、編集ルールと描画は UseCase へ委譲する。
@MainActor
final class ImageAdjustmentViewModel: ObservableObject {
    @Published private(set) var imageElement: ImageElement?
    private let edits: ImageEditUseCase
    /// フィルターと共有する描画の更新。共有関係をテストで照合するため内部公開にしている。
    let imageRenderRefreshUseCase: ImageRenderRefreshUseCase
    private let imageEditingSessionUseCase = ImageEditingSessionUseCase()
    private var selectionObservation: AnyCancellable?
    private let imageAdjustmentUseCase = ImageAdjustmentUseCase()
    private let metadataEditUseCase: ImageMetadataEditUseCase

    /// refresh は画像調整とフィルターで共有する。selection は MainActor 上で同期通知する。
    init(
        edits: ImageEditUseCase,
        refresh: ImageRenderRefreshUseCase,
        metadataEdits: ImageMetadataEditUseCase,
        selection: AnyPublisher<LogoElement?, Never>
    ) {
        self.edits = edits
        imageRenderRefreshUseCase = refresh
        metadataEditUseCase = metadataEdits
        selectionObservation = selection.sink { [weak self] element in
            self?.updateSelection(element as? ImageElement)
        }
    }

    private func updateSelection(_ element: ImageElement?) {
        if imageElement !== element {
            if let imageElement { imageEditingSessionUseCase.endEditing(imageElement) }
            imageRenderRefreshUseCase.cancelScheduledRefresh()
            imageAdjustmentUseCase.reset()
        }
        imageElement = element
    }

    // MARK: - 画像調整の開始/確定（汎用）

    /// 画像調整スライダーの開始を記録
    private func beginImageAdjustment(
        _ key: ImageAdjustmentKey,
        currentValue: CGFloat,
        descriptor: ImageAdjustmentDescriptor
    ) {
        imageAdjustmentUseCase.beginAdjustment(key, currentValue: currentValue)
        guard let imageElement = imageElement else { return }
        imageEditingSessionUseCase.applyAdjustmentState(
            to: imageElement,
            descriptor: descriptor
        )
    }

    /// 画像調整スライダーの確定（履歴に1件だけ記録）
    private func commitImageAdjustment(
        _ key: ImageAdjustmentKey,
        finalValue: CGFloat,
        descriptor: ImageAdjustmentDescriptor
    ) {
        guard let imageElement = imageElement else { return }

        imageEditingSessionUseCase.endEditing(imageElement)
        let plan = imageAdjustmentUseCase.makeCommitPlan(
            for: key,
            finalValue: finalValue,
            imageElement: imageElement,
            descriptor: descriptor
        )

        if let event = plan.event {
            edits.applyEvent(event)
        }

        metadataEditUseCase.recordEditIfNeeded(
            for: imageElement,
            fieldKey: plan.metadataKey,
            oldValue: plan.oldValue,
            newValue: plan.newValue
        )
    }

    // MARK: - 画像要素の更新（データ駆動型）

    /// 画像調整値のプレビュー更新（スライダー操作中に呼ばれる）
    func updateImageAdjustment(_ key: ImageAdjustmentKey, value: CGFloat) {
        guard let imageElement = imageElement,
              let descriptor = ImageAdjustmentDescriptor.all[key] else { return }

        imageEditingSessionUseCase.applyAdjustmentState(
            to: imageElement,
            descriptor: descriptor
        )
        guard imageRenderRefreshUseCase.applyAdjustmentPreview(
            value: value,
            to: imageElement,
            descriptor: descriptor
        ) else { return }

        imageRenderRefreshUseCase.cancelScheduledRefresh()
        edits.updateImageElement(imageElement)

        // gaussianBlurはRenderScheduler経由で最終品質の再描画を行う
        if descriptor.needsRenderScheduler {
            scheduleFinalRefresh(for: imageElement)
        }
    }

    /// 画像調整の編集開始（onEditingChanged: true 時に呼ばれる）
    func beginImageAdjustmentEditing(_ key: ImageAdjustmentKey) {
        guard let imageElement = imageElement,
              let descriptor = ImageAdjustmentDescriptor.all[key] else { return }
        beginImageAdjustment(
            key,
            currentValue: imageElement[keyPath: descriptor.keyPath],
            descriptor: descriptor
        )
    }

    /// 画像調整の編集確定（onEditingChanged: false 時に呼ばれる）
    func commitImageAdjustmentEditing(_ key: ImageAdjustmentKey) {
        guard let imageElement = imageElement,
              let descriptor = ImageAdjustmentDescriptor.all[key] else { return }
        commitImageAdjustment(
            key,
            finalValue: imageElement[keyPath: descriptor.keyPath],
            descriptor: descriptor
        )

        if descriptor.needsRenderScheduler {
            // 履歴確定も画像世代を進めるため、プレビュー中の予約を確定後の状態で置き換える。
            scheduleFinalRefresh(for: imageElement)
        } else {
            edits.updateImageElement(imageElement)
        }
    }

    /// トーンカーブの更新（プレビュー + 最終品質の2段階処理, RenderSchedulerを利用）
    func updateToneCurveData(_ newData: ToneCurveData) {
        guard let imageElement = imageElement else { return }

        guard imageRenderRefreshUseCase.applyToneCurvePreview(
            newData,
            to: imageElement
        ) else { return }

        imageRenderRefreshUseCase.cancelScheduledRefresh()
        imageEditingSessionUseCase.beginEditing(imageElement)

        edits.updateImageElement(imageElement)

        scheduleFinalRefresh(for: imageElement)
    }

    private func scheduleFinalRefresh(for imageElement: ImageElement) {
        imageRenderRefreshUseCase.scheduleFinalRefresh(
            for: imageElement,
            edits: edits,
            update: { [weak self] in
                guard let self, self.imageElement === imageElement else { return }
                imageEditingSessionUseCase.endEditing(imageElement)
                imageElement.cachedImage = nil
                self.edits.updateImageElement(imageElement)
            }
        )
    }

    /// ティントカラーの更新
    func updateTintColor(_ color: UIColor?, intensity: CGFloat) {
        guard let imageElement = imageElement else { return }

        // 現在と同じ色および強度なら何もしない
        let colorEqual = (color == nil && imageElement.tintColor == nil) ||
        (color != nil && imageElement.tintColor != nil && imageElement.tintColor!.isEqual(color!))
        let intensityEqual = imageElement.tintIntensity == intensity

        if colorEqual && intensityEqual { return }

        let oldColor = imageElement.tintColor
        let oldIntensity = imageElement.tintIntensity

        imageRenderRefreshUseCase.cancelScheduledRefresh()
        imageEditingSessionUseCase.beginEditing(imageElement)
        imageElement.tintColor = color
        imageElement.tintIntensity = intensity

        edits.updateImageTintColor(imageElement, oldColor: oldColor, newColor: color, oldIntensity: oldIntensity, newIntensity: intensity)

        metadataEditUseCase.recordEditIfNeeded(
            for: imageElement,
            fieldKey: "tintColor",
            oldValue: oldColor?.description,
            newValue: color?.description
        )
        metadataEditUseCase.recordEditIfNeeded(
            for: imageElement,
            fieldKey: "tintIntensity",
            oldValue: oldIntensity,
            newValue: intensity
        )
    }

}
