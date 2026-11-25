// テキスト編集の操作受付、プレビューと操作開始値の寿命を管理する。

import Combine
import UIKit

/// テキストパネルの状態を所有し、確定変更は共通の編集入口へ渡す。
@MainActor
final class TextEditingViewModel: ObservableObject {
    @Published private(set) var textElement: TextElement?

    private let editor: any TextEditApplying
    private var selectionObservation: AnyCancellable?

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

    /// - Parameters:
    ///   - editor: 確定操作を提供する UseCase。適用先の編集セッションは UseCase が非所有で参照する。
    ///   - selection: 現在値と以後の選択を MainActor 上で同期通知する Publisher。
    init(editor: any TextEditApplying, selection: AnyPublisher<LogoElement?, Never>) {
        self.editor = editor
        // 選択は MainActor から同期通知される。遅延させると選択直後の確定が旧要素へ届く。
        selectionObservation = selection.sink { [weak self] element in
            self?.updateSelection(element as? TextElement)
        }
    }

    /// 同じ要素のプレビュー通知では開始値を維持し、選択変更時だけ破棄する。
    private func updateSelection(_ element: TextElement?) {
        if textElement?.id != element?.id {
            textFontStartState = nil
            textLineSpacingStartValue = nil
            textLetterSpacingStartValue = nil
            textShadowStartState = nil
            textStrokeStartState = nil
            textGlowStartState = nil
            textGradientFillStartState = nil
            textGradientFillOpacityStartState = nil
        }
        textElement = element
    }

    /// 参照型のプロパティ変更もパネルへ通知し、共通の変更フラグを更新する。
    private func updateElement(to element: TextElement) {
        textElement = element
        editor.updateTextElement(element)
    }

    // MARK: - テキスト要素の更新

    /// テキスト内容の更新
    func updateText(_ text: String) {
        guard let textElement = textElement else { return }
        if textElement.text == text { return }
        editor.updateTextContent(textElement, newText: text)
    }

    /// フォントの更新
    func updateFont(name: String, size: CGFloat) {
        guard let textElement = textElement else { return }
        if textElement.fontName == name && textElement.fontSize == size { return }
        editor.updateFont(textElement, fontName: name, fontSize: size)
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
        editor.updateFont(
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
        editor.updateTextColor(textElement, newColor: color)
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
        editor.updateTextLineSpacing(
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
        editor.updateTextLineSpacing(
            textElement,
            oldSpacing: startValue,
            newSpacing: textElement.lineSpacing
        )
    }

    /// 文字間隔の更新
    func updateLetterSpacing(_ spacing: CGFloat) {
        guard let textElement = textElement else { return }
        if textElement.letterSpacing == spacing { return }
        editor.updateTextLetterSpacing(
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
        editor.updateTextLetterSpacing(
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

        editor.updateTextShadowEffect(
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

        editor.updateTextStrokeEffect(
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

        editor.updateTextGlowEffect(
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

        editor.updateTextGradientFillColor(
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

        editor.updateTextGradientFillEffect(
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

        editor.updateTextGradientFillOpacity(
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

        editor.updateTextGradientFillEffect(
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

        editor.updateTextGradientFillOpacity(
            textElement,
            effectIndex: index,
            oldOpacity: startOpacity,
            newOpacity: gradientEffect.opacity
        )
    }
}
