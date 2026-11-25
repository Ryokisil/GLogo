// テキスト編集から共通の編集状態・履歴へ変更を渡す境界を定義する。

import UIKit

/// プレビューの反映とテキストの確定操作に限定した編集能力。
@MainActor
protocol TextEditApplying: AnyObject {
    func updateTextElement(_ textElement: TextElement)

    func updateTextContent(_ textElement: TextElement, newText: String)

    func updateTextColor(_ textElement: TextElement, newColor: UIColor)

    func updateFont(_ textElement: TextElement, fontName: String, fontSize: CGFloat)

    func updateFont(
        _ textElement: TextElement,
        oldFontName: String,
        newFontName: String,
        oldFontSize: CGFloat,
        newFontSize: CGFloat
    )

    func updateTextLineSpacing(_ textElement: TextElement, oldSpacing: CGFloat, newSpacing: CGFloat)

    func updateTextLetterSpacing(_ textElement: TextElement, oldSpacing: CGFloat, newSpacing: CGFloat)

    func updateTextShadowEffect(
        _ textElement: TextElement,
        effectIndex: Int,
        oldOffset: CGSize,
        newOffset: CGSize,
        oldBlurRadius: CGFloat,
        newBlurRadius: CGFloat
    )

    func updateTextStrokeEffect(
        _ textElement: TextElement,
        effectIndex: Int,
        oldWidth: CGFloat,
        newWidth: CGFloat
    )

    func updateTextGlowEffect(
        _ textElement: TextElement,
        effectIndex: Int,
        oldRadius: CGFloat,
        newRadius: CGFloat
    )

    func updateTextGradientFillColor(
        _ textElement: TextElement,
        effectIndex: Int,
        oldStartColor: UIColor,
        newStartColor: UIColor,
        oldEndColor: UIColor,
        newEndColor: UIColor
    )

    func updateTextGradientFillEffect(
        _ textElement: TextElement,
        effectIndex: Int,
        oldAngle: CGFloat,
        newAngle: CGFloat
    )

    func updateTextGradientFillOpacity(
        _ textElement: TextElement,
        effectIndex: Int,
        oldOpacity: CGFloat,
        newOpacity: CGFloat
    )
}
