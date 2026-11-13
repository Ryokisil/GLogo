//
//  ImageEditingSessionUseCase.swift
//  GLogo
//
//  概要:
//  画像要素の編集中描画モード切り替えを扱うユースケース。
//

import Foundation

/// 画像要素の編集中描画モードを切り替えるユースケース。切り替えはエディタの管理役に求める。
@MainActor
struct ImageEditingSessionUseCase {
    private let renderSessions: any ImageRenderSessionControlling

    /// - Parameters:
    ///   - renderSessions: エディタの管理役（エディタが読み取りに使うものと同じインスタンス）
    init(renderSessions: any ImageRenderSessionControlling) {
        self.renderSessions = renderSessions
    }

    /// ジェスチャー操作中の描画モードを適用する
    /// - Parameters:
    ///   - imageElement: 対象画像要素
    ///   - ended: ジェスチャーが終了したかどうか
    /// - Returns: なし
    func applyManipulationState(to imageElement: ImageElement, ended: Bool) {
        if ended {
            renderSessions.endEditing(imageElement)
            return
        }

        // 移動・拡縮・回転は頻度が高い操作のため、調整差分ではなく追従性を優先する。
        renderSessions.startEditing(imageElement)
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
            renderSessions.startEditing(imageElement)
        } else {
            renderSessions.endEditing(imageElement)
        }
    }

    /// 編集中プレビューを開始する
    /// - Parameters:
    ///   - imageElement: 対象画像要素
    /// - Returns: なし
    func beginEditing(_ imageElement: ImageElement) {
        renderSessions.startEditing(imageElement)
    }

    /// 編集中プレビューを終了する
    /// - Parameters:
    ///   - imageElement: 対象画像要素
    /// - Returns: なし
    func endEditing(_ imageElement: ImageElement) {
        renderSessions.endEditing(imageElement)
    }
}
