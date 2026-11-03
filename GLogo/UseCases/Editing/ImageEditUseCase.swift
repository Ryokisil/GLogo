// 画像属性・加工結果・背景ぼかしの変更を履歴イベントへ変換し、共通の編集適用口へ渡す。

import UIKit

/// 画像編集の確定操作。プロジェクト・選択・履歴スタックは所有しない。
@MainActor
final class ImageEditUseCase: ImageFrameEditApplying, AIImageEditApplying {
    // 編集セッションから保持されるため、適用先を弱参照して循環参照を防ぐ。
    private weak var target: (any ImageEditCommitting)?

    private let backgroundBlurUseCase = BackgroundBlurUseCase()

    init(target: any ImageEditCommitting) {
        self.target = target
    }

    func imageEditToken(for element: ImageElement) -> ImageEditToken? {
        target?.imageEditToken(for: element)
    }

    /// MainActor 上で確認から結果適用まで await を挟まず実行する。
    func isImageEditCurrent(_ token: ImageEditToken, for element: ImageElement) -> Bool {
        target?.imageEditToken(for: element) == token
    }

    /// 履歴を積まないプレビュー変更を共通の編集状態へ反映する。
    func updateImageElement(_ imageElement: ImageElement) {
        target?.updateSelectedElement(imageElement)
    }

    /// 調整 UseCase が生成したイベントは既存の適用順序のまま渡す。
    func applyEvent(_ event: EditorEvent) {
        target?.applyEvent(event)
    }

    // MARK: - 画像要素の操作

    /// 画像のティントカラーを更新
    func updateImageTintColor(_ imageElement: ImageElement, oldColor: UIColor?, newColor: UIColor?, oldIntensity: CGFloat, newIntensity: CGFloat) {

        let event = ImageTintColorChangedEvent(
            elementId: imageElement.id,
            oldColor: oldColor,
            newColor: newColor,
            oldIntensity: oldIntensity,
            newIntensity: newIntensity
        )

        target?.applyEventAndRefreshSelection(event, elementId: imageElement.id)
    }

    /// 画像のフレーム表示を更新
    func updateImageShowFrame(_ imageElement: ImageElement, oldValue: Bool, newValue: Bool) {

        let event = ImageShowFrameChangedEvent(
            elementId: imageElement.id,
            oldValue: oldValue,
            newValue: newValue
        )

        target?.applyEventAndRefreshSelection(event, elementId: imageElement.id)
    }

    /// 画像のフレーム色を更新
    func updateImageFrameColor(_ imageElement: ImageElement, oldColor: UIColor, newColor: UIColor) {

        let event = ImageFrameColorChangedEvent(
            elementId: imageElement.id,
            oldColor: oldColor,
            newColor: newColor
        )

        target?.applyEventAndRefreshSelection(event, elementId: imageElement.id)
    }

    /// 画像のフレーム見た目をまとめて更新
    func updateImageFrameAppearance(
        _ imageElement: ImageElement,
        oldShowFrame: Bool,
        newShowFrame: Bool,
        oldStyle: ImageFrameStyle,
        newStyle: ImageFrameStyle,
        oldColor: UIColor,
        newColor: UIColor
    ) {

        let event = ImageFrameAppearanceChangedEvent(
            elementId: imageElement.id,
            oldShowFrame: oldShowFrame,
            newShowFrame: newShowFrame,
            oldFrameStyle: oldStyle,
            newFrameStyle: newStyle,
            oldFrameColor: oldColor,
            newFrameColor: newColor
        )

        target?.applyEventAndRefreshSelection(event, elementId: imageElement.id)
    }

    /// 画像のフレームスタイルを更新
    func updateImageFrameStyle(_ imageElement: ImageElement, oldStyle: ImageFrameStyle, newStyle: ImageFrameStyle) {

        let event = ImageFrameStyleChangedEvent(
            elementId: imageElement.id,
            oldStyle: oldStyle,
            newStyle: newStyle
        )

        target?.applyEventAndRefreshSelection(event, elementId: imageElement.id)
    }

    /// 画像の角丸設定を更新
    func updateImageRoundedCorners(_ imageElement: ImageElement, wasRounded: Bool, isRounded: Bool, oldRadius: CGFloat, newRadius: CGFloat) {

        let event = ImageRoundedCornersChangedEvent(
            elementId: imageElement.id,
            wasRounded: wasRounded,
            isRounded: isRounded,
            oldRadius: oldRadius,
            newRadius: newRadius
        )

        target?.applyEventAndRefreshSelection(event, elementId: imageElement.id)
    }
    // MARK: - 加工結果の確定

    /// 手動背景除去の結果を画像要素に反映
    /// - Parameters:
    ///   - image: 背景除去後の画像
    ///   - imageElement: 更新対象の画像要素
    /// - Returns: なし
    func applyManualBackgroundRemovalResult(_ image: UIImage, to imageElement: ImageElement) {
        applyReplacedImage(image, to: imageElement, hasAppliedUpscale: imageElement.hasAppliedUpscale)
    }

    /// 高画質化結果を画像要素に反映
    /// - Parameters:
    ///   - image: 高画質化後の画像
    ///   - imageElement: 更新対象の画像要素
    /// - Returns: なし
    func applyUpscaledImageResult(_ image: UIImage, to imageElement: ImageElement) {
        applyReplacedImage(image, to: imageElement, hasAppliedUpscale: true)
    }

    /// 差し替え画像を既存履歴へ反映
    /// - Parameters:
    ///   - image: 差し替え後の画像
    ///   - imageElement: 更新対象の画像要素
    ///   - hasAppliedUpscale: 差し替え後に高画質化済みとして扱うかどうか
    /// - Returns: なし
    private func applyReplacedImage(_ image: UIImage, to imageElement: ImageElement, hasAppliedUpscale: Bool) {
        guard let newImageData = image.pngData() else { return }

        let newOriginalIdentifier = UUID().uuidString
        let event = ImageContentReplacedEvent(
            elementId: imageElement.id,
            oldImageData: imageElement.imageData,
            oldImageFileName: imageElement.imageFileName,
            oldOriginalImageURL: imageElement.originalImageURL,
            oldOriginalImagePath: imageElement.originalImagePath,
            oldOriginalImageIdentifier: imageElement.originalImageIdentifier,
            oldHasAppliedUpscale: imageElement.hasAppliedUpscale,
            oldToneCurveData: imageElement.toneCurveData,
            oldSaturation: imageElement.saturationAdjustment,
            oldBrightness: imageElement.brightnessAdjustment,
            oldContrast: imageElement.contrastAdjustment,
            oldHighlights: imageElement.highlightsAdjustment,
            oldShadows: imageElement.shadowsAdjustment,
            oldBlacks: imageElement.blacksAdjustment,
            oldWhites: imageElement.whitesAdjustment,
            oldWarmth: imageElement.warmthAdjustment,
            oldVibrance: imageElement.vibranceAdjustment,
            oldHue: imageElement.hueAdjustment,
            oldSharpness: imageElement.sharpnessAdjustment,
            oldGaussianBlurRadius: imageElement.gaussianBlurRadius,
            oldVignette: imageElement.vignetteAdjustment,
            oldBloom: imageElement.bloomAdjustment,
            oldGrain: imageElement.grainAdjustment,
            oldFade: imageElement.fadeAdjustment,
            oldChromaticAberration: imageElement.chromaticAberrationAdjustment,
            oldTintIntensity: imageElement.tintIntensity,
            oldTintColor: imageElement.tintColor,
            oldAppliedFilterRecipe: imageElement.appliedFilterRecipe,
            oldAppliedFilterPresetId: imageElement.appliedFilterPresetId,
            newImageData: newImageData,
            newOriginalImageIdentifier: newOriginalIdentifier,
            newHasAppliedUpscale: hasAppliedUpscale
        )

        target?.applyImageEvents([event], elementId: imageElement.id, selectsResult: true)
    }

    /// AI マスクの既存の適用ルールと履歴順序を維持する。
    func applyAIBackgroundBlurMask(_ mask: UIImage, to element: ImageElement) -> Bool {
        guard let plan = backgroundBlurUseCase.makeAIMaskUpdatePlan(maskImage: mask, for: element) else {
            return false
        }
        applyBackgroundBlurPlan(plan, elementId: element.id)
        return true
    }

    /// 背景ぼかしマスク編集の結果を適用
    /// - Parameters:
    ///   - maskData: 編集後のマスクデータ（nilの場合は変更なし）
    ///   - imageElement: 対象の画像要素
    func applyBackgroundBlurMaskResult(_ maskData: Data?, to imageElement: ImageElement) {
        guard let plan = backgroundBlurUseCase.makeMaskUpdatePlan(
            maskData: maskData,
            for: imageElement
        ) else { return }

        applyBackgroundBlurPlan(plan, elementId: imageElement.id)
    }

    /// 背景ぼかしマスクを削除
    /// - Parameter imageElement: 対象の画像要素
    func removeBackgroundBlurMask(from imageElement: ImageElement) {
        guard let plan = backgroundBlurUseCase.makeRemoveMaskPlan(for: imageElement) else { return }
        applyBackgroundBlurPlan(plan, elementId: imageElement.id)
    }

    /// 背景ぼかし更新計画を履歴に適用して UI 状態を同期する
    /// - Parameters:
    ///   - plan: 適用する背景ぼかし更新計画
    ///   - elementId: 同期対象の要素ID
    /// - Returns: なし
    private func applyBackgroundBlurPlan(_ plan: BackgroundBlurUpdatePlan, elementId: UUID) {
        var events: [EditorEvent] = [plan.maskEvent]
        if let radiusEvent = plan.radiusEvent {
            events.append(radiusEvent)
        }
        target?.applyImageEvents(events, elementId: elementId, selectsResult: false)
    }

}
