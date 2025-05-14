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
    
    /// 元画像のURL
    var originalImageURL: URL?
    
    /// 元画像のパス
    var originalImagePath: String?
    
    /// 元画像の識別子（UUIDなど）
    var originalImageIdentifier: String?
    
    /// キャンバスサイズを保持（表示サイズ計算用）
    private var canvasSize: CGSize = CGSize(width: 3840, height: 2160)
    
    /// 編集履歴
    private var editHistory: [ImageEditOperation] = []
    
    /// 画像メタデータ
    var metadata: ImageMetadata?
    
    /// メタデータの編集履歴
    private var metadataEditHistory: [String: Any] = [:]
    
    /// キャッシュされた画像
    var cachedImage: UIImage?
    
    /// キャッシュされた元画像
    private var cachedOriginalImage: UIImage?
    
    /// 画像のフィッティングモード
    var fitMode: ImageFitMode = .aspectFit
    
    /// 色調補正（彩度調整）
    var saturationAdjustment: CGFloat = 1.0
    
    /// 色調補正（明度調整）
    var brightnessAdjustment: CGFloat = 0.0
    
    /// 色調補正（コントラスト調整）
    var contrastAdjustment: CGFloat = 1.0
    
    /// 色調補正（ハイライト調整）
    var highlightsAdjustment: CGFloat = 0.0
    
    /// 色調補正（シャドウ調整）
    var shadowsAdjustment: CGFloat = 0.0
    
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
    
    /// 元画像を取得
    var originalImage: UIImage? {
        if let cachedOriginalImage = cachedOriginalImage {
            return cachedOriginalImage
        }
        
        var loadedImage: UIImage?
        
        if let originalImagePath = originalImagePath {
            loadedImage = UIImage(contentsOfFile: originalImagePath)
        } else if let originalImageURL = originalImageURL {
            if originalImageURL.isFileURL {
                loadedImage = UIImage(contentsOfFile: originalImageURL.path)
            } else {
                // URLからの画像ロードは非同期で行うべきですが、
                // 簡略化のため同期処理としています
                if let data = try? Data(contentsOf: originalImageURL) {
                    loadedImage = UIImage(data: data)
                }
            }
        } else if let imageFileName = imageFileName {
            loadedImage = UIImage(named: imageFileName)
        } else if let imageData = imageData {
            loadedImage = UIImage(data: imageData)
        }
        
        // 元画像をキャッシュ
        cachedOriginalImage = loadedImage
        return loadedImage
    }
    
    /// 画像を取得
    var image: UIImage? {
        if let cachedImage = cachedImage {
            return cachedImage
        }
        
        guard let originalImage = self.originalImage else {
            return nil
        }
        
        // 編集操作を適用した画像を返す
        let processedImage = applyFilters(to: originalImage)
        
        // 編集後の画像をキャッシュ
        cachedImage = processedImage
        return processedImage
    }
    
    /// エンコード用のコーディングキー
    private enum ImageCodingKeys: String, CodingKey {
        case imageFileName, imageData, fitMode
        case originalImageURL, originalImagePath, originalImageIdentifier
        case saturationAdjustment, brightnessAdjustment, contrastAdjustment
        case highlightsAdjustment, shadowsAdjustment
        case tintColorData, tintIntensity
        case showFrame, frameColorData, frameWidth
        case roundedCorners, cornerRadius
        case editHistory
        case metadata
        case metadataEditHistory
    }
    
    /// カスタムエンコーダー
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        
        var container = encoder.container(keyedBy: ImageCodingKeys.self)
        try container.encodeIfPresent(imageFileName, forKey: .imageFileName)
        try container.encodeIfPresent(imageData, forKey: .imageData)
        try container.encodeIfPresent(originalImageURL, forKey: .originalImageURL)
        try container.encodeIfPresent(originalImagePath, forKey: .originalImagePath)
        try container.encodeIfPresent(originalImageIdentifier, forKey: .originalImageIdentifier)
        try container.encode(fitMode, forKey: .fitMode)
        try container.encode(saturationAdjustment, forKey: .saturationAdjustment)
        try container.encode(brightnessAdjustment, forKey: .brightnessAdjustment)
        try container.encode(contrastAdjustment, forKey: .contrastAdjustment)
        try container.encode(highlightsAdjustment, forKey: .highlightsAdjustment)
        try container.encode(shadowsAdjustment, forKey: .shadowsAdjustment)
        try container.encode(tintIntensity, forKey: .tintIntensity)
        try container.encode(showFrame, forKey: .showFrame)
        try container.encode(frameWidth, forKey: .frameWidth)
        try container.encode(roundedCorners, forKey: .roundedCorners)
        try container.encode(cornerRadius, forKey: .cornerRadius)
        try container.encode(editHistory, forKey: .editHistory)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        
        // メタデータ編集履歴をエンコード（Dictionary型は直接Codableに準拠していないため変換が必要）
        if !metadataEditHistory.isEmpty {
            let encodableHistory = metadataEditHistory.compactMapValues { value in
                return (value as? String) ?? String(describing: value)
            }
            try container.encode(encodableHistory, forKey: .metadataEditHistory)
        }
        
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
        originalImageURL = try container.decodeIfPresent(URL.self, forKey: .originalImageURL)
        originalImagePath = try container.decodeIfPresent(String.self, forKey: .originalImagePath)
        originalImageIdentifier = try container.decodeIfPresent(String.self, forKey: .originalImageIdentifier)
        fitMode = try container.decode(ImageFitMode.self, forKey: .fitMode)
        saturationAdjustment = try container.decode(CGFloat.self, forKey: .saturationAdjustment)
        brightnessAdjustment = try container.decode(CGFloat.self, forKey: .brightnessAdjustment)
        contrastAdjustment = try container.decode(CGFloat.self, forKey: .contrastAdjustment)
        highlightsAdjustment = try container.decode(CGFloat.self, forKey: .highlightsAdjustment)
        shadowsAdjustment = try container.decode(CGFloat.self, forKey: .shadowsAdjustment)
        tintIntensity = try container.decode(CGFloat.self, forKey: .tintIntensity)
        showFrame = try container.decode(Bool.self, forKey: .showFrame)
        frameWidth = try container.decode(CGFloat.self, forKey: .frameWidth)
        roundedCorners = try container.decode(Bool.self, forKey: .roundedCorners)
        cornerRadius = try container.decode(CGFloat.self, forKey: .cornerRadius)
        editHistory = try container.decodeIfPresent([ImageEditOperation].self, forKey: .editHistory) ?? []
        metadata = try container.decodeIfPresent(ImageMetadata.self, forKey: .metadata)
        
        // メタデータ編集履歴をデコード
        if let history = try container.decodeIfPresent([String: String].self, forKey: .metadataEditHistory) {
            metadataEditHistory = history
        }
        
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
    
    /// 画像とメタデータから初期化
    init(imageData: Data, metadata: ImageMetadata?, fitMode: ImageFitMode = .aspectFit) {
        super.init(name: "Image")
        self.imageData = imageData
        self.metadata = metadata
        self.originalImageIdentifier = UUID().uuidString
        self.fitMode = fitMode
        
        // 画像のサイズに合わせて要素のサイズを調整
        if let image = UIImage(data: imageData) {
            updateSizeFromImage(image)
            
            // メタデータがない場合は画像から抽出を試みる
            if metadata == nil {
                self.metadata = extractMetadataFromImageData(imageData)
            }
        }
    }
    
    /// ファイル名から画像要素を初期化
    init(fileName: String, fitMode: ImageFitMode = .aspectFit) {
        super.init(name: "Image")
        self.imageFileName = fileName
        self.originalImageIdentifier = UUID().uuidString
        self.fitMode = fitMode
        
        // 画像のサイズに合わせて要素のサイズを調整
        if let image = UIImage(named: fileName) {
            updateSizeFromImage(image)
        }
    }
    
    /// URLから初期化（メタデータの抽出を含む）
    init(url: URL, fitMode: ImageFitMode = .aspectFit) {
        super.init(name: "Image")
        self.originalImageURL = url
        self.originalImageIdentifier = UUID().uuidString
        self.fitMode = fitMode
        
        do {
            // URLから画像データを読み込む
            let data = try Data(contentsOf: url)
            self.imageData = data
            
            // 画像サイズを調整
            if let image = UIImage(data: data) {
                updateSizeFromImage(image)
            }
            
            // メタデータを抽出
            self.metadata = extractMetadataFromImageData(data)
        } catch {
            print("DEBUG: URLからの画像読み込みに失敗: \(error.localizedDescription)")
        }
    }
    
    /// パスから画像要素を初期化
    init(path: String, fitMode: ImageFitMode = .aspectFit) {
        super.init(name: "Image")
        self.originalImagePath = path
        self.originalImageIdentifier = UUID().uuidString
        self.fitMode = fitMode
        
        // 画像をロードしてサイズを調整
        if let image = UIImage(contentsOfFile: path) {
            updateSizeFromImage(image)
        }
    }
    
    /// データから画像要素を初期化（動的サイズ調整フラグ付き）
    init(imageData: Data, fitMode: ImageFitMode = .aspectFit, isDynamicSizing: Bool = true) {
        super.init(name: "Image")
        self.imageData = imageData
        self.originalImageIdentifier = UUID().uuidString
        self.fitMode = fitMode
        
        // isDynamicSizingフラグによってサイズ調整の実行を制御
        if let image = UIImage(data: imageData) {
            print("DEBUG: 初期化時の画像サイズ: \(image.size)")
            
            if isDynamicSizing {
                // 新規画像のインポート時はサイズを調整
                updateSizeFromImage(image)
            } else {
                // クロップ済み画像は元のサイズを維持
                size = image.size
                print("DEBUG: クロップ済み画像のサイズを維持: \(size)")
            }
        } else {
            print("DEBUG: エラー: UIImageの作成に失敗しました")
        }
    }
    
    /// データから画像要素を初期化（キャンバスサイズ付き）
    init(imageData: Data, fitMode: ImageFitMode = .aspectFit, canvasSize: CGSize = CGSize(width: 3840, height: 2160)) {
        super.init(name: "Image")
        self.imageData = imageData
        self.originalImageIdentifier = UUID().uuidString
        self.fitMode = fitMode
        self.canvasSize = canvasSize
        
        // 画像のサイズに合わせて要素のサイズを調整
        if let image = UIImage(data: imageData) {
            print("DEBUG: 初期化時の画像サイズ: \(image.size)")
            updateSizeFromImage(image)
        } else {
            print("DEBUG: エラー: UIImageの作成に失敗しました")
        }
    }
    
    /// データから画像要素を初期化
    init(imageData: Data, fitMode: ImageFitMode = .aspectFit) {
        super.init(name: "Image")
        self.imageData = imageData
        self.originalImageIdentifier = UUID().uuidString
        self.fitMode = fitMode
        
        // 画像のサイズに合わせて要素のサイズを調整
        if let image = UIImage(data: imageData) {
            print("DEBUG: 初期化時の画像サイズ: \(image.size)")
            updateSizeFromImage(image)
        } else {
            print("DEBUG: エラー: UIImageの作成に失敗しました")
        }
    }
    
    /// 編集操作を記録
    func recordEdit(operation: ImageEditOperation) {
        editHistory.append(operation)
        // キャッシュをクリアして再描画を促す
        cachedImage = nil
    }
    
    /// 元の画像に戻す
    func resetToOriginal() {
        saturationAdjustment = 1.0
        brightnessAdjustment = 0.0
        contrastAdjustment = 1.0
        highlightsAdjustment = 0.0
        shadowsAdjustment = 0.0
        tintColor = nil
        tintIntensity = 0.0
        editHistory.removeAll()
        
        // キャッシュをクリアして再描画を促す
        cachedImage = nil
    }
    
    /// 画像のサイズに基づいて要素のサイズを更新
    private func updateSizeFromImage(_ image: UIImage) {
        // キャンバスの15%程度を最大サイズとして使用
        let maxSize: CGFloat = min(canvasSize.width, canvasSize.height) * 0.15
        
        print("DEBUG: キャンバスサイズ: \(canvasSize)")
        print("DEBUG: 計算された最大サイズ: \(maxSize)")
        
        let imageSize = image.size
        
        // アスペクト比を保持しながらサイズを設定
        var newSize: CGSize
        
        if imageSize.width > imageSize.height {
            let aspectRatio = imageSize.height / imageSize.width
            newSize = CGSize(width: maxSize, height: maxSize * aspectRatio)
        } else {
            let aspectRatio = imageSize.width / imageSize.height
            newSize = CGSize(width: maxSize * aspectRatio, height: maxSize)
        }
        
        size = CGSize(
            width: max(1, newSize.width),
            height: max(1, newSize.height)
        )
        
        print("DEBUG: updateSizeFromImage - 元画像サイズ: \(imageSize), 設定サイズ: \(size)")
    }
    
    private func getCanvasSize() -> CGSize {
        // デフォルトは4Kサイズ
        return CGSize(width: 3840, height: 2160)
    }

    
    /// 画像にフィルターを適用
    private func applyFilters(to image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return image }
        
        // 元のCIImageを作成
        var ciImage = CIImage(cgImage: cgImage)
        
        // 基本的な色調整を適用
        if let adjusted = ImageFilterUtility.applyBasicColorAdjustment(
            to: ciImage,
            saturation: saturationAdjustment,
            brightness: brightnessAdjustment,
            contrast: contrastAdjustment
        ) {
            ciImage = adjusted
        }
        
        // ハイライトの調整を適用（値が0でない場合のみ）
        if highlightsAdjustment != 0,
           let adjusted = ImageFilterUtility.applyHighlightAdjustment(
            to: ciImage,
            amount: highlightsAdjustment
           ) {
            ciImage = adjusted
        }
        
        // シャドウの調整を適用（値が0でない場合のみ）
        if shadowsAdjustment != 0,
           let adjusted = ImageFilterUtility.applyShadowAdjustment(
            to: ciImage,
            amount: shadowsAdjustment
           ) {
            ciImage = adjusted
        }
        
        // CIImageをUIImageに変換
        var filteredImage = ImageFilterUtility.convertToUIImage(
            ciImage,
            scale: image.scale,
            orientation: image.imageOrientation
        ) ?? image
        
        // ティントカラーを適用
        if let tintColor = tintColor, tintIntensity > 0,
           let tinted = ImageFilterUtility.applyTintOverlay(
            to: filteredImage,
            color: tintColor,
            intensity: tintIntensity
           ) {
            filteredImage = tinted
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
        copy.highlightsAdjustment = highlightsAdjustment
        copy.shadowsAdjustment = shadowsAdjustment
        copy.tintColor = tintColor
        copy.tintIntensity = tintIntensity
        
        copy.showFrame = showFrame
        copy.frameColor = frameColor
        copy.frameWidth = frameWidth
        copy.roundedCorners = roundedCorners
        copy.cornerRadius = cornerRadius
        
        return copy
    }
    
    /// 画像とメタデータを初期状態に戻す
    func revertToInitialState() {
        // フィルター設定をリセット
        resetToOriginal()
        
        // メタデータをリバート
        if let identifier = originalImageIdentifier {
            let result = ImageMetadataManager.shared.revertMetadata(for: identifier)
            if case .success = result {
                // リバート後のメタデータを取得して設定
                if let metadata = ImageMetadataManager.shared.getMetadata(for: identifier) {
                    self.metadata = metadata
                    
                    // メタデータから画像プロパティを復元
                    applyMetadataToImageProperties(metadata)
                }
            }
        }
        
        // キャッシュをクリア
        cachedImage = nil
        cachedOriginalImage = nil
    }
    
    /// メタデータから画像プロパティを復元する
    private func applyMetadataToImageProperties(_ metadata: ImageMetadata) {
        // フレーム太さの復元
        if let frameWidthString = metadata.additionalMetadata["frameWidth"],
           let frameWidthValue = Double(frameWidthString) {
            self.frameWidth = CGFloat(frameWidthValue)
            print("DEBUG: フレーム太さを復元: \(frameWidthValue)")
        }
        
        // 角丸の復元
        if let roundedCornersString = metadata.additionalMetadata["roundedCorners"] {
            self.roundedCorners = roundedCornersString == "true"
            print("DEBUG: 角丸設定を復元: \(roundedCorners)")
        }
        
        // 角丸半径の復元
        if let cornerRadiusString = metadata.additionalMetadata["cornerRadius"],
           let cornerRadiusValue = Double(cornerRadiusString) {
            self.cornerRadius = CGFloat(cornerRadiusValue)
            print("DEBUG: 角丸半径を復元: \(cornerRadiusValue)")
        }
        
        // フレーム表示の復元
        if let showFrameString = metadata.additionalMetadata["showFrame"] {
            self.showFrame = showFrameString == "true"
        }
        
        // フレーム色の復元
        if let frameColorString = metadata.additionalMetadata["frameColor"],
           let frameColorData = frameColorString.data(using: .utf8),
           let frameColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: frameColorData) {
            self.frameColor = frameColor
        }
    }
    
    /// この画像が過去に編集されたことがあるかを確認
    var hasEditHistory: Bool {
        guard let identifier = originalImageIdentifier else { return false }
        
        // 編集履歴の確認
        let history = ImageMetadataManager.shared.getEditHistory(for: identifier)
        return !history.isEmpty
    }
}

extension ImageElement {
    func resizeToFit(maxSize: CGFloat) {
        guard let image = self.image else { return }
        
        let imageSize = image.size
        if imageSize.width > imageSize.height {
            let aspectRatio = imageSize.height / imageSize.width
            size = CGSize(width: maxSize, height: maxSize * aspectRatio)
        } else {
            let aspectRatio = imageSize.width / imageSize.height
            size = CGSize(width: maxSize * aspectRatio, height: maxSize)
        }
    }
}

/// 画像編集操作を表す構造体
struct ImageEditOperation: Codable {
    enum OperationType: String, Codable {
        case adjustSaturation
        case adjustBrightness
        case adjustContrast
        case adjustHighlights
        case adjustShadows
        case applyTint
        case changeFrame
        case changeCornerRadius
    }
    
    let type: OperationType
    let timestamp: Date
    let parameters: [String: Double]
    
    init(type: OperationType, parameters: [String: Double] = [:]) {
        self.type = type
        self.timestamp = Date()
        self.parameters = parameters
    }
}
// MARK: - メタデータ関連の実装
/// 画像メタデータを表す構造体
struct ImageMetadata: Codable {
    // 基本メタデータ
    var creationDate: Date?
    var modificationDate: Date?
    var author: String?
    var description: String?
    var copyright: String?
    var keywords: [String]
    var title: String?
    
    // EXIF情報
    var cameraMake: String?
    var cameraModel: String?
    var focalLength: Double?
    var aperture: Double?
    var shutterSpeed: Double?
    var iso: Int?
    var flash: Bool?
    var longitude: Double?
    var latitude: Double?
    var altitude: Double?
    
    // その他のメタデータ（汎用的なDictionary形式で保存）
    var additionalMetadata: [String: String]
    
    init(
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        author: String? = nil,
        description: String? = nil,
        copyright: String? = nil,
        keywords: [String] = [],
        title: String? = nil,
        cameraMake: String? = nil,
        cameraModel: String? = nil,
        focalLength: Double? = nil,
        aperture: Double? = nil,
        shutterSpeed: Double? = nil,
        iso: Int? = nil,
        flash: Bool? = nil,
        longitude: Double? = nil,
        latitude: Double? = nil,
        altitude: Double? = nil,
        additionalMetadata: [String: String] = [:]
    ) {
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.author = author
        self.description = description
        self.copyright = copyright
        self.keywords = keywords
        self.title = title
        self.cameraMake = cameraMake
        self.cameraModel = cameraModel
        self.focalLength = focalLength
        self.aperture = aperture
        self.shutterSpeed = shutterSpeed
        self.iso = iso
        self.flash = flash
        self.longitude = longitude
        self.latitude = latitude
        self.altitude = altitude
        self.additionalMetadata = additionalMetadata
    }
}
