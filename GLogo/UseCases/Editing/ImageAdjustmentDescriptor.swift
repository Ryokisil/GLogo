//
//  ImageAdjustmentDescriptor.swift
//
//  概要:
//  画像調整パラメータのディスクリプタ定義。
//  12種類のCGFloat画像調整を統一的に扱うためのデータ駆動テーブルを提供する。
//

import Foundation
import UIKit

/// 画像調整スライダーのキー
enum ImageAdjustmentKey: Hashable {
    case saturation
    case brightness
    case contrast
    case highlights
    case shadows
    case hue
    case sharpness
    case gaussianBlur
    case tintIntensity
    case frameWidth
    case cornerRadius
    case backgroundBlurRadius
}

/// 画像調整パラメータのディスクリプタ
struct ImageAdjustmentDescriptor {
    /// 調整キー
    let key: ImageAdjustmentKey

    /// ImageElementのプロパティへの書き込み可能キーパス
    let keyPath: ReferenceWritableKeyPath<ImageElement, CGFloat>

    /// 履歴イベント生成クロージャ
    let eventFactory: (_ element: ImageElement, _ oldValue: CGFloat, _ newValue: CGFloat) -> EditorEvent

    /// メタデータ保存用キー
    let metadataKey: String

    /// RenderScheduler経由の更新が必要か（gaussianBlur用）
    let needsRenderScheduler: Bool

    // MARK: - 全ディスクリプタテーブル

    /// 12種類の画像調整ディスクリプタ
    static let all: [ImageAdjustmentKey: ImageAdjustmentDescriptor] = {
        var table: [ImageAdjustmentKey: ImageAdjustmentDescriptor] = [:]

        table[.saturation] = ImageAdjustmentDescriptor(
            key: .saturation,
            keyPath: \.saturationAdjustment,
            eventFactory: { element, oldValue, newValue in
                ImageSaturationChangedEvent(
                    elementId: element.id,
                    oldSaturation: oldValue,
                    newSaturation: newValue
                )
            },
            metadataKey: "saturationAdjustment",
            needsRenderScheduler: false
        )

        table[.brightness] = ImageAdjustmentDescriptor(
            key: .brightness,
            keyPath: \.brightnessAdjustment,
            eventFactory: { element, oldValue, newValue in
                ImageBrightnessChangedEvent(
                    elementId: element.id,
                    oldBrightness: oldValue,
                    newBrightness: newValue
                )
            },
            metadataKey: "brigthtnessAdjustment",
            needsRenderScheduler: false
        )

        table[.contrast] = ImageAdjustmentDescriptor(
            key: .contrast,
            keyPath: \.contrastAdjustment,
            eventFactory: { element, oldValue, newValue in
                ImageContrastChangedEvent(
                    elementId: element.id,
                    oldContrast: oldValue,
                    newContrast: newValue
                )
            },
            metadataKey: "contrastAdjustment",
            needsRenderScheduler: false
        )

        table[.highlights] = ImageAdjustmentDescriptor(
            key: .highlights,
            keyPath: \.highlightsAdjustment,
            eventFactory: { element, oldValue, newValue in
                ImageHighlightsChangedEvent(
                    elementId: element.id,
                    oldHighlights: oldValue,
                    newHighlights: newValue
                )
            },
            metadataKey: "highlightsAdjustment",
            needsRenderScheduler: false
        )

        table[.shadows] = ImageAdjustmentDescriptor(
            key: .shadows,
            keyPath: \.shadowsAdjustment,
            eventFactory: { element, oldValue, newValue in
                ImageShadowsChangedEvent(
                    elementId: element.id,
                    oldShadows: oldValue,
                    newShadows: newValue
                )
            },
            metadataKey: "shadowsAdjustment",
            needsRenderScheduler: false
        )

        table[.hue] = ImageAdjustmentDescriptor(
            key: .hue,
            keyPath: \.hueAdjustment,
            eventFactory: { element, oldValue, newValue in
                ImageHueChangedEvent(
                    elementId: element.id,
                    oldHue: oldValue,
                    newHue: newValue
                )
            },
            metadataKey: "hueAdjustment",
            needsRenderScheduler: false
        )

        table[.sharpness] = ImageAdjustmentDescriptor(
            key: .sharpness,
            keyPath: \.sharpnessAdjustment,
            eventFactory: { element, oldValue, newValue in
                ImageSharpnessChangedEvent(
                    elementId: element.id,
                    oldSharpness: oldValue,
                    newSharpness: newValue
                )
            },
            metadataKey: "sharpnessAdjustment",
            needsRenderScheduler: false
        )

        table[.gaussianBlur] = ImageAdjustmentDescriptor(
            key: .gaussianBlur,
            keyPath: \.gaussianBlurRadius,
            eventFactory: { element, oldValue, newValue in
                ImageGaussianBlurChangedEvent(
                    elementId: element.id,
                    oldRadius: oldValue,
                    newRadius: newValue
                )
            },
            metadataKey: "gaussianBlurRadius",
            needsRenderScheduler: true
        )

        table[.tintIntensity] = ImageAdjustmentDescriptor(
            key: .tintIntensity,
            keyPath: \.tintIntensity,
            eventFactory: { element, oldValue, newValue in
                ImageTintColorChangedEvent(
                    elementId: element.id,
                    oldColor: element.tintColor,
                    newColor: element.tintColor,
                    oldIntensity: oldValue,
                    newIntensity: newValue
                )
            },
            metadataKey: "tintIntensity",
            needsRenderScheduler: false
        )

        table[.frameWidth] = ImageAdjustmentDescriptor(
            key: .frameWidth,
            keyPath: \.frameWidth,
            eventFactory: { element, oldValue, newValue in
                ImageFrameWidthChangedEvent(
                    elementId: element.id,
                    oldWidth: oldValue,
                    newWidth: newValue
                )
            },
            metadataKey: "frameWidth",
            needsRenderScheduler: false
        )

        table[.cornerRadius] = ImageAdjustmentDescriptor(
            key: .cornerRadius,
            keyPath: \.cornerRadius,
            eventFactory: { element, oldValue, newValue in
                ImageRoundedCornersChangedEvent(
                    elementId: element.id,
                    wasRounded: element.roundedCorners,
                    isRounded: element.roundedCorners,
                    oldRadius: oldValue,
                    newRadius: newValue
                )
            },
            metadataKey: "cornerRadius",
            needsRenderScheduler: false
        )

        table[.backgroundBlurRadius] = ImageAdjustmentDescriptor(
            key: .backgroundBlurRadius,
            keyPath: \.backgroundBlurRadius,
            eventFactory: { element, oldValue, newValue in
                ImageBackgroundBlurRadiusChangedEvent(
                    elementId: element.id,
                    oldRadius: oldValue,
                    newRadius: newValue
                )
            },
            metadataKey: "backgroundBlurRadius",
            needsRenderScheduler: false
        )

        return table
    }()
}
