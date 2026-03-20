//
//  ImageEditingSessionUseCase.swift
//  GLogo
//
//  概要:
//  画像要素の編集中描画モード切り替えを扱うユースケース。
//

import Foundation

/// 画像要素の編集中描画モードを切り替えるユースケース
struct ImageEditingSessionUseCase {
    /// ジェスチャー操作中の描画モードを適用する
    /// - Parameters:
    ///   - imageElement: 対象画像要素
    ///   - ended: ジェスチャーが終了したかどうか
    /// - Returns: なし
    func applyManipulationState(to imageElement: ImageElement, ended: Bool) {
        if ended {
            imageElement.endEditing()
            return
        }

        if imageElement.shouldUseInstantPreviewForManipulation {
            imageElement.startEditing()
        } else {
            imageElement.endEditing()
        }
    }

    /// 画像調整ディスクリプタに応じて描画モードを切り替える
    /// - Parameters:
    ///   - imageElement: 対象画像要素
    ///   - descriptor: 調整ディスクリプタ
    /// - Returns: なし
    func applyAdjustmentState(
        to imageElement: ImageElement,
        descriptor: ImageAdjustmentDescriptor
    ) {
        if descriptor.usesInstantPreviewWhileEditing {
            imageElement.startEditing()
        } else {
            imageElement.endEditing()
        }
    }

    /// 編集中プレビューを開始する
    /// - Parameters:
    ///   - imageElement: 対象画像要素
    /// - Returns: なし
    func beginEditing(_ imageElement: ImageElement) {
        imageElement.startEditing()
    }

    /// 編集中プレビューを終了する
    /// - Parameters:
    ///   - imageElement: 対象画像要素
    /// - Returns: なし
    func endEditing(_ imageElement: ImageElement) {
        imageElement.endEditing()
    }
}
