
//  ImageElement.swift
//  概要:
//  このファイルは画像要素を表すモデルクラスを定義しています。
//  LogoElementを継承し、画像データの管理と表示に関するプロパティを提供します。
//  フィッティングモード（Fill、Aspect Fit、Aspect Fill、Centerなど）や
//  彩度、明度、コントラスト調整、カラーフィルタ、フレーム表示などの
//  画像処理機能もサポートしています。

import Foundation
import UIKit
import CoreImage

/// 画像の役割定義
enum ImageRole: String, Codable, CaseIterable {
    case base = "base"           // ベース画像（保存時の基準画像）
    case overlay = "overlay"     // オーバーレイ画像（ベース画像の上に重ねる画像）
    
    /// 表示用の名称
    var displayName: String {
        switch self {
        case .base:
            return "ベース画像"
        case .overlay:
            return "オーバーレイ画像"
        }
    }
}

/// 画像要素クラス
class ImageElement: LogoElement {
    /// 画像アセット解決リポジトリ（VMから差し替え可能）
    static var assetRepository: ImageAssetRepositoryProtocol = ImageAssetRepository.shared
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

    // MARK: - 画像ソース管理

    /// 画像ソース種別
    private enum ImageSource {
        case data(Data)
        case fileName(String)
        case url(URL)
        case path(String)
    }

    /// 現在の画像ソースを取得
    /// - Parameters: なし
    /// - Returns: 画像ソース
    private var imageSource: ImageSource? {
        if let originalImagePath = originalImagePath {
            return .path(originalImagePath)
        }
        if let originalImageURL = originalImageURL {
            return .url(originalImageURL)
        }
        if let imageFileName = imageFileName {
            return .fileName(imageFileName)
        }
        if let imageData = imageData {
            return .data(imageData)
        }
        return nil
    }

    /// 画像ソースを設定（他のソースはクリア）
    /// - Parameters:
    ///   - source: 設定する画像ソース
    /// - Returns: なし
    private func setImageSource(_ source: ImageSource?) {
        imageData = nil
        imageFileName = nil
        originalImageURL = nil
        originalImagePath = nil

        guard let source else { return }
        switch source {
        case .data(let data):
            imageData = data
        case .fileName(let fileName):
            imageFileName = fileName
        case .url(let url):
            originalImageURL = url
        case .path(let path):
            originalImagePath = path
        }
    }

    /// 優先順位付きで画像ソースを解決
    /// - Parameters:
    ///   - imageData: 画像データ
    ///   - fileName: 画像ファイル名
    ///   - url: 画像URL
    ///   - path: 画像パス
    /// - Returns: 解決した画像ソース
    private func resolveImageSource(
        imageData: Data?,
        fileName: String?,
        url: URL?,
        path: String?
    ) -> ImageSource? {
        if let path = path {
            return .path(path)
        }
        if let url = url {
            return .url(url)
        }
        if let fileName = fileName {
            return .fileName(fileName)
        }
        if let imageData = imageData {
            return .data(imageData)
        }
        return nil
    }
    
    // MARK: - インポート順番管理
    
    /// 元々のインポート順序（変更不可、履歴・デバッグ用）
    var originalImportOrder: Int
    
    /// 画像の役割（ユーザーが変更可能）
    var imageRole: ImageRole = .overlay
    
    /// ベース画像かどうか
    var isBaseImage: Bool {
        return imageRole == .base
    }
    
    /// キャンバスサイズを保持（表示サイズ計算用）
    private var canvasSize: CGSize = CGSize(width: 3840, height: 2160)
    
    /// 編集履歴
    private var editHistory: [ImageEditOperation] = []
    
    /// 画像メタデータ
    var metadata: ImageMetadata?
    
    /// キャッシュされた画像
    var cachedImage: UIImage?

    /// キャッシュされた元画像
    private var cachedOriginalImage: UIImage?

    /// 編集用の低解像度プロキシ画像（高解像度時のみ生成・注入）
    private var proxyImage: UIImage?
    
    /// プロキシ生成時の長辺目安（約2MP相当）
    private let proxyTargetLongSide: CGFloat = 1920
    
    /// 高解像度判定の閾値（MP）
    private let highResThresholdMP: CGFloat = 18.0

    /// プレビュー用低解像度画像キャッシュ
    private var previewImage: UIImage?
    
    /// プレビュー・フィルタサービス（差し替え可能）
    static var previewService: ImagePreviewing = ImagePreviewService()
    
    /// 編集中かどうかのフラグ（プレビュー/高品質の切り替え用）
    private var isCurrentlyEditing: Bool = false
    
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

    /// 色調補正（黒レベル調整）
    var blacksAdjustment: CGFloat = 0.0

    /// 色調補正（白レベル調整）
    var whitesAdjustment: CGFloat = 0.0
    
    /// 色相調整（度数）
    var hueAdjustment: CGFloat = 0.0
    
    /// シャープネス調整
    var sharpnessAdjustment: CGFloat = 0.0
    
    /// ガウシアンブラー半径
    var gaussianBlurRadius: CGFloat = 0.0

    /// 背景ぼかし半径（前景マスク使用時）
    var backgroundBlurRadius: CGFloat = 0.0

    /// 背景ぼかし用マスクデータ（PNG形式）
    var backgroundBlurMaskData: Data?

    /// トーンカーブデータ
    var toneCurveData: ToneCurveData = ToneCurveData()

    /// カラーフィルター
    var tintColor: UIColor?
    
    /// カラーフィルターの強度
    var tintIntensity: CGFloat = 0.0

    /// 適用中のフィルターレシピ（nil = フィルター未適用）
    var appliedFilterRecipe: FilterRecipe?

    /// 適用中のフィルタープリセットID
    var appliedFilterPresetId: String?

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

        let loadedImage: UIImage? = {
            guard let source = imageSource else { return nil }
            switch source {
            case .path(let path):
                return UIImage(contentsOfFile: path)
            case .url(let url):
                if url.isFileURL {
                    return UIImage(contentsOfFile: url.path)
                }
                // 非ファイルURLは対象外（将来の拡張時に検討）
                return nil
            case .fileName(let fileName):
                return UIImage(named: fileName)
            case .data(let data):
                return UIImage(data: data)
            }
        }()

        // 元画像をキャッシュ
        cachedOriginalImage = loadedImage
        return loadedImage
    }

    /// 編集用プロキシ画像（外部リポジトリで生成・解決）
    private var editingImage: UIImage? {
        if let proxy = proxyImage {
            return proxy
        }
        if let resolved = ImageElement.assetRepository.loadEditingImage(
            identifier: originalImageIdentifier,
            fileName: imageFileName,
            originalPath: originalImagePath,
            originalImageProvider: { self.originalImage },
            proxyTargetLongSide: proxyTargetLongSide,
            highResThresholdMP: highResThresholdMP
        ) {
            proxyImage = resolved
            return resolved
        }
        return originalImage
    }
    
    /// 画像を取得
    var image: UIImage? {
        // 編集中はプレビュー品質のみ返してメインスレッド負荷を抑える
        if isCurrentlyEditing {
            return getInstantPreview() ?? editingImage ?? originalImage
        }

        if let cachedImage = cachedImage {
            return cachedImage
        }
        
        guard let originalImage = self.originalImage else {
            return nil
        }
        
        // 編集操作を適用した画像を返す（非編集時はフル品質）
        let source = originalImage
        let processedImage = applyFilters(to: source, quality: .full)
        
        // 編集後の画像をキャッシュ
        cachedImage = processedImage
        return processedImage
    }
    
    /// フィルター適用済み画像を強制的に生成（キャッシュを無視）
    func getFilteredImageForce() -> UIImage? {
        guard let originalImage = self.originalImage else {
            return nil
        }
        
        // キャッシュを無視して常に最新のフィルターを適用
        return applyFilters(to: originalImage)
    }
    
    /// 非同期で画像を取得（彩度調整用）
    @MainActor
    func getImageAsync() async -> UIImage? {
        if let cachedImage = cachedImage {
            return cachedImage
        }
        
        guard let originalImage = self.originalImage else {
            return nil
        }
        
        // 非同期でフィルターをフル品質適用
        let processedImage = await applyFiltersAsync(to: originalImage, quality: .full)
        
        // 編集後の画像をキャッシュ
        cachedImage = processedImage
        return processedImage
    }
    
    /// ローカル保存用Imageのエンコードキー
    /// - Note: 新規キー追加時は旧データとの互換性を確認すること
    private enum ImageCodingKeys: String, CodingKey {
        // 基本情報
        case imageFileName, imageData
        // 元画像参照
        case originalImageURL, originalImagePath, originalImageIdentifier
        // 色・トーン調整
        case saturationAdjustment, brightnessAdjustment, contrastAdjustment
        case highlightsAdjustment, shadowsAdjustment, blacksAdjustment, whitesAdjustment
        case hueAdjustment, sharpnessAdjustment, gaussianBlurRadius
        case toneCurveData
        // 背景ぼかし
        case backgroundBlurRadius, backgroundBlurMaskData
        // 効果・フレーム
        case tintColorData, tintIntensity
        case showFrame, frameColorData, frameWidth
        case roundedCorners, cornerRadius
        // 履歴・メタデータ
        case editHistory, metadata
        // フィルタープリセット
        case appliedFilterRecipe, appliedFilterPresetId
        // インポート順
        case originalImportOrder, imageRole
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
        try container.encode(saturationAdjustment, forKey: .saturationAdjustment)
        try container.encode(brightnessAdjustment, forKey: .brightnessAdjustment)
        try container.encode(contrastAdjustment, forKey: .contrastAdjustment)
        try container.encode(highlightsAdjustment, forKey: .highlightsAdjustment)
        try container.encode(shadowsAdjustment, forKey: .shadowsAdjustment)
        try container.encode(blacksAdjustment, forKey: .blacksAdjustment)
        try container.encode(whitesAdjustment, forKey: .whitesAdjustment)
        try container.encode(hueAdjustment, forKey: .hueAdjustment)
        try container.encode(sharpnessAdjustment, forKey: .sharpnessAdjustment)
        try container.encode(gaussianBlurRadius, forKey: .gaussianBlurRadius)
        try container.encode(toneCurveData, forKey: .toneCurveData)
        try container.encode(backgroundBlurRadius, forKey: .backgroundBlurRadius)
        try container.encodeIfPresent(backgroundBlurMaskData, forKey: .backgroundBlurMaskData)
        try container.encode(tintIntensity, forKey: .tintIntensity)
        try container.encode(showFrame, forKey: .showFrame)
        try container.encode(frameWidth, forKey: .frameWidth)
        try container.encode(roundedCorners, forKey: .roundedCorners)
        try container.encode(cornerRadius, forKey: .cornerRadius)
        try container.encode(editHistory, forKey: .editHistory)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        
        // UIColorのエンコード
        if let tintColor = tintColor {
            let tintColorData = try NSKeyedArchiver.archivedData(withRootObject: tintColor, requiringSecureCoding: false)
            try container.encode(tintColorData, forKey: .tintColorData)
        }
        
        let frameColorData = try NSKeyedArchiver.archivedData(withRootObject: frameColor, requiringSecureCoding: false)
        try container.encode(frameColorData, forKey: .frameColorData)
        
        // フィルタープリセット
        try container.encodeIfPresent(appliedFilterRecipe, forKey: .appliedFilterRecipe)
        try container.encodeIfPresent(appliedFilterPresetId, forKey: .appliedFilterPresetId)

        // インポート順番管理用のプロパティをエンコード
        try container.encode(originalImportOrder, forKey: .originalImportOrder)
        try container.encode(imageRole, forKey: .imageRole)
    }
    
    /// カスタムデコーダー
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: ImageCodingKeys.self)
        
        // インポート順番管理用のプロパティをデコード（後方互換性のためデフォルト値を提供）
        originalImportOrder = try container.decodeIfPresent(Int.self, forKey: .originalImportOrder) ?? 0
        imageRole = try container.decodeIfPresent(ImageRole.self, forKey: .imageRole) ?? .overlay
        
        try super.init(from: decoder)
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        originalImageURL = try container.decodeIfPresent(URL.self, forKey: .originalImageURL)
        originalImagePath = try container.decodeIfPresent(String.self, forKey: .originalImagePath)
        originalImageIdentifier = try container.decodeIfPresent(String.self, forKey: .originalImageIdentifier)
        saturationAdjustment = try container.decode(CGFloat.self, forKey: .saturationAdjustment)
        brightnessAdjustment = try container.decode(CGFloat.self, forKey: .brightnessAdjustment)
        contrastAdjustment = try container.decode(CGFloat.self, forKey: .contrastAdjustment)
        highlightsAdjustment = try container.decode(CGFloat.self, forKey: .highlightsAdjustment)
        shadowsAdjustment = try container.decode(CGFloat.self, forKey: .shadowsAdjustment)
        blacksAdjustment = try container.decodeIfPresent(CGFloat.self, forKey: .blacksAdjustment) ?? 0.0
        whitesAdjustment = try container.decodeIfPresent(CGFloat.self, forKey: .whitesAdjustment) ?? 0.0
        hueAdjustment = try container.decode(CGFloat.self, forKey: .hueAdjustment)
        sharpnessAdjustment = try container.decode(CGFloat.self, forKey: .sharpnessAdjustment)
        gaussianBlurRadius = try container.decode(CGFloat.self, forKey: .gaussianBlurRadius)
        toneCurveData = try container.decodeIfPresent(ToneCurveData.self, forKey: .toneCurveData) ?? ToneCurveData()
        backgroundBlurRadius = try container.decodeIfPresent(CGFloat.self, forKey: .backgroundBlurRadius) ?? 0.0
        backgroundBlurMaskData = try container.decodeIfPresent(Data.self, forKey: .backgroundBlurMaskData)
        tintIntensity = try container.decode(CGFloat.self, forKey: .tintIntensity)
        showFrame = try container.decode(Bool.self, forKey: .showFrame)
        frameWidth = try container.decode(CGFloat.self, forKey: .frameWidth)
        roundedCorners = try container.decode(Bool.self, forKey: .roundedCorners)
        cornerRadius = try container.decode(CGFloat.self, forKey: .cornerRadius)
        editHistory = try container.decodeIfPresent([ImageEditOperation].self, forKey: .editHistory) ?? []
        metadata = try container.decodeIfPresent(ImageMetadata.self, forKey: .metadata)
        
        // UIColorのデコード
        if let tintColorData = try? container.decode(Data.self, forKey: .tintColorData),
           let decodedTintColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: tintColorData) {
            tintColor = decodedTintColor
        }
        
        if let frameColorData = try? container.decode(Data.self, forKey: .frameColorData),
           let decodedFrameColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: frameColorData) {
            frameColor = decodedFrameColor
        }

        // フィルタープリセット（旧データ互換: nil = フィルター未適用）
        appliedFilterRecipe = try container.decodeIfPresent(FilterRecipe.self, forKey: .appliedFilterRecipe)
        appliedFilterPresetId = try container.decodeIfPresent(String.self, forKey: .appliedFilterPresetId)
    }
    
    /// 共通の初期化処理
    /// - Parameters:
    ///   - importOrder: インポート順序（1番目はベース画像として扱う）
    /// - Returns: なし
    private init(importOrder: Int) {
        self.originalImportOrder = importOrder
        
        super.init(name: "Image")
        originalImageIdentifier = UUID().uuidString
        
        // 1番目の画像は自動的にベース画像に設定
        if importOrder == 1 {
            imageRole = .base
        }
        
        // デフォルトzIndexを設定
        zIndex = ElementPriority.image.rawValue
    }
    
    /// 画像とメタデータから初期化
    /// - Parameters:
    ///   - imageData: 画像データ
    ///   - metadata: 画像メタデータ（nilの場合は抽出を試みる）
    ///   - importOrder: インポート順序
    /// - Returns: なし
    convenience init(imageData: Data, metadata: ImageMetadata?, importOrder: Int = 0) {
        self.init(importOrder: importOrder)
        setImageSource(.data(imageData))
        self.metadata = metadata
        
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
    /// - Parameters:
    ///   - fileName: 画像ファイル名
    ///   - importOrder: インポート順序
    /// - Returns: なし
    convenience init(fileName: String, importOrder: Int = 0) {
        self.init(importOrder: importOrder)
        setImageSource(.fileName(fileName))
        
        // 画像のサイズに合わせて要素のサイズを調整（必要なら外部でプロキシ生成）
        if let image = UIImage(named: fileName) {
            updateSizeFromImage(image)
        }
    }
    
    /// URLから初期化（メタデータの抽出を含む）
    /// - Parameters:
    ///   - url: 画像URL
    ///   - importOrder: インポート順序
    /// - Returns: なし
    convenience init(url: URL, importOrder: Int = 0) {
        self.init(importOrder: importOrder)
        setImageSource(.url(url))
        
        do {
            // URLから画像データを読み込む
            let data = try Data(contentsOf: url)
            imageData = data
            
            // 画像サイズを調整（必要なら外部でプロキシ生成）
            if let image = UIImage(data: data) {
                updateSizeFromImage(image)
            }
            
            // メタデータを抽出
            metadata = extractMetadataFromImageData(data)
        } catch {
        }
    }
    
    /// パスから画像要素を初期化
    /// - Parameters:
    ///   - path: 画像パス
    ///   - importOrder: インポート順序
    /// - Returns: なし
    convenience init(path: String, importOrder: Int = 0) {
        self.init(importOrder: importOrder)
        setImageSource(.path(path))
        
        // 画像をロードしてサイズを調整（必要なら外部でプロキシ生成）
        if let image = UIImage(contentsOfFile: path) {
            updateSizeFromImage(image)
        }
    }
    
    /// データから画像要素を初期化（動的サイズ調整フラグ付き）
    /// - Parameters:
    ///   - imageData: 画像データ
    ///   - isDynamicSizing: サイズを画像に合わせて自動調整するかどうか
    ///   - importOrder: インポート順序
    /// - Returns: なし
    convenience init(imageData: Data, isDynamicSizing: Bool = true, importOrder: Int = 0) {
        self.init(importOrder: importOrder)
        setImageSource(.data(imageData))
        
        // isDynamicSizingフラグによってサイズ調整の実行を制御
        if let image = UIImage(data: imageData) {
            
            if isDynamicSizing {
                // 新規画像のインポート時はサイズを調整
                updateSizeFromImage(image)
            } else {
                // クロップ済み画像は元のサイズを維持
                size = image.size
            }
        } else {
        }
    }
    
    /// データから画像要素を初期化（キャンバスサイズ付き）
    /// - Parameters:
    ///   - imageData: 画像データ
    ///   - canvasSize: キャンバスサイズ
    ///   - importOrder: インポート順序
    /// - Returns: なし
    convenience init(imageData: Data, canvasSize: CGSize = CGSize(width: 3840, height: 2160), importOrder: Int = 0) {
        self.init(importOrder: importOrder)
        setImageSource(.data(imageData))
        self.canvasSize = canvasSize
        
        // 画像のサイズに合わせて要素のサイズを調整（必要なら外部でプロキシ生成）
        if let image = UIImage(data: imageData) {
            updateSizeFromImage(image)
        } else {
        }
    }
    
    /// データから画像要素を初期化
    /// - Parameters:
    ///   - imageData: 画像データ
    ///   - importOrder: インポート順序
    /// - Returns: なし
    convenience init(imageData: Data, importOrder: Int = 0) {
        self.init(imageData: imageData, isDynamicSizing: true, importOrder: importOrder)
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
        blacksAdjustment = 0.0
        whitesAdjustment = 0.0
        hueAdjustment = 0.0
        sharpnessAdjustment = 0.0
        gaussianBlurRadius = 0.0
        backgroundBlurRadius = 0.0
        backgroundBlurMaskData = nil
        toneCurveData = ToneCurveData()
        tintColor = nil
        tintIntensity = 0.0
        appliedFilterRecipe = nil
        appliedFilterPresetId = nil
        editHistory.removeAll()

        // キャッシュをクリアして再描画を促す
        cachedImage = nil
        previewImage = nil  // プレビューもリセット
    }

    /// 画像ソースを差し替える
    /// - Parameters:
    ///   - imageData: 差し替える画像データ
    ///   - resetAdjustments: フィルター調整値を初期化するかどうか
    ///   - originalIdentifier: 差し替え後に設定する識別子（nilの場合は新規生成）
    /// - Returns: なし
    func replaceImageSource(with imageData: Data, resetAdjustments: Bool, originalIdentifier: String? = nil) {
        setImageSource(.data(imageData))
        originalImageIdentifier = originalIdentifier ?? UUID().uuidString

        if let image = UIImage(data: imageData) {
            updateSizeFromImage(image)
        }

        if resetAdjustments {
            resetToOriginal()
        }

        clearImageCaches()
    }

    /// 画像ソースを復元する
    /// - Parameters:
    ///   - imageData: 復元する画像データ
    ///   - fileName: 復元する画像ファイル名
    ///   - url: 復元する画像URL
    ///   - path: 復元する画像パス
    ///   - originalIdentifier: 復元する識別子
    /// - Returns: なし
    func restoreImageSource(imageData: Data?,fileName: String?,url: URL?,path: String?,originalIdentifier: String?) {
        let source = resolveImageSource(
            imageData: imageData,
            fileName: fileName,
            url: url,
            path: path
        )
        setImageSource(source)
        originalImageIdentifier = originalIdentifier

        if let source = source {
            switch source {
            case .data(let data):
                if let image = UIImage(data: data) {
                    updateSizeFromImage(image)
                }
            case .fileName(let fileName):
                if let image = UIImage(named: fileName) {
                    updateSizeFromImage(image)
                }
            case .url(let url):
                if url.isFileURL, let image = UIImage(contentsOfFile: url.path) {
                    updateSizeFromImage(image)
                }
            case .path(let path):
                if let image = UIImage(contentsOfFile: path) {
                    updateSizeFromImage(image)
                }
            }
        }

        clearImageCaches()
    }
    
    /// 画像のサイズに基づいて要素のサイズを更新
    private func updateSizeFromImage(_ image: UIImage) {
        // キャンバスの15%程度を最大サイズとして使用
        let maxSize: CGFloat = min(canvasSize.width, canvasSize.height) * 0.15
        
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
        
    }
    
    private func getCanvasSize() -> CGSize {
        // デフォルトは4Kサイズ
        return CGSize(width: 3840, height: 2160)
    }

    /// 画像キャッシュをクリアする
    private func clearImageCaches() {
        cachedImage = nil
        cachedOriginalImage = nil
        previewImage = nil
        proxyImage = nil
        ImageElement.previewService.resetCache()
    }

    /// レンダリング済み画像のキャッシュを無効化
    ///
    /// 画像調整の値だけが更新された場合に、表示の再描画を確実に行うために使用します。
    func invalidateRenderedImageCache() {
        cachedImage = nil
    }

    /// メモリ警告時に画像キャッシュを解放する
    func handleMemoryWarning() {
        cachedImage = nil
        cachedOriginalImage = nil
        previewImage = nil
        proxyImage = nil
    }
    
    /// プレビュー用低解像度画像を生成
    private func generatePreviewImage() -> UIImage? {
        ImageElement.previewService.generatePreviewImage(
            editingImage: editingImage,
            originalImage: originalImage
        )
    }
    
    /// 即座プレビュー用の画像を取得（低解像度、高速処理）
    func getInstantPreview() -> UIImage? {
        if previewImage == nil {
            previewImage = generatePreviewImage()
        }

        guard let preview = previewImage else { return nil }

        let params = currentFilterParams()
        return ImageElement.previewService.instantPreview(
            baseImage: preview,
            params: params,
            quality: .preview
        )
    }

    /// 編集開始をマーク
    func startEditing() {
        isCurrentlyEditing = true
        cachedImage = nil
    }

    /// 編集終了をマーク
    func endEditing() {
        isCurrentlyEditing = false
    }
    
    /// 画像にフィルターを適用
    private func applyFilters(to image: UIImage, quality: ToneCurveFilter.Quality = .full) -> UIImage? {
        ImageElement.previewService.applyFilters(
            to: image,
            params: currentFilterParams(),
            quality: quality
        )
    }
    
    /// 画像にフィルターを非同期で適用（彩度調整特化）
    private func applyFiltersAsync(to image: UIImage, quality: ToneCurveFilter.Quality = .full) async -> UIImage? {
        await ImageElement.previewService.applyFiltersAsync(
            to: image,
            params: currentFilterParams(),
            quality: quality
        )
    }

    /// 現在のフィルタ設定をまとめてサービスに渡す（filter + manual を合成）
    private func currentFilterParams() -> ImageFilterParams {
        let recipe = appliedFilterRecipe

        // 乗算系: filter_val * manual_val（デフォルト1.0同士 = 1.0）
        let effectiveSaturation = (recipe?.saturation ?? 1.0) * saturationAdjustment
        let effectiveContrast = (recipe?.contrast ?? 1.0) * contrastAdjustment

        // 加算系: filter_val + manual_val（デフォルト0.0同士 = 0.0）
        let effectiveBrightness = (recipe?.brightness ?? 0.0) + brightnessAdjustment
        let effectiveHighlights = (recipe?.highlights ?? 0.0) + highlightsAdjustment
        let effectiveShadows = (recipe?.shadows ?? 0.0) + shadowsAdjustment
        let effectiveBlacks = blacksAdjustment
        let effectiveWhites = whitesAdjustment
        let effectiveHue = (recipe?.hue ?? 0.0) + hueAdjustment
        let effectiveSharpness = (recipe?.sharpness ?? 0.0) + sharpnessAdjustment
        let effectiveBlur = (recipe?.gaussianBlur ?? 0.0) + gaussianBlurRadius

        // ティント: filter が設定されていれば filter 側を使用
        let effectiveTintColor: UIColor?
        let effectiveTintIntensity: CGFloat
        if let recipe = recipe, recipe.affectsTint {
            effectiveTintColor = recipe.tintColorHex.flatMap { UIColor(hex: $0) }
            effectiveTintIntensity = recipe.tintIntensity ?? 0.0
        } else {
            effectiveTintColor = tintColor
            effectiveTintIntensity = tintIntensity
        }

        return ImageFilterParams(
            toneCurveData: toneCurveData,
            saturation: effectiveSaturation,
            brightness: effectiveBrightness,
            contrast: effectiveContrast,
            highlights: effectiveHighlights,
            shadows: effectiveShadows,
            blacks: effectiveBlacks,
            whites: effectiveWhites,
            hue: effectiveHue,
            sharpness: effectiveSharpness,
            gaussianBlurRadius: effectiveBlur,
            tintColor: effectiveTintColor,
            tintIntensity: effectiveTintIntensity,
            backgroundBlurRadius: backgroundBlurRadius,
            backgroundBlurMaskData: backgroundBlurMaskData
        )
    }

    /// 画像を描画
    override func draw(in context: CGContext) {
        let filteredImage: UIImage? = {
            guard let image = self.image else { return nil }
            if isCurrentlyEditing {
                return getInstantPreview() ?? applyFilters(to: image, quality: .preview) ?? image
            } else {
                return image
            }
        }()

        ImageElementRenderer.draw(self, in: context, image: filteredImage)
    }
    
    /// 要素のコピーを作成
    override func copy() -> LogoElement {
        let copy: ImageElement

        if let source = imageSource {
            switch source {
            case .data(let data):
                copy = ImageElement(imageData: data)
            case .fileName(let fileName):
                copy = ImageElement(fileName: fileName)
            case .url(let url):
                copy = ImageElement(url: url)
            case .path(let path):
                copy = ImageElement(path: path)
            }
        } else {
            copy = ImageElement(fileName: "")
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
        copy.blacksAdjustment = blacksAdjustment
        copy.whitesAdjustment = whitesAdjustment
        copy.hueAdjustment = hueAdjustment
        copy.sharpnessAdjustment = sharpnessAdjustment
        copy.gaussianBlurRadius = gaussianBlurRadius
        copy.backgroundBlurRadius = backgroundBlurRadius
        copy.backgroundBlurMaskData = backgroundBlurMaskData
        copy.toneCurveData = toneCurveData
        copy.tintColor = tintColor
        copy.tintIntensity = tintIntensity
        copy.appliedFilterRecipe = appliedFilterRecipe
        copy.appliedFilterPresetId = appliedFilterPresetId

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
        }
        
        // 角丸の復元
        if let roundedCornersString = metadata.additionalMetadata["roundedCorners"] {
            self.roundedCorners = roundedCornersString == "true"
        }
        
        // 角丸半径の復元
        if let cornerRadiusString = metadata.additionalMetadata["cornerRadius"],
           let cornerRadiusValue = Double(cornerRadiusString) {
            self.cornerRadius = CGFloat(cornerRadiusValue)
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
