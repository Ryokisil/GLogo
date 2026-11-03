// 画像要素のデータ（画像ソースの参照・編集値・保存形式・複製）を表すモデル。
// 描画・画像取得・キャッシュ保持は段階的に Model 外へ移行中（docs/architecture/Models/ImageElement.md）。

import Foundation
import UIKit
import CoreImage

/// 画像要素クラス
class ImageElement: LogoElement {
    /// 加工の入力・結果に関わる属性の書き込み世代。キャッシュ・選択・配置は含めない。
    /// 同値の再代入も失効境界とし、Data 比較や画像ハッシュ計算を毎回行わない。
    /// 実行時の競合判定用で、Codable・Undo・コピーで以前の番号を復元しない。
    private(set) var editRevision: UInt = 0

    /// RGBA成分を保持する簡易カラー表現
    private struct RGBAColor: Codable, Equatable {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
    }

    /// リバート判定/復元に使用する調整値スナップショット
    private struct RevertAdjustmentSnapshot: Codable, Equatable {
        let saturationAdjustment: CGFloat
        let brightnessAdjustment: CGFloat
        let contrastAdjustment: CGFloat
        let highlightsAdjustment: CGFloat
        let shadowsAdjustment: CGFloat
        let blacksAdjustment: CGFloat
        let whitesAdjustment: CGFloat
        let warmthAdjustment: CGFloat
        let vibranceAdjustment: CGFloat
        let hueAdjustment: CGFloat
        let sharpnessAdjustment: CGFloat
        let gaussianBlurRadius: CGFloat
        let vignetteAdjustment: CGFloat
        let bloomAdjustment: CGFloat
        let grainAdjustment: CGFloat
        let fadeAdjustment: CGFloat
        let chromaticAberrationAdjustment: CGFloat
        let backgroundBlurRadius: CGFloat
        let backgroundBlurMaskData: Data?
        let toneCurveData: ToneCurveData
        let tintColorRGBA: RGBAColor?
        let tintIntensity: CGFloat
        let appliedFilterRecipe: FilterRecipe?
        let appliedFilterPresetId: String?
        let showFrame: Bool
        let frameColorRGBA: RGBAColor
        let frameWidth: CGFloat
        let frameStyle: ImageFrameStyle
        let roundedCorners: Bool
        let cornerRadius: CGFloat

        static let `default` = RevertAdjustmentSnapshot(
            saturationAdjustment: 1.0,
            brightnessAdjustment: 0.0,
            contrastAdjustment: 1.0,
            highlightsAdjustment: 0.0,
            shadowsAdjustment: 0.0,
            blacksAdjustment: 0.0,
            whitesAdjustment: 0.0,
            warmthAdjustment: 0.0,
            vibranceAdjustment: 0.0,
            hueAdjustment: 0.0,
            sharpnessAdjustment: 0.0,
            gaussianBlurRadius: 0.0,
            vignetteAdjustment: 0.0,
            bloomAdjustment: 0.0,
            grainAdjustment: 0.0,
            fadeAdjustment: 0.0,
            chromaticAberrationAdjustment: 0.0,
            backgroundBlurRadius: 0.0,
            backgroundBlurMaskData: nil,
            toneCurveData: ToneCurveData(),
            tintColorRGBA: nil,
            tintIntensity: 0.0,
            appliedFilterRecipe: nil,
            appliedFilterPresetId: nil,
            showFrame: false,
            frameColorRGBA: RGBAColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
            frameWidth: 4.0,
            frameStyle: .simple,
            roundedCorners: false,
            cornerRadius: 10.0
        )
    }

    /// 元画像・プロキシ取得の実行時依存。要素ごとに固定し、永続化しない。
    private let sourceResolver: any ImageSourceResolving

    /// 描画とサムネイルで共有する生成時の依存。保存データには含めない。
    let previewService: any ImagePreviewing

    /// 画像ファイル名
    var imageFileName: String? { didSet { editRevision &+= 1 } }
    
    /// 画像データ（直接保存する場合）
    var imageData: Data? { didSet { editRevision &+= 1 } }
    
    /// 元画像のURL
    var originalImageURL: URL? { didSet { editRevision &+= 1 } }
    
    /// 元画像のパス
    var originalImagePath: String? { didSet { editRevision &+= 1 } }
    
    /// 元画像の識別子（UUIDなど）
    var originalImageIdentifier: String? { didSet { editRevision &+= 1 } }

    /// 高画質化を適用済みかどうか
    var hasAppliedUpscale: Bool = false { didSet { editRevision &+= 1 } }

    // MARK: - 画像ソース管理

    /// 画像ソース種別
    private enum ImageSource {
        case data(Data)
        case fileName(String)
        case url(URL)
        case path(String)
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
    
    /// 画像要素ごとに所有する実行時キャッシュ。Codableやコピーには含めない。
    private var renderCache = ImageRenderCache()

    /// 履歴と描画完了処理から利用する既存の読み書き口。
    var cachedImage: UIImage? {
        get { renderCache.renderedImage }
        set { renderCache.renderedImage = newValue }
    }
    
    /// プロキシ生成時の長辺目安（約2MP相当）
    private let proxyTargetLongSide: CGFloat = 1920
    
    /// 高解像度判定の閾値（MP）
    private let highResThresholdMP: CGFloat = 18.0

    /// 編集中かどうかのフラグ（プレビュー/高品質の切り替え用）
    private var isCurrentlyEditing: Bool = false
    
    /// 色調補正（彩度調整）
    var saturationAdjustment: CGFloat = 1.0 { didSet { editRevision &+= 1 } }
    
    /// 色調補正（明度調整）
    var brightnessAdjustment: CGFloat = 0.0 { didSet { editRevision &+= 1 } }
    
    /// 色調補正（コントラスト調整）
    var contrastAdjustment: CGFloat = 1.0 { didSet { editRevision &+= 1 } }
    
    /// 色調補正（ハイライト調整）
    var highlightsAdjustment: CGFloat = 0.0 { didSet { editRevision &+= 1 } }
    
    /// 色調補正（シャドウ調整）
    var shadowsAdjustment: CGFloat = 0.0 { didSet { editRevision &+= 1 } }

    /// 色調補正（黒レベル調整）
    var blacksAdjustment: CGFloat = 0.0 { didSet { editRevision &+= 1 } }

    /// 色調補正（白レベル調整）
    var whitesAdjustment: CGFloat = 0.0 { didSet { editRevision &+= 1 } }

    /// 色調補正（色温度調整）
    var warmthAdjustment: CGFloat = 0.0 { didSet { editRevision &+= 1 } }

    /// 色調補正（ヴィブランス調整）
    var vibranceAdjustment: CGFloat = 0.0 { didSet { editRevision &+= 1 } }
    
    /// 色相調整（度数）
    var hueAdjustment: CGFloat = 0.0 { didSet { editRevision &+= 1 } }
    
    /// シャープネス調整
    var sharpnessAdjustment: CGFloat = 0.0 { didSet { editRevision &+= 1 } }
    
    /// ガウシアンブラー半径
    var gaussianBlurRadius: CGFloat = 0.0 { didSet { editRevision &+= 1 } }

    /// ビネット強度
    var vignetteAdjustment: CGFloat = 0.0 { didSet { editRevision &+= 1 } }

    /// ブルーム強度
    var bloomAdjustment: CGFloat = 0.0 { didSet { editRevision &+= 1 } }

    /// グレイン強度
    var grainAdjustment: CGFloat = 0.0 { didSet { editRevision &+= 1 } }

    /// フェード強度
    var fadeAdjustment: CGFloat = 0.0 { didSet { editRevision &+= 1 } }

    /// 色収差強度
    var chromaticAberrationAdjustment: CGFloat = 0.0 { didSet { editRevision &+= 1 } }

    /// 背景ぼかし半径（前景マスク使用時）
    var backgroundBlurRadius: CGFloat = 0.0 { didSet { editRevision &+= 1 } }

    /// 背景ぼかし用マスクデータ（PNG形式）
    var backgroundBlurMaskData: Data? { didSet { editRevision &+= 1 } }

    /// トーンカーブデータ
    var toneCurveData: ToneCurveData = ToneCurveData() { didSet { editRevision &+= 1 } }

    /// カラーフィルター
    var tintColor: UIColor? { didSet { editRevision &+= 1 } }
    
    /// カラーフィルターの強度
    var tintIntensity: CGFloat = 0.0 { didSet { editRevision &+= 1 } }

    /// 適用中のフィルターレシピ（nil = フィルター未適用）
    var appliedFilterRecipe: FilterRecipe? { didSet { editRevision &+= 1 } }

    /// 適用中のフィルタープリセットID
    var appliedFilterPresetId: String? { didSet { editRevision &+= 1 } }

    /// 画像フレーム表示
    var showFrame: Bool = false { didSet { editRevision &+= 1 } }
    
    /// フレームの色
    var frameColor: UIColor = .white { didSet { editRevision &+= 1 } }
    
    /// フレームの太さ
    var frameWidth: CGFloat = 4.0 { didSet { editRevision &+= 1 } }

    /// フレームのスタイル
    var frameStyle: ImageFrameStyle = .simple { didSet { editRevision &+= 1 } }
    
    /// 画像の境界を丸くするか
    var roundedCorners: Bool = false { didSet { editRevision &+= 1 } }
    
    /// 角丸の半径
    var cornerRadius: CGFloat = 10.0 { didSet { editRevision &+= 1 } }

    /// リバート基準として扱う初期スナップショット
    private var initialAdjustmentSnapshot: RevertAdjustmentSnapshot = .default
    
    /// 要素の種類
    override var type: LogoElementType {
        return .image
    }
    
    /// 元画像を取得
    var originalImage: UIImage? {
        if let cachedOriginalImage = renderCache.originalImage {
            return cachedOriginalImage
        }

        let loadedImage = sourceResolver.resolveOriginalImage(
            imageData: imageData,
            fileName: imageFileName,
            url: originalImageURL,
            path: originalImagePath
        )

        // 元画像をキャッシュ
        renderCache.originalImage = loadedImage
        return loadedImage
    }

    /// 編集用プロキシ画像（外部リポジトリで生成・解決）
    private var editingImage: UIImage? {
        if let proxy = renderCache.proxyImage {
            return proxy
        }
        if let resolved = sourceResolver.resolveEditingImage(
            identifier: originalImageIdentifier,
            fileName: imageFileName,
            originalPath: originalImagePath,
            originalImageProvider: { self.originalImage },
            proxyTargetLongSide: proxyTargetLongSide,
            highResThresholdMP: highResThresholdMP
        ) {
            renderCache.proxyImage = resolved
            return resolved
        }
        return originalImage
    }
    
    /// 画像を取得
    var image: UIImage? {
        // 編集中はプレビュー品質のみ返してメインスレッド負荷を抑える
        if isCurrentlyEditing {
            let instant = getInstantPreview()
            let fallbackEditing = editingImage
            let fallbackOriginal = originalImage
            let resolved = instant ?? fallbackEditing ?? fallbackOriginal
            return resolved
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
    
    /// フル品質のフィルター適用結果を非同期で生成する
    ///
    /// キャッシュ書き込みを伴わないため、呼び出し側で世代管理後に採用可否を判定できる。
    /// - Parameters: なし
    /// - Returns: フィルター適用済み画像。元画像未解決時は nil
    @MainActor
    func renderFullQualityImageAsync() async -> UIImage? {
        guard let originalImage = self.originalImage else {
            return nil
        }

        return await applyFiltersAsync(to: originalImage, quality: .full)
    }
    
    /// ローカル保存用Imageのエンコードキー
    /// - Note: 新規キー追加時は旧データとの互換性を確認すること
    private enum ImageCodingKeys: String, CodingKey {
        // 基本情報
        case imageFileName, imageData
        // 元画像参照
        case originalImageURL, originalImagePath, originalImageIdentifier
        // AI処理状態
        case hasAppliedUpscale
        // 色・トーン調整
        case saturationAdjustment, brightnessAdjustment, contrastAdjustment
        case highlightsAdjustment, shadowsAdjustment, blacksAdjustment, whitesAdjustment
        case warmthAdjustment, vibranceAdjustment
        case hueAdjustment, sharpnessAdjustment, gaussianBlurRadius
        case vignetteAdjustment, bloomAdjustment, grainAdjustment, fadeAdjustment, chromaticAberrationAdjustment
        case toneCurveData
        // 背景ぼかし
        case backgroundBlurRadius, backgroundBlurMaskData
        // 効果・フレーム
        case tintColorData, tintIntensity
        case showFrame, frameColorData, frameWidth, frameStyle
        case roundedCorners, cornerRadius
        // 履歴・メタデータ
        case editHistory, metadata
        // リバート基準スナップショット
        case initialAdjustmentSnapshot
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
        try container.encode(hasAppliedUpscale, forKey: .hasAppliedUpscale)
        try container.encode(saturationAdjustment, forKey: .saturationAdjustment)
        try container.encode(brightnessAdjustment, forKey: .brightnessAdjustment)
        try container.encode(contrastAdjustment, forKey: .contrastAdjustment)
        try container.encode(highlightsAdjustment, forKey: .highlightsAdjustment)
        try container.encode(shadowsAdjustment, forKey: .shadowsAdjustment)
        try container.encode(blacksAdjustment, forKey: .blacksAdjustment)
        try container.encode(whitesAdjustment, forKey: .whitesAdjustment)
        try container.encode(warmthAdjustment, forKey: .warmthAdjustment)
        try container.encode(vibranceAdjustment, forKey: .vibranceAdjustment)
        try container.encode(hueAdjustment, forKey: .hueAdjustment)
        try container.encode(sharpnessAdjustment, forKey: .sharpnessAdjustment)
        try container.encode(gaussianBlurRadius, forKey: .gaussianBlurRadius)
        try container.encode(vignetteAdjustment, forKey: .vignetteAdjustment)
        try container.encode(bloomAdjustment, forKey: .bloomAdjustment)
        try container.encode(grainAdjustment, forKey: .grainAdjustment)
        try container.encode(fadeAdjustment, forKey: .fadeAdjustment)
        try container.encode(chromaticAberrationAdjustment, forKey: .chromaticAberrationAdjustment)
        try container.encode(toneCurveData, forKey: .toneCurveData)
        try container.encode(backgroundBlurRadius, forKey: .backgroundBlurRadius)
        try container.encodeIfPresent(backgroundBlurMaskData, forKey: .backgroundBlurMaskData)
        try container.encode(tintIntensity, forKey: .tintIntensity)
        try container.encode(showFrame, forKey: .showFrame)
        try container.encode(frameWidth, forKey: .frameWidth)
        try container.encode(frameStyle, forKey: .frameStyle)
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
        try container.encode(initialAdjustmentSnapshot, forKey: .initialAdjustmentSnapshot)

        // インポート順番管理用のプロパティをエンコード
        try container.encode(originalImportOrder, forKey: .originalImportOrder)
        try container.encode(imageRole, forKey: .imageRole)
    }
    
    /// カスタムデコーダー
    required init(from decoder: Decoder) throws {
        sourceResolver = decoder.userInfo[.imageSourceResolver] as? any ImageSourceResolving ?? ImageSourceResolver()
        previewService = decoder.userInfo[.imagePreviewService] as? any ImagePreviewing ?? ImagePreviewService.shared
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
        hasAppliedUpscale = try container.decodeIfPresent(Bool.self, forKey: .hasAppliedUpscale) ?? false
        saturationAdjustment = try container.decode(CGFloat.self, forKey: .saturationAdjustment)
        brightnessAdjustment = try container.decode(CGFloat.self, forKey: .brightnessAdjustment)
        contrastAdjustment = try container.decode(CGFloat.self, forKey: .contrastAdjustment)
        highlightsAdjustment = try container.decode(CGFloat.self, forKey: .highlightsAdjustment)
        shadowsAdjustment = try container.decode(CGFloat.self, forKey: .shadowsAdjustment)
        blacksAdjustment = try container.decodeIfPresent(CGFloat.self, forKey: .blacksAdjustment) ?? 0.0
        whitesAdjustment = try container.decodeIfPresent(CGFloat.self, forKey: .whitesAdjustment) ?? 0.0
        warmthAdjustment = try container.decodeIfPresent(CGFloat.self, forKey: .warmthAdjustment) ?? 0.0
        vibranceAdjustment = try container.decodeIfPresent(CGFloat.self, forKey: .vibranceAdjustment) ?? 0.0
        hueAdjustment = try container.decode(CGFloat.self, forKey: .hueAdjustment)
        sharpnessAdjustment = try container.decode(CGFloat.self, forKey: .sharpnessAdjustment)
        gaussianBlurRadius = try container.decode(CGFloat.self, forKey: .gaussianBlurRadius)
        vignetteAdjustment = try container.decodeIfPresent(CGFloat.self, forKey: .vignetteAdjustment) ?? 0.0
        bloomAdjustment = try container.decodeIfPresent(CGFloat.self, forKey: .bloomAdjustment) ?? 0.0
        grainAdjustment = try container.decodeIfPresent(CGFloat.self, forKey: .grainAdjustment) ?? 0.0
        fadeAdjustment = try container.decodeIfPresent(CGFloat.self, forKey: .fadeAdjustment) ?? 0.0
        chromaticAberrationAdjustment = try container.decodeIfPresent(CGFloat.self, forKey: .chromaticAberrationAdjustment) ?? 0.0
        toneCurveData = try container.decodeIfPresent(ToneCurveData.self, forKey: .toneCurveData) ?? ToneCurveData()
        backgroundBlurRadius = try container.decodeIfPresent(CGFloat.self, forKey: .backgroundBlurRadius) ?? 0.0
        backgroundBlurMaskData = try container.decodeIfPresent(Data.self, forKey: .backgroundBlurMaskData)
        tintIntensity = try container.decode(CGFloat.self, forKey: .tintIntensity)
        showFrame = try container.decode(Bool.self, forKey: .showFrame)
        frameWidth = try container.decode(CGFloat.self, forKey: .frameWidth)
        frameStyle = try container.decodeIfPresent(ImageFrameStyle.self, forKey: .frameStyle) ?? .simple
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

        // 旧データ互換: 未保存の場合は復元後の現在値を初期基準として扱う
        initialAdjustmentSnapshot = try container.decodeIfPresent(RevertAdjustmentSnapshot.self, forKey: .initialAdjustmentSnapshot) ?? makeCurrentAdjustmentSnapshot()
    }
    
    /// 共通の初期化処理
    /// - Parameters:
    ///   - importOrder: インポート順序（1番目はベース画像として扱う）
    /// - Returns: なし
    private init(
        importOrder: Int, sourceResolver: any ImageSourceResolving = ImageSourceResolver(),
        previewService: any ImagePreviewing = ImagePreviewService.shared
    ) {
        self.sourceResolver = sourceResolver
        self.previewService = previewService
        self.originalImportOrder = importOrder
        
        super.init(name: "Image")
        originalImageIdentifier = UUID().uuidString
        
        // 1番目の画像は自動的にベース画像に設定
        if importOrder == 1 {
            imageRole = .base
        }
        
        // デフォルトzIndexを設定
        zIndex = ElementPriority.image.rawValue

        // 生成時点の調整値を初期スナップショットとして確定
        initialAdjustmentSnapshot = makeCurrentAdjustmentSnapshot()
    }
    
    /// 画像とメタデータから初期化
    /// - Parameters:
    ///   - imageData: 画像データ
    ///   - metadata: 画像メタデータ（nilの場合は抽出を試みる）
    ///   - importOrder: インポート順序
    /// - Returns: なし
    convenience init(
        imageData: Data, metadata: ImageMetadata?, importOrder: Int = 0,
        sourceResolver: any ImageSourceResolving = ImageSourceResolver(),
        previewService: any ImagePreviewing = ImagePreviewService.shared
    ) {
        self.init(importOrder: importOrder, sourceResolver: sourceResolver, previewService: previewService)
        setImageSource(.data(imageData))

        let content = ImageInitializationLoader().load(imageData: imageData, metadata: metadata)
        self.metadata = content.metadata
        if let imageSize = content.imageSize {
            updateSize(for: imageSize)
        }
    }
    
    /// ファイル名から画像要素を初期化
    /// - Parameters:
    ///   - fileName: 画像ファイル名
    ///   - importOrder: インポート順序
    /// - Returns: なし
    convenience init(
        fileName: String, importOrder: Int = 0,
        sourceResolver: any ImageSourceResolving = ImageSourceResolver(),
        previewService: any ImagePreviewing = ImagePreviewService.shared
    ) {
        self.init(importOrder: importOrder, sourceResolver: sourceResolver, previewService: previewService)
        setImageSource(.fileName(fileName))
        
        if let imageSize = ImageInitializationLoader().imageSize(fileName: fileName) {
            updateSize(for: imageSize)
        }
    }
    
    /// URLから初期化（メタデータの抽出を含む）
    /// - Parameters:
    ///   - url: 画像URL
    ///   - importOrder: インポート順序
    /// - Returns: なし
    convenience init(
        url: URL, importOrder: Int = 0,
        sourceResolver: any ImageSourceResolving = ImageSourceResolver(),
        previewService: any ImagePreviewing = ImagePreviewService.shared
    ) {
        self.init(importOrder: importOrder, sourceResolver: sourceResolver, previewService: previewService)
        setImageSource(.url(url))
        
        if let content = ImageInitializationLoader().load(url: url) {
            imageData = content.imageData
            if let imageSize = content.imageSize {
                updateSize(for: imageSize)
            }
            metadata = content.metadata
        }
    }
    
    /// パスから画像要素を初期化
    /// - Parameters:
    ///   - path: 画像パス
    ///   - importOrder: インポート順序
    /// - Returns: なし
    convenience init(
        path: String, importOrder: Int = 0,
        sourceResolver: any ImageSourceResolving = ImageSourceResolver(),
        previewService: any ImagePreviewing = ImagePreviewService.shared
    ) {
        self.init(importOrder: importOrder, sourceResolver: sourceResolver, previewService: previewService)
        setImageSource(.path(path))
        
        if let imageSize = ImageInitializationLoader().imageSize(path: path) {
            updateSize(for: imageSize)
        }
    }
    
    /// データから画像要素を初期化（動的サイズ調整フラグ付き）
    /// - Parameters:
    ///   - imageData: 画像データ
    ///   - isDynamicSizing: サイズを画像に合わせて自動調整するかどうか
    ///   - importOrder: インポート順序
    /// - Returns: なし
    convenience init(
        imageData: Data, isDynamicSizing: Bool = true, importOrder: Int = 0,
        sourceResolver: any ImageSourceResolving = ImageSourceResolver(),
        previewService: any ImagePreviewing = ImagePreviewService.shared
    ) {
        self.init(importOrder: importOrder, sourceResolver: sourceResolver, previewService: previewService)
        setImageSource(.data(imageData))
        
        if let imageSize = ImageInitializationLoader().imageSize(imageData: imageData) {
            if isDynamicSizing {
                updateSize(for: imageSize)
            } else {
                // クロップ済み画像は元のサイズを維持
                size = imageSize
            }
        }
    }
    
    /// データから画像要素を初期化（キャンバスサイズ付き）
    /// - Parameters:
    ///   - imageData: 画像データ
    ///   - canvasSize: キャンバスサイズ
    ///   - importOrder: インポート順序
    /// - Returns: なし
    convenience init(
        imageData: Data, canvasSize: CGSize = CGSize(width: 3840, height: 2160), importOrder: Int = 0,
        sourceResolver: any ImageSourceResolving = ImageSourceResolver(),
        previewService: any ImagePreviewing = ImagePreviewService.shared
    ) {
        self.init(importOrder: importOrder, sourceResolver: sourceResolver, previewService: previewService)
        setImageSource(.data(imageData))
        self.canvasSize = canvasSize
        
        if let imageSize = ImageInitializationLoader().imageSize(imageData: imageData) {
            updateSize(for: imageSize)
        }
    }
    
    /// データから画像要素を初期化
    /// - Parameters:
    ///   - imageData: 画像データ
    ///   - importOrder: インポート順序
    /// - Returns: なし
    convenience init(
        imageData: Data, importOrder: Int = 0,
        sourceResolver: any ImageSourceResolving = ImageSourceResolver(),
        previewService: any ImagePreviewing = ImagePreviewService.shared
    ) {
        self.init(imageData: imageData, isDynamicSizing: true, importOrder: importOrder, sourceResolver: sourceResolver, previewService: previewService)
    }
    
    /// 元の画像に戻す
    func resetToOriginal() {
        applyAdjustmentSnapshot(initialAdjustmentSnapshot)
        editHistory.removeAll()

        // キャッシュをクリアして再描画を促す
        renderCache.invalidate(.adjustments)
    }

    /// 画像ソースを差し替える
    /// - Parameters:
    ///   - imageData: 差し替える画像データ
    ///   - resetAdjustments: フィルター調整値を初期化するかどうか
    ///   - originalIdentifier: 差し替え後に設定する識別子（nilの場合は新規生成）
    ///   - hasAppliedUpscale: 差し替え後に高画質化済みとして扱うかどうか
    /// - Returns: なし
    func replaceImageSource(
        with imageData: Data,
        resetAdjustments: Bool,
        originalIdentifier: String? = nil,
        hasAppliedUpscale: Bool = false
    ) {
        setImageSource(.data(imageData))
        originalImageIdentifier = originalIdentifier ?? UUID().uuidString
        self.hasAppliedUpscale = hasAppliedUpscale

        if let imageSize = ImageInitializationLoader().imageSize(imageData: imageData) {
            updateSize(for: imageSize)
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
    ///   - hasAppliedUpscale: 復元後に高画質化済みとして扱うかどうか
    /// - Returns: なし
    func restoreImageSource(
        imageData: Data?,
        fileName: String?,
        url: URL?,
        path: String?,
        originalIdentifier: String?,
        hasAppliedUpscale: Bool
    ) {
        let source = resolveImageSource(
            imageData: imageData,
            fileName: fileName,
            url: url,
            path: path
        )
        setImageSource(source)
        originalImageIdentifier = originalIdentifier
        self.hasAppliedUpscale = hasAppliedUpscale

        if source != nil,
           let image = sourceResolver.resolveOriginalImage(
               imageData: self.imageData,
               fileName: imageFileName,
               url: originalImageURL,
               path: originalImagePath
           ) {
            updateSize(for: image.size)
        }

        clearImageCaches()
    }
    
    /// 画像のサイズに基づいて要素のサイズを更新
    private func updateSize(for imageSize: CGSize) {
        size = ImageSizeCalculator.fittedSize(imageSize: imageSize, canvasSize: canvasSize)
    }
    
    /// 画像キャッシュをクリアする
    private func clearImageCaches() {
        renderCache.invalidate(.all)
        previewService.resetCache()
    }

    /// レンダリング済み画像のキャッシュを無効化
    ///
    /// 画像調整の値だけが更新された場合に、表示の再描画を確実に行うために使用します。
    func invalidateRenderedImageCache() {
        renderCache.invalidate(.rendered)
    }

    /// メモリ警告時に画像キャッシュを解放する
    func handleMemoryWarning() {
        renderCache.invalidate(.all)
    }
    
    /// プレビュー用低解像度画像を生成
    private func generatePreviewImage() -> UIImage? {
        previewService.generatePreviewImage(
            editingImage: editingImage,
            originalImage: originalImage,
            mode: currentRenderMode()
        )
    }

    /// 即座プレビュー用の画像を取得（低解像度、高速処理）
    func getInstantPreview() -> UIImage? {
        if renderCache.previewBaseImage == nil {
            renderCache.previewBaseImage = generatePreviewImage()
        }

        guard let preview = renderCache.previewBaseImage else { return nil }

        let params = currentFilterParams()
        return previewService.instantPreview(
            baseImage: preview,
            params: params,
            quality: .preview,
            mode: currentRenderMode()
        )
    }

    /// 編集開始をマーク
    func startEditing() {
        isCurrentlyEditing = true
        renderCache.invalidate(.rendered)
    }

    /// 編集終了をマーク
    func endEditing() {
        isCurrentlyEditing = false
    }
    
    /// 画像にフィルターを適用
    private func applyFilters(to image: UIImage, quality: RenderQuality = .full) -> UIImage? {
        previewService.applyFilters(
            to: image,
            params: currentFilterParams(),
            quality: quality,
            mode: currentRenderMode()
        )
    }
    
    /// 画像にフィルターを非同期で適用（彩度調整特化）
    @MainActor
    private func applyFiltersAsync(to image: UIImage, quality: RenderQuality = .full) async -> UIImage? {
        await previewService.applyFiltersAsync(
            to: image,
            params: currentFilterParams(),
            quality: quality,
            mode: currentRenderMode()
        )
    }

    /// 適用中プリセットからレンダリング経路を判定
    /// - Parameters: なし
    /// - Returns: レンダリング経路
    private func currentRenderMode() -> ImageRenderMode {
        ImageRenderMode.fromPresetId(appliedFilterPresetId)
    }

    /// プリセット合成前の手動調整値。描画とプリセットのサムネイルが同じ値を受け取る。
    var adjustmentValues: ImageAdjustmentValues {
        ImageAdjustmentValues(
            saturation: saturationAdjustment,
            brightness: brightnessAdjustment,
            contrast: contrastAdjustment,
            highlights: highlightsAdjustment,
            shadows: shadowsAdjustment,
            blacks: blacksAdjustment,
            whites: whitesAdjustment,
            warmth: warmthAdjustment,
            vibrance: vibranceAdjustment,
            hue: hueAdjustment,
            sharpness: sharpnessAdjustment,
            gaussianBlurRadius: gaussianBlurRadius,
            vignette: vignetteAdjustment,
            bloom: bloomAdjustment,
            grain: grainAdjustment,
            fade: fadeAdjustment,
            chromaticAberration: chromaticAberrationAdjustment,
            toneCurveData: toneCurveData,
            tintColor: tintColor,
            tintIntensity: tintIntensity,
            backgroundBlurRadius: backgroundBlurRadius,
            backgroundBlurMaskData: backgroundBlurMaskData
        )
    }

    /// 現在のフィルタ設定をまとめてサービスに渡す（filter + manual を合成）
    private func currentFilterParams() -> ImageFilterParams {
        ImageFilterParamsComposer.compose(adjustmentValues, recipe: appliedFilterRecipe)
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

        if let source = resolveImageSource(
            imageData: imageData,
            fileName: imageFileName,
            url: originalImageURL,
            path: originalImagePath
        ) {
            switch source {
            case .data(let data):
                copy = ImageElement(imageData: data, sourceResolver: sourceResolver, previewService: previewService)
            case .fileName(let fileName):
                copy = ImageElement(fileName: fileName, sourceResolver: sourceResolver, previewService: previewService)
            case .url(let url):
                copy = ImageElement(url: url, sourceResolver: sourceResolver, previewService: previewService)
            case .path(let path):
                copy = ImageElement(path: path, sourceResolver: sourceResolver, previewService: previewService)
            }
        } else {
            copy = ImageElement(fileName: "", sourceResolver: sourceResolver, previewService: previewService)
        }

        copyAppearance(to: copy)
        return copy
    }

    /// 保存専用の独立した描画状態を作る。UI 用複製と異なり元画像をその場で固定する。
    /// UIImage は再圧縮せず共有し、調整値・キャッシュ・編集フラグは共有しない。
    /// 元のファイル参照を持ち越さないため、後続のソース差し替えや削除にも影響されない。
    func renderCopy() -> ImageElement {
        let copy = ImageElement(importOrder: originalImportOrder, sourceResolver: sourceResolver, previewService: previewService)
        copyAppearance(to: copy)
        copy.id = id
        copy.name = name
        copy.zIndex = zIndex
        copy.imageRole = imageRole
        copy.renderCache.originalImage = originalImage
        return copy
    }

    /// UI 用複製と保存用複製で、描画属性のコピー漏れを防ぐ。
    private func copyAppearance(to copy: ImageElement) {
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
        copy.warmthAdjustment = warmthAdjustment
        copy.vibranceAdjustment = vibranceAdjustment
        copy.hueAdjustment = hueAdjustment
        copy.sharpnessAdjustment = sharpnessAdjustment
        copy.gaussianBlurRadius = gaussianBlurRadius
        copy.vignetteAdjustment = vignetteAdjustment
        copy.bloomAdjustment = bloomAdjustment
        copy.grainAdjustment = grainAdjustment
        copy.fadeAdjustment = fadeAdjustment
        copy.chromaticAberrationAdjustment = chromaticAberrationAdjustment
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
        copy.frameStyle = frameStyle
        copy.roundedCorners = roundedCorners
        copy.cornerRadius = cornerRadius
        copy.hasAppliedUpscale = hasAppliedUpscale
        copy.initialAdjustmentSnapshot = initialAdjustmentSnapshot
    }

    // MARK: - Revert Support

    /// 画像要素内で保持する調整値を初期状態に戻す
    /// - Parameters: なし
    /// - Returns: なし
    func resetAdjustmentsToInitialState() {
        // フィルター設定をリセット
        resetToOriginal()

        // キャッシュをクリア
        clearRevertImageCaches()
    }

    /// 既存呼び出し元向けに調整値リセットを維持する互換口
    ///
    /// 新規の初期状態リバート経路では `ImageElementMetadataRevertUseCase` を使用します。
    /// メタデータ永続化履歴の巻き戻しはこのメソッドでは行いません。
    /// - Parameters: なし
    /// - Returns: なし
    func revertToInitialState() {
        resetAdjustmentsToInitialState()
    }

    /// リバート後に再解決すべき画像キャッシュをクリアする
    /// - Parameters: なし
    /// - Returns: なし
    func clearRevertImageCaches() {
        renderCache.invalidate(.revert)
    }
    
    /// 初期状態から外れた調整値変更があるかを確認
    /// - Parameters: なし
    /// - Returns: 現在値が初期スナップショットから外れている場合はtrue、そうでなければfalse
    var hasAdjustmentChangesFromInitialState: Bool {
        makeCurrentAdjustmentSnapshot() != initialAdjustmentSnapshot
    }

    /// 現在の調整値スナップショットを生成
    /// - Parameters: なし
    /// - Returns: 現在状態を表すスナップショット
    private func makeCurrentAdjustmentSnapshot() -> RevertAdjustmentSnapshot {
        RevertAdjustmentSnapshot(
            saturationAdjustment: saturationAdjustment,
            brightnessAdjustment: brightnessAdjustment,
            contrastAdjustment: contrastAdjustment,
            highlightsAdjustment: highlightsAdjustment,
            shadowsAdjustment: shadowsAdjustment,
            blacksAdjustment: blacksAdjustment,
            whitesAdjustment: whitesAdjustment,
            warmthAdjustment: warmthAdjustment,
            vibranceAdjustment: vibranceAdjustment,
            hueAdjustment: hueAdjustment,
            sharpnessAdjustment: sharpnessAdjustment,
            gaussianBlurRadius: gaussianBlurRadius,
            vignetteAdjustment: vignetteAdjustment,
            bloomAdjustment: bloomAdjustment,
            grainAdjustment: grainAdjustment,
            fadeAdjustment: fadeAdjustment,
            chromaticAberrationAdjustment: chromaticAberrationAdjustment,
            backgroundBlurRadius: backgroundBlurRadius,
            backgroundBlurMaskData: backgroundBlurMaskData,
            toneCurveData: toneCurveData,
            tintColorRGBA: makeRGBAColor(from: tintColor),
            tintIntensity: tintIntensity,
            appliedFilterRecipe: appliedFilterRecipe,
            appliedFilterPresetId: appliedFilterPresetId,
            showFrame: showFrame,
            frameColorRGBA: RGBAColor(
                red: frameColor.rgbComponents.red,
                green: frameColor.rgbComponents.green,
                blue: frameColor.rgbComponents.blue,
                alpha: frameColor.rgbComponents.alpha
            ),
            frameWidth: frameWidth,
            frameStyle: frameStyle,
            roundedCorners: roundedCorners,
            cornerRadius: cornerRadius
        )
    }

    /// スナップショットを現在の調整値へ反映
    /// - Parameters:
    ///   - snapshot: 反映する調整値スナップショット
    /// - Returns: なし
    private func applyAdjustmentSnapshot(_ snapshot: RevertAdjustmentSnapshot) {
        saturationAdjustment = snapshot.saturationAdjustment
        brightnessAdjustment = snapshot.brightnessAdjustment
        contrastAdjustment = snapshot.contrastAdjustment
        highlightsAdjustment = snapshot.highlightsAdjustment
        shadowsAdjustment = snapshot.shadowsAdjustment
        blacksAdjustment = snapshot.blacksAdjustment
        whitesAdjustment = snapshot.whitesAdjustment
        warmthAdjustment = snapshot.warmthAdjustment
        vibranceAdjustment = snapshot.vibranceAdjustment
        hueAdjustment = snapshot.hueAdjustment
        sharpnessAdjustment = snapshot.sharpnessAdjustment
        gaussianBlurRadius = snapshot.gaussianBlurRadius
        vignetteAdjustment = snapshot.vignetteAdjustment
        bloomAdjustment = snapshot.bloomAdjustment
        grainAdjustment = snapshot.grainAdjustment
        fadeAdjustment = snapshot.fadeAdjustment
        chromaticAberrationAdjustment = snapshot.chromaticAberrationAdjustment
        backgroundBlurRadius = snapshot.backgroundBlurRadius
        backgroundBlurMaskData = snapshot.backgroundBlurMaskData
        toneCurveData = snapshot.toneCurveData
        tintColor = makeUIColor(from: snapshot.tintColorRGBA)
        tintIntensity = snapshot.tintIntensity
        appliedFilterRecipe = snapshot.appliedFilterRecipe
        appliedFilterPresetId = snapshot.appliedFilterPresetId
        showFrame = snapshot.showFrame
        frameColor = UIColor(
            red: snapshot.frameColorRGBA.red,
            green: snapshot.frameColorRGBA.green,
            blue: snapshot.frameColorRGBA.blue,
            alpha: snapshot.frameColorRGBA.alpha
        )
        frameWidth = snapshot.frameWidth
        frameStyle = snapshot.frameStyle
        roundedCorners = snapshot.roundedCorners
        cornerRadius = snapshot.cornerRadius
    }

    /// 現在値を初期スナップショットとして再定義
    /// - Parameters: なし
    /// - Returns: なし
    func captureCurrentAdjustmentAsInitialSnapshot() {
        initialAdjustmentSnapshot = makeCurrentAdjustmentSnapshot()
    }

    /// UIColorをRGBA成分へ変換
    /// - Parameters:
    ///   - color: 変換対象の色
    /// - Returns: RGBA成分（変換不可時はnil）
    private func makeRGBAColor(from color: UIColor?) -> RGBAColor? {
        guard let color else { return nil }
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return RGBAColor(red: red, green: green, blue: blue, alpha: alpha)
        }

        let ciColor = CIColor(color: color)
        return RGBAColor(red: ciColor.red, green: ciColor.green, blue: ciColor.blue, alpha: ciColor.alpha)
    }

    /// RGBA成分からUIColorを復元
    /// - Parameters:
    ///   - rgba: 復元元RGBA成分
    /// - Returns: 復元後の色（復元失敗時はnil）
    private func makeUIColor(from rgba: RGBAColor?) -> UIColor? {
        guard let rgba else { return nil }
        return UIColor(red: rgba.red, green: rgba.green, blue: rgba.blue, alpha: rgba.alpha)
    }
}
