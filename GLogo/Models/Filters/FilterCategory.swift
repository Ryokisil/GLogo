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
    /// ヴィンテージ風フィルター
    case vintage
    /// モノクロ系フィルター
    case mono
    /// 映画風フィルター
    case cinematic

    var id: String { rawValue }

    /// 表示名
    var displayName: String {
        switch self {
        case .basic:
            return "Basic"
        case .vintage:
            return "Vintage"
        case .mono:
            return "Mono"
        case .cinematic:
            return "Cinematic"
        }
    }
}
