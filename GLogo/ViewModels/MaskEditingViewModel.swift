//
//  MaskEditingViewModeling.swift
//  GLogo
//
//  概要:
//  マスク編集用ViewModelの共通インターフェースを定義します。
//

import SwiftUI
import UIKit

/// マスク編集ViewModelが満たすべき要件
protocol MaskEditingViewModeling: ObservableObject {
    /// 元画像
    var originalImage: UIImage { get }
    /// 編集状態
    var state: ManualBackgroundRemovalState { get }

    /// 指定座標にブラシストロークを適用
    /// - Parameters:
    ///   - point: ブラシ適用位置
    /// - Returns: なし
    func applyBrushStroke(at point: CGPoint)

    /// 2点間に線を描画
    /// - Parameters:
    ///   - startPoint: 始点
    ///   - endPoint: 終点
    /// - Returns: なし
    func applyBrushLine(from startPoint: CGPoint, to endPoint: CGPoint)

    /// ターゲット位置を更新（画像内にクランプ）
    /// - Parameters:
    ///   - point: 更新する座標
    /// - Returns: なし
    func setTargetPoint(_ point: CGPoint)
}
