// テキストの変更内容から履歴イベントを生成し、共通の編集適用口へ渡す。

import UIKit

/// テキストの確定操作。プロジェクト・選択・履歴スタックは所有しない。
@MainActor
final class TextEditUseCase: TextEditApplying {
    // 編集セッションから保持されるため、適用先を弱参照して循環参照を防ぐ。
    private weak var target: (any ElementEditApplying)?

    init(target: any ElementEditApplying) {
        self.target = target
    }

    /// 履歴を積まないプレビュー変更を共通の編集状態へ反映する。
    func updateTextElement(_ textElement: TextElement) {
        target?.updateSelectedElement(textElement)
    }

    // MARK: - テキスト要素の操作

    /// テキスト内容の更新
    func updateTextContent(_ textElement: TextElement, newText: String) {
        let event = TextContentChangedEvent(
            elementId: textElement.id,
            oldText: textElement.text,
            newText: newText
        )

        target?.applyEventAndRefreshSelection(event, elementId: textElement.id)
    }

    /// テキスト色の更新
    func updateTextColor(_ textElement: TextElement, newColor: UIColor) {

        // 現在と同じ色なら何もしない
        if textElement.textColor.isEqual(newColor) {
            return
        }

        // TextColorChangedEventを作成
        let event = TextColorChangedEvent(
            elementId: textElement.id,
            oldColor: textElement.textColor,
            newColor: newColor
        )

        // イベントを履歴に記録して適用
        target?.applyEventAndRefreshSelection(event, elementId: textElement.id)

    }

    /// フォントの更新
    func updateFont(_ textElement: TextElement, fontName: String, fontSize: CGFloat) {
        if textElement.fontName == fontName && textElement.fontSize == fontSize {
            return
        }

        updateFont(
            textElement,
            oldFontName: textElement.fontName,
            newFontName: fontName,
            oldFontSize: textElement.fontSize,
            newFontSize: fontSize
        )
    }

    /// フォントの更新（旧値を明示指定）
    /// - Parameters:
    ///   - textElement: 更新対象のテキスト要素
    ///   - oldFontName: 変更前フォント名
    ///   - newFontName: 変更後フォント名
    ///   - oldFontSize: 変更前フォントサイズ
    ///   - newFontSize: 変更後フォントサイズ
    /// - Returns: なし
    func updateFont(
        _ textElement: TextElement,
        oldFontName: String,
        newFontName: String,
        oldFontSize: CGFloat,
        newFontSize: CGFloat
    ) {
        if oldFontName == newFontName && oldFontSize == newFontSize {
            return
        }

        let event = FontChangedEvent(
            elementId: textElement.id,
            oldFontName: oldFontName,
            newFontName: newFontName,
            oldFontSize: oldFontSize,
            newFontSize: newFontSize
        )

        target?.applyEventAndRefreshSelection(event, elementId: textElement.id)
    }

    /// 行間の更新
    /// - Parameters:
    ///   - textElement: 更新対象のテキスト要素
    ///   - oldSpacing: 変更前の行間
    ///   - newSpacing: 変更後の行間
    /// - Returns: なし
    func updateTextLineSpacing(_ textElement: TextElement, oldSpacing: CGFloat, newSpacing: CGFloat) {
        if oldSpacing == newSpacing {
            return
        }

        let event = TextLineSpacingChangedEvent(
            elementId: textElement.id,
            oldSpacing: oldSpacing,
            newSpacing: newSpacing
        )

        target?.applyEventAndRefreshSelection(event, elementId: textElement.id)
    }

    /// 文字間隔の更新
    /// - Parameters:
    ///   - textElement: 更新対象のテキスト要素
    ///   - oldSpacing: 変更前の文字間隔
    ///   - newSpacing: 変更後の文字間隔
    /// - Returns: なし
    func updateTextLetterSpacing(_ textElement: TextElement, oldSpacing: CGFloat, newSpacing: CGFloat) {
        if oldSpacing == newSpacing {
            return
        }

        let event = TextLetterSpacingChangedEvent(
            elementId: textElement.id,
            oldSpacing: oldSpacing,
            newSpacing: newSpacing
        )

        target?.applyEventAndRefreshSelection(event, elementId: textElement.id)
    }

    /// シャドウ効果の更新
    /// - Parameters:
    ///   - textElement: 更新対象のテキスト要素
    ///   - effectIndex: 更新対象の効果インデックス
    ///   - oldOffset: 変更前のオフセット
    ///   - newOffset: 変更後のオフセット
    ///   - oldBlurRadius: 変更前のぼかし半径
    ///   - newBlurRadius: 変更後のぼかし半径
    /// - Returns: なし
    func updateTextShadowEffect(
        _ textElement: TextElement,
        effectIndex: Int,
        oldOffset: CGSize,
        newOffset: CGSize,
        oldBlurRadius: CGFloat,
        newBlurRadius: CGFloat
    ) {
        if oldOffset == newOffset && oldBlurRadius == newBlurRadius {
            return
        }

        let event = TextShadowEffectChangedEvent(
            elementId: textElement.id,
            effectIndex: effectIndex,
            oldOffset: oldOffset,
            newOffset: newOffset,
            oldBlurRadius: oldBlurRadius,
            newBlurRadius: newBlurRadius
        )

        target?.applyEventAndRefreshSelection(event, elementId: textElement.id)
    }

    /// ストローク効果の更新
    /// - Parameters:
    ///   - textElement: 更新対象のテキスト要素
    ///   - effectIndex: 更新対象の効果インデックス
    ///   - oldWidth: 変更前の太さ
    ///   - newWidth: 変更後の太さ
    /// - Returns: なし
    func updateTextStrokeEffect(
        _ textElement: TextElement,
        effectIndex: Int,
        oldWidth: CGFloat,
        newWidth: CGFloat
    ) {
        if oldWidth == newWidth {
            return
        }

        let event = TextStrokeEffectChangedEvent(
            elementId: textElement.id,
            effectIndex: effectIndex,
            oldWidth: oldWidth,
            newWidth: newWidth
        )

        target?.applyEventAndRefreshSelection(event, elementId: textElement.id)
    }

    /// グロー効果の更新
    /// - Parameters:
    ///   - textElement: 更新対象のテキスト要素
    ///   - effectIndex: 更新対象の効果インデックス
    ///   - oldRadius: 変更前の半径
    ///   - newRadius: 変更後の半径
    /// - Returns: なし
    func updateTextGlowEffect(
        _ textElement: TextElement,
        effectIndex: Int,
        oldRadius: CGFloat,
        newRadius: CGFloat
    ) {
        if oldRadius == newRadius {
            return
        }

        let event = TextGlowEffectChangedEvent(
            elementId: textElement.id,
            effectIndex: effectIndex,
            oldRadius: oldRadius,
            newRadius: newRadius
        )

        target?.applyEventAndRefreshSelection(event, elementId: textElement.id)
    }

    /// グラデーション塗り効果の色更新
    /// - Parameters:
    ///   - textElement: 更新対象のテキスト要素
    ///   - effectIndex: 更新対象の効果インデックス
    ///   - oldStartColor: 変更前の開始色
    ///   - newStartColor: 変更後の開始色
    ///   - oldEndColor: 変更前の終了色
    ///   - newEndColor: 変更後の終了色
    func updateTextGradientFillColor(
        _ textElement: TextElement,
        effectIndex: Int,
        oldStartColor: UIColor,
        newStartColor: UIColor,
        oldEndColor: UIColor,
        newEndColor: UIColor
    ) {
        let event = TextGradientFillColorChangedEvent(
            elementId: textElement.id,
            effectIndex: effectIndex,
            oldStartColor: oldStartColor,
            newStartColor: newStartColor,
            oldEndColor: oldEndColor,
            newEndColor: newEndColor
        )

        target?.applyEventAndRefreshSelection(event, elementId: textElement.id)
    }

    /// グラデーション塗り効果の角度更新
    /// - Parameters:
    ///   - textElement: 更新対象のテキスト要素
    ///   - effectIndex: 更新対象の効果インデックス
    ///   - oldAngle: 変更前の角度
    ///   - newAngle: 変更後の角度
    func updateTextGradientFillEffect(
        _ textElement: TextElement,
        effectIndex: Int,
        oldAngle: CGFloat,
        newAngle: CGFloat
    ) {
        if oldAngle == newAngle {
            return
        }

        let event = TextGradientFillEffectChangedEvent(
            elementId: textElement.id,
            effectIndex: effectIndex,
            oldAngle: oldAngle,
            newAngle: newAngle
        )

        target?.applyEventAndRefreshSelection(event, elementId: textElement.id)
    }

    /// グラデーション塗り効果の不透明度更新
    /// - Parameters:
    ///   - textElement: 更新対象のテキスト要素
    ///   - effectIndex: 更新対象の効果インデックス
    ///   - oldOpacity: 変更前の不透明度
    ///   - newOpacity: 変更後の不透明度
    func updateTextGradientFillOpacity(
        _ textElement: TextElement,
        effectIndex: Int,
        oldOpacity: CGFloat,
        newOpacity: CGFloat
    ) {
        if oldOpacity == newOpacity {
            return
        }

        let event = TextGradientFillOpacityChangedEvent(
            elementId: textElement.id,
            effectIndex: effectIndex,
            oldOpacity: oldOpacity,
            newOpacity: newOpacity
        )

        target?.applyEventAndRefreshSelection(event, elementId: textElement.id)
    }
}
