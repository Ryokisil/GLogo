//
//  ImageCropViewModel.swift
//  GLogo
//
//  概要:
//  画像クロップ機能のビューモデルです。
//  画像の表示、クロップ領域の管理、AI背景除去機能を提供します。
//

import Foundation
import UIKit
import Vision

class ImageCropViewModel: ObservableObject {
    // MARK: - プロパティ
    
    @Published var cropRect: CGRect = CGRect(x: 0, y: 0, width: 100, height: 100) {
        didSet {
            checkHasCropped()
        }
    }
    
    @Published var imageViewFrame: CGRect = .zero {
        didSet {
            checkHasCropped()
        }
    }
    @Published var imageIsLoaded: Bool = false
    @Published var hasCropped: Bool = false
    
    /// AI背景除去の処理状態
    @Published var isProcessingBackgroundRemoval: Bool = false
    
    /// 背景除去済みの画像（nilの場合は未処理）
    @Published var backgroundRemovedImage: UIImage?
    
    
    let originalImage: UIImage
    private let completion: (UIImage) -> Void
    
    // MARK: - イニシャライザ
    
    init(image: UIImage, completion: @escaping (UIImage) -> Void) {
        self.originalImage = image
        self.completion = completion
    }
    
    // MARK: - AI背景除去
    
    /// AI背景除去を開始
    @MainActor
    func startBackgroundRemoval() {
        guard !isProcessingBackgroundRemoval else { return }
        
        isProcessingBackgroundRemoval = true
        
        Task {
            do {
                let processedImage = try await removeBackground(from: originalImage)
                await MainActor.run {
                    self.backgroundRemovedImage = processedImage
                    self.isProcessingBackgroundRemoval = false
                }
            } catch {
                print("AI背景除去エラー: \(error.localizedDescription)")
                await MainActor.run {
                    self.isProcessingBackgroundRemoval = false
                }
            }
        }
    }
    
    /// Vision フレームワークを使用した背景除去処理
    private func removeBackground(from image: UIImage) async throws -> UIImage {
    guard let cgImage = image.cgImage else {
        throw NSError(domain: "ImageCropError", code: 1, userInfo: [NSLocalizedDescriptionKey: "CGImageの作成に失敗"])
    }
    
    let request = VNGenerateForegroundInstanceMaskRequest()
    
    return try await withCheckedThrowingContinuation { continuation in
        let handler = VNImageRequestHandler(cgImage: cgImage)
        
        do {
            try handler.perform([request])
            
            guard let result = request.results?.first else {
                continuation.resume(throwing: NSError(domain: "VisionError", code: 2, userInfo: [NSLocalizedDescriptionKey: "前景マスクの生成に失敗"]))
                return
            }
            
            // マスクを生成（AIの高精度を完全保持）
            let mask = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
            let originalMaskImage = CIImage(cvPixelBuffer: mask)
            
            // 浸透効果用のソフトマスクを別途作成（元のマスクは触らない）
            let featheredMask = self.createFeatheredMask(from: originalMaskImage)
            
            // Core Imageで浸透効果を適用
            let originalCIImage = CIImage(cgImage: cgImage)
            
            guard let filter = CIFilter(name: "CIBlendWithMask") else {
                continuation.resume(throwing: NSError(domain: "CoreImageError", code: 3, userInfo: [NSLocalizedDescriptionKey: "CIBlendWithMaskフィルターが利用不可"]))
                return
            }
            
            // フィルター設定（フェザーマスクを使用）
            filter.setValue(originalCIImage, forKey: kCIInputImageKey)
            filter.setValue(featheredMask, forKey: kCIInputMaskImageKey)
            filter.setValue(CIImage.empty(), forKey: kCIInputBackgroundImageKey)
            
            guard let outputImage = filter.outputImage else {
                continuation.resume(throwing: NSError(domain: "CoreImageError", code: 4, userInfo: [NSLocalizedDescriptionKey: "フィルター処理に失敗"]))
                return
            }
            
            // CIImage → UIImage変換
            let context = CIContext()
            guard let resultCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
                continuation.resume(throwing: NSError(domain: "CoreImageError", code: 5, userInfo: [NSLocalizedDescriptionKey: "最終画像の生成に失敗"]))
                return
            }
            
            let resultImage = UIImage(cgImage: resultCGImage)
            continuation.resume(returning: resultImage)
            
        } catch {
            continuation.resume(throwing: error)
        }
    }
}
    
    
    // MARK: - コマンド
    
    func onComplete() {
        print("===完了時点でのデバッグ情報===")
        print("元画像サイズ: \(originalImage.size)")
        print("表示フレーム: \(imageViewFrame)")
        print("クロップ領域: \(cropRect)")
        print("クロップ実行の有無: \(hasCropped)")
        
        // AI背景除去済みの画像があればそれを使用、なければ通常のクロップ処理
        let sourceImage = backgroundRemovedImage ?? originalImage
        
        if let croppedImage = cropImage(from: sourceImage) {
            print("クロップ完了 - 結果画像サイズ: \(croppedImage.size)")
            completion(croppedImage)
        } else {
            print("エラー: クロップ処理に失敗しました")
            // フォールバックとして元画像を返す
            completion(originalImage)
        }
    }
    
    func onCropRectChanged() {
        let tolerance: CGFloat = 1.0
        let isEqual = abs(cropRect.minX - imageViewFrame.minX) < tolerance &&
        abs(cropRect.minY - imageViewFrame.minY) < tolerance &&
        abs(cropRect.width - imageViewFrame.width) < tolerance &&
        abs(cropRect.height - imageViewFrame.height) < tolerance
        
        hasCropped = !isEqual
        print("DEBUG: クロップ領域変更: hasCropped = \(hasCropped)")
    }
    
    private func checkHasCropped() {
        let tolerance: CGFloat = 1.0
        let isEqual = abs(cropRect.minX - imageViewFrame.minX) < tolerance &&
        abs(cropRect.minY - imageViewFrame.minY) < tolerance &&
        abs(cropRect.width - imageViewFrame.width) < tolerance &&
        abs(cropRect.height - imageViewFrame.height) < tolerance
        
        hasCropped = !isEqual
        print("DEBUG: クロップ領域変更: hasCropped = \(hasCropped)")
        print("DEBUG: cropRect = \(cropRect)")
        print("DEBUG: imageViewFrame = \(imageViewFrame)")
    }
    
    func resetCropRect() {
        if imageIsLoaded {
            self.cropRect = imageViewFrame
            self.hasCropped = false
            print("クロップ領域をリセット: \(cropRect)")
        }
    }
    
    func setCropAspectRatio(_ ratio: CGFloat) {
        let center = CGPoint(x: cropRect.midX, y: cropRect.midY)
        
        var newWidth: CGFloat
        var newHeight: CGFloat
        
        if cropRect.width > cropRect.height {
            newWidth = cropRect.width
            newHeight = newWidth / ratio
        } else {
            newHeight = cropRect.height
            newWidth = newHeight * ratio
        }
        
        cropRect = CGRect(
            x: center.x - newWidth / 2,
            y: center.y - newHeight / 2,
            width: newWidth,
            height: newHeight
        )
        
        adjustCropRectToImageBounds()
        hasCropped = true
    }
    
    // MARK: - ヘルパーメソッド
    
    func updateImageFrame(_ frame: CGRect) {
        print("DEBUG: updateImageFrame called with frame: \(frame)")
        
        self.imageViewFrame = frame
        
        if !imageIsLoaded {
            // 初期クロップ領域を画像フレーム全体に設定
            self.cropRect = frame
            self.imageIsLoaded = true
            self.hasCropped = false
            
            print("DEBUG: 初期クロップ領域を設定: \(cropRect)")
            print("DEBUG: 画像フレーム: \(imageViewFrame)")
        }
    }
    
    private func adjustCropRectToImageBounds() {
        if cropRect.minX < imageViewFrame.minX {
            cropRect.origin.x = imageViewFrame.minX
        }
        if cropRect.minY < imageViewFrame.minY {
            cropRect.origin.y = imageViewFrame.minY
        }
        if cropRect.maxX > imageViewFrame.maxX {
            cropRect.origin.x = imageViewFrame.maxX - cropRect.width
        }
        if cropRect.maxY > imageViewFrame.maxY {
            cropRect.origin.y = imageViewFrame.maxY - cropRect.height
        }
    }
    
    private func cropImage(from sourceImage: UIImage? = nil) -> UIImage? {
        let imageToProcess = sourceImage ?? originalImage
        guard imageViewFrame.width > 0 && imageViewFrame.height > 0 else {
            print("エラー: 画像表示フレームが無効です")
            return nil
        }
        
        print("=== クロップ処理デバッグ ===")
        print("処理画像サイズ: \(imageToProcess.size)")
        print("画像表示サイズ: \(imageViewFrame)")
        print("クロップ領域: \(cropRect)")
        print("クロップ実行済み: \(hasCropped)")
        
        if !hasCropped {
            print("クロップなし: 処理画像を返します")
            return imageToProcess
        }
        
        // クロップ枠を画像フレーム内に制限
        let boundedCropRect = cropRect.intersection(imageViewFrame)
        print("制限されたクロップ枠: \(boundedCropRect)")
        
        // 正規化座標系への変換
        let normalizedX = (boundedCropRect.minX - imageViewFrame.minX) / imageViewFrame.width
        let normalizedY = (boundedCropRect.minY - imageViewFrame.minY) / imageViewFrame.height
        let normalizedWidth = boundedCropRect.width / imageViewFrame.width
        let normalizedHeight = boundedCropRect.height / imageViewFrame.height
        
        print("正規化座標: x=\(normalizedX), y=\(normalizedY), w=\(normalizedWidth), h=\(normalizedHeight)")
        
        // UIImage.sizeを使用してスケーリング
        let imageSize = imageToProcess.size
        let scaledX = normalizedX * imageSize.width
        let scaledY = normalizedY * imageSize.height
        let scaledWidth = normalizedWidth * imageSize.width
        let scaledHeight = normalizedHeight * imageSize.height
        
        print("スケールされた浮動小数点値: x=\(scaledX), y=\(scaledY), w=\(scaledWidth), h=\(scaledHeight)")
        
        // 画像の向きを考慮してCGImageを取得
        guard let orientedCGImage = createOrientedCGImage(from: imageToProcess) else {
            print("エラー: orientedCGImageの作成に失敗")
            return nil
        }
        
        // 整数への変換
        let intX = Int(scaledX.rounded(.toNearestOrAwayFromZero))
        let intY = Int(scaledY.rounded(.toNearestOrAwayFromZero))
        let intWidth = Int(scaledWidth.rounded(.toNearestOrAwayFromZero))
        let intHeight = Int(scaledHeight.rounded(.toNearestOrAwayFromZero))
        
        print("整数変換後: x=\(intX), y=\(intY), w=\(intWidth), h=\(intHeight)")
        
        let scaledCropRect = CGRect(
            x: CGFloat(intX),
            y: CGFloat(intY),
            width: CGFloat(intWidth),
            height: CGFloat(intHeight)
        )
        
        print("スケールされたクロップ枠: \(scaledCropRect)")
        
        guard let croppedCGImage = orientedCGImage.cropping(to: scaledCropRect) else {
            print("エラー: クロップに失敗しました")
            return nil
        }
        
        print("クロップ成功！")
        let resultImage = UIImage(cgImage: croppedCGImage)
        
        print("クロップ完了 - 結果画像サイズ: \(resultImage.size)")
        
        return resultImage
    }
    
    /// AIマスクに浸透効果を適用（高精度を保持しつつエッジを柔らかく）
    private func createFeatheredMask(from originalMask: CIImage) -> CIImage {
        // ガウシアンブラーでエッジを柔らかくして浸透効果を作成
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else {
            print("WARNING: CIGaussianBlur が利用できません - 元のマスクを使用")
            return originalMask
        }
        
        blurFilter.setValue(originalMask, forKey: kCIInputImageKey)
        blurFilter.setValue(6.0, forKey: kCIInputRadiusKey) // 自然な浸透効果の最適値
        
        guard let blurredMask = blurFilter.outputImage else {
            print("WARNING: ブラー処理に失敗 - 元のマスクを使用")
            return originalMask
        }
        
        // ガンマ調整で浸透の減衰カーブを調整
        guard let gammaFilter = CIFilter(name: "CIGammaAdjust") else {
            return blurredMask
        }
        
        gammaFilter.setValue(blurredMask, forKey: kCIInputImageKey)
        gammaFilter.setValue(0.8, forKey: "inputPower") // 柔らかな減衰カーブ
        
        return gammaFilter.outputImage ?? blurredMask
    }
    
    // MARK: - 画像の向きを考慮したCGImageを作成
    
    private func createOrientedCGImage(from uiImage: UIImage) -> CGImage? {
        // UIImageを描画して新しいCGImageを作成
        let size = uiImage.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = uiImage.scale
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        
        let renderedImage = renderer.image { context in
            // CGContextで画像を描画（向きが自動的に考慮される）
            uiImage.draw(in: CGRect(origin: .zero, size: size))
        }
        
        return renderedImage.cgImage
    }
}
