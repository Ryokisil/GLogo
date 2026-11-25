// 画像フレームの操作受付、プレビューと編集中の開始値を管理する。

import Combine
import UIKit

/// フレームパネルの状態を所有し、確定変更は共通の編集入口へ渡す。
@MainActor
final class ImageFrameViewModel: ObservableObject {
    /// フレームで扱う数値調整に限定し、他の画像調整の開始値と分離する。
    enum Adjustment: CaseIterable {
        case frameWidth
        case cornerRadius

        fileprivate var key: ImageAdjustmentKey {
            switch self {
            case .frameWidth: return .frameWidth
            case .cornerRadius: return .cornerRadius
            }
        }
    }

    @Published private(set) var imageElement: ImageElement?

    private let editor: any ImageFrameEditApplying
    private var selectionObservation: AnyCancellable?
    private var frameColorStartState: UIColor?
    private let imageAdjustmentUseCase = ImageAdjustmentUseCase()
    private let imageEditingSessionUseCase: ImageEditingSessionUseCase
    /// プレビューの反映に使う描画の更新。調整・フィルターとは別のものを受け取る。共有関係をテストで照合するため内部公開にしている。
    let imageRenderRefreshUseCase: ImageRenderRefreshUseCase
    private let metadataEditUseCase: ImageMetadataEditUseCase

    /// - Parameters:
    ///   - editor: 確定操作を提供する UseCase。適用先の編集セッションは UseCase が非所有で参照する。
    ///   - refresh: フレーム用の描画の更新。調整・フィルターと共有しない
    ///   - renderSessions: 編集中の切り替えを求めるエディタの管理役
    ///   - metadataEdits: フレーム値のメタデータ記録
    ///   - selection: 現在値と以後の選択を MainActor 上で同期通知する Publisher。
    init(
        editor: any ImageFrameEditApplying,
        refresh: ImageRenderRefreshUseCase,
        renderSessions: any ImageRenderSessionControlling,
        metadataEdits: ImageMetadataEditUseCase,
        selection: AnyPublisher<LogoElement?, Never>
    ) {
        self.editor = editor
        imageRenderRefreshUseCase = refresh
        imageEditingSessionUseCase = ImageEditingSessionUseCase(renderSessions: renderSessions)
        metadataEditUseCase = metadataEdits
        selectionObservation = selection.sink { [weak self] element in
            self?.updateSelection(element as? ImageElement)
        }
    }

    /// 同じ画像のプレビュー通知では開始値を保ち、選択変更時に旧画像の編集を終了する。
    private func updateSelection(_ element: ImageElement?) {
        if imageElement?.id != element?.id {
            if let imageElement {
                imageEditingSessionUseCase.endEditing(imageElement)
            }
            frameColorStartState = nil
            imageAdjustmentUseCase.reset()
        }
        imageElement = element
    }

    // MARK: - 幅・角丸半径

    func beginAdjustmentEditing(_ adjustment: Adjustment) {
        guard let imageElement,
              let descriptor = ImageAdjustmentDescriptor.all[adjustment.key] else { return }
        imageAdjustmentUseCase.beginAdjustment(
            adjustment.key,
            currentValue: imageElement[keyPath: descriptor.keyPath]
        )
        imageEditingSessionUseCase.applyAdjustmentState(to: imageElement, descriptor: descriptor)
    }

    func updateAdjustment(_ adjustment: Adjustment, value: CGFloat) {
        guard let imageElement,
              let descriptor = ImageAdjustmentDescriptor.all[adjustment.key] else { return }
        imageEditingSessionUseCase.applyAdjustmentState(to: imageElement, descriptor: descriptor)
        guard imageRenderRefreshUseCase.applyAdjustmentPreview(
            value: value,
            to: imageElement,
            descriptor: descriptor
        ) else { return }
        editor.updateImageElement(imageElement)
    }

    func commitAdjustmentEditing(_ adjustment: Adjustment) {
        guard let imageElement,
              let descriptor = ImageAdjustmentDescriptor.all[adjustment.key] else { return }
        imageEditingSessionUseCase.endEditing(imageElement)
        let plan = imageAdjustmentUseCase.makeCommitPlan(
            for: adjustment.key,
            finalValue: imageElement[keyPath: descriptor.keyPath],
            imageElement: imageElement,
            descriptor: descriptor
        )
        if let event = plan.event {
            editor.applyEvent(event)
        }
        metadataEditUseCase.recordEditIfNeeded(
            for: imageElement,
            fieldKey: plan.metadataKey,
            oldValue: plan.oldValue,
            newValue: plan.newValue
        )
        // 幅と角丸半径は遅延描画を使わず、従来どおり確定直後に通知する。
        editor.updateImageElement(imageElement)
    }

    // MARK: - 表示・色・スタイル

    /// フレーム表示の更新
    func updateShowFrame(_ showFrame: Bool) {
        guard let imageElement = imageElement else { return }
        if imageElement.showFrame == showFrame { return }

        let oldValue = imageElement.showFrame
        imageEditingSessionUseCase.beginEditing(imageElement)
        imageElement.showFrame = showFrame

        editor.updateImageShowFrame(imageElement, oldValue: oldValue, newValue: showFrame)

        metadataEditUseCase.recordEditIfNeeded(
            for: imageElement,
            fieldKey: "showFrame",
            oldValue: oldValue,
            newValue: showFrame
        )
    }

    /// フレームの色の更新
    func updateFrameColor(_ color: UIColor) {
        guard let imageElement = imageElement else { return }
        if imageElement.frameColor.isEqual(color) { return }

        let oldColor = imageElement.frameColor
        imageEditingSessionUseCase.beginEditing(imageElement)
        imageElement.frameColor = color

        editor.updateImageFrameColor(imageElement, oldColor: oldColor, newColor: color)

        metadataEditUseCase.recordEditIfNeeded(
            for: imageElement,
            fieldKey: "frameColor",
            oldValue: oldColor.rgbaHexString,
            newValue: color.rgbaHexString
        )
    }

    /// フレーム色編集の開始
    func beginFrameColorEditing() {
        guard let imageElement = imageElement else { return }
        frameColorStartState = imageElement.frameColor
    }

    /// フレーム色編集のプレビュー
    func previewFrameColor(_ color: UIColor) {
        guard let imageElement = imageElement else { return }
        if imageElement.frameColor.isEqual(color) { return }

        imageElement.frameColor = color
        editor.updateImageElement(imageElement)
    }

    /// フレーム色編集の確定
    func commitFrameColorEditing() {
        guard let imageElement = imageElement,
              let startColor = frameColorStartState else { return }
        defer { frameColorStartState = nil }

        if startColor.isEqual(imageElement.frameColor) {
            return
        }

        editor.updateImageFrameColor(
            imageElement,
            oldColor: startColor,
            newColor: imageElement.frameColor
        )
        metadataEditUseCase.recordEditIfNeeded(
            for: imageElement,
            fieldKey: "frameColor",
            oldValue: startColor.rgbaHexString,
            newValue: imageElement.frameColor.rgbaHexString
        )
    }

    /// 角丸の設定の更新
    func updateRoundedCorners(_ rounded: Bool, radius: CGFloat) {
        guard let imageElement = imageElement else { return }
        if imageElement.roundedCorners == rounded && imageElement.cornerRadius == radius { return }

        let wasRounded = imageElement.roundedCorners
        let oldRadius = imageElement.cornerRadius

        imageEditingSessionUseCase.beginEditing(imageElement)
        imageElement.roundedCorners = rounded
        imageElement.cornerRadius = radius

        editor.updateImageRoundedCorners(imageElement, wasRounded: wasRounded, isRounded: rounded, oldRadius: oldRadius, newRadius: radius)

        metadataEditUseCase.recordEditIfNeeded(
            for: imageElement,
            fieldKey: "roundedCorners",
            oldValue: wasRounded,
            newValue: rounded
        )
        metadataEditUseCase.recordEditIfNeeded(
            for: imageElement,
            fieldKey: "cornerRadius",
            oldValue: oldRadius,
            newValue: radius
        )
    }

    /// フレームスタイルの更新
    func updateFrameStyle(_ style: ImageFrameStyle) {
        guard let imageElement = imageElement else { return }
        if imageElement.frameStyle == style && imageElement.showFrame { return }

        let oldStyle = imageElement.frameStyle
        let oldShowFrame = imageElement.showFrame
        let oldColor = imageElement.frameColor

        imageEditingSessionUseCase.beginEditing(imageElement)
        imageElement.frameStyle = style
        imageElement.showFrame = true

        editor.updateImageFrameAppearance(
            imageElement,
            oldShowFrame: oldShowFrame,
            newShowFrame: imageElement.showFrame,
            oldStyle: oldStyle,
            newStyle: style,
            oldColor: oldColor,
            newColor: imageElement.frameColor
        )

        if oldStyle != style {
            metadataEditUseCase.recordEditIfNeeded(
                for: imageElement,
                fieldKey: "frameStyle",
                oldValue: oldStyle.rawValue,
                newValue: style.rawValue
            )
        }
        if oldShowFrame != imageElement.showFrame {
            metadataEditUseCase.recordEditIfNeeded(
                for: imageElement,
                fieldKey: "showFrame",
                oldValue: oldShowFrame,
                newValue: imageElement.showFrame
            )
        }
        if oldColor.isEqual(imageElement.frameColor) == false {
            metadataEditUseCase.recordEditIfNeeded(
                for: imageElement,
                fieldKey: "frameColor",
                oldValue: oldColor.rgbaHexString,
                newValue: imageElement.frameColor.rgbaHexString
            )
        }
    }
}
