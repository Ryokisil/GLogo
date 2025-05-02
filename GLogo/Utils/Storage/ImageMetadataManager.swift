
//  概要:
//  このファイルは画像メタデータの管理と操作を担当するマネージャークラスです。
//  メタデータの読み取り、保存、編集履歴の管理、およびリバート機能を提供します。

import Foundation
import UIKit
import Photos
import CoreLocation
import ImageIO

/// メタデータ編集操作の種類
enum MetadataEditOperationType: String, Codable {
    case edit           // 通常の編集
    case update         // 更新
    case delete         // 削除
    case restore        // 復元
    case batchEdit      // 一括編集
}

/// メタデータ編集操作を表す構造体
struct MetadataEditOperation: Codable, Identifiable {
    let id: UUID
    let type: MetadataEditOperationType
    let timestamp: Date
    let fieldKey: String
    let oldValue: String?
    let newValue: String?
    let metadata: [String: String]?  // 一括編集用
    
    init(type: MetadataEditOperationType, fieldKey: String, oldValue: String? = nil, newValue: String? = nil, metadata: [String: String]? = nil) {
        self.id = UUID()
        self.type = type
        self.timestamp = Date()
        self.fieldKey = fieldKey
        self.oldValue = oldValue
        self.newValue = newValue
        self.metadata = metadata
    }
}

/// メタデータ操作の結果
enum MetadataOperationResult {
    case success
    case failure(Error)
    case notFound
    case noChanges
}

/// メタデータ操作エラー
enum MetadataError: Error {
    case invalidData
    case extractionFailed
    case saveFailed
    case operationNotFound
    case historyCorrupted
    case unsupportedField
}

/// メタデータフィールドのタイプ
enum MetadataFieldType {
    case text
    case date
    case number
    case boolean
    case location
    case array
}

/// メタデータマネージャークラス
class ImageMetadataManager {
    // シングルトンインスタンス
    static let shared = ImageMetadataManager()
    
    // 編集履歴キャッシュ - 画像IDをキーとしたディクショナリ
    private var editHistoryCache: [String: [MetadataEditOperation]] = [:]
    
    // メタデータキャッシュ - 画像IDをキーとしたディクショナリ
    private var metadataCache: [String: ImageMetadata] = [:]
    
    // 変更通知
    var onMetadataChanged: ((String, ImageMetadata) -> Void)?
    
    // プライベートイニシャライザ（シングルトンパターン）
    private init() {}
    
    // MARK: - 公開メソッド
    
    /// 画像データからメタデータを抽出
    /// - Parameter imageData: 画像データ
    /// - Returns: 抽出されたメタデータ（失敗した場合はnil）
    func extractMetadata(from imageData: Data) -> ImageMetadata? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return nil
        }
        
        return extractMetadataFromImageSource(source)
    }
    
    /// 画像URLからメタデータを抽出
    /// - Parameter url: 画像ファイルのURL
    /// - Returns: 抽出されたメタデータ（失敗した場合はnil）
    func extractMetadata(from url: URL) -> ImageMetadata? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        
        return extractMetadataFromImageSource(source)
    }
    
    /// PHAssetからメタデータを抽出
    /// - Parameter asset: PHAsset
    /// - Returns: 抽出されたメタデータ（失敗した場合はnil）
    func extractMetadata(from asset: PHAsset) -> ImageMetadata? {
        var metadata = ImageMetadata()
        
        // 基本情報
        metadata.creationDate = asset.creationDate
        metadata.modificationDate = asset.modificationDate
        
        // 位置情報
        if let location = asset.location {
            metadata.latitude = location.coordinate.latitude
            metadata.longitude = location.coordinate.longitude
            metadata.altitude = location.altitude
        }
        
        // カメラ情報の取得を試行
        let resources = PHAssetResource.assetResources(for: asset)
        if let resource = resources.first {
            // ファイル名
            metadata.additionalMetadata["originalFilename"] = resource.originalFilename
            
            // ファイルサイズ
            if let fileSizeBytes = resource.value(forKey: "fileSize") as? Int64 {
                metadata.additionalMetadata["fileSize"] = String(fileSizeBytes)
            }
        }
        
        // PHAssetの追加情報を取得
        let options = PHContentEditingInputRequestOptions()
        options.canHandleAdjustmentData = { _ in true }
        
        // 非同期取得をシンクロナスに変換するためのセマフォ
        let semaphore = DispatchSemaphore(value: 0)
        
        asset.requestContentEditingInput(with: options) { contentEditingInput, info in
            defer { semaphore.signal() }
            
            guard let contentEditingInput = contentEditingInput,
                  let url = contentEditingInput.fullSizeImageURL else {
                return
            }
            
            // URLから詳細なメタデータを取得して既存のメタデータを補完
            if let additionalMetadata = self.extractMetadata(from: url) {
                // カメラ情報を更新
                metadata.cameraMake = additionalMetadata.cameraMake
                metadata.cameraModel = additionalMetadata.cameraModel
                metadata.focalLength = additionalMetadata.focalLength
                metadata.aperture = additionalMetadata.aperture
                metadata.shutterSpeed = additionalMetadata.shutterSpeed
                metadata.iso = additionalMetadata.iso
                metadata.flash = additionalMetadata.flash
                
                // 位置情報が未設定の場合のみ更新
                if metadata.latitude == nil {
                    metadata.latitude = additionalMetadata.latitude
                    metadata.longitude = additionalMetadata.longitude
                    metadata.altitude = additionalMetadata.altitude
                }
                
                // 追加メタデータをマージ
                for (key, value) in additionalMetadata.additionalMetadata {
                    metadata.additionalMetadata[key] = value
                }
            }
        }
        
        // 最大5秒待機（タイムアウト対策）
        _ = semaphore.wait(timeout: .now() + 5.0)
        
        return metadata
    }
    
    /// メタデータの特定フィールドを更新
    /// - Parameters:
    ///   - identifier: 画像識別子
    ///   - fieldKey: 更新するフィールドのキー
    ///   - value: 新しい値
    /// - Returns: 操作結果
    func updateMetadataField(for identifier: String, fieldKey: String, value: Any) -> MetadataOperationResult {
        // キャッシュまたはストレージからメタデータを取得
        guard var metadata = getMetadata(for: identifier) else {
            return .notFound
        }
        
        // 現在の値を取得
        let oldValue = getFieldValue(from: metadata, for: fieldKey)
        
        // フィールドを更新
        let updateResult = updateField(in: &metadata, fieldKey: fieldKey, value: value)
        guard case .success = updateResult else {
            return updateResult
        }
        
        // 新しい値を文字列に変換
        let newValue = getFieldValue(from: metadata, for: fieldKey)
        
        // 値に変更がなければ何もしない
        if oldValue == newValue {
            return .noChanges
        }
        
        // 編集操作を記録
        let operation = MetadataEditOperation(
            type: .edit,
            fieldKey: fieldKey,
            oldValue: oldValue,
            newValue: newValue
        )
        
        // 編集履歴に追加
        addToEditHistory(identifier: identifier, operation: operation)
        
        // メタデータをキャッシュに保存
        metadataCache[identifier] = metadata
        
        // 変更通知
        onMetadataChanged?(identifier, metadata)
        
        return .success
    }
    
    /// メタデータを一括更新
    /// - Parameters:
    ///   - identifier: 画像識別子
    ///   - updates: キーと値のペアによる更新内容
    /// - Returns: 操作結果
    func updateMetadataFields(for identifier: String, updates: [String: Any]) -> MetadataOperationResult {
        // キャッシュまたはストレージからメタデータを取得
        guard var metadata = getMetadata(for: identifier) else {
            return .notFound
        }
        
        // 更新前の値を保存
        var oldValues: [String: String] = [:]
        var newValues: [String: String] = [:]
        var hasChanges = false
        
        // 各フィールドを更新
        for (fieldKey, value) in updates {
            // 更新前の値を取得
            oldValues[fieldKey] = getFieldValue(from: metadata, for: fieldKey)
            
            // フィールドを更新
            let updateResult = updateField(in: &metadata, fieldKey: fieldKey, value: value)
            guard case .success = updateResult else {
                continue
            }
            
            // 更新後の値を取得
            newValues[fieldKey] = getFieldValue(from: metadata, for: fieldKey)
            
            // 値に変更があるか確認
            if oldValues[fieldKey] != newValues[fieldKey] {
                hasChanges = true
            }
        }
        
        // 変更がなければ何もしない
        if !hasChanges {
            return .noChanges
        }
        
        // 編集操作を記録（一括編集）
        let operation = MetadataEditOperation(
            type: .batchEdit,
            fieldKey: "multiple",
            metadata: oldValues
        )
        
        // 編集履歴に追加
        addToEditHistory(identifier: identifier, operation: operation)
        
        // メタデータをキャッシュに保存
        metadataCache[identifier] = metadata
        
        // 変更通知
        onMetadataChanged?(identifier, metadata)
        
        return .success
    }
    
    /// 指定した画像のメタデータを取得
    /// - Parameter identifier: 画像識別子
    /// - Returns: メタデータ（存在しない場合はnil）
    func getMetadata(for identifier: String) -> ImageMetadata? {
        // キャッシュから取得を試行
        if let cachedMetadata = metadataCache[identifier] {
            return cachedMetadata
        }
        
        // ストレージから読み込み
        if let metadata = loadMetadataFromStorage(for: identifier) {
            // キャッシュに保存
            metadataCache[identifier] = metadata
            return metadata
        }
        
        return nil
    }
    
    /// メタデータを保存
    /// - Parameters:
    ///   - metadata: 保存するメタデータ
    ///   - identifier: 画像識別子
    /// - Returns: 保存が成功したかどうか
    func saveMetadata(_ metadata: ImageMetadata, for identifier: String) -> Bool {
        // キャッシュに保存
        metadataCache[identifier] = metadata
        
        // ストレージに保存
        return saveMetadataToStorage(metadata, for: identifier)
    }
    
    /// 編集履歴を取得
    /// - Parameter identifier: 画像識別子
    /// - Returns: 編集操作の配列
    func getEditHistory(for identifier: String) -> [MetadataEditOperation] {
        // キャッシュから取得を試行
        if let cachedHistory = editHistoryCache[identifier] {
            return cachedHistory
        }
        
        // ストレージから読み込み
        if let history = loadEditHistoryFromStorage(for: identifier) {
            // キャッシュに保存
            editHistoryCache[identifier] = history
            return history
        }
        
        return []
    }
    
    /// 指定した画像の編集履歴があるかを確認
    func hasEditHistory(for identifier: String) -> Bool {
        let history = getEditHistory(for: identifier)
        return !history.isEmpty
    }
    
    /// 指定した画像を完全に初期状態に戻す
    func revertToInitialState(for identifier: String) -> MetadataOperationResult {
        // 履歴の最初の状態（初期状態）に戻す
        return revertMetadata(for: identifier)
    }
    
    /// 特定のポイントまでメタデータをリバート
    /// - Parameters:
    ///   - identifier: 画像識別子
    ///   - operationId: リバート先の操作ID（nilの場合は最初の状態に戻す）
    /// - Returns: 操作結果
    func revertMetadata(for identifier: String, to operationId: UUID? = nil) -> MetadataOperationResult {
        // 編集履歴を取得
        let history = getEditHistory(for: identifier)
        guard !history.isEmpty else {
            return .noChanges
        }
        
        // メタデータを取得
        guard var metadata = getMetadata(for: identifier) else {
            return .notFound
        }
        
        // リバート対象のインデックスを特定
        var targetIndex: Int
        
        if let operationId = operationId {
            // 特定の操作までリバート
            guard let index = history.firstIndex(where: { $0.id == operationId }) else {
                return .failure(MetadataError.operationNotFound)
            }
            targetIndex = index
        } else {
            // 最初の状態にリバート
            targetIndex = 0
        }
        
        // 履歴を逆順に処理し、操作を取り消す
        for i in stride(from: history.count - 1, to: targetIndex - 1, by: -1) {
            let operation = history[i]
            
            switch operation.type {
            case .edit:
                // 単一フィールドの編集を元に戻す
                if let oldValue = operation.oldValue {
                    _ = updateField(in: &metadata, fieldKey: operation.fieldKey, valueString: oldValue)
                }
                
            case .batchEdit:
                // 一括編集を元に戻す
                if let oldValues = operation.metadata {
                    for (key, value) in oldValues {
                        _ = updateField(in: &metadata, fieldKey: key, valueString: value)
                    }
                }
                
            case .delete:
                // 削除を元に戻す（復元）
                if let oldValue = operation.oldValue {
                    _ = updateField(in: &metadata, fieldKey: operation.fieldKey, valueString: oldValue)
                }
                
            case .restore:
                // 復元を元に戻す（削除）
                _ = updateField(in: &metadata, fieldKey: operation.fieldKey, value: nil)
                
            case .update:
                // 更新を元に戻す
                if let oldValue = operation.oldValue {
                    _ = updateField(in: &metadata, fieldKey: operation.fieldKey, valueString: oldValue)
                }
            }
        }
        
        // メタデータを保存
        metadataCache[identifier] = metadata
        
        // 編集履歴を更新（リバートポイント以降を削除）
        let updatedHistory = Array(history.prefix(targetIndex))
        editHistoryCache[identifier] = updatedHistory
        
        // 変更通知
        onMetadataChanged?(identifier, metadata)
        
        return .success
    }
    
    /// メタデータキャッシュをクリア
    func clearCache() {
        metadataCache.removeAll()
        editHistoryCache.removeAll()
    }
    
    // MARK: - プライベートメソッド
    
    /// 画像ソースからメタデータを抽出
    private func extractMetadataFromImageSource(_ source: CGImageSource) -> ImageMetadata {
        var metadata = ImageMetadata()
        
        // メタデータ辞書を取得
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return metadata
        }
        
        // 主要なメタデータ辞書を取得
        let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let tiffDict = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        let gpsDict = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any]
        let iptcDict = properties[kCGImagePropertyIPTCDictionary as String] as? [String: Any]
        
        // EXIF情報を抽出
        extractExifMetadata(from: exifDict, into: &metadata)
        
        // TIFF情報を抽出
        extractTiffMetadata(from: tiffDict, into: &metadata)
        
        // GPS情報を抽出
        extractGpsMetadata(from: gpsDict, into: &metadata)
        
        // IPTC情報を抽出
        extractIptcMetadata(from: iptcDict, into: &metadata)
        
        // その他の一般情報を抽出
        extractGeneralMetadata(from: properties, into: &metadata)
        
        return metadata
    }
    
    /// EXIF情報を抽出
    private func extractExifMetadata(from exifDict: [String: Any]?, into metadata: inout ImageMetadata) {
        guard let exifDict = exifDict else { return }
        
        // 撮影日時
        if let dateTimeOriginal = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            metadata.creationDate = dateFormatter.date(from: dateTimeOriginal)
        }
        
        // 露出設定
        metadata.focalLength = exifDict[kCGImagePropertyExifFocalLength as String] as? Double
        metadata.aperture = exifDict[kCGImagePropertyExifFNumber as String] as? Double
        metadata.shutterSpeed = exifDict[kCGImagePropertyExifExposureTime as String] as? Double
        
        // ISO感度
        if let isoValue = exifDict[kCGImagePropertyExifISOSpeedRatings as String] as? [Int],
           let iso = isoValue.first {
            metadata.iso = iso
        } else if let iso = exifDict[kCGImagePropertyExifISOSpeedRatings as String] as? Int {
            metadata.iso = iso
        }
        
        // フラッシュ
        if let flashValue = exifDict[kCGImagePropertyExifFlash as String] as? Int {
            metadata.flash = flashValue > 0
        }
        
        // その他のEXIF情報を追加メタデータに保存
        for (key, value) in exifDict {
            if let stringValue = String(describing: value).convertToReadableString() {
                metadata.additionalMetadata["exif_\(key)"] = stringValue
            }
        }
    }
    
    /// TIFF情報を抽出
    private func extractTiffMetadata(from tiffDict: [String: Any]?, into metadata: inout ImageMetadata) {
        guard let tiffDict = tiffDict else { return }
        
        // カメラ情報
        metadata.cameraMake = tiffDict[kCGImagePropertyTIFFMake as String] as? String
        metadata.cameraModel = tiffDict[kCGImagePropertyTIFFModel as String] as? String
        
        // 著作権情報
        metadata.copyright = tiffDict[kCGImagePropertyTIFFCopyright as String] as? String
        metadata.author = tiffDict[kCGImagePropertyTIFFArtist as String] as? String
        
        // 撮影日時（EXIF情報がない場合のフォールバック）
        if metadata.creationDate == nil, let dateTime = tiffDict[kCGImagePropertyTIFFDateTime as String] as? String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            metadata.creationDate = dateFormatter.date(from: dateTime)
        }
        
        // その他のTIFF情報を追加メタデータに保存
        for (key, value) in tiffDict {
            if let stringValue = String(describing: value).convertToReadableString() {
                metadata.additionalMetadata["tiff_\(key)"] = stringValue
            }
        }
    }
    
    /// GPS情報を抽出
    private func extractGpsMetadata(from gpsDict: [String: Any]?, into metadata: inout ImageMetadata) {
        guard let gpsDict = gpsDict else { return }
        
        // 緯度
        if let latitude = gpsDict[kCGImagePropertyGPSLatitude as String] as? Double {
            metadata.latitude = latitude
            
            // 南緯の場合は符号を反転
            if let latitudeRef = gpsDict[kCGImagePropertyGPSLatitudeRef as String] as? String,
               latitudeRef == "S" {
                metadata.latitude = -metadata.latitude!
            }
        }
        
        // 経度
        if let longitude = gpsDict[kCGImagePropertyGPSLongitude as String] as? Double {
            metadata.longitude = longitude
            
            // 西経の場合は符号を反転
            if let longitudeRef = gpsDict[kCGImagePropertyGPSLongitudeRef as String] as? String,
               longitudeRef == "W" {
                metadata.longitude = -metadata.longitude!
            }
        }
        
        // 高度
        if let altitude = gpsDict[kCGImagePropertyGPSAltitude as String] as? Double {
            metadata.altitude = altitude
            
            // 高度基準が海面下の場合は符号を反転
            if let altitudeRef = gpsDict[kCGImagePropertyGPSAltitudeRef as String] as? Int,
               altitudeRef == 1 {
                metadata.altitude = -metadata.altitude!
            }
        }
        
        // その他のGPS情報を追加メタデータに保存
        for (key, value) in gpsDict {
            if let stringValue = String(describing: value).convertToReadableString() {
                metadata.additionalMetadata["gps_\(key)"] = stringValue
            }
        }
    }
    
    /// IPTC情報を抽出
    private func extractIptcMetadata(from iptcDict: [String: Any]?, into metadata: inout ImageMetadata) {
        guard let iptcDict = iptcDict else { return }
        
        // タイトル
        metadata.title = iptcDict[kCGImagePropertyIPTCObjectName as String] as? String
        
        // 説明文
        if metadata.description == nil {
            metadata.description = iptcDict[kCGImagePropertyIPTCCaptionAbstract as String] as? String
        }
        
        // キーワード
        if let keywords = iptcDict[kCGImagePropertyIPTCKeywords as String] as? [String] {
            metadata.keywords = keywords
        }
        
        // 著作者情報（TIFF情報がない場合のフォールバック）
        if metadata.author == nil {
            metadata.author = iptcDict[kCGImagePropertyIPTCByline as String] as? String
        }
        
        // 著作権情報（TIFF情報がない場合のフォールバック）
        if metadata.copyright == nil {
            metadata.copyright = iptcDict[kCGImagePropertyIPTCCopyrightNotice as String] as? String
        }
        
        // その他のIPTC情報を追加メタデータに保存
        for (key, value) in iptcDict {
            if let stringValue = String(describing: value).convertToReadableString() {
                metadata.additionalMetadata["iptc_\(key)"] = stringValue
            }
        }
    }
    
    /// 一般的なメタデータを抽出
    private func extractGeneralMetadata(from properties: [String: Any], into metadata: inout ImageMetadata) {
        // 画像サイズ
        if let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
           let height = properties[kCGImagePropertyPixelHeight as String] as? Int {
            metadata.additionalMetadata["pixelWidth"] = "\(width)"
            metadata.additionalMetadata["pixelHeight"] = "\(height)"
        }
        
        // カラープロファイル
        if let colorModel = properties[kCGImagePropertyColorModel as String] as? String {
            metadata.additionalMetadata["colorModel"] = colorModel
        }
        
        // DPI情報
        if let dpiWidth = properties[kCGImagePropertyDPIWidth as String] as? Double,
           let dpiHeight = properties[kCGImagePropertyDPIHeight as String] as? Double {
            metadata.additionalMetadata["dpiWidth"] = "\(dpiWidth)"
            metadata.additionalMetadata["dpiHeight"] = "\(dpiHeight)"
        }
        
        // ファイル形式
        if let fileType = properties[kCGImagePropertyFileContentsDictionary as String] as? [String: Any] {
            // UTTypeIdentifierを取得
            if let typeIdentifier = fileType["UTTypeIdentifier" as String] as? String {
                metadata.additionalMetadata["fileType"] = typeIdentifier
            }
        }
        
        // パスからファイル名を取得（可能な場合）
        if let path = properties["path"] as? String {
            let url = URL(fileURLWithPath: path)
            metadata.additionalMetadata["filename"] = url.lastPathComponent
        }
        
        // 修正日（作成日がない場合のフォールバック）
        if metadata.modificationDate == nil && metadata.creationDate != nil {
            metadata.modificationDate = metadata.creationDate
        }
    }
    
    /// メタデータからフィールドの値を取得（文字列形式）
    private func getFieldValue(from metadata: ImageMetadata, for fieldKey: String) -> String? {
        switch fieldKey {
        case "title":
            return metadata.title
        case "description":
            return metadata.description
        case "author":
            return metadata.author
        case "copyright":
            return metadata.copyright
        case "cameraMake":
            return metadata.cameraMake
        case "cameraModel":
            return metadata.cameraModel
        case "creationDate":
            return metadata.creationDate?.description
        case "modificationDate":
            return metadata.modificationDate?.description
        case "latitude":
            return metadata.latitude?.description
        case "longitude":
            return metadata.longitude?.description
        case "altitude":
            return metadata.altitude?.description
        case "focalLength":
            return metadata.focalLength?.description
        case "aperture":
            return metadata.aperture?.description
        case "shutterSpeed":
            return metadata.shutterSpeed?.description
        case "iso":
            return metadata.iso?.description
        case "flash":
            return metadata.flash?.description
        case "keywords":
            return metadata.keywords.joined(separator: ", ")
        default:
            // 追加メタデータから検索
            return metadata.additionalMetadata[fieldKey]
        }
    }
    
    /// メタデータフィールドを更新
    private func updateField(in metadata: inout ImageMetadata, fieldKey: String, value: Any?) -> MetadataOperationResult {
        // 値がnilの場合は削除操作とみなす
        if value == nil {
            return deleteField(in: &metadata, fieldKey: fieldKey)
        }
        
        // valueが文字列の場合、型変換を行う
        if let stringValue = value as? String {
            return updateField(in: &metadata, fieldKey: fieldKey, valueString: stringValue)
        }
        
        // 型に応じたフィールド更新
        switch fieldKey {
        case "title":
            metadata.title = value as? String
        case "description":
            metadata.description = value as? String
        case "author":
            metadata.author = value as? String
        case "copyright":
            metadata.copyright = value as? String
        case "cameraMake":
            metadata.cameraMake = value as? String
        case "cameraModel":
            metadata.cameraModel = value as? String
        case "keywords":
            if let keywords = value as? [String] {
                metadata.keywords = keywords
            } else if let keywordString = value as? String {
                metadata.keywords = keywordString.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
            }
        case "creationDate":
            metadata.creationDate = value as? Date
        case "modificationDate":
            metadata.modificationDate = value as? Date
        case "latitude":
            metadata.latitude = value as? Double
        case "longitude":
            metadata.longitude = value as? Double
        case "altitude":
            metadata.altitude = value as? Double
        case "focalLength":
            metadata.focalLength = value as? Double
        case "aperture":
            metadata.aperture = value as? Double
        case "shutterSpeed":
            metadata.shutterSpeed = value as? Double
        case "iso":
            if let intValue = value as? Int {
                metadata.iso = intValue
            } else if let doubleValue = value as? Double {
                metadata.iso = Int(doubleValue)
            }
        case "flash":
            if let boolValue = value as? Bool {
                metadata.flash = boolValue
            } else if let intValue = value as? Int {
                metadata.flash = intValue > 0
            } else if let stringValue = value as? String {
                metadata.flash = stringValue.lowercased() == "true" || stringValue == "1"
            }
        default:
            // 追加メタデータに保存
            metadata.additionalMetadata[fieldKey] = String(describing: value)
        }
        
        return .success
    }
    
    /// 文字列からメタデータフィールドを更新（型変換を含む）
    private func updateField(in metadata: inout ImageMetadata, fieldKey: String, valueString: String) -> MetadataOperationResult {
        switch fieldKey {
        case "title", "description", "author", "copyright", "cameraMake", "cameraModel":
            // 文字列フィールドは直接設定
            return updateField(in: &metadata, fieldKey: fieldKey, value: valueString)
            
        case "keywords":
            // カンマ区切りの文字列から配列に変換
            let keywords = valueString.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
            return updateField(in: &metadata, fieldKey: fieldKey, value: keywords)
            
        case "creationDate", "modificationDate":
            // 日付文字列をDateに変換
            if let date = DateFormatter.iso8601.date(from: valueString) {
                return updateField(in: &metadata, fieldKey: fieldKey, value: date)
            } else {
                // 標準の文字列表現からの変換を試みる
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
                if let date = formatter.date(from: valueString) {
                    return updateField(in: &metadata, fieldKey: fieldKey, value: date)
                }
            }
            return .failure(MetadataError.invalidData)
            
        case "latitude", "longitude", "altitude", "focalLength", "aperture", "shutterSpeed":
            // 数値への変換
            if let doubleValue = Double(valueString) {
                return updateField(in: &metadata, fieldKey: fieldKey, value: doubleValue)
            }
            return .failure(MetadataError.invalidData)
            
        case "iso":
            // 整数値への変換
            if let intValue = Int(valueString) {
                return updateField(in: &metadata, fieldKey: fieldKey, value: intValue)
            }
            return .failure(MetadataError.invalidData)
            
        case "flash":
            // ブール値への変換
            let lowercased = valueString.lowercased()
            if lowercased == "true" || lowercased == "yes" || lowercased == "1" {
                return updateField(in: &metadata, fieldKey: fieldKey, value: true)
            } else if lowercased == "false" || lowercased == "no" || lowercased == "0" {
                return updateField(in: &metadata, fieldKey: fieldKey, value: false)
            }
            return .failure(MetadataError.invalidData)
            
        default:
            // 追加メタデータはそのまま文字列として保存
            metadata.additionalMetadata[fieldKey] = valueString
            return .success
        }
    }
    
    /// メタデータフィールドを削除
    private func deleteField(in metadata: inout ImageMetadata, fieldKey: String) -> MetadataOperationResult {
        switch fieldKey {
        case "title":
            metadata.title = nil
        case "description":
            metadata.description = nil
        case "author":
            metadata.author = nil
        case "copyright":
            metadata.copyright = nil
        case "cameraMake":
            metadata.cameraMake = nil
        case "cameraModel":
            metadata.cameraModel = nil
        case "keywords":
            metadata.keywords = []
        case "creationDate":
            metadata.creationDate = nil
        case "modificationDate":
            metadata.modificationDate = nil
        case "latitude", "longitude", "altitude":
            if fieldKey == "latitude" { metadata.latitude = nil }
            if fieldKey == "longitude" { metadata.longitude = nil }
            if fieldKey == "altitude" { metadata.altitude = nil }
        case "focalLength":
            metadata.focalLength = nil
        case "aperture":
            metadata.aperture = nil
        case "shutterSpeed":
            metadata.shutterSpeed = nil
        case "iso":
            metadata.iso = nil
        case "flash":
            metadata.flash = nil
        default:
            // 追加メタデータから削除
            metadata.additionalMetadata.removeValue(forKey: fieldKey)
        }
        
        return .success
    }
    
    /// 編集履歴に操作を追加
    func addToEditHistory(identifier: String, operation: MetadataEditOperation) {
        // 現在の履歴を取得または初期化
        var history = editHistoryCache[identifier] ?? []
        
        // 操作を追加
        history.append(operation)
        
        // キャッシュを更新
        editHistoryCache[identifier] = history
        
        // ストレージに保存
        saveEditHistoryToStorage(history, for: identifier)
    }
    
    /// メタデータをストレージに保存
    private func saveMetadataToStorage(_ metadata: ImageMetadata, for identifier: String) -> Bool {
        do {
            // メタデータをJSONデータに変換
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(metadata)
            
            // ファイル名を決定
            let filename = "metadata_\(identifier).json"
            
            // ドキュメントディレクトリのURLを取得
            guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return false
            }
            
            // ファイルパスを作成
            let fileURL = documentsDirectory.appendingPathComponent("GLogo/Metadata").appendingPathComponent(filename)
            
            // ディレクトリが存在することを確認
            let directoryURL = fileURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directoryURL.path) {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            }
            
            // ファイルに書き込み
            try data.write(to: fileURL)
            
            print("DEBUG: メタデータをストレージに保存しました: \(fileURL.path)")
            return true
        } catch {
            print("DEBUG: メタデータの保存に失敗: \(error.localizedDescription)")
            return false
        }
    }
    
    /// メタデータをストレージから読み込み
    private func loadMetadataFromStorage(for identifier: String) -> ImageMetadata? {
        // ファイル名を決定
        let filename = "metadata_\(identifier).json"
        
        // ドキュメントディレクトリのURLを取得
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        // ファイルパスを作成
        let fileURL = documentsDirectory.appendingPathComponent("GLogo/Metadata").appendingPathComponent(filename)
        
        do {
            // ファイルが存在するか確認
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return nil
            }
            
            // ファイルからデータを読み込み
            let data = try Data(contentsOf: fileURL)
            
            // JSONデータをデコード
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let metadata = try decoder.decode(ImageMetadata.self, from: data)
            
            return metadata
        } catch {
            print("DEBUG: メタデータの読み込みに失敗: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 編集履歴をストレージに保存
    private func saveEditHistoryToStorage(_ history: [MetadataEditOperation], for identifier: String) -> Bool {
        do {
            // 編集履歴をJSONデータに変換
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(history)
            
            // ファイル名を決定
            let filename = "history_\(identifier).json"
            
            // ドキュメントディレクトリのURLを取得
            guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return false
            }
            
            // ファイルパスを作成
            let fileURL = documentsDirectory.appendingPathComponent("GLogo/History").appendingPathComponent(filename)
            
            // ディレクトリが存在することを確認
            let directoryURL = fileURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directoryURL.path) {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            }
            
            // ファイルに書き込み
            try data.write(to: fileURL)
            
            print("DEBUG: 編集履歴をストレージに保存しました: \(fileURL.path)")
            return true
        } catch {
            print("DEBUG: 編集履歴の保存に失敗: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 編集履歴をストレージから読み込み
    private func loadEditHistoryFromStorage(for identifier: String) -> [MetadataEditOperation]? {
        // ファイル名を決定
        let filename = "history_\(identifier).json"
        
        // ドキュメントディレクトリのURLを取得
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        // ファイルパスを作成
        let fileURL = documentsDirectory.appendingPathComponent("GLogo/History").appendingPathComponent(filename)
        
        do {
            // ファイルが存在するか確認
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return nil
            }
            
            // ファイルからデータを読み込み
            let data = try Data(contentsOf: fileURL)
            
            // JSONデータをデコード
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let history = try decoder.decode([MetadataEditOperation].self, from: data)
            
            return history
        } catch {
            print("DEBUG: 編集履歴の読み込みに失敗: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - ユーティリティ拡張

/// DateFormatterの拡張
extension DateFormatter {
    /// ISO8601形式のDateFormatter
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

/// StringのPretty Print拡張
extension String {
    /// データ表現を読みやすい文字列に変換
    func convertToReadableString() -> String? {
        // 配列およびディクショナリ表現の処理
        if self.hasPrefix("[") && self.hasSuffix("]") ||
            self.hasPrefix("{") && self.hasSuffix("}") {
            return self
        }
        
        // 数値の処理
        if let _ = Double(self) {
            return self
        }
        
        // 日付の処理
        if self.contains(":") && self.count >= 10 {
            return self
        }
        
        // オブジェクト参照の処理（不要なものを除外）
        if self.contains("<") && self.contains(">") && self.contains("0x") {
            return nil
        }
        
        return self
    }
}

// MARK: - View拡張

#if canImport(SwiftUI)
import SwiftUI

/// SwiftUI拡張
@available(iOS 14.0, *)
extension View {
    /// メタデータ編集ビューを表示するモディファイア
    func metadataEditor(for identifier: String, isPresented: Binding<Bool>) -> some View {
        self.sheet(isPresented: isPresented) {
            MetadataEditorView(identifier: identifier)
        }
    }
}

/// メタデータ編集ビュー
@available(iOS 14.0, *)
struct MetadataEditorView: View {
    let identifier: String
    @Environment(\.presentationMode) var presentationMode
    @State private var metadata: ImageMetadata?
    @State private var history: [MetadataEditOperation] = []
    @State private var selectedSection: MetadataSection = .basic
    @State private var showHistoryView = false
    
    /// メタデータセクション
    enum MetadataSection: String, CaseIterable {
        case basic = "基本情報"
        case camera = "カメラ情報"
        case location = "位置情報"
        case other = "その他"
    }
    
    var body: some View {
        NavigationView {
            Form {
                if let metadata = metadata {
                    Picker("セクション", selection: $selectedSection) {
                        ForEach(MetadataSection.allCases, id: \.self) { section in
                            Text(section.rawValue).tag(section)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.vertical)
                    
                    switch selectedSection {
                    case .basic:
                        basicInfoSection(metadata: metadata)
                    case .camera:
                        cameraInfoSection(metadata: metadata)
                    case .location:
                        locationInfoSection(metadata: metadata)
                    case .other:
                        otherInfoSection(metadata: metadata)
                    }
                } else {
                    Text("メタデータがありません")
                        .padding()
                }
            }
            .navigationTitle("メタデータ編集")
            .navigationBarItems(
                leading: Button("閉じる") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: HStack {
                    Button("履歴") {
                        showHistoryView = true
                    }
                    
                    Button("元に戻す") {
                        // 最後の操作を取り消し（リバート）
                        if !history.isEmpty {
                            _ = ImageMetadataManager.shared.revertMetadata(for: identifier, to: history[max(0, history.count - 2)].id)
                            loadData()
                        }
                    }
                    .disabled(history.count <= 1)
                }
            )
            .sheet(isPresented: $showHistoryView) {
                MetadataHistoryView(identifier: identifier, onRevert: {
                    loadData()
                })
            }
            .onAppear {
                loadData()
                // メタデータ変更通知の登録
                ImageMetadataManager.shared.onMetadataChanged = { updatedIdentifier, updatedMetadata in
                    if updatedIdentifier == identifier {
                        self.metadata = updatedMetadata
                        self.history = ImageMetadataManager.shared.getEditHistory(for: identifier)
                    }
                }
            }
            .onDisappear {
                // 通知の登録解除
                ImageMetadataManager.shared.onMetadataChanged = nil
            }
        }
    }
    
    /// データの読み込み
    private func loadData() {
        metadata = ImageMetadataManager.shared.getMetadata(for: identifier)
        history = ImageMetadataManager.shared.getEditHistory(for: identifier)
    }
    
    /// 基本情報セクション
    private func basicInfoSection(metadata: ImageMetadata) -> some View {
        Section(header: Text("基本情報")) {
            editableTextField(title: "タイトル", value: metadata.title, key: "title")
            editableTextField(title: "説明", value: metadata.description, key: "description")
            editableTextField(title: "作成者", value: metadata.author, key: "author")
            editableTextField(title: "著作権", value: metadata.copyright, key: "copyright")
            
            if let creationDate = metadata.creationDate {
                dateRow(title: "作成日時", date: creationDate, key: "creationDate")
            }
            
            if let modificationDate = metadata.modificationDate {
                dateRow(title: "更新日時", date: modificationDate, key: "modificationDate")
            }
            
            editableTextField(title: "キーワード", value: metadata.keywords.joined(separator: ", "), key: "keywords")
        }
    }
    
    /// カメラ情報セクション
    private func cameraInfoSection(metadata: ImageMetadata) -> some View {
        Section(header: Text("カメラ情報")) {
            editableTextField(title: "カメラメーカー", value: metadata.cameraMake, key: "cameraMake")
            editableTextField(title: "カメラモデル", value: metadata.cameraModel, key: "cameraModel")
            
            if let focalLength = metadata.focalLength {
                numberRow(title: "焦点距離", value: focalLength, unit: "mm", key: "focalLength")
            }
            
            if let aperture = metadata.aperture {
                numberRow(title: "F値", value: aperture, unit: "", key: "aperture")
            }
            
            if let shutterSpeed = metadata.shutterSpeed {
                numberRow(title: "シャッタースピード", value: shutterSpeed, unit: "秒", key: "shutterSpeed")
            }
            
            if let iso = metadata.iso {
                numberRow(title: "ISO感度", value: Double(iso), unit: "", key: "iso")
            }
            
            if let flash = metadata.flash {
                toggleRow(title: "フラッシュ", isOn: flash, key: "flash")
            }
        }
    }
    
    /// 位置情報セクション
    private func locationInfoSection(metadata: ImageMetadata) -> some View {
        Section(header: Text("位置情報")) {
            if let latitude = metadata.latitude {
                numberRow(title: "緯度", value: latitude, unit: "°", key: "latitude")
            }
            
            if let longitude = metadata.longitude {
                numberRow(title: "経度", value: longitude, unit: "°", key: "longitude")
            }
            
            if let altitude = metadata.altitude {
                numberRow(title: "高度", value: altitude, unit: "m", key: "altitude")
            }
            
            if let latitude = metadata.latitude,
               let longitude = metadata.longitude {
                Link("地図で見る", destination: URL(string: "https://maps.apple.com/?q=\(latitude),\(longitude)")!)
            }
        }
    }
    
    /// その他の情報セクション
    private func otherInfoSection(metadata: ImageMetadata) -> some View {
        Section(header: Text("その他の情報")) {
            ForEach(metadata.additionalMetadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                editableTextField(title: formatMetadataKey(key), value: value, key: key)
            }
        }
    }
    
    /// メタデータキーのフォーマット
    private func formatMetadataKey(_ key: String) -> String {
        // プレフィックスの除去
        var formattedKey = key
            .replacingOccurrences(of: "exif_", with: "")
            .replacingOccurrences(of: "tiff_", with: "")
            .replacingOccurrences(of: "gps_", with: "")
            .replacingOccurrences(of: "iptc_", with: "")
        
        // キャメルケースをスペースで区切る
        let pattern = "([a-z0-9])([A-Z])"
        formattedKey = formattedKey.replacingOccurrences(of: pattern, with: "$1 $2", options: .regularExpression)
        
        // 先頭を大文字に
        formattedKey = formattedKey.prefix(1).uppercased() + formattedKey.dropFirst()
        
        return formattedKey
    }
    
    /// 編集可能なテキストフィールド
    private func editableTextField(title: String, value: String?, key: String) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if #available(iOS 15.0, *) {
                TextField(title, text: Binding(
                    get: { value ?? "" },
                    set: { newValue in
                        _ = ImageMetadataManager.shared.updateMetadataField(for: identifier, fieldKey: key, value: newValue)
                    }
                ))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            } else {
                TextField(title, text: Binding(
                    get: { value ?? "" },
                    set: { newValue in
                        _ = ImageMetadataManager.shared.updateMetadataField(for: identifier, fieldKey: key, value: newValue)
                    }
                ))
                .autocapitalization(.none)
                .disableAutocorrection(true)
            }
        }
        .padding(.vertical, 4)
    }
    
    /// 数値表示行
    private func numberRow(title: String, value: Double, unit: String, key: String) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                TextField(title, value: Binding(
                    get: { value },
                    set: { newValue in
                        _ = ImageMetadataManager.shared.updateMetadataField(for: identifier, fieldKey: key, value: newValue)
                    }
                ), formatter: NumberFormatter())
                .keyboardType(.decimalPad)
                
                if !unit.isEmpty {
                    Text(unit)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    /// 日付表示行
    private func dateRow(title: String, date: Date, key: String) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            DatePicker(
                title,
                selection: Binding(
                    get: { date },
                    set: { newValue in
                        _ = ImageMetadataManager.shared.updateMetadataField(for: identifier, fieldKey: key, value: newValue)
                    }
                ),
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
    
    /// トグル表示行
    private func toggleRow(title: String, isOn: Bool, key: String) -> some View {
        Toggle(title, isOn: Binding(
            get: { isOn },
            set: { newValue in
                _ = ImageMetadataManager.shared.updateMetadataField(for: identifier, fieldKey: key, value: newValue)
            }
        ))
    }
}

/// メタデータ履歴ビュー
@available(iOS 14.0, *)
struct MetadataHistoryView: View {
    let identifier: String
    let onRevert: () -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @State private var history: [MetadataEditOperation] = []
    @State private var selectedOperation: MetadataEditOperation?
    
    var body: some View {
        NavigationView {
            List {
                if history.isEmpty {
                    Text("編集履歴がありません")
                        .padding()
                } else {
                    ForEach(history.reversed()) { operation in
                        operationRow(operation)
                            .contextMenu {
                                Button(action: {
                                    revertTo(operation)
                                }) {
                                    Label("この時点に戻す", systemImage: "arrow.uturn.backward")
                                }
                            }
                    }
                }
            }
            .navigationTitle("編集履歴")
            .navigationBarItems(
                leading: Button("閉じる") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .onAppear {
                loadHistory()
            }
            .sheet(item: $selectedOperation) { operation in
                operationDetailView(operation)
            }
        }
    }
    
    /// 履歴の読み込み
    private func loadHistory() {
        history = ImageMetadataManager.shared.getEditHistory(for: identifier)
    }
    
    /// 操作行のビュー
    private func operationRow(_ operation: MetadataEditOperation) -> some View {
        Button(action: {
            selectedOperation = operation
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    operationTypeIcon(operation.type)
                    
                    Text(operationTypeText(operation.type))
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(formattedDate(operation.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if operation.type == .batchEdit {
                    if let metadata = operation.metadata, !metadata.isEmpty {
                        Text("\(metadata.count)個のフィールドを更新")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(formatFieldKey(operation.fieldKey))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let oldValue = operation.oldValue, let newValue = operation.newValue {
                        Group {
                            Text("\(truncateValue(oldValue)) → \(truncateValue(newValue))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
    
    /// 操作詳細ビュー
    private func operationDetailView(_ operation: MetadataEditOperation) -> some View {
        NavigationView {
            Form {
                Section(header: Text("基本情報")) {
                    HStack {
                        Text("操作タイプ")
                        Spacer()
                        operationTypeIcon(operation.type)
                        Text(operationTypeText(operation.type))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("タイムスタンプ")
                        Spacer()
                        Text(formattedDate(operation.timestamp, detailed: true))
                            .foregroundColor(.secondary)
                    }
                    
                    if operation.type != .batchEdit {
                        HStack {
                            Text("フィールド")
                            Spacer()
                            Text(formatFieldKey(operation.fieldKey))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if operation.type == .batchEdit, let metadata = operation.metadata {
                    Section(header: Text("変更されたフィールド")) {
                        ForEach(metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            VStack(alignment: .leading) {
                                Text(formatFieldKey(key))
                                    .font(.caption)
                                Text(value)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } else {
                    Section(header: Text("変更内容")) {
                        if let oldValue = operation.oldValue {
                            VStack(alignment: .leading) {
                                Text("変更前")
                                    .font(.caption)
                                Text(oldValue)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let newValue = operation.newValue {
                            VStack(alignment: .leading) {
                                Text("変更後")
                                    .font(.caption)
                                Text(newValue)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        revertTo(operation)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "arrow.uturn.backward")
                            Text("この時点に戻す")
                        }
                    }
                }
            }
            .navigationTitle("操作詳細")
            .navigationBarItems(
                trailing: Button("閉じる") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    /// 指定した操作の時点までリバート
    private func revertTo(_ operation: MetadataEditOperation) {
        let result = ImageMetadataManager.shared.revertMetadata(for: identifier, to: operation.id)
        if case .success = result {
            onRevert()
        }
    }
    
    /// 操作タイプに応じたアイコン
    private func operationTypeIcon(_ type: MetadataEditOperationType) -> some View {
        switch type {
        case .edit:
            return Image(systemName: "pencil")
        case .update:
            return Image(systemName: "arrow.2.circlepath")
        case .delete:
            return Image(systemName: "trash")
        case .restore:
            return Image(systemName: "arrow.clockwise")
        case .batchEdit:
            return Image(systemName: "rectangle.and.pencil.and.ellipsis")
        }
    }
    
    /// 操作タイプのテキスト表現
    private func operationTypeText(_ type: MetadataEditOperationType) -> String {
        switch type {
        case .edit:
            return "編集"
        case .update:
            return "更新"
        case .delete:
            return "削除"
        case .restore:
            return "復元"
        case .batchEdit:
            return "一括編集"
        }
    }
    
    /// 日付のフォーマット
    private func formattedDate(_ date: Date, detailed: Bool = false) -> String {
        let formatter = DateFormatter()
        
        if detailed {
            formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
        }
        
        return formatter.string(from: date)
    }
    
    /// フィールドキーのフォーマット
    private func formatFieldKey(_ key: String) -> String {
        // プレフィックスの除去
        var formattedKey = key
            .replacingOccurrences(of: "exif_", with: "")
            .replacingOccurrences(of: "tiff_", with: "")
            .replacingOccurrences(of: "gps_", with: "")
            .replacingOccurrences(of: "iptc_", with: "")
        
        // キャメルケースをスペースで区切る
        let pattern = "([a-z0-9])([A-Z])"
        formattedKey = formattedKey.replacingOccurrences(of: pattern, with: "$1 $2", options: .regularExpression)
        
        // 先頭を大文字に
        formattedKey = formattedKey.prefix(1).uppercased() + formattedKey.dropFirst()
        
        return formattedKey
    }
    
    /// 表示する値を省略
    private func truncateValue(_ value: String) -> String {
        let maxLength = 20
        if value.count > maxLength {
            return value.prefix(maxLength) + "..."
        }
        return value
    }
}
#endif

// MARK: - ViewModelのExtension

/// MVVM対応のためのViewModelサポート
extension ImageMetadataManager {
    /// メタデータビューモデル
    class MetadataViewModel: ObservableObject {
        /// 画像識別子
        let identifier: String
        
        /// メタデータ
        @Published var metadata: ImageMetadata?
        
        /// 編集履歴
        @Published var history: [MetadataEditOperation] = []
        
        /// 元のマネージャーインスタンス
        private let manager: ImageMetadataManager
        
        /// イニシャライザ
        init(identifier: String, manager: ImageMetadataManager = .shared) {
            self.identifier = identifier
            self.manager = manager
            
            // 初期データの読み込み
            loadData()
            
            // メタデータ変更通知の登録
            manager.onMetadataChanged = { [weak self] updatedIdentifier, updatedMetadata in
                guard let self = self, updatedIdentifier == self.identifier else {
                    return
                }
                
                DispatchQueue.main.async {
                    self.metadata = updatedMetadata
                    self.history = self.manager.getEditHistory(for: self.identifier)
                }
            }
        }
        
        /// データの読み込み
        func loadData() {
            metadata = manager.getMetadata(for: identifier)
            history = manager.getEditHistory(for: identifier)
        }
        
        /// メタデータフィールドの更新
        func updateField(key: String, value: Any) -> Bool {
            let result = manager.updateMetadataField(for: identifier, fieldKey: key, value: value)
            
            switch result {
            case .success:
                return true
            case .noChanges:
                return true
            default:
                return false
            }
        }
        
        /// 複数フィールドの一括更新
        func updateFields(updates: [String: Any]) -> Bool {
            let result = manager.updateMetadataFields(for: identifier, updates: updates)
            
            switch result {
            case .success:
                return true
            case .noChanges:
                return true
            default:
                return false
            }
        }
        
        /// 指定した操作の時点までリバート
        func revertTo(operation: MetadataEditOperation) -> Bool {
            let result = manager.revertMetadata(for: identifier, to: operation.id)
            
            switch result {
            case .success:
                return true
            default:
                return false
            }
        }
        
        /// 最後の操作を取り消し
        func undoLastOperation() -> Bool {
            guard history.count > 1 else {
                return false
            }
            
            let secondLastOperation = history[history.count - 2]
            return revertTo(operation: secondLastOperation)
        }
        
        /// 初期状態にリセット
        func resetToOriginal() -> Bool {
            let result = manager.revertMetadata(for: identifier)
            
            switch result {
            case .success:
                return true
            default:
                return false
            }
        }
        
        deinit {
            // 通知の登録解除
            manager.onMetadataChanged = nil
        }
    }
}

// MARK: - ImageElementとの連携拡張

/// UIImageからメタデータを抽出する拡張
extension UIImage {
    /// 画像からメタデータを抽出
    var extractedMetadata: ImageMetadata? {
        guard let imageData = jpegData(compressionQuality: 1.0) else { return nil }
        return ImageMetadataManager.shared.extractMetadata(from: imageData)
    }
}

/// ImageElement連携拡張
extension ImageElement {
    /// 画像データからメタデータを抽出するメソッド
    func extractMetadataFromImageData(_ imageData: Data) -> ImageMetadata? {
        return ImageMetadataManager.shared.extractMetadata(from: imageData)
    }
    
    /// メタデータ編集操作を記録
    func recordMetadataEdit(fieldKey: String, oldValue: Any?, newValue: Any?) {
        guard let identifier = originalImageIdentifier else { return }
        
        // メタデータがない場合は作成
        if metadata == nil {
            metadata = ImageMetadata()
        }
        
        // 操作の種類を決定
        let operationType: MetadataEditOperationType
        if oldValue == nil && newValue != nil {
            operationType = .restore
        } else if oldValue != nil && newValue == nil {
            operationType = .delete
        } else {
            operationType = .edit
        }
        
        // 文字列表現に変換
        let oldValueString = oldValue != nil ? String(describing: oldValue!) : nil
        let newValueString = newValue != nil ? String(describing: newValue!) : nil
        
        // 操作を作成
        let operation = MetadataEditOperation(
            type: operationType,
            fieldKey: fieldKey,
            oldValue: oldValueString,
            newValue: newValueString
        )
        
        // マネージャーを通して編集履歴に追加
        if let metadata = metadata {
            // メタデータの保存
            _ = ImageMetadataManager.shared.saveMetadata(metadata, for: identifier)
            
            // 編集操作を記録（直接追加メソッドを使用）
            ImageMetadataManager.shared.addToEditHistory(identifier: identifier, operation: operation)
        }
    }
    
    /// メタデータをリバート
    func revertMetadataToOriginal() -> Bool {
        guard let identifier = originalImageIdentifier else { return false }
        
        let result = ImageMetadataManager.shared.revertMetadata(for: identifier)
        
        switch result {
        case .success:
            // リバート後のメタデータを取得
            self.metadata = ImageMetadataManager.shared.getMetadata(for: identifier)
            return true
        default:
            return false
        }
    }
    
    /// 最後のメタデータ編集を取り消し
    func undoLastMetadataEdit() -> Bool {
        guard let identifier = originalImageIdentifier else { return false }
        
        // 履歴を取得
        let history = ImageMetadataManager.shared.getEditHistory(for: identifier)
        guard history.count > 1 else { return false }
        
        // 最後から2番目の操作を取得
        let secondLastOperation = history[history.count - 2]
        
        // リバート実行
        let result = ImageMetadataManager.shared.revertMetadata(for: identifier, to: secondLastOperation.id)
        
        switch result {
        case .success:
            // リバート後のメタデータを取得
            self.metadata = ImageMetadataManager.shared.getMetadata(for: identifier)
            return true
        default:
            return false
        }
    }
}
