// 変形の確定差分と回転リセットから、既存の履歴イベントを生成する。

import Foundation

struct ElementTransformUseCase {
    /// 変化した属性だけを履歴へ含め、無変更操作は履歴を作らない。
    func commitEvent(from start: ElementTransformState, to element: LogoElement) -> ElementTransformedEvent? {
        let moved = start.position != element.position
        let resized = start.size != element.size
        let rotated = start.rotation != element.rotation
        guard moved || resized || rotated else { return nil }
        return ElementTransformedEvent(
            elementId: element.id,
            oldPosition: moved ? start.position : nil,
            newPosition: moved ? element.position : nil,
            oldSize: resized ? start.size : nil,
            newSize: resized ? element.size : nil,
            oldRotation: rotated ? start.rotation : nil,
            newRotation: rotated ? element.rotation : nil
        )
    }

    /// ジェスチャーで動かした種類の属性だけを履歴へ含める。
    /// 操作中にほかの編集が同じ要素の別の属性を変えても、その変更は変形の履歴に含めず、元の編集の履歴に任せる。
    func commitEvent(
        from start: ElementTransformState,
        to element: LogoElement,
        limitedTo kinds: Set<ElementGestureTransformKind>
    ) -> ElementTransformedEvent? {
        var limitedStart = ElementTransformState(element)
        if kinds.contains(.move) { limitedStart.position = start.position }
        if kinds.contains(.magnify) { limitedStart.size = start.size }
        if kinds.contains(.rotate) { limitedStart.rotation = start.rotation }
        return commitEvent(from: limitedStart, to: element)
    }

    func resetRotationEvent(for element: LogoElement) -> ElementRotatedEvent? {
        guard !element.isLocked, abs(element.rotation) > 0.001 else { return nil }
        return ElementRotatedEvent(elementId: element.id, oldRotation: element.rotation, newRotation: 0)
    }
}
