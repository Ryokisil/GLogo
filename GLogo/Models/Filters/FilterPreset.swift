//
//  FilterPreset.swift
//  GLogo
//
//  概要:
//  名前付きフィルタープリセットの定義。
//  カテゴリ・レシピ・プレビュー用カラーを保持する。
//

import Foundation
import UIKit

/// フィルタープリセット
struct FilterPreset: Identifiable, Equatable {
    /// 一意識別子
    let id: String
    /// 表示名
    let name: String
    /// 所属カテゴリ
    let category: FilterCategory
    /// 調整レシピ
    let recipe: FilterRecipe
    /// プレビューカード用の代表色
    let previewColor: UIColor

    static func == (lhs: FilterPreset, rhs: FilterPreset) -> Bool {
        lhs.id == rhs.id
    }
}
