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
        film,
        filmMatte,
        mono,
        monoContrast
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
}
