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
    private let renderScheduler: any RenderScheduling
    private let renderFullQuality: @MainActor (ImageElement) async -> UIImage?
    private var generation: UInt = 0
    private var renderTask: Task<Void, Never>?
    private var isRenderCurrent: (() -> Bool)?

    deinit { renderTask?.cancel() }

    /// 編集通知後に呼び、予約の世代とは別に変わった画像・履歴の失効を伝える。
    func cancelInvalidRefresh() {
        if isRenderCurrent?() == false { cancelScheduledRefresh() }
    }

    init(
        renderScheduler: any RenderScheduling,
        renderFullQuality: @escaping @MainActor (ImageElement) async -> UIImage? = { image in
            await image.renderFullQualityImageAsync()
        }
    ) {
        self.renderScheduler = renderScheduler
        self.renderFullQuality = renderFullQuality
    }

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

    /// 予約時の画像・履歴が有効な場合だけ、編集終了と表示更新を実行する。
    func scheduleFinalRefresh(
        for imageElement: ImageElement,
        edits: ImageEditUseCase,
        update: @escaping @MainActor () -> Void
    ) {
        guard let token = edits.imageEditToken(for: imageElement) else { return }
        scheduleRefresh {
            guard edits.isImageEditCurrent(token, for: imageElement) else { return }
            update()
        }
    }

    /// 選択変更や次の予約で失効したコールバックは、対象照合より前に破棄する。
    private func scheduleRefresh(
        update: @escaping @MainActor () -> Void
    ) {
        cancelScheduledRefresh()
        let requestGeneration = generation
        renderScheduler.schedule { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.generation == requestGeneration else { return }
                update()
            }
        }
    }

    /// 予約世代に加え、AI・履歴操作などで変わる編集対象も描画の前後で照合する。
    func scheduleFullQualityRefresh(
        for imageElement: ImageElement,
        edits: ImageEditUseCase,
        update: @escaping @MainActor () -> Void
    ) {
        guard let token = edits.imageEditToken(for: imageElement) else { return }
        let render = renderFullQuality
        scheduleRefresh { [weak self] in
            guard let requestGeneration = self?.generation else { return }
            self?.renderTask = Task { @MainActor [weak self] in
                defer {
                    if self?.generation == requestGeneration {
                        self?.renderTask = nil
                        self?.isRenderCurrent = nil
                    }
                }
                guard !Task.isCancelled, self?.generation == requestGeneration,
                      edits.isImageEditCurrent(token, for: imageElement) else { return }
                let processedImage = await render(imageElement)
                guard !Task.isCancelled, let self, self.generation == requestGeneration,
                      edits.isImageEditCurrent(token, for: imageElement) else { return }
                imageElement.cachedImage = processedImage
                imageElement.endEditing()
                update()
            }
        }
        isRenderCurrent = { edits.isImageEditCurrent(token, for: imageElement) }
    }

    /// 再描画の予約を取り消し、実行中の古い描画結果も反映対象から外す。
    /// - Parameters: なし
    /// - Returns: なし
    func cancelScheduledRefresh() {
        generation &+= 1
        renderScheduler.cancel()
        renderTask?.cancel()
        renderTask = nil
        isRenderCurrent = nil
    }
}
