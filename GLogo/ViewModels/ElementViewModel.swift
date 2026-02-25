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

    /// EditorViewModel への参照（非所有）
    /// 循環参照を避けるため weak で保持する。
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

    /// テキストサイズ編集の開始値（ドラッグ開始時）
    private var textFontStartState: (name: String, size: CGFloat)?

    /// 行間編集の開始値（ドラッグ開始時）
    private var textLineSpacingStartValue: CGFloat?

    /// 文字間隔編集の開始値（ドラッグ開始時）
    private var textLetterSpacingStartValue: CGFloat?

    /// シャドウ編集の開始値（ドラッグ開始時）
    private var textShadowStartState: (index: Int, offset: CGSize, blurRadius: CGFloat)?

    /// ストローク編集の開始値（ドラッグ開始時）
    private var textStrokeStartState: (index: Int, width: CGFloat)?

    /// グロー編集の開始値（ドラッグ開始時）
    private var textGlowStartState: (index: Int, radius: CGFloat)?

    /// グラデーション塗り編集の開始値（ドラッグ開始時）
    private var textGradientFillStartState: (index: Int, angle: CGFloat)?

    /// グラデーション不透明度編集の開始値（ドラッグ開始時）
    private var textGradientFillOpacityStartState: (index: Int, opacity: CGFloat)?

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
            textFontStartState = nil
            textLineSpacingStartValue = nil
            textLetterSpacingStartValue = nil
            textShadowStartState = nil
            textStrokeStartState = nil
            textGlowStartState = nil
            textGradientFillStartState = nil
            textGradientFillOpacityStartState = nil
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

        // タップ誤検知によるゼロ移動ドラッグを除外し、不要なプレビュー切替を防止
        let hasMeaningfulTranslation: Bool = {
            guard let translation else { return false }
            return abs(translation.width) > 0.5 || abs(translation.height) > 0.5
        }()
        let hasMeaningfulScale: Bool = {
            guard let scale else { return false }
            return abs(scale - 1.0) > 0.001
        }()
        let hasMeaningfulRotation: Bool = {
            guard let rotation else { return false }
            return abs(rotation) > 0.001
        }()
        let hasMeaningfulInput = hasMeaningfulTranslation || hasMeaningfulScale || hasMeaningfulRotation

        // ジェスチャー中で入力が実質ゼロなら無視（選択タップ時の副作用を抑制）
        if !ended && !hasMeaningfulInput { return }

        // 終了イベントだけ飛んできたケースは無視（未開始ジェスチャーの終了）
        if ended, gestureBasePosition == nil, gestureBaseSize == nil, gestureBaseRotation == nil {
            return
        }

        // 画像要素はジェスチャー中にプレビュー品質へ切り替えて操作遅延を抑える
        if let imageElement = element as? ImageElement {
            if ended {
                imageElement.endEditing()
            } else {
                // 調整変更ありの画像はfull経路を維持し、ドラッグ中の色揺れを防止
                if imageElement.shouldUseInstantPreviewForManipulation {
                    imageElement.startEditing()
                } else {
                    imageElement.endEditing()
                }
            }
        }

        // 基準値を保持（ジェスチャー開始時のみ）
        if gestureBasePosition == nil { gestureBasePosition = element.position }
        if gestureBaseSize == nil { gestureBaseSize = element.size }
        if gestureBaseRotation == nil { gestureBaseRotation = element.rotation }

        if let basePos = gestureBasePosition, let delta = translation, hasMeaningfulTranslation {
            element.position = CGPoint(x: basePos.x + delta.width, y: basePos.y + delta.height)
        }

        if let baseSize = gestureBaseSize, let scale = scale, hasMeaningfulScale {
            let clampedScale = max(scale, 0.01) // 極端な縮小を防止
            element.size = CGSize(width: baseSize.width * clampedScale, height: baseSize.height * clampedScale)
        }

        if let baseRot = gestureBaseRotation, let deltaRot = rotation, hasMeaningfulRotation {
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

    /// フォントサイズ編集の開始（onEditingChanged: true 時に呼ばれる）
    /// - Parameters: なし
    /// - Returns: なし
    func beginTextFontSizeEditing() {
        guard let textElement = textElement else { return }
        if textFontStartState == nil {
            textFontStartState = (name: textElement.fontName, size: textElement.fontSize)
        }
    }

    /// フォントサイズのプレビュー更新（スライダー操作中に呼ばれる）
    /// - Parameters:
    ///   - size: プレビュー反映するフォントサイズ
    /// - Returns: なし
    func previewTextFontSize(_ size: CGFloat) {
        guard let textElement = textElement else { return }
        if textElement.fontSize == size { return }
        textElement.fontSize = size
        updateElement(to: textElement)
    }

    /// フォントサイズ編集の確定（onEditingChanged: false 時に呼ばれる）
    /// - Parameters: なし
    /// - Returns: なし
    func commitTextFontSizeEditing() {
        guard let textElement = textElement else { return }
        let startState = textFontStartState ?? (name: textElement.fontName, size: textElement.fontSize)
        textFontStartState = nil

        if startState.name == textElement.fontName && startState.size == textElement.fontSize { return }
        editorViewModel?.updateFont(
            textElement,
            oldFontName: startState.name,
            newFontName: textElement.fontName,
            oldFontSize: startState.size,
            newFontSize: textElement.fontSize
        )
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
        if textElement.lineSpacing == spacing { return }
        editorViewModel?.updateTextLineSpacing(
            textElement,
            oldSpacing: textElement.lineSpacing,
            newSpacing: spacing
        )
    }

    /// 行間編集の開始（onEditingChanged: true 時に呼ばれる）
    /// - Parameters: なし
    /// - Returns: なし
    func beginTextLineSpacingEditing() {
        guard let textElement = textElement else { return }
        if textLineSpacingStartValue == nil {
            textLineSpacingStartValue = textElement.lineSpacing
        }
    }

    /// 行間のプレビュー更新（スライダー操作中に呼ばれる）
    /// - Parameters:
    ///   - spacing: プレビュー反映する行間値
    /// - Returns: なし
    func previewTextLineSpacing(_ spacing: CGFloat) {
        guard let textElement = textElement else { return }
        if textElement.lineSpacing == spacing { return }
        textElement.lineSpacing = spacing
        updateElement(to: textElement)
    }

    /// 行間編集の確定（onEditingChanged: false 時に呼ばれる）
    /// - Parameters: なし
    /// - Returns: なし
    func commitTextLineSpacingEditing() {
        guard let textElement = textElement else { return }
        let startValue = textLineSpacingStartValue ?? textElement.lineSpacing
        textLineSpacingStartValue = nil

        if startValue == textElement.lineSpacing { return }
        editorViewModel?.updateTextLineSpacing(
            textElement,
            oldSpacing: startValue,
            newSpacing: textElement.lineSpacing
        )
    }

    /// 文字間隔の更新
    func updateLetterSpacing(_ spacing: CGFloat) {
        guard let textElement = textElement else { return }
        if textElement.letterSpacing == spacing { return }
        editorViewModel?.updateTextLetterSpacing(
            textElement,
            oldSpacing: textElement.letterSpacing,
            newSpacing: spacing
        )
    }

    /// 文字間隔編集の開始（onEditingChanged: true 時に呼ばれる）
    /// - Parameters: なし
    /// - Returns: なし
    func beginTextLetterSpacingEditing() {
        guard let textElement = textElement else { return }
        if textLetterSpacingStartValue == nil {
            textLetterSpacingStartValue = textElement.letterSpacing
        }
    }

    /// 文字間隔のプレビュー更新（スライダー操作中に呼ばれる）
    /// - Parameters:
    ///   - spacing: プレビュー反映する文字間隔値
    /// - Returns: なし
    func previewTextLetterSpacing(_ spacing: CGFloat) {
        guard let textElement = textElement else { return }
        if textElement.letterSpacing == spacing { return }
        textElement.letterSpacing = spacing
        updateElement(to: textElement)
    }

    /// 文字間隔編集の確定（onEditingChanged: false 時に呼ばれる）
    /// - Parameters: なし
    /// - Returns: なし
    func commitTextLetterSpacingEditing() {
        guard let textElement = textElement else { return }
        let startValue = textLetterSpacingStartValue ?? textElement.letterSpacing
        textLetterSpacingStartValue = nil

        if startValue == textElement.letterSpacing { return }
        editorViewModel?.updateTextLetterSpacing(
            textElement,
            oldSpacing: startValue,
            newSpacing: textElement.letterSpacing
        )
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

    /// シャドウ編集の開始（onEditingChanged: true 時に呼ばれる）
    /// - Parameters:
    ///   - index: 編集対象シャドウ効果のインデックス
    /// - Returns: なし
    func beginShadowEffectEditing(atIndex index: Int) {
        guard let textElement = textElement,
              index < textElement.effects.count,
              let shadowEffect = textElement.effects[index] as? ShadowEffect else { return }

        if textShadowStartState == nil || textShadowStartState?.index != index {
            textShadowStartState = (index: index, offset: shadowEffect.offset, blurRadius: shadowEffect.blurRadius)
        }
    }

    /// シャドウ編集の確定（onEditingChanged: false 時に呼ばれる）
    /// - Parameters:
    ///   - index: 編集対象シャドウ効果のインデックス
    /// - Returns: なし
    func commitShadowEffectEditing(atIndex index: Int) {
        guard let textElement = textElement,
              index < textElement.effects.count,
              let shadowEffect = textElement.effects[index] as? ShadowEffect else {
            textShadowStartState = nil
            return
        }

        let startState: (offset: CGSize, blurRadius: CGFloat)
        if let cachedState = textShadowStartState, cachedState.index == index {
            startState = (offset: cachedState.offset, blurRadius: cachedState.blurRadius)
        } else {
            startState = (offset: shadowEffect.offset, blurRadius: shadowEffect.blurRadius)
        }
        textShadowStartState = nil

        if startState.offset == shadowEffect.offset && startState.blurRadius == shadowEffect.blurRadius {
            return
        }

        editorViewModel?.updateTextShadowEffect(
            textElement,
            effectIndex: index,
            oldOffset: startState.offset,
            newOffset: shadowEffect.offset,
            oldBlurRadius: startState.blurRadius,
            newBlurRadius: shadowEffect.blurRadius
        )
    }

    /// ストローク効果の更新
    func updateStrokeEffect(atIndex index: Int, color: UIColor, width: CGFloat) {
        guard let textElement = textElement, index < textElement.effects.count,
              let strokeEffect = textElement.effects[index] as? StrokeEffect else { return }

        strokeEffect.color = color
        strokeEffect.width = width

        updateElement(to: textElement)
    }

    /// ストローク編集の開始（onEditingChanged: true 時に呼ばれる）
    /// - Parameters:
    ///   - index: 編集対象ストローク効果のインデックス
    /// - Returns: なし
    func beginStrokeEffectEditing(atIndex index: Int) {
        guard let textElement = textElement,
              index < textElement.effects.count,
              let strokeEffect = textElement.effects[index] as? StrokeEffect else { return }

        if textStrokeStartState == nil || textStrokeStartState?.index != index {
            textStrokeStartState = (index: index, width: strokeEffect.width)
        }
    }

    /// ストローク編集の確定（onEditingChanged: false 時に呼ばれる）
    /// - Parameters:
    ///   - index: 編集対象ストローク効果のインデックス
    /// - Returns: なし
    func commitStrokeEffectEditing(atIndex index: Int) {
        guard let textElement = textElement,
              index < textElement.effects.count,
              let strokeEffect = textElement.effects[index] as? StrokeEffect else {
            textStrokeStartState = nil
            return
        }

        let startWidth = textStrokeStartState?.index == index ? textStrokeStartState?.width ?? strokeEffect.width : strokeEffect.width
        textStrokeStartState = nil

        if startWidth == strokeEffect.width {
            return
        }

        editorViewModel?.updateTextStrokeEffect(
            textElement,
            effectIndex: index,
            oldWidth: startWidth,
            newWidth: strokeEffect.width
        )
    }

    /// グロー効果の更新
    func updateGlowEffect(atIndex index: Int, color: UIColor, radius: CGFloat) {
        guard let textElement = textElement, index < textElement.effects.count,
              let glowEffect = textElement.effects[index] as? GlowEffect else { return }

        glowEffect.color = color
        glowEffect.radius = radius

        updateElement(to: textElement)
    }

    /// グロー編集の開始（onEditingChanged: true 時に呼ばれる）
    /// - Parameters:
    ///   - index: 編集対象グロー効果のインデックス
    /// - Returns: なし
    func beginGlowEffectEditing(atIndex index: Int) {
        guard let textElement = textElement,
              index < textElement.effects.count,
              let glowEffect = textElement.effects[index] as? GlowEffect else { return }

        if textGlowStartState == nil || textGlowStartState?.index != index {
            textGlowStartState = (index: index, radius: glowEffect.radius)
        }
    }

    /// グロー編集の確定（onEditingChanged: false 時に呼ばれる）
    /// - Parameters:
    ///   - index: 編集対象グロー効果のインデックス
    /// - Returns: なし
    func commitGlowEffectEditing(atIndex index: Int) {
        guard let textElement = textElement,
              index < textElement.effects.count,
              let glowEffect = textElement.effects[index] as? GlowEffect else {
            textGlowStartState = nil
            return
        }

        let startRadius = textGlowStartState?.index == index ? textGlowStartState?.radius ?? glowEffect.radius : glowEffect.radius
        textGlowStartState = nil

        if startRadius == glowEffect.radius {
            return
        }

        editorViewModel?.updateTextGlowEffect(
            textElement,
            effectIndex: index,
            oldRadius: startRadius,
            newRadius: glowEffect.radius
        )
    }

    /// グラデーション塗り効果の色更新（即時イベント発行）
    func updateGradientFillColor(atIndex index: Int, startColor: UIColor, endColor: UIColor) {
        guard let textElement = textElement, index < textElement.effects.count,
              let gradientEffect = textElement.effects[index] as? GradientFillEffect else { return }

        let oldStartColor = gradientEffect.startColor
        let oldEndColor = gradientEffect.endColor

        // 変更がなければスキップ
        if oldStartColor.isEqual(startColor) && oldEndColor.isEqual(endColor) { return }

        gradientEffect.startColor = startColor
        gradientEffect.endColor = endColor

        editorViewModel?.updateTextGradientFillColor(
            textElement,
            effectIndex: index,
            oldStartColor: oldStartColor,
            newStartColor: startColor,
            oldEndColor: oldEndColor,
            newEndColor: endColor
        )
    }

    /// グラデーション塗り効果の角度更新（プレビュー用、確定は commit で行う）
    func updateGradientFillAngle(atIndex index: Int, angle: CGFloat) {
        guard let textElement = textElement, index < textElement.effects.count,
              let gradientEffect = textElement.effects[index] as? GradientFillEffect else { return }

        gradientEffect.angle = angle

        updateElement(to: textElement)
    }

    /// グラデーション塗り効果の不透明度更新（プレビュー用、確定は commit で行う）
    func updateGradientFillOpacity(atIndex index: Int, opacity: CGFloat) {
        guard let textElement = textElement, index < textElement.effects.count,
              let gradientEffect = textElement.effects[index] as? GradientFillEffect else { return }

        gradientEffect.opacity = opacity

        updateElement(to: textElement)
    }

    /// グラデーション塗り効果の角度を即時確定（リセット等、スライダー外からの呼び出し用）
    func commitGradientFillAngle(atIndex index: Int, angle: CGFloat) {
        guard let textElement = textElement, index < textElement.effects.count,
              let gradientEffect = textElement.effects[index] as? GradientFillEffect else { return }

        let oldAngle = gradientEffect.angle
        if oldAngle == angle { return }

        gradientEffect.angle = angle

        editorViewModel?.updateTextGradientFillEffect(
            textElement,
            effectIndex: index,
            oldAngle: oldAngle,
            newAngle: angle
        )
    }

    /// グラデーション塗り効果の不透明度を即時確定（リセット等、スライダー外からの呼び出し用）
    func commitGradientFillOpacity(atIndex index: Int, opacity: CGFloat) {
        guard let textElement = textElement, index < textElement.effects.count,
              let gradientEffect = textElement.effects[index] as? GradientFillEffect else { return }

        let oldOpacity = gradientEffect.opacity
        if oldOpacity == opacity { return }

        gradientEffect.opacity = opacity

        editorViewModel?.updateTextGradientFillOpacity(
            textElement,
            effectIndex: index,
            oldOpacity: oldOpacity,
            newOpacity: opacity
        )
    }

    /// グラデーション塗り編集の開始（onEditingChanged: true 時に呼ばれる）
    /// - Parameters:
    ///   - index: 編集対象グラデーション効果のインデックス
    func beginGradientFillEffectEditing(atIndex index: Int) {
        guard let textElement = textElement,
              index < textElement.effects.count,
              let gradientEffect = textElement.effects[index] as? GradientFillEffect else { return }

        if textGradientFillStartState == nil || textGradientFillStartState?.index != index {
            textGradientFillStartState = (index: index, angle: gradientEffect.angle)
        }
    }

    /// グラデーション不透明度編集の開始（onEditingChanged: true 時に呼ばれる）
    /// - Parameters:
    ///   - index: 編集対象グラデーション効果のインデックス
    func beginGradientFillOpacityEditing(atIndex index: Int) {
        guard let textElement = textElement,
              index < textElement.effects.count,
              let gradientEffect = textElement.effects[index] as? GradientFillEffect else { return }

        if textGradientFillOpacityStartState == nil || textGradientFillOpacityStartState?.index != index {
            textGradientFillOpacityStartState = (index: index, opacity: gradientEffect.opacity)
        }
    }

    /// グラデーション塗り編集の確定（onEditingChanged: false 時に呼ばれる）
    /// - Parameters:
    ///   - index: 編集対象グラデーション効果のインデックス
    func commitGradientFillEffectEditing(atIndex index: Int) {
        guard let textElement = textElement,
              index < textElement.effects.count,
              let gradientEffect = textElement.effects[index] as? GradientFillEffect else {
            textGradientFillStartState = nil
            return
        }

        let startAngle = textGradientFillStartState?.index == index ? textGradientFillStartState?.angle ?? gradientEffect.angle : gradientEffect.angle
        textGradientFillStartState = nil

        if startAngle == gradientEffect.angle {
            return
        }

        editorViewModel?.updateTextGradientFillEffect(
            textElement,
            effectIndex: index,
            oldAngle: startAngle,
            newAngle: gradientEffect.angle
        )
    }

    /// グラデーション不透明度編集の確定（onEditingChanged: false 時に呼ばれる）
    /// - Parameters:
    ///   - index: 編集対象グラデーション効果のインデックス
    func commitGradientFillOpacityEditing(atIndex index: Int) {
        guard let textElement = textElement,
              index < textElement.effects.count,
              let gradientEffect = textElement.effects[index] as? GradientFillEffect else {
            textGradientFillOpacityStartState = nil
            return
        }

        let startOpacity = textGradientFillOpacityStartState?.index == index
            ? textGradientFillOpacityStartState?.opacity ?? gradientEffect.opacity
            : gradientEffect.opacity
        textGradientFillOpacityStartState = nil

        if startOpacity == gradientEffect.opacity {
            return
        }

        editorViewModel?.updateTextGradientFillOpacity(
            textElement,
            effectIndex: index,
            oldOpacity: startOpacity,
            newOpacity: gradientEffect.opacity
        )
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
    private func beginImageAdjustment(
        _ key: ImageAdjustmentKey,
        currentValue: CGFloat,
        descriptor: ImageAdjustmentDescriptor
    ) {
        if imageAdjustmentStartValues[key] == nil {
            imageAdjustmentStartValues[key] = currentValue
        }
        guard let imageElement = imageElement else { return }
        applyEditingModeForImageAdjustment(imageElement, descriptor: descriptor)
    }

    /// 調整キーに応じて編集中の描画経路を切り替える
    /// - Parameters:
    ///   - imageElement: 対象画像要素
    ///   - descriptor: 調整ディスクリプタ
    /// - Returns: なし
    private func applyEditingModeForImageAdjustment(
        _ imageElement: ImageElement,
        descriptor: ImageAdjustmentDescriptor
    ) {
        if descriptor.usesInstantPreviewWhileEditing {
            imageElement.startEditing()
        } else {
            imageElement.endEditing()
        }
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

        applyEditingModeForImageAdjustment(imageElement, descriptor: descriptor)
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
