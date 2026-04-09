//
//  FilterCategory.swift
//  GLogo
//
//  概要:
//  フィルタープリセットのカテゴリ定義。
//  プリセットをグループ化して表示するための分類を提供する。
//

import Foundation

/// フィルターカテゴリ
enum FilterCategory: String, CaseIterable, Identifiable {
    /// 基本的なフィルター
    case basic
    /// ポートレート向けフィルター
    case portrait
    /// 映画風フィルター
    case cinematic
    /// ヴィンテージ風フィルター
    case vintage
    /// 雰囲気・空気感フィルター
    case mood
    /// モノクロ系フィルター
    case mono

    var id: String { rawValue }

    /// 表示名（英語固定。ローカライズは View 層で LocalizedStringKey 経由で解決する）
    var displayName: String {
        switch self {
        case .basic:
            return "Basic"
        case .portrait:
            return "Portrait"
        case .cinematic:
            return "Cinematic"
        case .vintage:
            return "Vintage"
        case .mood:
            return "Mood"
        case .mono:
            return "Mono"
        }
    }

    /// View 層でローカライズ表示に使用するキー文字列
    var localizationKey: String {
        "filters.category.\(rawValue)"
    }
}
