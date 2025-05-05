//
//  ImageCropViewModel.swift
//  GameLogoMaker
//
//  概要:
//  ImageCropView用のViewModel。クロップロジックとデータ管理を担当します。
//

import SwiftUI
import UIKit

class ImageCropViewModel: ObservableObject {
    // MARK: - プロパティ
    
    @Published var cropRect: CGRect {
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
    
    // MARK: - イニシャライザ
    
    init(image: UIImage, completion: @escaping (UIImage) -> Void) {
        self.originalImage = image
        self.completion = completion
        self.cropRect = CGRect(x: 0, y: 0, width: 100, height: 100)
    }
    
    // MARK: - コマンド
    
    func onComplete() {
        print("===完了時点でのデバッグ情報===")
        print("元画像サイズ: \(originalImage.size)")
        print("表示フレーム: \(imageViewFrame)")
        print("クロップ領域: \(cropRect)")
        print("クロップ実行の有無: \(hasCropped)")
        
        if let croppedImage = cropImage() {
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
            let margin: CGFloat = imageViewFrame.width * 0.1
            self.cropRect = imageViewFrame.insetBy(dx: margin, dy: margin * (imageViewFrame.height / imageViewFrame.width))
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
            // 初期クロップ領域を画像フレームの90%程度に設定
            let margin: CGFloat = frame.width * 0.1 // 10%のマージン
            self.cropRect = frame.insetBy(dx: margin, dy: margin * (frame.height / frame.width))
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
    
    // ImageCropViewModel.swift
    
    private func cropImage() -> UIImage? {
        guard imageViewFrame.width > 0 && imageViewFrame.height > 0 else {
            print("エラー: 画像表示フレームが無効です")
            return nil
        }
        
        print("=== クロップ処理デバッグ ===")
        print("元画像サイズ: \(originalImage.size)")
        print("画像表示サイズ: \(imageViewFrame)")
        print("クロップ領域: \(cropRect)")
        print("クロップ実行済み: \(hasCropped)")
        
        if !hasCropped {
            print("クロップなし: 元画像を返します")
            return originalImage
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
        let imageSize = originalImage.size
        let scaledX = normalizedX * imageSize.width
        let scaledY = normalizedY * imageSize.height
        let scaledWidth = normalizedWidth * imageSize.width
        let scaledHeight = normalizedHeight * imageSize.height
        
        print("スケールされた浮動小数点値: x=\(scaledX), y=\(scaledY), w=\(scaledWidth), h=\(scaledHeight)")
        
        // 画像の向きを考慮してCGImageを取得
        guard let orientedCGImage = createOrientedCGImage(from: originalImage) else {
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
