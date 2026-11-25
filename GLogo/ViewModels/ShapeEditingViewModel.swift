// 図形パネルの選択参照と操作受付を管理し、確定処理を図形 UseCase へ渡す。

import Combine
import UIKit

/// 図形の選択を同期購読し、パネルへ更新を通知する。
@MainActor
final class ShapeEditingViewModel: ObservableObject {
    @Published private(set) var shapeElement: ShapeElement?
    private let edits: ShapeEditUseCase
    private var selectionObservation: AnyCancellable?

    /// selection は現在値と以後の選択を MainActor 上で同期通知する。
    /// edits は共通の編集セッションを弱参照し、子から親の寿命を延長しない。
    init(edits: ShapeEditUseCase, selection: AnyPublisher<LogoElement?, Never>) {
        self.edits = edits
        selectionObservation = selection.sink { [weak self] element in
            self?.shapeElement = element as? ShapeElement
        }
    }

    // MARK: - 図形要素の更新

    /// 図形の種類の更新
    func updateShapeType(_ shapeType: ShapeType) {
        guard let shapeElement = shapeElement else { return }
        if shapeElement.shapeType == shapeType { return }
        edits.updateShapeType(shapeElement, newType: shapeType)
    }

    /// 塗りつぶしモードの更新
    func updateFillMode(_ fillMode: FillMode) {
        guard let shapeElement = shapeElement else { return }
        if shapeElement.fillMode == fillMode { return }
        edits.updateShapeFillMode(shapeElement, newMode: fillMode)
    }

    /// 塗りつぶし色の更新
    func updateFillColor(_ color: UIColor) {
        guard let shapeElement = shapeElement else { return }
        if shapeElement.fillColor.isEqual(color) { return }
        edits.updateShapeFillColor(shapeElement, newColor: color)
    }

    /// グラデーション色の更新
    func updateGradientColors(startColor: UIColor, endColor: UIColor) {
        guard let shapeElement = shapeElement else { return }
        if shapeElement.gradientStartColor.isEqual(startColor) && shapeElement.gradientEndColor.isEqual(endColor) { return }
        edits.updateShapeGradientColors(
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
        edits.updateShapeGradientAngle(shapeElement, newAngle: angle)
    }

    /// 枠線モードの更新
    func updateStrokeMode(_ strokeMode: StrokeMode) {
        guard let shapeElement = shapeElement else { return }
        if shapeElement.strokeMode == strokeMode { return }
        edits.updateShapeStrokeMode(shapeElement, newMode: strokeMode)
    }

    /// 枠線色の更新
    func updateStrokeColor(_ color: UIColor) {
        guard let shapeElement = shapeElement else { return }
        if shapeElement.strokeColor.isEqual(color) { return }
        edits.updateShapeStrokeColor(shapeElement, newColor: color)
    }

    /// 枠線の太さの更新
    func updateStrokeWidth(_ width: CGFloat) {
        guard let shapeElement = shapeElement else { return }
        if shapeElement.strokeWidth == width { return }
        edits.updateShapeStrokeWidth(shapeElement, newWidth: width)
    }

    /// 角丸の半径の更新（図形）
    func updateShapeCornerRadius(_ radius: CGFloat) {
        guard let shapeElement = shapeElement else { return }
        if shapeElement.cornerRadius == radius { return }
        edits.updateShapeCornerRadius(shapeElement, newRadius: radius)
    }

    /// 多角形の辺の数の更新
    func updateSides(_ sides: Int) {
        guard let shapeElement = shapeElement else { return }
        if shapeElement.sides == sides { return }
        edits.updateShapeSides(shapeElement, newSides: sides)
    }

    /// カスタムポイントの更新
    func updateCustomPoints(_ points: [CGPoint]) {
        guard let shapeElement = shapeElement else { return }
        edits.updateCustomPoints(shapeElement, points: points)
    }

}
