//
//  ImageRenderRefreshUseCase.swift
//  GLogo
//
//  概要:
//  画像調整プレビューと最終品質の再描画更新フローを扱うユースケース。
//

import Foundation
import UIKit

/// 画像レンダリング更新ユースケース
@MainActor
final class ImageRenderRefreshUseCase {
    /// 最新のみ実行するレンダリングスケジューラ
    private let renderScheduler = RenderScheduler()

    /// 画像調整プレビュー値を適用する
    /// - Parameters:
    ///   - value: 新しい調整値
    ///   - imageElement: 対象画像要素
    ///   - descriptor: 調整ディスクリプタ
    /// - Returns: 値が更新された場合の `true`
    func applyAdjustmentPreview(
        value: CGFloat,
        to imageElement: ImageElement,
        descriptor: ImageAdjustmentDescriptor
    ) -> Bool {
        guard imageElement[keyPath: descriptor.keyPath] != value else {
            return false
        }

        imageElement[keyPath: descriptor.keyPath] = value
        return true
    }

    /// トーンカーブのプレビュー値を適用する
    /// - Parameters:
    ///   - newData: 新しいトーンカーブデータ
    ///   - imageElement: 対象画像要素
    /// - Returns: 値が更新された場合の `true`
    func applyToneCurvePreview(
        _ newData: ToneCurveData,
        to imageElement: ImageElement
    ) -> Bool {
        guard imageElement.toneCurveData != newData else {
            return false
        }

        imageElement.toneCurveData = newData
        imageElement.cachedImage = nil
        return true
    }

    /// 最終品質の再描画を遅延実行する
    /// - Parameters:
    ///   - update: メインアクター上の更新処理
    /// - Returns: なし
    func scheduleFinalRefresh(
        update: @escaping @MainActor () -> Void
    ) {
        renderScheduler.schedule {
            Task { @MainActor in
                guard !Task.isCancelled else { return }
                update()
            }
        }
    }

    /// 保留中の再描画を破棄する
    /// - Parameters: なし
    /// - Returns: なし
    func cancelScheduledRefresh() {
        renderScheduler.cancel()
    }
}
