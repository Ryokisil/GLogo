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
class ManualBackgroundRemovalViewModel: ObservableObject, @MainActor MaskEditingViewModeling {
    // MARK: - プロパティ

    /// 編集状態
    @Published var state: ManualBackgroundRemovalState

    /// 元画像（編集開始時の状態）
    let originalImage: UIImage

    /// 完了時のコールバック（画像を返す）
    private let completion: (UIImage) -> Void

    /// 画像処理ユースケース
    private let useCase: ManualBackgroundRemovalUseCase

    /// AI背景除去ユースケース
    private let backgroundRemovalUseCase: BackgroundRemovalUseCase

    // MARK: - イニシャライザ

    /// 背景除去モード用イニシャライザ
    /// - Parameters:
    ///   - imageElement: 編集対象の画像要素
    ///   - completion: 編集完了時の処理（背景除去後の画像を返す）
    ///   - useCase: 画像処理ユースケース
    ///   - backgroundRemovalUseCase: AI背景除去ユースケース
    /// - Returns: なし
    init(
        imageElement: ImageElement,
        completion: @escaping (UIImage) -> Void,
        useCase: ManualBackgroundRemovalUseCase = ManualBackgroundRemovalUseCase(),
        backgroundRemovalUseCase: BackgroundRemovalUseCase = BackgroundRemovalUseCase()
    ) {
        self.completion = completion
        self.useCase = useCase
        self.backgroundRemovalUseCase = backgroundRemovalUseCase
        // ImageElementから現在の表示用画像を取得
        let resolvedImage = imageElement.image ?? imageElement.originalImage
        let isSourceImageAvailable = (resolvedImage != nil)
        self.originalImage = resolvedImage ?? Self.makeFallbackImage()

        // 初期状態の設定
        var initialState = ManualBackgroundRemovalState()
        initialState.isSourceImageAvailable = isSourceImageAvailable
        if !isSourceImageAvailable {
            initialState.sourceImageErrorMessage = "Failed to load image."
        }

        // SwiftUIマスキングでは履歴管理も簡素化
        self.state = initialState

        // selfが完全に初期化された後にマスクを作成
        let initialMask = useCase.createInitialMask(for: originalImage)
        self.state.maskImage = initialMask
        self.state.baseMaskImage = initialMask
        self.state.targetPoint = CGPoint(x: originalImage.size.width / 2, y: originalImage.size.height / 2)
    }

    /// 元画像が取得できない場合に使用するフォールバック画像を生成する
    /// - Parameters: なし
    /// - Returns: 1x1の透明画像
    private static func makeFallbackImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        return renderer.image { context in
            context.cgContext.setFillColor(UIColor.clear.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: CGSize(width: 1, height: 1)))
        }
    }
    
    // MARK: - ブラシ編集
    
    /// 指定座標にブラシストロークを適用
    func applyBrushStroke(at point: CGPoint) {
        guard let currentMask = state.maskImage else { return }

        let updatedMask = useCase.drawBrush(
            on: currentMask,
            at: point,
            size: state.brushSize,
            mode: state.mode
        )

        state.maskImage = updatedMask
        state.maskUpdateId = UUID()
    }
    
    /// 2点間に線を描画
    func applyBrushLine(from startPoint: CGPoint, to endPoint: CGPoint) {
        guard let currentMask = state.maskImage else { return }
        
        let updatedMask = useCase.drawLine(
            on: currentMask,
            from: startPoint,
            to: endPoint,
            size: state.brushSize,
            mode: state.mode
        )

        state.maskImage = updatedMask
        state.maskUpdateId = UUID()
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
        if let baseMask = state.baseMaskImage {
            state.maskImage = baseMask
        } else {
            state.maskImage = useCase.createInitialMask(for: originalImage)
        }
        state.editedImage = originalImage
        state.history = [originalImage]
        state.historyIndex = 0
    }
    
    // MARK: - 完了・キャンセル

    /// 編集完了
    func complete() {
        // マスクを適用した最終画像を生成
        if let maskImage = state.maskImage,
           let finalImage = useCase.applyMask(maskImage, to: originalImage) {
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
        return useCase.applyMask(maskImage, to: originalImage)
    }

    /// AIで生成したマスクを適用する
    func applyAIMask() async {
        state.isProcessingAI = true
        defer { state.isProcessingAI = false }

        do {
            let aiMask = try await backgroundRemovalUseCase.generateMask(from: originalImage)
            state.baseMaskImage = aiMask
            state.maskImage = aiMask
            state.maskUpdateId = UUID()
        } catch {
        }
    }

    /// ターゲット位置を更新（画像内にクランプ）
    func setTargetPoint(_ point: CGPoint) {
        state.targetPoint = clampedImagePoint(point)
    }
    
    // MARK: - プライベートメソッド
    
    /// 編集済み画像からマスクを再生成
    private func regenerateMaskFromImage() {
        // 実装の簡略化のため、履歴管理時は既存マスクを維持
        // より高度な実装では画像差分からマスクを逆算
    }

    private func clampedImagePoint(_ point: CGPoint) -> CGPoint {
        let maxX = max(0, originalImage.size.width - 1)
        let maxY = max(0, originalImage.size.height - 1)
        let clampedX = min(max(point.x, 0), maxX)
        let clampedY = min(max(point.y, 0), maxY)
        return CGPoint(x: clampedX, y: clampedY)
    }
}
