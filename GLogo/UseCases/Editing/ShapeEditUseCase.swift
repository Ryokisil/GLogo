// 図形の変更内容から履歴イベントを生成し、共通の編集適用口へ渡す。

import UIKit

/// 図形の確定操作。プロジェクト・選択・履歴スタックは所有しない。
@MainActor
final class ShapeEditUseCase {
    // 編集セッションから保持されるため、適用先を弱参照して循環参照を防ぐ。
    private weak var target: (any ElementEditApplying)?

    init(target: any ElementEditApplying) {
        self.target = target
    }

    /// カスタム頂点は既存どおり履歴を積まずに反映する。
    func updateCustomPoints(_ shapeElement: ShapeElement, points: [CGPoint]) {
        shapeElement.customPoints = points
        target?.updateSelectedElement(shapeElement)
    }

    // MARK: - 図形の操作

    /// 図形タイプの更新
    func updateShapeType(_ shapeElement: ShapeElement, newType: ShapeType) {

        // 図形タイプ変更イベントの作成
        let event = ShapeTypeChangedEvent(
            elementId: shapeElement.id,
            oldType: shapeElement.shapeType,
            newType: newType
        )

        // イベントを履歴に記録して適用
        target?.applyEventAndRefreshSelection(event, elementId: shapeElement.id)
    }

    /// 図形の塗りつぶし色を更新
    func updateShapeFillColor(_ shapeElement: ShapeElement, newColor: UIColor) {

        let event = ShapeFillColorChangedEvent(
            elementId: shapeElement.id,
            oldColor: shapeElement.fillColor,
            newColor: newColor
        )

        target?.applyEventAndRefreshSelection(event, elementId: shapeElement.id)
    }

    /// 図形の塗りつぶしモードを更新
    func updateShapeFillMode(_ shapeElement: ShapeElement, newMode: FillMode) {

        let event = ShapeFillModeChangedEvent(
            elementId: shapeElement.id,
            oldMode: shapeElement.fillMode,
            newMode: newMode
        )

        target?.applyEventAndRefreshSelection(event, elementId: shapeElement.id)
    }

    /// 図形の枠線色を更新
    func updateShapeStrokeColor(_ shapeElement: ShapeElement, newColor: UIColor) {

        let event = ShapeStrokeColorChangedEvent(
            elementId: shapeElement.id,
            oldColor: shapeElement.strokeColor,
            newColor: newColor
        )

        target?.applyEventAndRefreshSelection(event, elementId: shapeElement.id)
    }

    /// 図形の枠線太さを更新
    func updateShapeStrokeWidth(_ shapeElement: ShapeElement, newWidth: CGFloat) {

        let event = ShapeStrokeWidthChangedEvent(
            elementId: shapeElement.id,
            oldWidth: shapeElement.strokeWidth,
            newWidth: newWidth
        )

        target?.applyEventAndRefreshSelection(event, elementId: shapeElement.id)
    }

    /// 図形の枠線モードを更新
    func updateShapeStrokeMode(_ shapeElement: ShapeElement, newMode: StrokeMode) {

        let event = ShapeStrokeModeChangedEvent(
            elementId: shapeElement.id,
            oldMode: shapeElement.strokeMode,
            newMode: newMode
        )

        target?.applyEventAndRefreshSelection(event, elementId: shapeElement.id)
    }

    /// 図形の角丸半径を更新
    func updateShapeCornerRadius(_ shapeElement: ShapeElement, newRadius: CGFloat) {

        let event = ShapeCornerRadiusChangedEvent(
            elementId: shapeElement.id,
            oldRadius: shapeElement.cornerRadius,
            newRadius: newRadius
        )

        target?.applyEventAndRefreshSelection(event, elementId: shapeElement.id)
    }

    /// 図形の辺の数を更新
    func updateShapeSides(_ shapeElement: ShapeElement, newSides: Int) {

        let event = ShapeSidesChangedEvent(
            elementId: shapeElement.id,
            oldSides: shapeElement.sides,
            newSides: newSides
        )

        target?.applyEventAndRefreshSelection(event, elementId: shapeElement.id)
    }

    /// 図形のグラデーション色を更新
    func updateShapeGradientColors(_ shapeElement: ShapeElement, oldStartColor: UIColor, newStartColor: UIColor, oldEndColor: UIColor, newEndColor: UIColor) {

        let event = ShapeGradientColorsChangedEvent(
            elementId: shapeElement.id,
            oldStartColor: oldStartColor,
            newStartColor: newStartColor,
            oldEndColor: oldEndColor,
            newEndColor: newEndColor
        )

        target?.applyEventAndRefreshSelection(event, elementId: shapeElement.id)
    }

    func updateShapeGradientAngle(_ shapeElement: ShapeElement, newAngle: CGFloat) {

        let event = ShapeGradientAngleChangedEvent(
            elementId: shapeElement.id,
            oldAngle: shapeElement.gradientAngle,
            newAngle: newAngle
        )

        target?.applyEventAndRefreshSelection(event, elementId: shapeElement.id)
    }
}
