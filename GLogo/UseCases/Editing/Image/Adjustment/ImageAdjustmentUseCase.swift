//
//  ImageAdjustmentUseCase.swift
//  GLogo
//
//  概要:
//  画像調整スライダーの開始値保持と、確定時の履歴イベント生成を扱うユースケース。
//

import Foundation
import UIKit

/// 画像調整確定計画
struct ImageAdjustmentCommitPlan {
    /// 履歴に記録するイベント
    let event: EditorEvent?

    /// メタデータ保存用キー
    let metadataKey: String

    /// 変更前の値
    let oldValue: CGFloat

    /// 変更後の値
    let newValue: CGFloat
}

/// 画像調整ユースケース
@MainActor
final class ImageAdjustmentUseCase {
    /// スライダー操作開始時の値
    private var startValues: [ImageAdjustmentKey: CGFloat] = [:]

    /// 要素切り替え時に保持中の開始値を破棄する
    /// - Parameters: なし
    /// - Returns: なし
    func reset() {
        startValues.removeAll()
    }

    /// 画像調整の開始値を記録する
    /// - Parameters:
    ///   - key: 調整キー
    ///   - currentValue: 開始時点の値
    /// - Returns: なし
    func beginAdjustment(_ key: ImageAdjustmentKey, currentValue: CGFloat) {
        if startValues[key] == nil {
            startValues[key] = currentValue
        }
    }

    /// 画像調整確定時の計画を作成する
    /// - Parameters:
    ///   - key: 調整キー
    ///   - finalValue: 確定値
    ///   - imageElement: 対象画像要素
    ///   - descriptor: 調整ディスクリプタ
    /// - Returns: 履歴イベントとメタデータ保存に必要な計画
    func makeCommitPlan(
        for key: ImageAdjustmentKey,
        finalValue: CGFloat,
        imageElement: ImageElement,
        descriptor: ImageAdjustmentDescriptor
    ) -> ImageAdjustmentCommitPlan {
        let startValue = startValues[key] ?? finalValue
        startValues[key] = nil

        let event: EditorEvent?
        if startValue != finalValue {
            event = descriptor.eventFactory(imageElement, startValue, finalValue)
        } else {
            event = nil
        }

        return ImageAdjustmentCommitPlan(
            event: event,
            metadataKey: descriptor.metadataKey,
            oldValue: startValue,
            newValue: finalValue
        )
    }
}
