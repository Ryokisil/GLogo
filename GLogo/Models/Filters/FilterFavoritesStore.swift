//
//  FilterFavoritesStore.swift
//  GLogo
//
//  概要:
//  フィルタープリセットのお気に入り状態を UserDefaults で管理する薄いストア。
//  preset.id 単位で保存し、SDR/HDR は ID の違いで自然に分離される。
//

import Foundation

/// フィルターお気に入りの永続管理
struct FilterFavoritesStore {

    /// UserDefaults に保存する際のキー
    private static let defaultsKey = "filterFavoritePresetIds"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// お気に入り登録済みの preset.id 集合を読み出す
    func loadFavoriteIds() -> Set<String> {
        Set(defaults.stringArray(forKey: Self.defaultsKey) ?? [])
    }

    /// お気に入り状態を切り替え、更新後の集合を返す
    @discardableResult
    mutating func toggle(_ presetId: String) -> Set<String> {
        var ids = loadFavoriteIds()
        if ids.contains(presetId) {
            ids.remove(presetId)
        } else {
            ids.insert(presetId)
        }
        defaults.set(Array(ids), forKey: Self.defaultsKey)
        return ids
    }

    /// 指定プリセットがお気に入りかどうか
    func isFavorite(_ presetId: String) -> Bool {
        loadFavoriteIds().contains(presetId)
    }

    /// 指定プリセット群からお気に入りのみ抽出
    func favorites(from presets: [FilterPreset]) -> [FilterPreset] {
        let ids = loadFavoriteIds()
        return presets.filter { ids.contains($0.id) }
    }
}
