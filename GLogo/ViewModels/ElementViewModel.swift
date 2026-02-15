//
//  ElementViewModel.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはエディタ画面の主要なビューモデルを定義しています。
//  プロジェクトの状態管理、要素の追加/選択/編集/削除などの編集操作、
//  要素の移動/リサイズ/回転などの操作処理、操作履歴の管理（イベントソーシングによるアンドゥ/リドゥ）、
//  プロジェクトの保存/読み込み、画像エクスポート機能など、
//  エディタの中核となる機能を提供します。ユーザー操作とモデルの間の橋渡し役を担います。
//

import Foundation
import UIKit
import Combine

/// 要素編集ビューモデル - 選択された要素の編集機能を提供
@MainActor
class ElementViewModel: ObservableObject {
    // MARK: - プロパティ

    /// エディタビューモデルへの弱参照 - 循環参照を防ぐため弱参照で保持。
    /// ElementViewModel　は　EditorViewによって所有され、EditorViewModelとは参照のみの関係を持つ。
    /// この設計により、EditorViewModelが解放されたときに自動的にnilになる。
    private weak var editorViewModel: EditorViewModel?

    /// 現在編集中の要素
    @Published private(set) var element: LogoElement?

    /// 要素の種類
    @Published private(set) var elementType: LogoElementType?

    /// 型変換済みの参照 - LogoElement型から適切なサブクラス型へ一度だけ変換しておくことで、
    /// 元の型を失わずに特定の要素タイプ固有のプロパティやメソッドに直接アクセスできる
    /// これによりビューコードでの毎回の型チェックや変換処理が不要になる
    @Published private(set) var textElement: TextElement?

    /// 図形要素（キャスト済み）
    @Published private(set) var shapeElement: ShapeElement?

    /// 画像要素（キャスト済み）
    @Published private(set) var imageElement: ImageElement?

    /// 購読の保持
    private var cancellables = Set<AnyCancellable>()

    /// 最新のみ実行するレンダリングスケジューラ
    private let renderScheduler = RenderScheduler()

    /// AI処理中フラグ（EditorViewModelの状態を反映）
    @Published var isProcessingAI: Bool = false

    /// 画像調整スライダーの開始値（ドラッグ開始時）
    private var imageAdjustmentStartValues: [ImageAdjustmentKey: CGFloat] = [:]

    /// 現在適用中のフィルタープリセットID（ImageElement から読み出す）
    var appliedFilterPresetId: String? {
        imageElement?.appliedFilterPresetId
    }

    /// ジェスチャー変形用の基準値
    private var gestureBasePosition: CGPoint?
    private var gestureBaseSize: CGSize?
    private var gestureBaseRotation: CGFloat?

    // MARK: - イニシャライザ

    init(editorViewModel: EditorViewModel) {
        self.editorViewModel = editorViewModel

        // エディタの選択要素の変更を監視
        editorViewModel.$selectedElement
            .receive(on: RunLoop.main)
            .sink { [weak self] selectedElement in
                self?.updateElement(selectedElement)
            }
            .store(in: &cancellables)

        // AI処理中フラグを監視
        editorViewModel.$isProcessingAI
            .receive(on: RunLoop.main)
            .sink { [weak self] isProcessing in
                self?.isProcessingAI = isProcessing
            }
            .store(in: &cancellables)
    }

    // MARK: - メソッド

    /// 要素の更新
    private func updateElement(_ element: LogoElement?) {
        // 要素切り替え時にキャッシュをクリアして、別要素への状態持ち越しを防ぐ
        if self.element?.id != element?.id {
            imageAdjustmentStartValues.removeAll()
        }

        self.element = element

        // 要素の種類に基づいて適切な要素にキャスト
        if let textElement = element as? TextElement {
            self.elementType = .text
            self.textElement = textElement
            self.shapeElement = nil
            self.imageElement = nil
        } else if let shapeElement = element as? ShapeElement {
            self.elementType = .shape
            self.textElement = nil
            self.shapeElement = shapeElement
            self.imageElement = nil
        } else if let imageElement = element as? ImageElement {
            self.elementType = .image
            self.textElement = nil
            self.shapeElement = nil
            self.imageElement = imageElement
        } else {
            self.elementType = nil
            self.textElement = nil
            self.shapeElement = nil
            self.imageElement = nil
        }
    }

    // MARK: - 共通プロパティの更新

    /// 位置の更新
    func updatePosition(_ position: CGPoint) {
        guard let element = element else { return }
        element.position = position

        updateElement(to: element)
    }

    /// サイズの更新
    func updateSize(_ size: CGSize) {
        guard let element = element else { return }
        element.size = size

        updateElement(to: element)
    }

    /// 回転の更新
    func updateRotation(_ rotation: CGFloat) {
        guard let element = element else { return }
        element.rotation = rotation

        updateElement(to: element)
    }

    /// ジェスチャーによる変形（移動・拡大縮小・回転）
    func applyGestureTransform(translation: CGSize?, scale: CGFloat?, rotation: CGFloat?, ended: Bool) {
        guard let element = element else { return }

        // 基準値を保持（ジェスチャー開始時のみ）
        if gestureBasePosition == nil { gestureBasePosition = element.position }
        if gestureBaseSize == nil { gestureBaseSize = element.size }
        if gestureBaseRotation == nil { gestureBaseRotation = element.rotation }

        if let basePos = gestureBasePosition, let delta = translation {
            element.position = CGPoint(x: basePos.x + delta.width, y: basePos.y + delta.height)
        }

        if let baseSize = gestureBaseSize, let scale = scale {
            let clampedScale = max(scale, 0.01) // 極端な縮小を防止
            element.size = CGSize(width: baseSize.width * clampedScale, height: baseSize.height * clampedScale)
        }

        if let baseRot = gestureBaseRotation, let deltaRot = rotation {
            element.rotation = baseRot + deltaRot
        }

        updateElement(to: element)

        if ended {
            gestureBasePosition = nil
            gestureBaseSize = nil
            gestureBaseRotation = nil
            editorViewModel?.markProjectModified()
        }
    }


    /// 不透明度の更新
    func updateOpacity(_ opacity: CGFloat) {
        guard let element = element else { return }
        element.opacity = opacity

        updateElement(to: element)
    }

    /// 名前の更新
    func updateName(_ name: String) {
        guard let element = element else { return }
        element.name = name

        updateElement(to: element)
    }

    /// 可視性の更新
    func updateVisibility(_ isVisible: Bool) {
        guard let element = element else { return }
        element.isVisible = isVisible

        updateElement(to: element)
    }

    /// ロック状態の更新
    func updateLock(_ isLocked: Bool) {
        guard let element = element else { return }
        element.isLocked = isLocked

        updateElement(to: element)
    }


    // MARK: - テキスト要素の更新

    /// テキスト内容の更新
    func updateText(_ text: String) {
        guard let textElement = textElement else { return }
        if textElement.text == text { return }
        editorViewModel?.updateTextContent(textElement, newText: text)
    }

    /// フォントの更新
    func updateFont(name: String, size: CGFloat) {
        guard let textElement = textElement else { return }
        if textElement.fontName == name && textElement.fontSize == size { return }
        editorViewModel?.updateFont(textElement, fontName: name, fontSize: size)
    }

    /// テキスト色の更新
    func updateTextColor(_ color: UIColor) {
        guard let textElement = textElement else { return }
        if textElement.textColor.isEqual(color) { return }
        editorViewModel?.updateTextColor(textElement, newColor: color)
    }

    /// テキスト整列の更新
    func updateTextAlignment(_ alignment: TextAlignment) {
        guard let textElement = textElement else { return }
        textElement.alignment = alignment

        updateElement(to: textElement)
    }

    /// 行間の更新
    func updateLineSpacing(_ spacing: CGFloat) {
        guard let textElement = textElement else { return }
        textElement.lineSpacing = spacing

        updateElement(to: textElement)
    }

    /// 文字間隔の更新
    func updateLetterSpacing(_ spacing: CGFloat) {
        guard let textElement = textElement else { return }
        textElement.letterSpacing = spacing

        updateElement(to: textElement)
    }

    /// テキスト効果の追加
    func addTextEffect(_ effect: TextEffect) {
        guard let textElement = textElement else { return }
        textElement.effects.append(effect)

        updateElement(to: textElement)
    }

    /// テキスト効果の削除
    func removeTextEffect(atIndex index: Int) {
        guard let textElement = textElement, index < textElement.effects.count else { return }
        textElement.effects.remove(at: index)

        updateElement(to: textElement)
    }

    /// テキスト効果の更新
    func updateTextEffect(atIndex index: Int, isEnabled: Bool) {
        guard let textElement = textElement, index < textElement.effects.count else { return }
        textElement.effects[index].isEnabled = isEnabled

        updateElement(to: textElement)
    }

    /// シャドウ効果の更新
    func updateShadowEffect(atIndex index: Int, color: UIColor, offset: CGSize, blurRadius: CGFloat) {
        guard let textElement = textElement, index < textElement.effects.count,
              let shadowEffect = textElement.effects[index] as? ShadowEffect else { return }

        shadowEffect.color = color
        shadowEffect.offset = offset
        shadowEffect.blurRadius = blurRadius

        updateElement(to: textElement)
    }

    // MARK: - 図形要素の更新

    /// 図形の種類の更新
    func updateShapeType(_ shapeType: ShapeType) {
        guard let shapeElement = shapeElement else { return }
        if shapeElement.shapeType == shapeType { return }
        editorViewModel?.updateShapeType(shapeElement, newType: shapeType)
    }

    /// 塗りつぶしモードの更新
    func updateFillMode(_ fillMode: FillMode) {
        guard let shapeElement = shapeElement else { return }
        if shapeElement.fillMode == fillMode { return }
        editorViewModel?.updateShapeFillMode(shapeElement, newMode: fillMode)
    }

    /// 塗りつぶし色の更新
    func updateFillColor(_ color: UIColor) {
        guard let shapeElement = shapeElement else { return }
        if shapeElement.fillColor.isEqual(color) { return }
        editorViewModel?.updateShapeFillColor(shapeElement, newColor: color)
    }

    /// グラデーション色の更新
    func updateGradientColors(startColor: UIColor, endColor: UIColor) {
        guard let shapeElement = shapeElement else { return }
        if shapeElement.gradientStartColor.isEqual(startColor) && shapeElement.gradientEndColor.isEqual(endColor) { return }
        editorViewModel?.updateShapeGradientColors(
            shapeElement,
            oldStartColor: shapeElement.gradientStartColor,
            newStartColor: startColor,
            oldEndColor: shapeElement.gradientEndColor,
            newEndColor: endColor
        )
    }

    /// グラデーション角度の更新
    func updateGradientAngle(_ angle: CGFloat) {
        guard let shapeElement = shapeElement else { return }
        if shapeElement.gradientAngle == angle { return }
        editorViewModel?.updateShapeGradientAngle(shapeElement, newAngle: angle)
    }

    /// 枠線モードの更新
    func updateStrokeMode(_ strokeMode: StrokeMode) {
        guard let shapeElement = shapeElement else { return }
        if shapeElement.strokeMode == strokeMode { return }
        editorViewModel?.updateShapeStrokeMode(shapeElement, newMode: strokeMode)
    }

    /// 枠線色の更新
    func updateStrokeColor(_ color: UIColor) {
        guard let shapeElement = shapeElement else { return }
        if shapeElement.strokeColor.isEqual(color) { return }
        editorViewModel?.updateShapeStrokeColor(shapeElement, newColor: color)
    }

    /// 枠線の太さの更新
    func updateStrokeWidth(_ width: CGFloat) {
        guard let shapeElement = shapeElement else { return }
        if shapeElement.strokeWidth == width { return }
        editorViewModel?.updateShapeStrokeWidth(shapeElement, newWidth: width)
    }

    /// 角丸の半径の更新（図形）
    func updateShapeCornerRadius(_ radius: CGFloat) {
        guard let shapeElement = shapeElement else { return }
        if shapeElement.cornerRadius == radius { return }
        editorViewModel?.updateShapeCornerRadius(shapeElement, newRadius: radius)
    }

    /// 多角形の辺の数の更新
    func updateSides(_ sides: Int) {
        guard let shapeElement = shapeElement else { return }
        if shapeElement.sides == sides { return }
        editorViewModel?.updateShapeSides(shapeElement, newSides: sides)
    }

    /// カスタムポイントの更新
    func updateCustomPoints(_ points: [CGPoint]) {
        guard let shapeElement = shapeElement else { return }
        shapeElement.customPoints = points

        updateElement(to: shapeElement)
    }

    // MARK: - 画像調整の開始/確定（汎用）

    /// 画像調整スライダーの開始を記録
    private func beginImageAdjustment(_ key: ImageAdjustmentKey, currentValue: CGFloat) {
        if imageAdjustmentStartValues[key] == nil {
            imageAdjustmentStartValues[key] = currentValue
        }

        imageElement?.startEditing()
    }

    /// 画像調整スライダーの確定（履歴に1件だけ記録）
    private func commitImageAdjustment(
        _ key: ImageAdjustmentKey,
        finalValue: CGFloat,
        eventFactory: (_ oldValue: CGFloat, _ newValue: CGFloat) -> EditorEvent,
        metadataKey: String
    ) {
        guard let imageElement = imageElement else { return }

        let startValue = imageAdjustmentStartValues[key] ?? finalValue
        imageAdjustmentStartValues[key] = nil

        imageElement.endEditing()

        guard startValue != finalValue else { return }

        let event = eventFactory(startValue, finalValue)
        editorViewModel?.applyEvent(event)

        if imageElement.originalImageIdentifier != nil {
            imageElement.recordMetadataEdit(
                fieldKey: metadataKey,
                oldValue: startValue,
                newValue: finalValue
            )
        }
    }

    // MARK: - 画像要素の更新（データ駆動型）

    /// 画像調整値のプレビュー更新（スライダー操作中に呼ばれる）
    func updateImageAdjustment(_ key: ImageAdjustmentKey, value: CGFloat) {
        guard let imageElement = imageElement,
              let descriptor = ImageAdjustmentDescriptor.all[key] else { return }

        // 現在と同じ値なら何もしない
        if imageElement[keyPath: descriptor.keyPath] == value { return }

        imageElement.startEditing()
        imageElement[keyPath: descriptor.keyPath] = value

        editorViewModel?.updateImageElement(imageElement)

        // gaussianBlurはRenderScheduler経由で最終品質の再描画を行う
        if descriptor.needsRenderScheduler {
            renderScheduler.schedule { [weak self] in
                guard let self = self, let imageElement = self.imageElement else { return }
                imageElement.endEditing()
                imageElement.cachedImage = nil
                Task { @MainActor in
                    self.editorViewModel?.updateImageElement(imageElement)
                }
            }
        }
    }

    /// 画像調整の編集開始（onEditingChanged: true 時に呼ばれる）
    func beginImageAdjustmentEditing(_ key: ImageAdjustmentKey) {
        guard let imageElement = imageElement,
              let descriptor = ImageAdjustmentDescriptor.all[key] else { return }
        beginImageAdjustment(key, currentValue: imageElement[keyPath: descriptor.keyPath])
    }

    /// 画像調整の編集確定（onEditingChanged: false 時に呼ばれる）
    func commitImageAdjustmentEditing(_ key: ImageAdjustmentKey) {
        guard let imageElement = imageElement,
              let descriptor = ImageAdjustmentDescriptor.all[key] else { return }
        commitImageAdjustment(
            key,
            finalValue: imageElement[keyPath: descriptor.keyPath],
            eventFactory: { oldValue, newValue in
                descriptor.eventFactory(imageElement, oldValue, newValue)
            },
            metadataKey: descriptor.metadataKey
        )

        // 非gaussianBlurはここで確定状態（非編集）を即時反映する
        if !descriptor.needsRenderScheduler {
            editorViewModel?.updateImageElement(imageElement)
        }
    }

    /// トーンカーブの更新（プレビュー + 最終品質の2段階処理, RenderSchedulerを利用）
    func updateToneCurveData(_ newData: ToneCurveData) {
        guard let imageElement = imageElement else { return }

        imageElement.toneCurveData = newData
        imageElement.startEditing()

        imageElement.cachedImage = nil
        editorViewModel?.updateImageElement(imageElement)

        renderScheduler.schedule { [weak self] in
            guard let self = self, let imageElement = self.imageElement else { return }
            imageElement.endEditing()
            imageElement.cachedImage = nil
            Task { @MainActor in
                self.editorViewModel?.updateImageElement(imageElement)
            }
        }
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

        imageElement.startEditing()
        imageElement.tintColor = color
        imageElement.tintIntensity = intensity

        editorViewModel?.updateImageTintColor(imageElement, oldColor: oldColor, newColor: color, oldIntensity: oldIntensity, newIntensity: intensity)

        if imageElement.originalImageIdentifier != nil {
            imageElement.recordMetadataEdit(
                fieldKey: "tintColor",
                oldValue: oldColor?.description,
                newValue: color?.description
            )
            imageElement.recordMetadataEdit(
                fieldKey: "tintIntensity",
                oldValue: oldIntensity,
                newValue: intensity
            )
        }
    }

    /// フレーム表示の更新
    func updateShowFrame(_ showFrame: Bool) {
        guard let imageElement = imageElement else { return }
        if imageElement.showFrame == showFrame { return }

        let oldValue = imageElement.showFrame
        imageElement.startEditing()
        imageElement.showFrame = showFrame

        editorViewModel?.updateImageShowFrame(imageElement, newValue: showFrame)

        if imageElement.originalImageIdentifier != nil {
            imageElement.recordMetadataEdit(
                fieldKey: "showFrame",
                oldValue: oldValue,
                newValue: showFrame
            )
        }
    }

    /// フレームの色の更新
    func updateFrameColor(_ color: UIColor) {
        guard let imageElement = imageElement else { return }
        if imageElement.frameColor.isEqual(color) { return }

        let oldColor = imageElement.frameColor
        imageElement.startEditing()
        imageElement.frameColor = color

        editorViewModel?.updateImageFrameColor(imageElement, newColor: color)

        if imageElement.originalImageIdentifier != nil {
            imageElement.recordMetadataEdit(
                fieldKey: "frameColor",
                oldValue: oldColor.description,
                newValue: color.description
            )
        }
    }

    /// 角丸の設定の更新
    func updateRoundedCorners(_ rounded: Bool, radius: CGFloat) {
        guard let imageElement = imageElement else { return }
        if imageElement.roundedCorners == rounded && imageElement.cornerRadius == radius { return }

        let wasRounded = imageElement.roundedCorners
        let oldRadius = imageElement.cornerRadius

        imageElement.startEditing()
        imageElement.roundedCorners = rounded
        imageElement.cornerRadius = radius

        editorViewModel?.updateImageRoundedCorners(imageElement, wasRounded: wasRounded, isRounded: rounded, oldRadius: oldRadius, newRadius: radius)

        if imageElement.originalImageIdentifier != nil {
            imageElement.recordMetadataEdit(
                fieldKey: "roundedCorners",
                oldValue: wasRounded,
                newValue: rounded
            )
            imageElement.recordMetadataEdit(
                fieldKey: "cornerRadius",
                oldValue: oldRadius,
                newValue: radius
            )
        }
    }

    // MARK: - フィルタープリセット適用

    /// フィルタープリセットを適用（レシピを ImageElement に直接設定）
    /// - Parameter preset: 適用するフィルタープリセット
    func applyFilterPreset(_ preset: FilterPreset) {
        guard let imageElement = imageElement else { return }

        let oldRecipe = imageElement.appliedFilterRecipe
        let oldPresetId = imageElement.appliedFilterPresetId

        // 同一プリセットが既に適用済みなら何もしない
        guard oldPresetId != preset.id || oldRecipe != preset.recipe else { return }

        // ImageElement に直接設定
        imageElement.appliedFilterRecipe = preset.recipe
        imageElement.appliedFilterPresetId = preset.id
        imageElement.invalidateRenderedImageCache()

        // イベント記録
        let event = FilterPresetChangedEvent(
            elementId: imageElement.id,
            oldRecipe: oldRecipe,
            newRecipe: preset.recipe,
            oldPresetId: oldPresetId,
            newPresetId: preset.id
        )
        editorViewModel?.applyEvent(event)
        editorViewModel?.updateImageElement(imageElement)
        objectWillChange.send()
    }

    /// フィルタープリセットを解除（manual 調整値は維持）
    func resetFilterPresets() {
        guard let imageElement = imageElement else { return }

        let oldRecipe = imageElement.appliedFilterRecipe
        let oldPresetId = imageElement.appliedFilterPresetId
        guard oldRecipe != nil || oldPresetId != nil else { return }

        imageElement.appliedFilterRecipe = nil
        imageElement.appliedFilterPresetId = nil
        imageElement.invalidateRenderedImageCache()

        let event = FilterPresetChangedEvent(
            elementId: imageElement.id,
            oldRecipe: oldRecipe,
            newRecipe: nil,
            oldPresetId: oldPresetId,
            newPresetId: nil
        )
        editorViewModel?.applyEvent(event)
        editorViewModel?.updateImageElement(imageElement)
        objectWillChange.send()
    }

    /// フィルタープリセットのプレビュー画像を生成
    /// - Parameters:
    ///   - preset: プレビューを生成するフィルタープリセット
    ///   - targetSize: サムネイルの目標サイズ
    /// - Returns: 生成したプレビュー画像。生成失敗時は nil
    func generateFilterPreview(for preset: FilterPreset, targetSize: CGSize) async -> UIImage? {
        guard let imageElement = imageElement,
              let sourceImage = imageElement.originalImage else {
            return nil
        }

        return await FilterPreviewUseCase.generatePreview(
            sourceImage: sourceImage,
            toneCurveData: imageElement.toneCurveData,
            manualSaturation: imageElement.saturationAdjustment,
            manualBrightness: imageElement.brightnessAdjustment,
            manualContrast: imageElement.contrastAdjustment,
            manualHighlights: imageElement.highlightsAdjustment,
            manualShadows: imageElement.shadowsAdjustment,
            manualBlacks: imageElement.blacksAdjustment,
            manualWhites: imageElement.whitesAdjustment,
            manualWarmth: imageElement.warmthAdjustment,
            manualVibrance: imageElement.vibranceAdjustment,
            manualHue: imageElement.hueAdjustment,
            manualSharpness: imageElement.sharpnessAdjustment,
            manualGaussianBlur: imageElement.gaussianBlurRadius,
            manualTintColor: imageElement.tintColor,
            manualTintIntensity: imageElement.tintIntensity,
            backgroundBlurRadius: imageElement.backgroundBlurRadius,
            backgroundBlurMaskData: imageElement.backgroundBlurMaskData,
            preset: preset,
            targetSize: targetSize
        )
    }

    // MARK: - 背景除去・背景ぼかし

    /// AI背景除去をリクエスト（ワンタップ）
    func requestAIBackgroundRemoval() {
        guard let imageElement = imageElement else { return }
        editorViewModel?.requestAIBackgroundRemoval(for: imageElement)
    }

    /// AI背景ぼかしをリクエスト
    func requestAIBackgroundBlur() {
        guard let imageElement = imageElement else { return }
        editorViewModel?.requestAIBackgroundBlur(for: imageElement)
    }

    /// 背景ぼかしマスク編集をリクエスト
    func requestBackgroundBlurMaskEdit() {
        guard let imageElement = imageElement else { return }
        editorViewModel?.requestBackgroundBlurMaskEdit(for: imageElement)
    }

    /// 背景ぼかしマスクを削除（EditorViewModelへ委譲）
    func removeBackgroundBlurMask() {
        guard let imageElement = imageElement else { return }
        editorViewModel?.removeBackgroundBlurMask(from: imageElement)
    }

    // MARK: - 更新の適用

    /// 要素を更新してエディタビューモデルに通知
    private func updateElement(to element: LogoElement) {
        // 要素の参照を更新
        self.element = element

        // エディタビューモデルに要素の更新を通知
        if let editorViewModel = editorViewModel {
            editorViewModel.updateSelectedElement(element)

            // 要素の種類に応じて専用の更新メソッドを呼び出す
            if let textElement = element as? TextElement {
                editorViewModel.updateTextElement(textElement)
                self.textElement = textElement
            } else if let shapeElement = element as? ShapeElement {
                editorViewModel.updateShapeElement(shapeElement)
                self.shapeElement = shapeElement
            } else if let imageElement = element as? ImageElement {
                editorViewModel.updateImageElement(imageElement)
                self.imageElement = imageElement
            }
        }
    }
}
