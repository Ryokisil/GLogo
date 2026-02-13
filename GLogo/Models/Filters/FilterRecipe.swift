//
//  FilterRecipe.swift
//  GLogo
//
//  概要:
//  フィルタープリセットが適用する画像調整値のレシピ定義。
//  nil のフィールドは「変更しない」を意味し、
//  非nil のフィールドのみ画像に適用される。
//

import Foundation

/// フィルター調整レシピ
struct FilterRecipe: Codable, Equatable {
    /// 彩度（デフォルト: 1.0, 範囲: 0...2）
    var saturation: CGFloat?
    /// 明度（デフォルト: 0.0, 範囲: -0.5...0.5）
    var brightness: CGFloat?
    /// コントラスト（デフォルト: 1.0, 範囲: 0.5...1.5）
    var contrast: CGFloat?
    /// ハイライト（デフォルト: 0.0, 範囲: -1...1）
    var highlights: CGFloat?
    /// シャドウ（デフォルト: 0.0, 範囲: -1...1）
    var shadows: CGFloat?
    /// 色相（デフォルト: 0.0, 範囲: -180...180）
    var hue: CGFloat?
    /// シャープネス（デフォルト: 0.0, 範囲: 0...2）
    var sharpness: CGFloat?
    /// ガウシアンブラー（デフォルト: 0.0, 範囲: 0...10）
    var gaussianBlur: CGFloat?
    /// ティントカラー（HEX文字列, 例: "#C98A4B"）nil = ティント変更なし
    var tintColorHex: String?
    /// ティント強度（デフォルト: 0.0）
    var tintIntensity: CGFloat?

    /// ティント変更を含むかどうか
    var affectsTint: Bool {
        tintColorHex != nil || tintIntensity != nil
    }
}
