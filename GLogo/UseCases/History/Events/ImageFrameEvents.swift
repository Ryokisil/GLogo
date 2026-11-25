// 画像要素のフレームと角丸の変更を記録する履歴イベント。
// 表示画像の失効は、各イベントが `ImageAppearanceEvent` として示し、履歴が適用・巻き戻しの直後に行う。

import UIKit

/// UIColor を RGBA 成分に変換して保持する色の値
struct RGBAColorSnapshot {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    init(_ color: UIColor) {
        var redValue: CGFloat = 0
        var greenValue: CGFloat = 0
        var blueValue: CGFloat = 0
        var alphaValue: CGFloat = 0

        if color.getRed(&redValue, green: &greenValue, blue: &blueValue, alpha: &alphaValue) {
            red = redValue
            green = greenValue
            blue = blueValue
            alpha = alphaValue
            return
        }

        let ciColor = CIColor(color: color)
        red = ciColor.red
        green = ciColor.green
        blue = ciColor.blue
        alpha = ciColor.alpha
    }

    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

/// 画像フレーム表示変更イベント
struct ImageShowFrameChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldValue: Bool
    let newValue: Bool

    var description: String {
        return "画像のフレーム表示を\(newValue ? "有効" : "無効")にしました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.showFrame = newValue
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.showFrame = oldValue
        }
    }
}

/// 画像フレーム色変更イベント
struct ImageFrameColorChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldColor: UIColor
    let newColor: UIColor

    var description: String {
        return "画像のフレーム色を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.frameColor = newColor
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.frameColor = oldColor
        }
    }
}

/// 画像フレーム太さ変更イベント
struct ImageFrameWidthChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldWidth: CGFloat
    let newWidth: CGFloat

    var description: String {
        return "画像のフレーム太さを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.frameWidth = newWidth
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.frameWidth = oldWidth
        }
    }
}

/// 画像フレームスタイル変更イベント
struct ImageFrameStyleChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldStyle: ImageFrameStyle
    let newStyle: ImageFrameStyle

    var description: String {
        return "画像のフレームスタイルを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.frameStyle = newStyle
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.frameStyle = oldStyle
        }
    }
}

/// 画像フレームの表示・スタイル・色をまとめて変更するイベント
struct ImageFrameAppearanceChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldShowFrame: Bool
    let newShowFrame: Bool
    let oldFrameStyle: ImageFrameStyle
    let newFrameStyle: ImageFrameStyle
    let oldFrameColor: RGBAColorSnapshot
    let newFrameColor: RGBAColorSnapshot

    var description: String {
        return "画像のフレーム見た目を変更しました"
    }

    init(
        elementId: UUID,
        oldShowFrame: Bool,
        newShowFrame: Bool,
        oldFrameStyle: ImageFrameStyle,
        newFrameStyle: ImageFrameStyle,
        oldFrameColor: UIColor,
        newFrameColor: UIColor
    ) {
        self.elementId = elementId
        self.oldShowFrame = oldShowFrame
        self.newShowFrame = newShowFrame
        self.oldFrameStyle = oldFrameStyle
        self.newFrameStyle = newFrameStyle
        self.oldFrameColor = RGBAColorSnapshot(oldFrameColor)
        self.newFrameColor = RGBAColorSnapshot(newFrameColor)
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.showFrame = newShowFrame
            element.frameStyle = newFrameStyle
            element.frameColor = newFrameColor.uiColor
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.showFrame = oldShowFrame
            element.frameStyle = oldFrameStyle
            element.frameColor = oldFrameColor.uiColor
        }
    }
}

/// 画像角丸設定変更イベント
struct ImageRoundedCornersChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let wasRounded: Bool
    let isRounded: Bool
    let oldRadius: CGFloat
    let newRadius: CGFloat

    var description: String {
        if wasRounded != isRounded {
            return "画像の角丸を\(isRounded ? "有効" : "無効")にしました"
        } else {
            return "画像の角丸半径を変更しました"
        }
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.roundedCorners = isRounded
            element.cornerRadius = newRadius
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.roundedCorners = wasRounded
            element.cornerRadius = oldRadius
        }
    }
}
