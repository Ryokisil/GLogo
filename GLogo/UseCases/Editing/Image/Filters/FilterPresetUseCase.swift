//
//  FilterPresetUseCase.swift
//  GLogo
//
//  概要:
//  フィルタープリセットの適用・解除ルールと履歴イベント生成を扱うユースケース。
//

import Foundation

/// フィルタープリセット適用計画
struct FilterPresetUpdatePlan {
    /// 履歴に記録するイベント
    let event: FilterPresetChangedEvent
}

/// フィルタープリセット適用ユースケース。表示画像の失効は、エディタの管理役に求める。
@MainActor
struct FilterPresetUseCase {
    private let renderSessions: any ImageRenderSessionControlling

    /// - Parameters:
    ///   - renderSessions: エディタの管理役（エディタが読み取りに使うものと同じインスタンス）
    init(renderSessions: any ImageRenderSessionControlling) {
        self.renderSessions = renderSessions
    }

    /// フィルタープリセット適用の更新計画を作成する
    /// - Parameters:
    ///   - preset: 適用するプリセット
    ///   - imageElement: 対象画像要素
    /// - Returns: 更新が必要な場合の適用計画
    func makeApplyPlan(
        preset: FilterPreset,
        for imageElement: ImageElement
    ) -> FilterPresetUpdatePlan? {
        let oldRecipe = imageElement.appliedFilterRecipe
        let oldPresetId = imageElement.appliedFilterPresetId

        guard oldPresetId != preset.id || oldRecipe != preset.recipe else {
            return nil
        }

        imageElement.appliedFilterRecipe = preset.recipe
        imageElement.appliedFilterPresetId = preset.id
        renderSessions.invalidate(.rendered, of: imageElement)

        let event = FilterPresetChangedEvent(
            elementId: imageElement.id,
            oldRecipe: oldRecipe,
            newRecipe: preset.recipe,
            oldPresetId: oldPresetId,
            newPresetId: preset.id
        )
        return FilterPresetUpdatePlan(event: event)
    }

    /// フィルタープリセット解除の更新計画を作成する
    /// - Parameters:
    ///   - imageElement: 対象画像要素
    /// - Returns: 更新が必要な場合の適用計画
    func makeResetPlan(for imageElement: ImageElement) -> FilterPresetUpdatePlan? {
        let oldRecipe = imageElement.appliedFilterRecipe
        let oldPresetId = imageElement.appliedFilterPresetId

        guard oldRecipe != nil || oldPresetId != nil else {
            return nil
        }

        imageElement.appliedFilterRecipe = nil
        imageElement.appliedFilterPresetId = nil
        renderSessions.invalidate(.rendered, of: imageElement)

        let event = FilterPresetChangedEvent(
            elementId: imageElement.id,
            oldRecipe: oldRecipe,
            newRecipe: nil,
            oldPresetId: oldPresetId,
            newPresetId: nil
        )
        return FilterPresetUpdatePlan(event: event)
    }
}
