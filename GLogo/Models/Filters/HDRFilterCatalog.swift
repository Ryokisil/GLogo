//
//  HDRFilterCatalog.swift
//  GLogo
//
//  概要:
//  HDR専用フィルタープリセットの一覧を提供するカタログ。
//  カテゴリ別のプリセット取得や全プリセットの一覧を返す。
//

import Foundation
import UIKit

/// HDRフィルターカタログ
enum HDRFilterCatalog {

    // MARK: - カテゴリ一覧

    /// プリセットが存在するカテゴリのみ返す
    static var categories: [FilterCategory] {
        FilterCategory.allCases.filter { !presets(for: $0).isEmpty }
    }

    // MARK: - 全プリセット

    /// 全HDRプリセット一覧（表示順）
    static let allPresets: [FilterPreset] = [
        original,
        natural,
        vivid,
        crisp,
        soft,
        dramatic,
        cityNight,
        goldenHour,
        tealOrange,
        neonNoir,
        epicLandscape,
        film,
        filmMatte,
        vintageWarm,
        fadedMemory,
        dustyFilm,
        retroChrome,
        mono,
        monoContrast,
        monoSoft,
        monoMatte,
        silverGrain,
        graphite
    ]

    // MARK: - カテゴリ別取得

    /// 指定カテゴリのプリセットを返す
    static func presets(for category: FilterCategory) -> [FilterPreset] {
        allPresets.filter { $0.category == category }
    }

    // MARK: - プリセット定義

    /// Original: 全値デフォルト（リセット用）
    static let original = FilterPreset(
        id: "hdr_original",
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

    /// Natural HDR: シャドウ持ち上げ + ハイライト抑制の自然なHDR
    static let natural = FilterPreset(
        id: "hdr_natural",
        name: "Natural HDR",
        category: .basic,
        recipe: FilterRecipe(
            saturation: 1.04,
            brightness: 0.02,
            contrast: 1.04,
            highlights: -0.20,
            shadows: 0.25,
            sharpness: 0.08
        ),
        previewColor: UIColor.systemGreen.withAlphaComponent(0.6)
    )

    /// Vivid: 彩度↑ コントラスト↑ の鮮やかHDR
    static let vivid = FilterPreset(
        id: "hdr_vivid",
        name: "Vivid",
        category: .basic,
        recipe: FilterRecipe(
            saturation: 1.25,
            contrast: 1.15,
            highlights: -0.10,
            shadows: 0.15,
            sharpness: 0.12
        ),
        previewColor: UIColor.systemOrange.withAlphaComponent(0.7)
    )

    /// Crisp: ディテール重視のシャープなHDR
    static let crisp = FilterPreset(
        id: "hdr_crisp",
        name: "Crisp",
        category: .basic,
        recipe: FilterRecipe(
            saturation: 1.12,
            contrast: 1.16,
            highlights: -0.12,
            shadows: 0.14,
            sharpness: 0.24
        ),
        previewColor: UIColor.systemBlue.withAlphaComponent(0.65)
    )

    /// Soft: ハイライトを少し残した柔らかいHDR
    static let soft = FilterPreset(
        id: "hdr_soft",
        name: "Soft",
        category: .basic,
        recipe: FilterRecipe(
            saturation: 1.02,
            brightness: 0.03,
            contrast: 0.96,
            highlights: 0.06,
            shadows: 0.22,
            gaussianBlur: 0.6
        ),
        previewColor: UIColor.systemPink.withAlphaComponent(0.45)
    )

    /// Dramatic: 高コントラスト + 深い影の劇的なHDR
    static let dramatic = FilterPreset(
        id: "hdr_dramatic",
        name: "Dramatic",
        category: .cinematic,
        recipe: FilterRecipe(
            saturation: 1.10,
            brightness: -0.03,
            contrast: 1.30,
            highlights: -0.15,
            shadows: -0.10,
            sharpness: 0.15
        ),
        previewColor: UIColor.systemIndigo.withAlphaComponent(0.7)
    )

    /// City Night: 夜景向けに寒色とコントラストを強調
    static let cityNight = FilterPreset(
        id: "hdr_city_night",
        name: "City Night",
        category: .cinematic,
        recipe: FilterRecipe(
            saturation: 1.08,
            brightness: -0.04,
            contrast: 1.26,
            highlights: -0.22,
            shadows: 0.06,
            hue: 7.0,
            sharpness: 0.20,
            tintColorHex: "#5E84B8",
            tintIntensity: 0.10
        ),
        previewColor: UIColor(hex: "#5E84B8") ?? UIColor.systemBlue
    )

    /// Golden Hour: 暖色ハイライト + ソフトシャドウ
    static let goldenHour = FilterPreset(
        id: "hdr_golden_hour",
        name: "Golden Hour",
        category: .cinematic,
        recipe: FilterRecipe(
            saturation: 1.12,
            brightness: 0.03,
            contrast: 1.06,
            highlights: 0.10,
            shadows: 0.20,
            tintColorHex: "#D4A054",
            tintIntensity: 0.15
        ),
        previewColor: UIColor(hex: "#D4A054") ?? UIColor.systemYellow
    )

    /// Teal & Orange: 映画的な寒暖分離
    static let tealOrange = FilterPreset(
        id: "hdr_teal_orange",
        name: "Teal & Orange",
        category: .cinematic,
        recipe: FilterRecipe(
            saturation: 1.15,
            contrast: 1.12,
            highlights: -0.08,
            shadows: 0.12,
            hue: 5.0,
            tintColorHex: "#E08840",
            tintIntensity: 0.12
        ),
        previewColor: UIColor(hex: "#E08840") ?? UIColor.systemTeal
    )

    /// Neon Noir: ネオン光を強調する高コントラストシネマトーン
    static let neonNoir = FilterPreset(
        id: "hdr_neon_noir",
        name: "Neon Noir",
        category: .cinematic,
        recipe: FilterRecipe(
            saturation: 1.18,
            brightness: -0.05,
            contrast: 1.34,
            highlights: -0.24,
            shadows: 0.04,
            hue: 9.0,
            sharpness: 0.24,
            tintColorHex: "#6A59C8",
            tintIntensity: 0.12
        ),
        previewColor: UIColor(hex: "#6A59C8") ?? UIColor.systemIndigo
    )

    /// Epic Landscape: 空と地表の立体感を強める風景向けトーン
    static let epicLandscape = FilterPreset(
        id: "hdr_epic_landscape",
        name: "Epic Landscape",
        category: .cinematic,
        recipe: FilterRecipe(
            saturation: 1.14,
            brightness: 0.01,
            contrast: 1.20,
            highlights: -0.14,
            shadows: 0.18,
            sharpness: 0.20,
            tintColorHex: "#4D87A9",
            tintIntensity: 0.08
        ),
        previewColor: UIColor(hex: "#4D87A9") ?? UIColor.systemCyan
    )

    /// Film HDR: フィルム調ミュートHDR
    static let film = FilterPreset(
        id: "hdr_film",
        name: "Film HDR",
        category: .vintage,
        recipe: FilterRecipe(
            saturation: 0.88,
            brightness: 0.02,
            contrast: 0.94,
            highlights: -0.18,
            shadows: 0.22,
            gaussianBlur: 0.3,
            tintColorHex: "#B8956A",
            tintIntensity: 0.10
        ),
        previewColor: UIColor(hex: "#B8956A") ?? UIColor.systemBrown
    )

    /// Film Matte: 黒浮きを抑えたマット寄りHDRフィルム
    static let filmMatte = FilterPreset(
        id: "hdr_film_matte",
        name: "Film Matte",
        category: .vintage,
        recipe: FilterRecipe(
            saturation: 0.84,
            brightness: 0.01,
            contrast: 0.90,
            highlights: -0.24,
            shadows: 0.28,
            gaussianBlur: 0.5,
            tintColorHex: "#A98867",
            tintIntensity: 0.12
        ),
        previewColor: UIColor(hex: "#A98867") ?? UIColor.brown
    )

    /// Vintage Warm: 暖色寄りに柔らかくまとめたHDRヴィンテージ
    static let vintageWarm = FilterPreset(
        id: "hdr_vintage_warm",
        name: "Vintage Warm",
        category: .vintage,
        recipe: FilterRecipe(
            saturation: 0.92,
            brightness: 0.02,
            contrast: 0.92,
            highlights: -0.20,
            shadows: 0.24,
            tintColorHex: "#C89A64",
            tintIntensity: 0.14
        ),
        previewColor: UIColor(hex: "#C89A64") ?? UIColor.systemOrange
    )

    /// Faded Memory: 退色感を強めた懐古調HDR
    static let fadedMemory = FilterPreset(
        id: "hdr_faded_memory",
        name: "Faded Memory",
        category: .vintage,
        recipe: FilterRecipe(
            saturation: 0.80,
            brightness: 0.03,
            contrast: 0.88,
            highlights: -0.16,
            shadows: 0.28,
            gaussianBlur: 0.45,
            tintColorHex: "#BAA07E",
            tintIntensity: 0.12
        ),
        previewColor: UIColor(hex: "#BAA07E") ?? UIColor.systemBrown
    )

    /// Dusty Film: 粒感を活かしたドライなフィルム調HDR
    static let dustyFilm = FilterPreset(
        id: "hdr_dusty_film",
        name: "Dusty Film",
        category: .vintage,
        recipe: FilterRecipe(
            saturation: 0.86,
            brightness: -0.01,
            contrast: 0.94,
            highlights: -0.24,
            shadows: 0.20,
            gaussianBlur: 0.55,
            tintColorHex: "#9E8A74",
            tintIntensity: 0.10
        ),
        previewColor: UIColor(hex: "#9E8A74") ?? UIColor.brown
    )

    /// Retro Chrome: 寒色寄りメタリックなレトロ調HDR
    static let retroChrome = FilterPreset(
        id: "hdr_retro_chrome",
        name: "Retro Chrome",
        category: .vintage,
        recipe: FilterRecipe(
            saturation: 0.88,
            brightness: -0.02,
            contrast: 1.02,
            highlights: -0.22,
            shadows: 0.14,
            hue: 6.0,
            sharpness: 0.14,
            tintColorHex: "#7E8FA4",
            tintIntensity: 0.10
        ),
        previewColor: UIColor(hex: "#7E8FA4") ?? UIColor.systemGray
    )

    /// HDR Mono: ディテール豊富なモノクロHDR
    static let mono = FilterPreset(
        id: "hdr_mono",
        name: "HDR Mono",
        category: .mono,
        recipe: FilterRecipe(
            saturation: 0.0,
            contrast: 1.18,
            highlights: -0.12,
            shadows: 0.20,
            sharpness: 0.20
        ),
        previewColor: UIColor.systemGray2
    )

    /// Mono Contrast: モノクロでコントラストをさらに強調
    static let monoContrast = FilterPreset(
        id: "hdr_mono_contrast",
        name: "Mono Contrast",
        category: .mono,
        recipe: FilterRecipe(
            saturation: 0.0,
            brightness: -0.02,
            contrast: 1.28,
            highlights: -0.20,
            shadows: 0.14,
            sharpness: 0.24
        ),
        previewColor: UIColor.systemGray
    )

    /// Mono Soft: 明部階調を残した柔らかいHDRモノクロ
    static let monoSoft = FilterPreset(
        id: "hdr_mono_soft",
        name: "Mono Soft",
        category: .mono,
        recipe: FilterRecipe(
            saturation: 0.0,
            brightness: 0.03,
            contrast: 0.92,
            highlights: 0.06,
            shadows: 0.18,
            sharpness: 0.10
        ),
        previewColor: UIColor.systemGray4
    )

    /// Mono Matte: 黒を少し浮かせたマット調モノクロ
    static let monoMatte = FilterPreset(
        id: "hdr_mono_matte",
        name: "Mono Matte",
        category: .mono,
        recipe: FilterRecipe(
            saturation: 0.0,
            brightness: 0.02,
            contrast: 0.86,
            highlights: 0.04,
            shadows: 0.24,
            sharpness: 0.08
        ),
        previewColor: UIColor.systemGray3
    )

    /// Silver Grain: 銀塩写真のような硬質モノクロ
    static let silverGrain = FilterPreset(
        id: "hdr_silver_grain",
        name: "Silver Grain",
        category: .mono,
        recipe: FilterRecipe(
            saturation: 0.0,
            brightness: -0.01,
            contrast: 1.24,
            highlights: -0.10,
            shadows: 0.10,
            sharpness: 0.22
        ),
        previewColor: UIColor.systemGray2
    )

    /// Graphite: 暗部を締めた重厚モノクロ
    static let graphite = FilterPreset(
        id: "hdr_graphite",
        name: "Graphite",
        category: .mono,
        recipe: FilterRecipe(
            saturation: 0.0,
            brightness: -0.04,
            contrast: 1.30,
            highlights: -0.18,
            shadows: -0.10,
            sharpness: 0.20
        ),
        previewColor: UIColor.darkGray
    )
}
