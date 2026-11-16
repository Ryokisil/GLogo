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

    /// RGBA成分を保持する簡易カラー表現。初期スナップショットに色を保存するときの形式。
    /// 色との変換はファイル末尾の extension に置き、メンバーワイズ初期化を残すため fileprivate にする。
    fileprivate struct RGBAColor: Codable, Equatable {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
    }

    /// リバート判定/復元に使用する調整値スナップショット
    /// 保存データの `initialAdjustmentSnapshot` として書き出す。プロパティ名が保存キーになるため変更しない。
    /// 編集値との変換はファイル末尾の extension に置く（`default` がメンバーワイズ初期化を使うため）。
    fileprivate struct RevertAdjustmentSnapshot: Codable, Equatable {
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

    /// 取得・描画・キャッシュの管理。要素と同じ寿命を持ち、初期化のたびに作る（複製・保存用の複製とは共有しない）。
    /// 処理を移した中間段階で、所有と依存の向きの整理は残る（docs/architecture/Models/ImageElement.md の第16回・第17回）。
    /// エディタの管理役（`ImageRenderSessionStore`）と保存の範囲（`SaveProjectSnapshot`）が読むので internal にしている。
    /// この2つのほかは、ここを直接使わない（所有を移す第21回で、要素から外す）。
    let renderSession: ImageRenderSession

    /// 元画像・プロキシ取得の実行時依存。要素ごとに固定し、永続化しない。
    private var sourceResolver: any ImageSourceResolving { renderSession.sourceResolver }

    /// 描画とサムネイルで共有する生成時の依存。保存データには含めない。
    var previewService: any ImagePreviewing { renderSession.previewService }

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

    /// 画像ソース種別。設定時は他のソース参照をクリアする。
    enum ImageSource {
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
    
    /// キャンバス指定のない生成と、保存データから復元した要素が使うキャンバスサイズ。
    static let defaultCanvasSize = CGSize(width: 3840, height: 2160)

    /// キャンバスサイズを保持（表示サイズ計算用）
    private var canvasSize: CGSize = ImageElement.defaultCanvasSize
    
    /// 編集履歴
    private var editHistory: [ImageEditOperation] = []
    
    /// 画像メタデータ
    var metadata: ImageMetadata?
    
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
    /// 実行時の依存（取得先・描画サービス）は保存データに含めず、`ProjectDecodingDependencies` が userInfo で渡す。
    /// 欠けていれば既定の実装で補わず、依存の設定不足として `MissingDecodingDependencyError` で失敗させる。
    required init(from decoder: Decoder) throws {
        guard let sourceResolver = decoder.userInfo[.imageSourceResolver] as? any ImageSourceResolving else {
            throw MissingDecodingDependencyError(key: .imageSourceResolver)
        }
        guard let previewService = decoder.userInfo[.imagePreviewService] as? any ImagePreviewing else {
            throw MissingDecodingDependencyError(key: .imagePreviewService)
        }
        self.renderSession = ImageRenderSession(sourceResolver: sourceResolver, previewService: previewService)
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
        initialAdjustmentSnapshot = try container.decodeIfPresent(RevertAdjustmentSnapshot.self, forKey: .initialAdjustmentSnapshot) ?? RevertAdjustmentSnapshot(editState)
    }
    
    /// 読み込み済みの値から画像要素を作る。画像の読み込み・デコードは行わない。
    /// 画像データからの生成は `ImageElementFactory` が寸法の読み取りと配置サイズの計算を担当する。
    /// - Parameters:
    ///   - source: 画像ソース。nil の場合はソースを持たない（保存用コピーは元画像を別途固定する）
    ///   - size: 配置サイズ。nil の場合は既定サイズのまま
    ///   - canvasSize: 画像差し替え・履歴復元でサイズを計算するキャンバス。保存しない
    ///   - importOrder: インポート順序（1番目はベース画像として扱う）
    init(
        source: ImageSource?,
        size: CGSize?,
        canvasSize: CGSize = ImageElement.defaultCanvasSize,
        importOrder: Int = 0,
        sourceResolver: any ImageSourceResolving,
        previewService: any ImagePreviewing
    ) {
        self.renderSession = ImageRenderSession(sourceResolver: sourceResolver, previewService: previewService)
        self.originalImportOrder = importOrder
        self.canvasSize = canvasSize

        super.init(name: "Image")
        originalImageIdentifier = UUID().uuidString

        // 1番目の画像は自動的にベース画像に設定
        if importOrder == 1 {
            imageRole = .base
        }

        // デフォルトzIndexを設定
        zIndex = ElementPriority.image.rawValue

        // 生成時点の調整値を初期スナップショットとして確定
        initialAdjustmentSnapshot = RevertAdjustmentSnapshot(editState)

        if let source {
            setImageSource(source)
        }
        if let size {
            self.size = size
        }
    }
    
    /// 元の画像に戻す（編集値だけ。描画キャッシュの失効は、呼び出した履歴イベントの範囲で行う）
    func resetToOriginal() {
        applyEditState(initialAdjustmentSnapshot.editState)
        editHistory.removeAll()
    }

    /// 画像ソースを差し替える（値と配置サイズだけ。描画キャッシュは、差し替えのイベントの範囲で履歴が消す）
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
    }

    /// 画像ソースを復元する（値と配置サイズだけ。描画キャッシュは、差し替えのイベントの巻き戻しの範囲で履歴が消す）
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
    }
    
    /// 画像のサイズに基づいて要素のサイズを更新
    private func updateSize(for imageSize: CGSize) {
        size = ImageSizeCalculator.fittedSize(imageSize: imageSize, canvasSize: canvasSize)
    }
    
    /// 適用中プリセットからレンダリング経路を判定。描画のセッションが、描画の時点で読む
    /// - Parameters: なし
    /// - Returns: レンダリング経路
    func currentRenderMode() -> ImageRenderMode {
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

    /// Revert・画像差し替えの Undo と複製で受け渡す編集値30項目。
    var editState: ImageEditState {
        ImageEditState(
            adjustments: adjustmentValues,
            filterRecipe: appliedFilterRecipe,
            filterPresetId: appliedFilterPresetId,
            frame: ImageFrameSettings(
                isShown: showFrame,
                color: frameColor,
                width: frameWidth,
                style: frameStyle,
                hasRoundedCorners: roundedCorners,
                cornerRadius: cornerRadius
            )
        )
    }

    /// 編集値30項目をまとめて反映する。
    /// 描画キャッシュの扱いは経路ごとに異なるため、無効化は呼び出し側が行う。
    func applyEditState(_ state: ImageEditState) {
        let values = state.adjustments
        saturationAdjustment = values.saturation
        brightnessAdjustment = values.brightness
        contrastAdjustment = values.contrast
        highlightsAdjustment = values.highlights
        shadowsAdjustment = values.shadows
        blacksAdjustment = values.blacks
        whitesAdjustment = values.whites
        warmthAdjustment = values.warmth
        vibranceAdjustment = values.vibrance
        hueAdjustment = values.hue
        sharpnessAdjustment = values.sharpness
        gaussianBlurRadius = values.gaussianBlurRadius
        vignetteAdjustment = values.vignette
        bloomAdjustment = values.bloom
        grainAdjustment = values.grain
        fadeAdjustment = values.fade
        chromaticAberrationAdjustment = values.chromaticAberration
        backgroundBlurRadius = values.backgroundBlurRadius
        backgroundBlurMaskData = values.backgroundBlurMaskData
        toneCurveData = values.toneCurveData
        tintColor = values.tintColor
        tintIntensity = values.tintIntensity
        appliedFilterRecipe = state.filterRecipe
        appliedFilterPresetId = state.filterPresetId
        showFrame = state.frame.isShown
        frameColor = state.frame.color
        frameWidth = state.frame.width
        frameStyle = state.frame.style
        roundedCorners = state.frame.hasRoundedCorners
        cornerRadius = state.frame.cornerRadius
    }

    /// 現在のフィルタ設定をまとめてサービスに渡す（filter + manual を合成）。描画のセッションが、描画の時点で読む
    func currentFilterParams() -> ImageFilterParams {
        ImageFilterParamsComposer.compose(adjustmentValues, recipe: appliedFilterRecipe)
    }

    /// 受け取った画像で描画する。キャンバスと削除エフェクトは、エディタの管理役から受け取った画像を渡す
    /// （保存の合成は、保存の範囲から受け取った画像で `ImageElementRenderer` を直接呼ぶ）。
    /// 画像を受け取らずに描く入口は持たない（`ContextDrawable` を採用しない。第21回で基底の描画の入口を外した）。
    /// - Parameters:
    ///   - context: 描き込み先
    ///   - image: 描く画像。nil のときは何も描かない
    func draw(in context: CGContext, image: UIImage?) {
        ImageElementRenderer.draw(self, in: context, image: image)
    }
    
    /// 要素のコピーを作成
    override func copy() -> LogoElement {
        // ソースのない複製元は、従来どおり空のアセット名を参照として持たせる。
        let source = resolveImageSource(
            imageData: imageData,
            fileName: imageFileName,
            url: originalImageURL,
            path: originalImagePath
        ) ?? .fileName("")
        let copy = ImageElement(source: source, size: nil, sourceResolver: sourceResolver, previewService: previewService)

        // URL ソースは従来どおり複製時にファイルを読み直し、読めた Data と抽出したメタデータを持たせる。
        // 配置サイズは copyAppearance で複製元の値に上書きするため、ここでは計算しない。
        if case .url(let url) = source, let content = ImageInitializationLoader().load(url: url) {
            copy.imageData = content.imageData
            copy.metadata = content.metadata
        }

        copyAppearance(to: copy)
        return copy
    }

    /// 保存専用の複製を作る。描画属性と識別子・順序・役割だけを写し、調整値・キャッシュ・編集フラグは共有しない。
    /// 元のファイル参照を持ち越さないため、後続のソース差し替えや削除にも影響されない。
    /// 元画像は、保存の範囲（`SaveProjectSnapshot`）が受付時にエディタの管理役から受け取って固定する。
    func renderCopy() -> ImageElement {
        let copy = ImageElement(
            source: nil, size: nil, importOrder: originalImportOrder,
            sourceResolver: sourceResolver, previewService: previewService
        )
        copyAppearance(to: copy)
        copy.id = id
        copy.name = name
        copy.zIndex = zIndex
        copy.imageRole = imageRole
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
        copy.applyEditState(editState)
        copy.hasAppliedUpscale = hasAppliedUpscale
        copy.initialAdjustmentSnapshot = initialAdjustmentSnapshot
    }

    // MARK: - Revert Support

    /// 画像要素内で保持する調整値を初期状態に戻す（編集値だけ。描画キャッシュの失効は、Revert のイベントの範囲で行う）
    /// - Parameters: なし
    /// - Returns: なし
    func resetAdjustmentsToInitialState() {
        resetToOriginal()
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

    /// 初期状態から外れた調整値変更があるかを確認
    /// - Parameters: なし
    /// - Returns: 現在値が初期スナップショットから外れている場合はtrue、そうでなければfalse
    var hasAdjustmentChangesFromInitialState: Bool {
        // 保存用の表現（色は RGBA 成分）で比べ、色の表現の違いを変更として扱わない。
        RevertAdjustmentSnapshot(editState) != initialAdjustmentSnapshot
    }

    /// 現在値を初期スナップショットとして再定義
    /// - Parameters: なし
    /// - Returns: なし
    func captureCurrentAdjustmentAsInitialSnapshot() {
        initialAdjustmentSnapshot = RevertAdjustmentSnapshot(editState)
    }
}

// MARK: - 初期スナップショットと編集値の変換

private extension ImageElement.RevertAdjustmentSnapshot {
    /// 編集値を保存用の表現へ変換する。色は RGBA 成分で持つ。
    init(_ state: ImageEditState) {
        let values = state.adjustments
        self.init(
            saturationAdjustment: values.saturation,
            brightnessAdjustment: values.brightness,
            contrastAdjustment: values.contrast,
            highlightsAdjustment: values.highlights,
            shadowsAdjustment: values.shadows,
            blacksAdjustment: values.blacks,
            whitesAdjustment: values.whites,
            warmthAdjustment: values.warmth,
            vibranceAdjustment: values.vibrance,
            hueAdjustment: values.hue,
            sharpnessAdjustment: values.sharpness,
            gaussianBlurRadius: values.gaussianBlurRadius,
            vignetteAdjustment: values.vignette,
            bloomAdjustment: values.bloom,
            grainAdjustment: values.grain,
            fadeAdjustment: values.fade,
            chromaticAberrationAdjustment: values.chromaticAberration,
            backgroundBlurRadius: values.backgroundBlurRadius,
            backgroundBlurMaskData: values.backgroundBlurMaskData,
            toneCurveData: values.toneCurveData,
            tintColorRGBA: values.tintColor.map(ImageElement.RGBAColor.init(tintColor:)),
            tintIntensity: values.tintIntensity,
            appliedFilterRecipe: state.filterRecipe,
            appliedFilterPresetId: state.filterPresetId,
            showFrame: state.frame.isShown,
            frameColorRGBA: ImageElement.RGBAColor(frameColor: state.frame.color),
            frameWidth: state.frame.width,
            frameStyle: state.frame.style,
            roundedCorners: state.frame.hasRoundedCorners,
            cornerRadius: state.frame.cornerRadius
        )
    }

    /// 保存用の表現を編集値へ戻す。
    var editState: ImageEditState {
        ImageEditState(
            adjustments: ImageAdjustmentValues(
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
                tintColor: tintColorRGBA?.uiColor,
                tintIntensity: tintIntensity,
                backgroundBlurRadius: backgroundBlurRadius,
                backgroundBlurMaskData: backgroundBlurMaskData
            ),
            filterRecipe: appliedFilterRecipe,
            filterPresetId: appliedFilterPresetId,
            frame: ImageFrameSettings(
                isShown: showFrame,
                color: frameColorRGBA.uiColor,
                width: frameWidth,
                style: frameStyle,
                hasRoundedCorners: roundedCorners,
                cornerRadius: cornerRadius
            )
        )
    }
}

private extension ImageElement.RGBAColor {
    // ティントとフレームで既存データの変換方法が異なるため、保存値を変えないようそれぞれを残す。

    /// ティント色を RGBA 成分へ変換する。成分を直接取り出せない色は CIColor 経由で得る。
    init(tintColor color: UIColor) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            self.init(red: red, green: green, blue: blue, alpha: alpha)
            return
        }

        let ciColor = CIColor(color: color)
        self.init(red: ciColor.red, green: ciColor.green, blue: ciColor.blue, alpha: ciColor.alpha)
    }

    /// フレーム色を RGBA 成分へ変換する。成分を直接取り出せない色は sRGB へ変換して得る。
    init(frameColor color: UIColor) {
        let components = color.rgbComponents
        self.init(red: components.red, green: components.green, blue: components.blue, alpha: components.alpha)
    }

    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
