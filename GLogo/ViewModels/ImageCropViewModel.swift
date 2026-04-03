//
//  ImageCropViewModel.swift
//  GLogo
//
//  概要:
//  画像クロップ機能のビューモデルです。
//  画像の表示、クロップ領域の管理を提供します。
//

import Foundation
import UIKit

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
    
    let originalImage: UIImage
    private let completion: (UIImage) -> Void
    private let cropHandleUseCase: CropHandleInteractionUseCase
    private var activeHandle: CropHandleType?
    private var dragStart: CGPoint = .zero
    private var initialRect: CGRect = .zero
    
    // MARK: - イニシャライザ
    
    init(
        image: UIImage,
        completion: @escaping (UIImage) -> Void,
        cropHandleUseCase: CropHandleInteractionUseCase = CropHandleInteractionUseCase()
    ) {
        self.originalImage = image
        self.completion = completion
        self.cropHandleUseCase = cropHandleUseCase
    }
    
    // MARK: - クロップ（UIエントリーポイント）
    //
    // フロー概要:
    //  - ImagePreviewView が updateImageFrame を呼び、初期の cropRect を画像フレームに合わせる。
    //  - CropHandles が start/update/end を呼び、UseCase で矩形更新して cropRect を反映する。
    //  - UIの比率/リセット操作は setCropAspectRatio / resetCropRect を呼ぶ。
    //  - 完了ボタンは onComplete を呼び、クロップ処理して completion に返す。

    func onComplete() {
        if let croppedImage = cropImage(from: originalImage) {
            completion(croppedImage)
        } else {
            // フォールバックとして元画像を返す
            completion(originalImage)
        }
    }
    
    // MARK: - クロップハンドル操作

    func cropHandlePosition(for type: CropHandleType) -> CGPoint {
        cropHandleUseCase.handlePosition(for: type, cropRect: cropRect)
    }

    func startCropHandleDrag(_ type: CropHandleType, at point: CGPoint) {
        activeHandle = type
        dragStart = point
        initialRect = cropRect
    }

    func updateCropHandleDrag(at point: CGPoint) {
        guard let activeHandle = activeHandle else { return }
        cropRect = cropHandleUseCase.updatedCropRect(
            for: activeHandle,
            dragStart: dragStart,
            currentPoint: point,
            initialRect: initialRect,
            imageFrame: imageViewFrame
        )
    }

    func endCropHandleDrag() {
        activeHandle = nil
    }
    
    private func checkHasCropped() {
        let tolerance: CGFloat = 1.0
        let isEqual = abs(cropRect.minX - imageViewFrame.minX) < tolerance &&
        abs(cropRect.minY - imageViewFrame.minY) < tolerance &&
        abs(cropRect.width - imageViewFrame.width) < tolerance &&
        abs(cropRect.height - imageViewFrame.height) < tolerance
        
        hasCropped = !isEqual
    }
    
    func resetCropRect() {
        if imageIsLoaded {
            self.cropRect = imageViewFrame
            self.hasCropped = false
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
        
        self.imageViewFrame = frame
        
        if !imageIsLoaded {
            // 初期クロップ領域を画像フレーム全体に設定
            self.cropRect = frame
            self.imageIsLoaded = true
            self.hasCropped = false
            
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
            return nil
        }

        if !hasCropped {
            return imageToProcess
        }
        
        // クロップ枠を画像フレーム内に制限
        let boundedCropRect = cropRect.intersection(imageViewFrame)
        
        // 正規化座標系への変換
        let normalizedX = (boundedCropRect.minX - imageViewFrame.minX) / imageViewFrame.width
        let normalizedY = (boundedCropRect.minY - imageViewFrame.minY) / imageViewFrame.height
        let normalizedWidth = boundedCropRect.width / imageViewFrame.width
        let normalizedHeight = boundedCropRect.height / imageViewFrame.height
        
        // UIImage.sizeを使用してスケーリング
        let imageSize = imageToProcess.size
        let scaledX = normalizedX * imageSize.width
        let scaledY = normalizedY * imageSize.height
        let scaledWidth = normalizedWidth * imageSize.width
        let scaledHeight = normalizedHeight * imageSize.height
        
        // 画像の向きを考慮してCGImageを取得
        guard let orientedCGImage = createOrientedCGImage(from: imageToProcess) else {
            return nil
        }
        
        // 整数への変換
        let intX = Int(scaledX.rounded(.toNearestOrAwayFromZero))
        let intY = Int(scaledY.rounded(.toNearestOrAwayFromZero))
        let intWidth = Int(scaledWidth.rounded(.toNearestOrAwayFromZero))
        let intHeight = Int(scaledHeight.rounded(.toNearestOrAwayFromZero))
        
        let scaledCropRect = CGRect(
            x: CGFloat(intX),
            y: CGFloat(intY),
            width: CGFloat(intWidth),
            height: CGFloat(intHeight)
        )

        guard let croppedCGImage = orientedCGImage.cropping(to: scaledCropRect) else {
            return nil
        }

        let resultImage = UIImage(cgImage: croppedCGImage)

        return resultImage
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
