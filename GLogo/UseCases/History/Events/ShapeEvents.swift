// 図形要素の種類・塗り・枠線・角丸・辺の数・グラデーションの変更を記録する履歴イベント。

import UIKit

/// 図形タイプ変更イベント
struct ShapeTypeChangedEvent: EditorEvent {
    let elementId: UUID
    let oldType: ShapeType
    let newType: ShapeType

    var description: String {
        return "図形タイプを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.shapeType = newType
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.shapeType = oldType
        }
    }
}

/// 図形の塗りつぶし色変更イベント
struct ShapeFillColorChangedEvent: EditorEvent {
    let elementId: UUID
    let oldColor: UIColor
    let newColor: UIColor

    var description: String {
        return "図形の塗りつぶし色を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.fillColor = newColor
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.fillColor = oldColor
        }
    }
}

/// 図形の塗りつぶしモード変更イベント
struct ShapeFillModeChangedEvent: EditorEvent {
    let elementId: UUID
    let oldMode: FillMode
    let newMode: FillMode

    var description: String {
        return "図形の塗りつぶしモードを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.fillMode = newMode
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.fillMode = oldMode
        }
    }
}

/// 図形の枠線色変更イベント
struct ShapeStrokeColorChangedEvent: EditorEvent {
    let elementId: UUID
    let oldColor: UIColor
    let newColor: UIColor

    var description: String {
        return "図形の枠線色を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.strokeColor = newColor
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.strokeColor = oldColor
        }
    }
}

/// 図形の枠線太さ変更イベント
struct ShapeStrokeWidthChangedEvent: EditorEvent {
    let elementId: UUID
    let oldWidth: CGFloat
    let newWidth: CGFloat

    var description: String {
        return "図形の枠線太さを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.strokeWidth = newWidth
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.strokeWidth = oldWidth
        }
    }
}

/// 図形の枠線モード変更イベント
struct ShapeStrokeModeChangedEvent: EditorEvent {
    let elementId: UUID
    let oldMode: StrokeMode
    let newMode: StrokeMode

    var description: String {
        return "図形の枠線モードを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.strokeMode = newMode
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.strokeMode = oldMode
        }
    }
}

/// 図形の角丸半径変更イベント
struct ShapeCornerRadiusChangedEvent: EditorEvent {
    let elementId: UUID
    let oldRadius: CGFloat
    let newRadius: CGFloat

    var description: String {
        return "図形の角丸半径を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.cornerRadius = newRadius
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.cornerRadius = oldRadius
        }
    }
}

/// 図形の辺の数変更イベント
struct ShapeSidesChangedEvent: EditorEvent {
    let elementId: UUID
    let oldSides: Int
    let newSides: Int

    var description: String {
        return "図形の辺の数を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.sides = newSides
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.sides = oldSides
        }
    }
}

/// 図形のグラデーション色変更イベント
struct ShapeGradientColorsChangedEvent: EditorEvent {
    let elementId: UUID
    let oldStartColor: UIColor
    let newStartColor: UIColor
    let oldEndColor: UIColor
    let newEndColor: UIColor

    var description: String {
        return "図形のグラデーション色を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.gradientStartColor = newStartColor
            element.gradientEndColor = newEndColor
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.gradientStartColor = oldStartColor
            element.gradientEndColor = oldEndColor
        }
    }
}

/// 図形のグラデーション角度変更イベント
struct ShapeGradientAngleChangedEvent: EditorEvent {
    let elementId: UUID
    let oldAngle: CGFloat
    let newAngle: CGFloat

    var description: String {
        return "図形のグラデーション角度を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.gradientAngle = newAngle
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ShapeElement.self) {
            element.gradientAngle = oldAngle
        }
    }
}
