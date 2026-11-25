// テキスト要素の内容・色・フォント・間隔・効果の変更を記録する履歴イベント。

import UIKit

/// テキスト内容変更イベント
struct TextContentChangedEvent: EditorEvent {
    let elementId: UUID
    let oldText: String
    let newText: String

    var description: String {
        return "テキストを編集しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: TextElement.self) {
            element.text = newText
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: TextElement.self) {
            element.text = oldText
        }
    }
}

/// テキスト色変更イベント
struct TextColorChangedEvent: EditorEvent {
    let elementId: UUID
    let oldColor: UIColor
    let newColor: UIColor

    var description: String {
        return "テキストの色を変更しました"
    }

    func apply(to project: LogoProject) {

        if let element = project.element(for: elementId, as: TextElement.self) {
            element.textColor = newColor
        }
    }

    func revert(from project: LogoProject) {

        if let element = project.element(for: elementId, as: TextElement.self) {
            element.textColor = oldColor
        }
    }
}

/// フォント変更イベント
struct FontChangedEvent: EditorEvent {
    let elementId: UUID
    let oldFontName: String
    let newFontName: String
    let oldFontSize: CGFloat
    let newFontSize: CGFloat

    var description: String {
        return "フォントを変更しました"
    }

    func apply(to project: LogoProject) {

        if let element = project.element(for: elementId, as: TextElement.self) {
            element.fontName = newFontName
            element.fontSize = newFontSize
        }
    }

    func revert(from project: LogoProject) {

        if let element = project.element(for: elementId, as: TextElement.self) {
            element.fontName = oldFontName
            element.fontSize = oldFontSize
        }
    }
}

/// 行間変更イベント
struct TextLineSpacingChangedEvent: EditorEvent {
    let elementId: UUID
    let oldSpacing: CGFloat
    let newSpacing: CGFloat

    var description: String {
        return "テキストの行間を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: TextElement.self) {
            element.lineSpacing = newSpacing
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: TextElement.self) {
            element.lineSpacing = oldSpacing
        }
    }
}

/// 文字間隔変更イベント
struct TextLetterSpacingChangedEvent: EditorEvent {
    let elementId: UUID
    let oldSpacing: CGFloat
    let newSpacing: CGFloat

    var description: String {
        return "テキストの文字間隔を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: TextElement.self) {
            element.letterSpacing = newSpacing
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: TextElement.self) {
            element.letterSpacing = oldSpacing
        }
    }
}

/// シャドウ効果変更イベント
struct TextShadowEffectChangedEvent: EditorEvent {
    let elementId: UUID
    let effectIndex: Int
    let oldOffset: CGSize
    let newOffset: CGSize
    let oldBlurRadius: CGFloat
    let newBlurRadius: CGFloat

    var description: String {
        return "テキストのシャドウを調整しました"
    }

    func apply(to project: LogoProject) {
        guard let element = project.element(for: elementId, as: TextElement.self),
              effectIndex < element.effects.count,
              let shadowEffect = element.effects[effectIndex] as? ShadowEffect else { return }

        shadowEffect.offset = newOffset
        shadowEffect.blurRadius = newBlurRadius
    }

    func revert(from project: LogoProject) {
        guard let element = project.element(for: elementId, as: TextElement.self),
              effectIndex < element.effects.count,
              let shadowEffect = element.effects[effectIndex] as? ShadowEffect else { return }

        shadowEffect.offset = oldOffset
        shadowEffect.blurRadius = oldBlurRadius
    }
}

/// ストローク効果変更イベント
struct TextStrokeEffectChangedEvent: EditorEvent {
    let elementId: UUID
    let effectIndex: Int
    let oldWidth: CGFloat
    let newWidth: CGFloat

    var description: String {
        return "テキストのストロークを調整しました"
    }

    func apply(to project: LogoProject) {
        guard let element = project.element(for: elementId, as: TextElement.self),
              effectIndex < element.effects.count,
              let strokeEffect = element.effects[effectIndex] as? StrokeEffect else { return }

        strokeEffect.width = newWidth
    }

    func revert(from project: LogoProject) {
        guard let element = project.element(for: elementId, as: TextElement.self),
              effectIndex < element.effects.count,
              let strokeEffect = element.effects[effectIndex] as? StrokeEffect else { return }

        strokeEffect.width = oldWidth
    }
}

/// グロー効果変更イベント
struct TextGlowEffectChangedEvent: EditorEvent {
    let elementId: UUID
    let effectIndex: Int
    let oldRadius: CGFloat
    let newRadius: CGFloat

    var description: String {
        return "テキストのグローを調整しました"
    }

    func apply(to project: LogoProject) {
        guard let element = project.element(for: elementId, as: TextElement.self),
              effectIndex < element.effects.count,
              let glowEffect = element.effects[effectIndex] as? GlowEffect else { return }

        glowEffect.radius = newRadius
    }

    func revert(from project: LogoProject) {
        guard let element = project.element(for: elementId, as: TextElement.self),
              effectIndex < element.effects.count,
              let glowEffect = element.effects[effectIndex] as? GlowEffect else { return }

        glowEffect.radius = oldRadius
    }
}

/// グラデーション塗り効果の色変更イベント
struct TextGradientFillColorChangedEvent: EditorEvent {
    let elementId: UUID
    let effectIndex: Int
    let oldStartColor: UIColor
    let newStartColor: UIColor
    let oldEndColor: UIColor
    let newEndColor: UIColor

    var description: String {
        return "テキストのグラデーション色を変更しました"
    }

    func apply(to project: LogoProject) {
        guard let element = project.element(for: elementId, as: TextElement.self),
              effectIndex < element.effects.count,
              let gradientEffect = element.effects[effectIndex] as? GradientFillEffect else { return }

        gradientEffect.startColor = newStartColor
        gradientEffect.endColor = newEndColor
    }

    func revert(from project: LogoProject) {
        guard let element = project.element(for: elementId, as: TextElement.self),
              effectIndex < element.effects.count,
              let gradientEffect = element.effects[effectIndex] as? GradientFillEffect else { return }

        gradientEffect.startColor = oldStartColor
        gradientEffect.endColor = oldEndColor
    }
}

/// グラデーション塗り効果の角度変更イベント
struct TextGradientFillEffectChangedEvent: EditorEvent {
    let elementId: UUID
    let effectIndex: Int
    let oldAngle: CGFloat
    let newAngle: CGFloat

    var description: String {
        return "テキストのグラデーション角度を調整しました"
    }

    func apply(to project: LogoProject) {
        guard let element = project.element(for: elementId, as: TextElement.self),
              effectIndex < element.effects.count,
              let gradientEffect = element.effects[effectIndex] as? GradientFillEffect else { return }

        gradientEffect.angle = newAngle
    }

    func revert(from project: LogoProject) {
        guard let element = project.element(for: elementId, as: TextElement.self),
              effectIndex < element.effects.count,
              let gradientEffect = element.effects[effectIndex] as? GradientFillEffect else { return }

        gradientEffect.angle = oldAngle
    }
}

/// グラデーション塗り効果の不透明度変更イベント
struct TextGradientFillOpacityChangedEvent: EditorEvent {
    let elementId: UUID
    let effectIndex: Int
    let oldOpacity: CGFloat
    let newOpacity: CGFloat

    var description: String {
        return "テキストのグラデーション不透明度を調整しました"
    }

    func apply(to project: LogoProject) {
        guard let element = project.element(for: elementId, as: TextElement.self),
              effectIndex < element.effects.count,
              let gradientEffect = element.effects[effectIndex] as? GradientFillEffect else { return }

        gradientEffect.opacity = newOpacity
    }

    func revert(from project: LogoProject) {
        guard let element = project.element(for: elementId, as: TextElement.self),
              effectIndex < element.effects.count,
              let gradientEffect = element.effects[effectIndex] as? GradientFillEffect else { return }

        gradientEffect.opacity = oldOpacity
    }
}
