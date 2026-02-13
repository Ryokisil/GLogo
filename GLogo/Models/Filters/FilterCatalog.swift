//
//  FilterCatalog.swift
//  GLogo
//
//  概要:
//  フィルタープリセットの一覧を提供するカタログ。
//  カテゴリ別のプリセット取得や全プリセットの一覧を返す。
//

import Foundation
import UIKit

/// フィルターカタログ
enum FilterCatalog {

    // MARK: - カテゴリ一覧

    /// 利用可能なカテゴリ一覧
    static let categories: [FilterCategory] = FilterCategory.allCases

    // MARK: - 全プリセット

    /// 全プリセット一覧（表示順）
    static let allPresets: [FilterPreset] = [
        original,
        crisp,
        soft,
        vintageWarm,
        vintageInstant,
        agedPhoto,
        coolMatte,
        coolShadowsWarmHighlights,
        subtleFade,
        bwHighContrast,
        noir
    ]

    // MARK: - カテゴリ別取得

    /// 指定カテゴリのプリセットを返す
    static func presets(for category: FilterCategory) -> [FilterPreset] {
        allPresets.filter { $0.category == category }
    }

    // MARK: - プリセット定義

    /// Original: すべてデフォルト値に戻す
    static let original = FilterPreset(
        id: "original",
        name: "Original",
        category: .basic,
        recipe: FilterRecipe(
            saturation: 1.0,
            brightness: 0.0,
            contrast: 1.0,
            highlights: 0.0,
            shadows: 0.0,
            hue: 0.0,
            sharpness: 0.0,
            gaussianBlur: 0.0,
            tintColorHex: nil,
            tintIntensity: 0.0
        ),
        previewColor: UIColor.systemGray4
    )

    /// Crisp: コントラスト↑ 彩度↑ シャープネス↑
    static let crisp = FilterPreset(
        id: "crisp",
        name: "Crisp",
        category: .basic,
        recipe: FilterRecipe(
            saturation: 1.08,
            contrast: 1.12,
            sharpness: 0.20
        ),
        previewColor: UIColor.systemBlue.withAlphaComponent(0.6)
    )

    /// Soft: コントラスト↓ ハイライト↑ ブラー軽め
    static let soft = FilterPreset(
        id: "soft",
        name: "Soft",
        category: .basic,
        recipe: FilterRecipe(
            contrast: 0.92,
            highlights: 0.08,
            gaussianBlur: 1.0
        ),
        previewColor: UIColor.systemPink.withAlphaComponent(0.4)
    )

    /// Vintage Warm: 彩度↓ コントラスト↓ シャドウ↑ セピア系ティント
    static let vintageWarm = FilterPreset(
        id: "vintage_warm",
        name: "Vintage Warm",
        category: .vintage,
        recipe: FilterRecipe(
            saturation: 0.86,
            contrast: 0.90,
            shadows: 0.10,
            tintColorHex: "#C98A4B",
            tintIntensity: 0.20
        ),
        previewColor: UIColor(hex: "#C98A4B") ?? UIColor.orange
    )

    /// Vintage Instant: 軽い退色 + 暖色寄り
    static let vintageInstant = FilterPreset(
        id: "vintage_instant",
        name: "Vintage Instant",
        category: .vintage,
        recipe: FilterRecipe(
            saturation: 0.86,
            brightness: 0.04,
            contrast: 0.88,
            highlights: -0.22,
            shadows: 0.18,
            hue: 0.0,
            sharpness: 0.02,
            gaussianBlur: 0.3,
            tintColorHex: "#D3A86E",
            tintIntensity: 0.18
        ),
        previewColor: UIColor(hex: "#D3A86E") ?? UIColor.systemOrange
    )

    /// Aged Photo: 退色強め + くすみ
    static let agedPhoto = FilterPreset(
        id: "aged_photo",
        name: "Aged Photo",
        category: .vintage,
        recipe: FilterRecipe(
            saturation: 0.72,
            brightness: -0.02,
            contrast: 0.84,
            highlights: -0.18,
            shadows: 0.24,
            hue: 0.0,
            sharpness: 0.00,
            gaussianBlur: 0.8,
            tintColorHex: "#C79A62",
            tintIntensity: 0.24
        ),
        previewColor: UIColor(hex: "#C79A62") ?? UIColor.brown
    )

    /// Cool Matte: 寒色マット
    static let coolMatte = FilterPreset(
        id: "cool_matte",
        name: "Cool Matte",
        category: .vintage,
        recipe: FilterRecipe(
            saturation: 0.82,
            brightness: -0.05,
            contrast: 0.86,
            highlights: -0.20,
            shadows: 0.10,
            hue: 6.0,
            sharpness: 0.05,
            gaussianBlur: 0.5,
            tintColorHex: "#6F89A8",
            tintIntensity: 0.14
        ),
        previewColor: UIColor(hex: "#6F89A8") ?? UIColor.systemBlue
    )

    /// Cool Shadows Warm Highlights: 寒色影 + 暖色ハイライト
    static let coolShadowsWarmHighlights = FilterPreset(
        id: "cool_shadows_warm_highlights",
        name: "Cool/Warm Split",
        category: .vintage,
        recipe: FilterRecipe(
            saturation: 0.90,
            brightness: 0.00,
            contrast: 0.90,
            highlights: -0.24,
            shadows: 0.12,
            hue: 8.0,
            sharpness: 0.08,
            gaussianBlur: 0.2,
            tintColorHex: "#C7A26D",
            tintIntensity: 0.10
        ),
        previewColor: UIColor(hex: "#C7A26D") ?? UIColor.systemTeal
    )

    /// Subtle Fade: 控えめフェード
    static let subtleFade = FilterPreset(
        id: "subtle_fade",
        name: "Subtle Fade",
        category: .vintage,
        recipe: FilterRecipe(
            saturation: 0.90,
            brightness: 0.02,
            contrast: 0.92,
            highlights: -0.10,
            shadows: 0.15,
            hue: -3.0,
            sharpness: 0.06,
            gaussianBlur: 0.25,
            tintColorHex: "#D0B28D",
            tintIntensity: 0.08
        ),
        previewColor: UIColor(hex: "#D0B28D") ?? UIColor.systemGray
    )

    /// B&W High Contrast: 高コントラストモノクロ
    static let bwHighContrast = FilterPreset(
        id: "bw_high_contrast",
        name: "B&W High Contrast",
        category: .mono,
        recipe: FilterRecipe(
            saturation: 0.00,
            brightness: -0.02,
            contrast: 1.20,
            highlights: 0.08,
            shadows: -0.18,
            hue: 0.0,
            sharpness: 0.18,
            gaussianBlur: 0.0,
            tintColorHex: nil,
            tintIntensity: 0.0
        ),
        previewColor: UIColor.systemGray
    )

    /// Noir: 完全モノクロ コントラスト↑ シャープネス↑
    static let noir = FilterPreset(
        id: "noir",
        name: "Noir",
        category: .mono,
        recipe: FilterRecipe(
            saturation: 0.0,
            contrast: 1.12,
            sharpness: 0.10
        ),
        previewColor: UIColor.darkGray
    )
}
