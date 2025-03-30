//
//  ImageElement.swift
//  GameLogoMaker
//
//  概要:
//  このファイルは画像要素を表すモデルクラスを定義しています。
//  LogoElementを継承し、画像データの管理と表示に関するプロパティを提供します。
//  フィッティングモード（Fill、Aspect Fit、Aspect Fill、Centerなど）や
//  彩度、明度、コントラスト調整、カラーフィルタ、フレーム表示などの
//  画像処理機能もサポートしています。
//

import Foundation
import UIKit

/// 画像フィッティングモード
enum ImageFitMode: String, Codable {
    case fill       // 画像を引き伸ばして要素全体を埋める
    case aspectFit  // アスペクト比を維持して要素内に収める
    case aspectFill // アスペクト比を維持して要素全体を埋める（はみ出す部分はクリップ）
    case center     // 中央に配置（サイズはそのまま）
    case tile       // タイル状に繰り返し表示
}

/// 画像要素クラス
class ImageElement: LogoElement {
    /// 画像ファイル名
    var imageFileName: String?
    
    /// 画像データ（直接保存する場合）
    var imageData: Data?
    
    /// キャッシュされた画像
    private var cachedImage: UIImage?
    
    /// 画像のフィッティングモード
    var fitMode: ImageFitMode = .aspectFit
    
    /// 色調補正（彩度調整）
    var saturationAdjustment: CGFloat = 1.0
    
    /// 色調補正（明度調整）
    var brightnessAdjustment: CGFloat = 0.0
    
    /// 色調補正（コントラスト調整）
    var contrastAdjustment: CGFloat = 1.0
    
    /// カラーフィルター
    var tintColor: UIColor?
    
    /// カラーフィルターの強度
    var tintIntensity: CGFloat = 0.0
    
    /// 画像フレーム表示
    var showFrame: Bool = false
    
    /// フレームの色
    var frameColor: UIColor = .white
    
    /// フレームの太さ
    var frameWidth: CGFloat = 4.0
    
    /// 画像の境界を丸くするか
    var roundedCorners: Bool = false
    
    /// 角丸の半径
    var cornerRadius: CGFloat = 10.0
    
    /// 要素の種類
    override var type: LogoElementType {
        return .image
    }
    
    /// 画像を取得
    var image: UIImage? {
        if let cachedImage = cachedImage {
            return cachedImage
        }
        
        var loadedImage: UIImage?
        
        if let imageFileName = imageFileName {
            loadedImage = UIImage(named: imageFileName)
        } else if let imageData = imageData {
            loadedImage = UIImage(data: imageData)
        }
        
        // 画像をキャッシュ
        cachedImage = loadedImage
        return loadedImage
    }
    
    /// エンコード用のコーディングキー
    private enum ImageCodingKeys: String, CodingKey {
        case imageFileName, imageData, fitMode
        case saturationAdjustment, brightnessAdjustment, contrastAdjustment
        case tintColorData, tintIntensity
        case showFrame, frameColorData, frameWidth
        case roundedCorners, cornerRadius
    }
    
    /// カスタムエンコーダー
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        
        var container = encoder.container(keyedBy: ImageCodingKeys.self)
        try container.encodeIfPresent(imageFileName, forKey: .imageFileName)
        try container.encodeIfPresent(imageData, forKey: .imageData)
        try container.encode(fitMode, forKey: .fitMode)
        try container.encode(saturationAdjustment, forKey: .saturationAdjustment)
        try container.encode(brightnessAdjustment, forKey: .brightnessAdjustment)
        try container.encode(contrastAdjustment, forKey: .contrastAdjustment)
        try container.encode(tintIntensity, forKey: .tintIntensity)
        try container.encode(showFrame, forKey: .showFrame)
        try container.encode(frameWidth, forKey: .frameWidth)
        try container.encode(roundedCorners, forKey: .roundedCorners)
        try container.encode(cornerRadius, forKey: .cornerRadius)
        
        // UIColorのエンコード
        if let tintColor = tintColor {
            let tintColorData = try NSKeyedArchiver.archivedData(withRootObject: tintColor, requiringSecureCoding: false)
            try container.encode(tintColorData, forKey: .tintColorData)
        }
        
        let frameColorData = try NSKeyedArchiver.archivedData(withRootObject: frameColor, requiringSecureCoding: false)
        try container.encode(frameColorData, forKey: .frameColorData)
    }
    
    /// カスタムデコーダー
    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        
        let container = try decoder.container(keyedBy: ImageCodingKeys.self)
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        fitMode = try container.decode(ImageFitMode.self, forKey: .fitMode)
        saturationAdjustment = try container.decode(CGFloat.self, forKey: .saturationAdjustment)
        brightnessAdjustment = try container.decode(CGFloat.self, forKey: .brightnessAdjustment)
        contrastAdjustment = try container.decode(CGFloat.self, forKey: .contrastAdjustment)
        tintIntensity = try container.decode(CGFloat.self, forKey: .tintIntensity)
        showFrame = try container.decode(Bool.self, forKey: .showFrame)
        frameWidth = try container.decode(CGFloat.self, forKey: .frameWidth)
        roundedCorners = try container.decode(Bool.self, forKey: .roundedCorners)
        cornerRadius = try container.decode(CGFloat.self, forKey: .cornerRadius)
        
        // UIColorのデコード
        if let tintColorData = try? container.decode(Data.self, forKey: .tintColorData),
           let decodedTintColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: tintColorData) {
            tintColor = decodedTintColor
        }
        
        if let frameColorData = try? container.decode(Data.self, forKey: .frameColorData),
           let decodedFrameColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: frameColorData) {
            frameColor = decodedFrameColor
        }
    }
    
    /// ファイル名から画像要素を初期化
    init(fileName: String, fitMode: ImageFitMode = .aspectFit) {
        super.init(name: "Image")
        self.imageFileName = fileName
        self.fitMode = fitMode
        
        // 画像のサイズに合わせて要素のサイズを調整
        if let image = UIImage(named: fileName) {
            updateSizeFromImage(image)
        }
    }
    
    /// データから画像要素を初期化
    init(imageData: Data, fitMode: ImageFitMode = .aspectFit) {
        super.init(name: "Image")
        self.imageData = imageData
        self.fitMode = fitMode
        
        // 画像のサイズに合わせて要素のサイズを調整
        if let image = UIImage(data: imageData) {
            updateSizeFromImage(image)
        }
    }
    
    /// 画像のサイズに基づいて要素のサイズを更新
    private func updateSizeFromImage(_ image: UIImage) {
        // 最大サイズは画面の状況に応じて調整
        let maxSize: CGFloat = 300
        let imageSize = image.size
        
        // 余白を追加するために少し幅を広げる
        let extraWidth: CGFloat = 60
        
        // アスペクト比を保持しながらサイズを設定
        if imageSize.width > imageSize.height {
            let aspectRatio = imageSize.height / imageSize.width
            size = CGSize(width: maxSize, height: maxSize * aspectRatio)
        } else {
            let aspectRatio = imageSize.width / imageSize.height
            size = CGSize(width: maxSize * aspectRatio, height: maxSize)
        }
        
        print("DEBUG: 元画像サイズ: \(imageSize), 設定サイズ: \(size)")
    }

    
    /// 画像にフィルターを適用
    private func applyFilters(to image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage,
              let filter = CIFilter(name: "CIColorControls") else {
            return image
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        
        // 彩度、明度、コントラストの調整
        filter.setValue(saturationAdjustment, forKey: kCIInputSaturationKey)
        filter.setValue(brightnessAdjustment, forKey: kCIInputBrightnessKey)
        filter.setValue(contrastAdjustment, forKey: kCIInputContrastKey)
        
        // フィルター結果の取得
        guard let outputImage = filter.outputImage else {
            return image
        }
        let context = CIContext(options: nil)
        guard let outputCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }
        
        var filteredImage = UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
        
        // ティントカラーの適用（オーバーレイブレンド）
        if let tintColor = tintColor, tintIntensity > 0 {
            UIGraphicsBeginImageContextWithOptions(filteredImage.size, false, filteredImage.scale)
            
            let rect = CGRect(origin: .zero, size: filteredImage.size)
            filteredImage.draw(in: rect)
            
            // ティントカラーを指定された強度で適用
            tintColor.withAlphaComponent(tintIntensity).setFill()
            UIRectFillUsingBlendMode(rect, .overlay)
            
            if let tintedImage = UIGraphicsGetImageFromCurrentImageContext() {
                filteredImage = tintedImage
            }
            
            UIGraphicsEndImageContext()
        }
        
        return filteredImage
    }
    
    /// フィッティングモードに応じた描画矩形を計算
    private func calculateDrawRect(imageSize: CGSize, boundingRect: CGRect) -> CGRect {
        switch fitMode {
        case .fill:
            // 要素全体を埋める
            return boundingRect
            
        case .aspectFit:
            // アスペクト比を維持して要素内に収める
            let widthRatio = boundingRect.width / imageSize.width
            let heightRatio = boundingRect.height / imageSize.height
            let scale = min(widthRatio, heightRatio)
            
            let newWidth = imageSize.width * scale
            let newHeight = imageSize.height * scale
            
            return CGRect(
                x: boundingRect.midX - newWidth / 2,
                y: boundingRect.midY - newHeight / 2,
                width: newWidth,
                height: newHeight
            )
            
        case .aspectFill:
            // アスペクト比を維持して要素全体を埋める
            let widthRatio = boundingRect.width / imageSize.width
            let heightRatio = boundingRect.height / imageSize.height
            let scale = max(widthRatio, heightRatio)
            
            let newWidth = imageSize.width * scale
            let newHeight = imageSize.height * scale
            
            return CGRect(
                x: boundingRect.midX - newWidth / 2,
                y: boundingRect.midY - newHeight / 2,
                width: newWidth,
                height: newHeight
            )
            
        case .center:
            // 中央に配置
            return CGRect(
                x: boundingRect.midX - imageSize.width / 2,
                y: boundingRect.midY - imageSize.height / 2,
                width: imageSize.width,
                height: imageSize.height
            )
            
        case .tile:
            // タイル状に表示（元のサイズ）
            return boundingRect
        }
    }
    
    /// 画像を描画
    override func draw(in context: CGContext) {
        guard isVisible, let image = self.image else { return }
        
        context.saveGState()
        
        // 透明度の設定
        context.setAlpha(opacity)
        
        // 中心点を計算
        let centerX = position.x + size.width / 2
        let centerY = position.y + size.height / 2
        
        // 変換行列を適用（回転と位置）
        context.translateBy(x: centerX, y: centerY)
        context.rotate(by: rotation)
        context.translateBy(x: -size.width / 2, y: -size.height / 2)
        
        // 描画領域
        let rect = CGRect(origin: .zero, size: size)
        
        // 角丸クリッピングパスの設定
        if roundedCorners && cornerRadius > 0 {
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            context.addPath(path.cgPath)
            context.clip()
        }
        
        // フィルターを適用した画像を取得
        let filteredImage = applyFilters(to: image) ?? image
        
        // フィットモードに応じた描画矩形を計算
        let drawRect = calculateDrawRect(imageSize: filteredImage.size, boundingRect: rect)
        
        if fitMode == .tile {
            // タイルパターンで描画
            context.saveGState()
            context.clip(to: rect)
            
            let tileSize = filteredImage.size
            let horizontalTiles = ceil(size.width / tileSize.width)
            let verticalTiles = ceil(size.height / tileSize.height)
            
            for y in 0..<Int(verticalTiles) {
                for x in 0..<Int(horizontalTiles) {
                    let tileRect = CGRect(
                        x: CGFloat(x) * tileSize.width,
                        y: CGFloat(y) * tileSize.height,
                        width: tileSize.width,
                        height: tileSize.height
                    )
                    filteredImage.draw(in: tileRect)
                }
            }
            
            context.restoreGState()
        } else {
            // 通常描画
            filteredImage.draw(in: drawRect)
        }
        
        // フレーム描画
        if showFrame && frameWidth > 0 {
            context.setStrokeColor(frameColor.cgColor)
            context.setLineWidth(frameWidth)
            
            if roundedCorners && cornerRadius > 0 {
                let frameRect = rect.insetBy(dx: frameWidth / 2, dy: frameWidth / 2)
                let path = UIBezierPath(roundedRect: frameRect, cornerRadius: cornerRadius)
                context.addPath(path.cgPath)
            } else {
                context.stroke(rect.insetBy(dx: frameWidth / 2, dy: frameWidth / 2))
            }
        }
        
        context.restoreGState()
    }
    
    /// 要素のコピーを作成
    override func copy() -> LogoElement {
        let copy: ImageElement
        
        if let imageFileName = imageFileName {
            copy = ImageElement(fileName: imageFileName, fitMode: fitMode)
        } else if let imageData = imageData {
            copy = ImageElement(imageData: imageData, fitMode: fitMode)
        } else {
            copy = ImageElement(fileName: "", fitMode: fitMode)
        }
        
        copy.position = position
        copy.size = size
        copy.rotation = rotation
        copy.opacity = opacity
        copy.name = "\(name) Copy"
        copy.isVisible = isVisible
        copy.isLocked = isLocked
        
        copy.saturationAdjustment = saturationAdjustment
        copy.brightnessAdjustment = brightnessAdjustment
        copy.contrastAdjustment = contrastAdjustment
        copy.tintColor = tintColor
        copy.tintIntensity = tintIntensity
        
        copy.showFrame = showFrame
        copy.frameColor = frameColor
        copy.frameWidth = frameWidth
        copy.roundedCorners = roundedCorners
        copy.cornerRadius = cornerRadius
        
        return copy
    }
}
