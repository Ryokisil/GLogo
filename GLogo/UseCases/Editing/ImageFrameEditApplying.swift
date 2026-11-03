// フレーム編集から共通の編集状態・履歴へ変更を渡す境界を定義する。

import UIKit

/// フレームのプレビュー反映と確定操作に限定した編集能力。
@MainActor
protocol ImageFrameEditApplying: AnyObject {
    func updateImageElement(_ imageElement: ImageElement)

    func updateImageShowFrame(_ imageElement: ImageElement, oldValue: Bool, newValue: Bool)

    func updateImageFrameColor(_ imageElement: ImageElement, oldColor: UIColor, newColor: UIColor)

    func updateImageFrameAppearance(
        _ imageElement: ImageElement,
        oldShowFrame: Bool,
        newShowFrame: Bool,
        oldStyle: ImageFrameStyle,
        newStyle: ImageFrameStyle,
        oldColor: UIColor,
        newColor: UIColor
    )

    func updateImageRoundedCorners(_ imageElement: ImageElement, wasRounded: Bool, isRounded: Bool, oldRadius: CGFloat, newRadius: CGFloat)

    func applyEvent(_ event: EditorEvent)
}
