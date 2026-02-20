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
        natural,
        vivid,
        crisp,
        soft,
        dramatic,
        goldenHour,
        tealOrange,
        nightDrive,
        sunsetCinema,
        film,
        vintageWarm,
        vintageInstant,
        agedPhoto,
        coolMatte,
        coolShadowsWarmHighlights,
        subtleFade,
        bwHighContrast,
        monoSoft,
        monoMatte,
        monoPunch,
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

    /// Natural: 破綻を抑えた自然な補正
    static let natural = FilterPreset(
        id: "natural",
        name: "Natural",
        category: .basic,
        recipe: FilterRecipe(
            saturation: 1.04,
            brightness: 0.01,
            contrast: 1.04,
            highlights: -0.06,
            shadows: 0.08,
            sharpness: 0.06
        ),
        previewColor: UIColor.systemGreen.withAlphaComponent(0.55)
    )

    /// Vivid: 彩度とコントラストをしっかり強調
    static let vivid = FilterPreset(
        id: "vivid",
        name: "Vivid",
        category: .basic,
        recipe: FilterRecipe(
            saturation: 1.18,
            contrast: 1.14,
            highlights: -0.05,
            shadows: 0.06,
            sharpness: 0.14
        ),
        previewColor: UIColor.systemOrange.withAlphaComponent(0.65)
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

    /// Dramatic: 映画風の強い立体感
    static let dramatic = FilterPreset(
        id: "dramatic",
        name: "Dramatic",
        category: .cinematic,
        recipe: FilterRecipe(
            saturation: 1.08,
            brightness: -0.03,
            contrast: 1.24,
            highlights: -0.14,
            shadows: -0.08,
            sharpness: 0.16
        ),
        previewColor: UIColor.systemIndigo.withAlphaComponent(0.68)
    )

    /// Golden Hour: 暖色寄りでやわらかな夕景トーン
    static let goldenHour = FilterPreset(
        id: "golden_hour",
        name: "Golden Hour",
        category: .cinematic,
        recipe: FilterRecipe(
            saturation: 1.10,
            brightness: 0.03,
            contrast: 1.06,
            highlights: 0.10,
            shadows: 0.16,
            tintColorHex: "#D69E58",
            tintIntensity: 0.16
        ),
        previewColor: UIColor(hex: "#D69E58") ?? UIColor.systemYellow
    )

    /// Teal & Orange: 寒暖分離を強調するシネマトーン
    static let tealOrange = FilterPreset(
        id: "teal_orange",
        name: "Teal & Orange",
        category: .cinematic,
        recipe: FilterRecipe(
            saturation: 1.10,
            contrast: 1.10,
            highlights: -0.08,
            shadows: 0.10,
            hue: 5.0,
            tintColorHex: "#DB8B46",
            tintIntensity: 0.10
        ),
        previewColor: UIColor(hex: "#DB8B46") ?? UIColor.systemTeal
    )

    /// Night Drive: 寒色寄りで暗部を締めた夜景シネマトーン
    static let nightDrive = FilterPreset(
        id: "night_drive",
        name: "Night Drive",
        category: .cinematic,
        recipe: FilterRecipe(
            saturation: 0.96,
            brightness: -0.04,
            contrast: 1.20,
            highlights: -0.18,
            shadows: -0.04,
            hue: -4.0,
            sharpness: 0.14,
            tintColorHex: "#5D7DAE",
            tintIntensity: 0.12
        ),
        previewColor: UIColor(hex: "#5D7DAE") ?? UIColor.systemBlue
    )

    /// Sunset Cinema: 暖色の光感を強調する夕景シネマトーン
    static let sunsetCinema = FilterPreset(
        id: "sunset_cinema",
        name: "Sunset Cinema",
        category: .cinematic,
        recipe: FilterRecipe(
            saturation: 1.08,
            brightness: 0.02,
            contrast: 1.08,
            highlights: 0.06,
            shadows: 0.10,
            hue: 3.0,
            sharpness: 0.10,
            tintColorHex: "#D77A46",
            tintIntensity: 0.14
        ),
        previewColor: UIColor(hex: "#D77A46") ?? UIColor.systemOrange
    )

    /// Film: 軽い退色と粒状感のあるフィルム調
    static let film = FilterPreset(
        id: "film",
        name: "Film",
        category: .vintage,
        recipe: FilterRecipe(
            saturation: 0.90,
            brightness: 0.01,
            contrast: 0.94,
            highlights: -0.14,
            shadows: 0.16,
            gaussianBlur: 0.25,
            tintColorHex: "#BE9669",
            tintIntensity: 0.09
        ),
        previewColor: UIColor(hex: "#BE9669") ?? UIColor.systemBrown
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

    /// Mono Soft: 低コントラスト寄りの柔らかいモノクロ
    static let monoSoft = FilterPreset(
        id: "mono_soft",
        name: "Mono Soft",
        category: .mono,
        recipe: FilterRecipe(
            saturation: 0.0,
            brightness: 0.02,
            contrast: 0.90,
            highlights: 0.04,
            shadows: 0.12,
            sharpness: 0.06
        ),
        previewColor: UIColor.systemGray3
    )

    /// Mono Matte: 黒を少し持ち上げたマット調モノクロ
    static let monoMatte = FilterPreset(
        id: "mono_matte",
        name: "Mono Matte",
        category: .mono,
        recipe: FilterRecipe(
            saturation: 0.0,
            brightness: 0.03,
            contrast: 0.86,
            highlights: 0.06,
            shadows: 0.18,
            sharpness: 0.04
        ),
        previewColor: UIColor.systemGray4
    )

    /// Mono Punch: 強いコントラストで輪郭を立てるモノクロ
    static let monoPunch = FilterPreset(
        id: "mono_punch",
        name: "Mono Punch",
        category: .mono,
        recipe: FilterRecipe(
            saturation: 0.0,
            brightness: -0.01,
            contrast: 1.28,
            highlights: -0.04,
            shadows: -0.22,
            sharpness: 0.18
        ),
        previewColor: UIColor.systemGray2
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
