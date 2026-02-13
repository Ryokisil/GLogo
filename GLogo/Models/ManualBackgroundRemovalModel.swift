//
//  ManualBackgroundRemovalModel.swift
//  GLogo
//
//  概要:
//  手動背景除去機能のデータモデルを定義します。
//  ブラシ設定、編集状態、マスク画像などの状態を管理します。
//

import Foundation
import UIKit

/// 手動背景除去の編集モード
enum RemovalMode: String, CaseIterable {
    case erase = "Erase"     // 背景を透明化
    case restore = "Restore" // 透明部分を元に戻す
}

/// 手動背景除去の状態を管理するモデル
struct ManualBackgroundRemovalState {
    /// 現在の編集モード
    var mode: RemovalMode = .erase
    
    /// ブラシサイズ（5-50ピクセル）
    var brushSize: CGFloat = 20.0
    
    /// 編集中のマスク画像（白=表示、黒=透明）
    var maskImage: UIImage?

    /// 編集の基準となるマスク画像（AI適用後の初期状態を保持）
    var baseMaskImage: UIImage?
    
    /// SwiftUI更新トリガー用のID
    var maskUpdateId: UUID = UUID()
    
    /// 編集済みの画像（マスク適用後）
    var editedImage: UIImage?
    
    /// 編集履歴（undo/redo用）
    var history: [UIImage] = []
    
    /// 現在の履歴インデックス
    var historyIndex: Int = -1
    
    /// undoが可能かどうか
    var canUndo: Bool {
        return historyIndex > 0
    }
    
    /// redoが可能かどうか
    var canRedo: Bool {
        return historyIndex < history.count - 1
    }
    
    /// プレビューモード（true=編集結果、false=元画像）
    var isShowingPreview: Bool = false

    /// ターゲット中心の画像座標
    var targetPoint: CGPoint = .zero

    /// AI処理中かどうか
    var isProcessingAI: Bool = false

    /// 元画像の取得に成功したかどうか
    var isSourceImageAvailable: Bool = true

    /// 元画像の取得に失敗した場合のメッセージ
    var sourceImageErrorMessage: String? = nil
}
