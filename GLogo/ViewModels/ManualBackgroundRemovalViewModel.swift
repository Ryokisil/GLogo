//
//  ManualBackgroundRemovalViewModel.swift
//  GLogo
//
//  概要:
//  手動背景除去機能のビューモデルです。
//  選択された画像要素に対してブラシベースの背景除去編集を提供し、
//  undo/redo機能とメモリ安全な状態管理を行います。
//

import SwiftUI
import UIKit

/// 手動背景除去用のビューモデル
@MainActor
class ManualBackgroundRemovalViewModel: ObservableObject {
    // MARK: - プロパティ
    
    /// 編集状態
    @Published var state: ManualBackgroundRemovalState
    
    /// 編集対象の画像要素（弱参照で循環参照を防ぐ）
    weak var editorViewModel: EditorViewModel?
    
    /// 編集対象の画像要素
    let targetImageElement: ImageElement
    
    /// 元画像（編集開始時の状態）
    let originalImage: UIImage
    
    /// 完了時のコールバック
    private let completion: (UIImage) -> Void
    
    // MARK: - イニシャライザ
    
    init(imageElement: ImageElement, editorViewModel: EditorViewModel?, completion: @escaping (UIImage) -> Void) {
        self.targetImageElement = imageElement
        self.editorViewModel = editorViewModel
        self.completion = completion
        // ImageElementから現在の表示用画像を取得
        self.originalImage = imageElement.image ?? UIImage()
        
        // 初期状態の設定
        let initialState = ManualBackgroundRemovalState()
        
        // SwiftUIマスキングでは履歴管理も簡素化
        self.state = initialState
        
        // selfが完全に初期化された後にマスクを作成
        self.state.maskImage = createInitialMask()
    }
    
    // MARK: - ブラシ編集
    
    /// 指定座標にブラシストロークを適用
    func applyBrushStroke(at point: CGPoint) {
    print("DEBUG: applyBrushStroke called at point: \(point)")
    guard let currentMask = state.maskImage else { 
        print("DEBUG: currentMask is nil")
        return 
    }
    
    print("DEBUG: Drawing brush on mask...")
    // ブラシストロークをマスクに適用
    let updatedMask = drawBrushOnMask(currentMask, at: point, size: state.brushSize, mode: state.mode)
    
    // SwiftUIに確実に変更を通知
    state.maskImage = updatedMask
    state.maskUpdateId = UUID()  // 強制的にSwiftUIを更新
    print("DEBUG: Mask updated with new ID: \(state.maskUpdateId)")
}
    
    /// 2点間に線を描画
    func applyBrushLine(from startPoint: CGPoint, to endPoint: CGPoint) {
        guard let currentMask = state.maskImage else { return }
        
        // 線描画でマスクを更新
        let updatedMask = drawLineOnMask(currentMask, from: startPoint, to: endPoint, size: state.brushSize, mode: state.mode)
        
        // SwiftUIに確実に変更を通知
        state.maskImage = updatedMask
        state.maskUpdateId = UUID()  // 強制的にSwiftUIを更新
    }
    
    /// ブラシサイズを変更
    func setBrushSize(_ size: CGFloat) {
        state.brushSize = max(5, min(50, size))
    }
    
    /// 編集モードを切り替え
    func toggleMode() {
        state.mode = state.mode == .erase ? .restore : .erase
    }
    
    /// プレビューモードを切り替え
    func togglePreview() {
        state.isShowingPreview.toggle()
    }
    
    // MARK: - 履歴管理（Undo/Redo）
    
    /// 履歴に追加
    private func addToHistory(_ image: UIImage) {
        // 現在位置より後の履歴を削除（新しい分岐）
        if state.historyIndex < state.history.count - 1 {
            state.history.removeSubrange((state.historyIndex + 1)...)
        }
        
        // 新しい状態を追加
        state.history.append(image)
        state.historyIndex = state.history.count - 1
        
        // 履歴サイズ制限（メモリ管理）
        let maxHistorySize = 20
        if state.history.count > maxHistorySize {
            let removeCount = state.history.count - maxHistorySize
            state.history.removeFirst(removeCount)
            state.historyIndex -= removeCount
        }
    }
    
    /// Undo実行
    func undo() {
        guard state.canUndo else { return }
        
        state.historyIndex -= 1
        state.editedImage = state.history[state.historyIndex]
        
        // マスクも再生成
        regenerateMaskFromImage()
    }
    
    /// Redo実行
    func redo() {
        guard state.canRedo else { return }
        
        state.historyIndex += 1
        state.editedImage = state.history[state.historyIndex]
        
        // マスクも再生成
        regenerateMaskFromImage()
    }
    
    /// リセット（初期状態に戻す）
    func reset() {
        state.maskImage = createInitialMask()
        state.editedImage = originalImage
        state.history = [originalImage]
        state.historyIndex = 0
    }
    
    // MARK: - 完了・キャンセル
    
    /// 編集完了
    func complete() {
        // マスクを適用した最終画像を生成
        if let maskImage = state.maskImage,
           let finalImage = applyMaskToImage(originalImage, mask: maskImage) {
            completion(finalImage)
        } else {
            completion(originalImage)
        }
    }
    
    /// 編集キャンセル
    func cancel() {
        completion(originalImage)
    }

    /// マスクを適用した画像を取得
    func getMaskedImage() -> UIImage? {
        guard let maskImage = state.maskImage else { return nil }
        return applyMaskToImage(originalImage, mask: maskImage)
    }
    
    // MARK: - プライベートメソッド
    
    /// 初期マスク作成（完全透明）
    private func createInitialMask() -> UIImage {
        let size = originalImage.size
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = originalImage.scale
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            // 白で塗りつぶし（初期状態：画像全体が見える）
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    /// マスクにブラシストロークを描画
    private func drawBrushOnMask(_ mask: UIImage, at point: CGPoint, size: CGFloat, mode: RemovalMode) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(mask.size, false, mask.scale)
    defer { UIGraphicsEndImageContext() }
    
    guard let context = UIGraphicsGetCurrentContext() else { return mask }
    
    // 既存マスクを描画
    mask.draw(in: CGRect(origin: .zero, size: mask.size))
    
    // CGImageMask用の色設定（白=表示、黒=透明）
    let brushColor = mode == .erase ? UIColor.black : UIColor.white  // 除去=黒（透明化）、復元=白（表示）
    context.setFillColor(brushColor.cgColor)
    
    // 円形ブラシを描画
    context.fillEllipse(in: CGRect(
        x: point.x - size / 2,
        y: point.y - size / 2,
        width: size,
        height: size
    ))
    
    print("DEBUG: Drew brush at (\(point.x), \(point.y)) with color: \(mode == .erase ? "black (透明化)" : "white (表示)")")
    
    return UIGraphicsGetImageFromCurrentImageContext() ?? mask
}
    
    /// 2点間に線を描画してマスクを更新
    private func drawLineOnMask(_ mask: UIImage, from startPoint: CGPoint, to endPoint: CGPoint, size: CGFloat, mode: RemovalMode) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(mask.size, false, mask.scale)
    defer { UIGraphicsEndImageContext() }
    
    guard let context = UIGraphicsGetCurrentContext() else { return mask }
    
    // 既存マスクを描画
    mask.draw(in: CGRect(origin: .zero, size: mask.size))
    
    // CGImageMask用の色設定（白=表示、黒=透明）
    let brushColor = mode == .erase ? UIColor.black : UIColor.white  // 除去=黒（透明化）、復元=白（表示）
    context.setFillColor(brushColor.cgColor)
    
    // 線の描画設定
    context.setLineCap(.round)
    context.setLineWidth(size)
    context.setStrokeColor(brushColor.cgColor)
    
    // 線を描画
    context.beginPath()
    context.move(to: startPoint)
    context.addLine(to: endPoint)
    context.strokePath()
    
    return UIGraphicsGetImageFromCurrentImageContext() ?? mask
}
    
    /// マスクを画像に適用
    private func applyMaskToImage(_ image: UIImage, mask: UIImage) -> UIImage? {
    let format = UIGraphicsImageRendererFormat()
    format.opaque = false
    format.scale = image.scale
    
    let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
    return renderer.image { context in
        let cgContext = context.cgContext
        
        // 元画像を描画
        image.draw(in: CGRect(origin: .zero, size: image.size))
        
        // マスクを取得してアルファチャンネルとして適用
        guard let maskCGImage = mask.cgImage else { return }
        
        // CGImageMaskを作成（白=透明、黒=不透明になるように反転）
        cgContext.clip(to: CGRect(origin: .zero, size: image.size), mask: maskCGImage)
    }
}
    
    /// 編集済み画像からマスクを再生成
    private func regenerateMaskFromImage() {
        // 実装の簡略化のため、履歴管理時は既存マスクを維持
        // より高度な実装では画像差分からマスクを逆算
    }
}
