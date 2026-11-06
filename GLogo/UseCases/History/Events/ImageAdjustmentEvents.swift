// 画像要素の調整値・ティント・背景ぼかし・フィルタープリセットの変更を記録する履歴イベント。

import UIKit

// MARK: - 調整値

/// 画像彩度変更イベント
struct ImageSaturationChangedEvent: EditorEvent {
    let elementId: UUID
    let oldSaturation: CGFloat
    let newSaturation: CGFloat

    var description: String {
        return "画像の彩度を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.saturationAdjustment = newSaturation
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.saturationAdjustment = oldSaturation
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像明度変更イベント
struct ImageBrightnessChangedEvent: EditorEvent {
    let elementId: UUID
    let oldBrightness: CGFloat
    let newBrightness: CGFloat

    var description: String {
        return "画像の明度を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.brightnessAdjustment = newBrightness
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.brightnessAdjustment = oldBrightness
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像コントラスト変更イベント
struct ImageContrastChangedEvent: EditorEvent {
    let elementId: UUID
    let oldContrast: CGFloat
    let newContrast: CGFloat

    var description: String {
        return "画像のコントラストを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.contrastAdjustment = newContrast
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.contrastAdjustment = oldContrast
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像ハイライト変更イベント
struct ImageHighlightsChangedEvent: EditorEvent {
    let elementId: UUID
    let oldHighlights: CGFloat
    let newHighlights: CGFloat

    var description: String {
        return "画像のハイライトを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.highlightsAdjustment = newHighlights
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.highlightsAdjustment = oldHighlights
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像シャドウ変更イベント
struct ImageShadowsChangedEvent: EditorEvent {
    let elementId: UUID
    let oldShadows: CGFloat
    let newShadows: CGFloat

    var description: String {
        return "画像のシャドウを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.shadowsAdjustment = newShadows
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.shadowsAdjustment = oldShadows
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像黒レベル変更イベント
struct ImageBlacksChangedEvent: EditorEvent {
    let elementId: UUID
    let oldBlacks: CGFloat
    let newBlacks: CGFloat

    var description: String {
        return "画像の黒レベルを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.blacksAdjustment = newBlacks
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.blacksAdjustment = oldBlacks
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像白レベル変更イベント
struct ImageWhitesChangedEvent: EditorEvent {
    let elementId: UUID
    let oldWhites: CGFloat
    let newWhites: CGFloat

    var description: String {
        return "画像の白レベルを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.whitesAdjustment = newWhites
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.whitesAdjustment = oldWhites
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像色温度変更イベント
struct ImageWarmthChangedEvent: EditorEvent {
    let elementId: UUID
    let oldWarmth: CGFloat
    let newWarmth: CGFloat

    var description: String {
        return "画像の色温度を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.warmthAdjustment = newWarmth
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.warmthAdjustment = oldWarmth
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像ヴィブランス変更イベント
struct ImageVibranceChangedEvent: EditorEvent {
    let elementId: UUID
    let oldVibrance: CGFloat
    let newVibrance: CGFloat

    var description: String {
        return "画像のヴィブランスを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.vibranceAdjustment = newVibrance
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.vibranceAdjustment = oldVibrance
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像色相変更イベント
struct ImageHueChangedEvent: EditorEvent {
    let elementId: UUID
    let oldHue: CGFloat
    let newHue: CGFloat

    var description: String {
        return "画像の色相を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.hueAdjustment = newHue
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.hueAdjustment = oldHue
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像シャープネス変更イベント
struct ImageSharpnessChangedEvent: EditorEvent {
    let elementId: UUID
    let oldSharpness: CGFloat
    let newSharpness: CGFloat

    var description: String {
        return "画像のシャープネスを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.sharpnessAdjustment = newSharpness
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.sharpnessAdjustment = oldSharpness
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像ガウシアンブラー変更イベント
struct ImageGaussianBlurChangedEvent: EditorEvent {
    let elementId: UUID
    let oldRadius: CGFloat
    let newRadius: CGFloat

    var description: String {
        return "画像のガウシアンブラーを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.gaussianBlurRadius = newRadius
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.gaussianBlurRadius = oldRadius
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像ビネット変更イベント
struct ImageVignetteChangedEvent: EditorEvent {
    let elementId: UUID
    let oldIntensity: CGFloat
    let newIntensity: CGFloat

    var description: String {
        return "画像のビネットを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.vignetteAdjustment = newIntensity
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.vignetteAdjustment = oldIntensity
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像ブルーム変更イベント
struct ImageBloomChangedEvent: EditorEvent {
    let elementId: UUID
    let oldIntensity: CGFloat
    let newIntensity: CGFloat

    var description: String {
        return "画像のブルームを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.bloomAdjustment = newIntensity
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.bloomAdjustment = oldIntensity
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像グレイン変更イベント
struct ImageGrainChangedEvent: EditorEvent {
    let elementId: UUID
    let oldIntensity: CGFloat
    let newIntensity: CGFloat

    var description: String {
        return "画像のグレインを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.grainAdjustment = newIntensity
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.grainAdjustment = oldIntensity
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像フェード変更イベント
struct ImageFadeChangedEvent: EditorEvent {
    let elementId: UUID
    let oldIntensity: CGFloat
    let newIntensity: CGFloat

    var description: String {
        return "画像のフェードを変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.fadeAdjustment = newIntensity
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.fadeAdjustment = oldIntensity
            element.invalidateRenderedImageCache()
        }
    }
}

/// 画像色収差変更イベント
struct ImageChromaticAberrationChangedEvent: EditorEvent {
    let elementId: UUID
    let oldIntensity: CGFloat
    let newIntensity: CGFloat

    var description: String {
        return "画像の色収差を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.chromaticAberrationAdjustment = newIntensity
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.chromaticAberrationAdjustment = oldIntensity
            element.invalidateRenderedImageCache()
        }
    }
}

// MARK: - ティント

/// 画像ティントカラー変更イベント
struct ImageTintColorChangedEvent: EditorEvent {
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
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.tintColor = oldColor
            element.tintIntensity = oldIntensity
            element.invalidateRenderedImageCache()
        }
    }
}

// MARK: - 背景ぼかし

/// 背景ぼかしマスク変更イベント
struct ImageBackgroundBlurMaskChangedEvent: EditorEvent {
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
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.backgroundBlurMaskData = oldMaskData
            element.invalidateRenderedImageCache()
        }
    }
}

/// 背景ぼかし半径変更イベント
struct ImageBackgroundBlurRadiusChangedEvent: EditorEvent {
    let elementId: UUID
    let oldRadius: CGFloat
    let newRadius: CGFloat

    var description: String {
        return "背景ぼかしの強度を変更しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.backgroundBlurRadius = newRadius
            element.invalidateRenderedImageCache()
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId, as: ImageElement.self) {
            element.backgroundBlurRadius = oldRadius
            element.invalidateRenderedImageCache()
        }
    }
}

// MARK: - フィルタープリセット

/// フィルタープリセット変更イベント
struct FilterPresetChangedEvent: EditorEvent {
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
        element.invalidateRenderedImageCache()
    }

    func revert(from project: LogoProject) {
        guard let element = project.element(for: elementId, as: ImageElement.self) else { return }
        element.appliedFilterRecipe = oldRecipe
        element.appliedFilterPresetId = oldPresetId
        element.invalidateRenderedImageCache()
    }
}
