// 画像要素の調整値・ティント・背景ぼかし・フィルタープリセットの変更を記録する履歴イベント。
// 表示画像の失効は、各イベントが `ImageAppearanceEvent` として示し、履歴が適用・巻き戻しの直後に行う。

import UIKit

// MARK: - 調整値

/// 画像彩度変更イベント
struct ImageSaturationChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldSaturation: CGFloat
    let newSaturation: CGFloat

    var description: String {
        return "画像の彩度を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.saturationAdjustment = newSaturation
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.saturationAdjustment = oldSaturation
        }
    }
}

/// 画像明度変更イベント
struct ImageBrightnessChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldBrightness: CGFloat
    let newBrightness: CGFloat

    var description: String {
        return "画像の明度を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.brightnessAdjustment = newBrightness
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.brightnessAdjustment = oldBrightness
        }
    }
}

/// 画像コントラスト変更イベント
struct ImageContrastChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldContrast: CGFloat
    let newContrast: CGFloat

    var description: String {
        return "画像のコントラストを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.contrastAdjustment = newContrast
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.contrastAdjustment = oldContrast
        }
    }
}

/// 画像ハイライト変更イベント
struct ImageHighlightsChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldHighlights: CGFloat
    let newHighlights: CGFloat

    var description: String {
        return "画像のハイライトを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.highlightsAdjustment = newHighlights
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.highlightsAdjustment = oldHighlights
        }
    }
}

/// 画像シャドウ変更イベント
struct ImageShadowsChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldShadows: CGFloat
    let newShadows: CGFloat

    var description: String {
        return "画像のシャドウを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.shadowsAdjustment = newShadows
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.shadowsAdjustment = oldShadows
        }
    }
}

/// 画像黒レベル変更イベント
struct ImageBlacksChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldBlacks: CGFloat
    let newBlacks: CGFloat

    var description: String {
        return "画像の黒レベルを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.blacksAdjustment = newBlacks
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.blacksAdjustment = oldBlacks
        }
    }
}

/// 画像白レベル変更イベント
struct ImageWhitesChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldWhites: CGFloat
    let newWhites: CGFloat

    var description: String {
        return "画像の白レベルを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.whitesAdjustment = newWhites
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.whitesAdjustment = oldWhites
        }
    }
}

/// 画像色温度変更イベント
struct ImageWarmthChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldWarmth: CGFloat
    let newWarmth: CGFloat

    var description: String {
        return "画像の色温度を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.warmthAdjustment = newWarmth
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.warmthAdjustment = oldWarmth
        }
    }
}

/// 画像ヴィブランス変更イベント
struct ImageVibranceChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldVibrance: CGFloat
    let newVibrance: CGFloat

    var description: String {
        return "画像のヴィブランスを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.vibranceAdjustment = newVibrance
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.vibranceAdjustment = oldVibrance
        }
    }
}

/// 画像色相変更イベント
struct ImageHueChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldHue: CGFloat
    let newHue: CGFloat

    var description: String {
        return "画像の色相を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.hueAdjustment = newHue
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.hueAdjustment = oldHue
        }
    }
}

/// 画像シャープネス変更イベント
struct ImageSharpnessChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldSharpness: CGFloat
    let newSharpness: CGFloat

    var description: String {
        return "画像のシャープネスを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.sharpnessAdjustment = newSharpness
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.sharpnessAdjustment = oldSharpness
        }
    }
}

/// 画像ガウシアンブラー変更イベント
struct ImageGaussianBlurChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldRadius: CGFloat
    let newRadius: CGFloat

    var description: String {
        return "画像のガウシアンブラーを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.gaussianBlurRadius = newRadius
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.gaussianBlurRadius = oldRadius
        }
    }
}

/// 画像ビネット変更イベント
struct ImageVignetteChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldIntensity: CGFloat
    let newIntensity: CGFloat

    var description: String {
        return "画像のビネットを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.vignetteAdjustment = newIntensity
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.vignetteAdjustment = oldIntensity
        }
    }
}

/// 画像ブルーム変更イベント
struct ImageBloomChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldIntensity: CGFloat
    let newIntensity: CGFloat

    var description: String {
        return "画像のブルームを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.bloomAdjustment = newIntensity
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.bloomAdjustment = oldIntensity
        }
    }
}

/// 画像グレイン変更イベント
struct ImageGrainChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldIntensity: CGFloat
    let newIntensity: CGFloat

    var description: String {
        return "画像のグレインを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.grainAdjustment = newIntensity
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.grainAdjustment = oldIntensity
        }
    }
}

/// 画像フェード変更イベント
struct ImageFadeChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldIntensity: CGFloat
    let newIntensity: CGFloat

    var description: String {
        return "画像のフェードを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.fadeAdjustment = newIntensity
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.fadeAdjustment = oldIntensity
        }
    }
}

/// 画像色収差変更イベント
struct ImageChromaticAberrationChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldIntensity: CGFloat
    let newIntensity: CGFloat

    var description: String {
        return "画像の色収差を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.chromaticAberrationAdjustment = newIntensity
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.chromaticAberrationAdjustment = oldIntensity
        }
    }
}

// MARK: - ティント

/// 画像ティントカラー変更イベント
struct ImageTintColorChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldColor: UIColor?
    let newColor: UIColor?
    let oldIntensity: CGFloat
    let newIntensity: CGFloat

    var description: String {
        return "画像のティントカラーを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.tintColor = newColor
            element.tintIntensity = newIntensity
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.tintColor = oldColor
            element.tintIntensity = oldIntensity
        }
    }
}

// MARK: - 背景ぼかし

/// 背景ぼかしマスク変更イベント
struct ImageBackgroundBlurMaskChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldMaskData: Data?
    let newMaskData: Data?

    var description: String {
        if newMaskData != nil {
            return "背景ぼかしマスクを設定しました"
        } else {
            return "背景ぼかしマスクを削除しました"
        }
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.backgroundBlurMaskData = newMaskData
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.backgroundBlurMaskData = oldMaskData
        }
    }
}

/// 背景ぼかし半径変更イベント
struct ImageBackgroundBlurRadiusChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldRadius: CGFloat
    let newRadius: CGFloat

    var description: String {
        return "背景ぼかしの強度を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.backgroundBlurRadius = newRadius
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.backgroundBlurRadius = oldRadius
        }
    }
}

// MARK: - フィルタープリセット

/// フィルタープリセット変更イベント
struct FilterPresetChangedEvent: ImageAppearanceEvent {
    let elementId: UUID
    let oldRecipe: FilterRecipe?
    let newRecipe: FilterRecipe?
    let oldPresetId: String?
    let newPresetId: String?

    var description: String {
        if newPresetId != nil {
            return "フィルタープリセットを変更しました"
        } else {
            return "フィルタープリセットを解除しました"
        }
    }

    func apply(to project: LogoProject) {
        guard let element = project.element(for: elementId, as: ImageElement.self) else { return }
        element.appliedFilterRecipe = newRecipe
        element.appliedFilterPresetId = newPresetId
    }

    func revert(from project: LogoProject) {
        guard let element = project.element(for: elementId, as: ImageElement.self) else { return }
        element.appliedFilterRecipe = oldRecipe
        element.appliedFilterPresetId = oldPresetId
    }
}
