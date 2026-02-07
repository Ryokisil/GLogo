
//  概要:
// このファイルは画像メタデータの管理と操作を担当するマネージャークラス
// メタデータの読み取り、保存、編集履歴の管理、およびリバート機能を実装
// リバート機能実装の為にメタデータが必要なので用意したが不要なメソッドも多いのでいつか整理する
// アンドゥリドゥと動作は似てるがあれは1個前の操作に戻るだけでリバートは編集前の初期状態に戻すので本質が異なる、オリジナルのメタデータを保持が必要

// コード量が多いがrevertMetadataToOriginal関数(2200行目辺り)が機能がメインなのでその処理を簡潔に残す ぶっちゃけこれだけあれば...
// 識別子取得 - 画像要素の識別子を取得（なければ失敗）
// リバート実行 - メタデータマネージャーを使い履歴の初期状態に戻す
// メタデータ適用 - 成功したら最新メタデータを取得して要素に設定
// プロパティ復元 - メタデータ値から実際のプロパティ（frameWidth, roundedCorners等）に適用
// キャッシュクリア - 画像キャッシュをクリアして変更を反映
// 結果返却 - 成功/失敗状態を返す


import Foundation  // 基本的なデータ型、ファイル操作、日付処理などの基本機能
import UIKit       // UIColor、UIImageなどのUI関連の型
import Photos      // PHAsset、PHPhotoLibraryなど写真ライブラリアクセス
import CoreLocation // 位置情報（緯度・経度・高度）の処理
import ImageIO     // 画像メタデータの読み取り・書き込み

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
enum MetadataError: Error, LocalizedError {
    case invalidData
    case extractionFailed
    case saveFailed
    case operationNotFound
    case historyCorrupted
    case unsupportedField
    case assetNotFound
    case authorizationDenied
    case imageDataNotAvailable
    case metadataApplicationFailed
    case readOnlyAsset
    case partialSuccess(errorCode: Int)
    //switch文は全てのケースを書く
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "メタデータが無効です。"
        case .extractionFailed:
            return "メタデータの抽出に失敗しました。"
        case .saveFailed:
            return "メタデータの保存に失敗しました。"
        case .operationNotFound:
            return "指定された操作が見つかりません。"
        case .historyCorrupted:
            return "編集履歴が破損しています。"
        case .unsupportedField:
            return "サポートされていないフィールドです。"
        case .assetNotFound:
            return "対応する写真アセットが見つかりません。"
        case .authorizationDenied:
            return "写真ライブラリへのアクセス権限がありません。"
        case .imageDataNotAvailable:
            return "画像データを取得できません。"
        case .metadataApplicationFailed:
            return "メタデータの適用に失敗しました。"
        case .readOnlyAsset:
            return "写真は読み取り専用です。アプリ内のみメタデータを保存しました。"
        case .partialSuccess(let code):
            return "元の写真への書き込みは失敗しましたが、アプリ内にメタデータは保存されました。(エラーコード: \(code))"
        }
    }
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
    
    
    // MARK: - ヘルパーメソッド
    
    /// アセットの詳細情報を出力
    private func debugAssetStatus(_ asset: PHAsset) {
        
        // 可能であればiCloud状態も確認
        if asset.responds(to: NSSelectorFromString("locallyAvailable")) {
        }
    }
    
    /// 画像データを読み込み、メタデータを適用して保存
    private func readImageAndApplyMetadata(url: URL, contentEditingInput: PHContentEditingInput, metadata: ImageMetadata, asset: PHAsset, completion: @escaping (Bool, Error?) -> Void) {
        do {
            let imageData = try Data(contentsOf: url)
            
            guard self.applyMetadataToImageData(imageData, metadata: metadata) != nil else {
                DispatchQueue.main.async {
                    completion(false, MetadataError.metadataApplicationFailed)
                }
                return
            }
            
            
        } catch {
            DispatchQueue.main.async {
                completion(false, error)
            }
        }
    }
    
    /// PHAssetが編集可能かどうかを確認
    func isAssetEditable(_ asset: PHAsset) -> Bool {
        // 編集操作が可能かチェック
        let canEdit = PHPhotoLibrary.authorizationStatus() == .authorized &&
        asset.canPerform(.content)
        
        return canEdit
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
        let metadata = ImageMetadata()
        
        // メタデータ辞書を取得
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return metadata
        }
        
        // 主要なメタデータ辞書を取得
        _ = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
        _ = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        _ = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any]
        _ = properties[kCGImagePropertyIPTCDictionary as String] as? [String: Any]
        
        return metadata
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
        case "frameWidth":
            if let doubleValue = value as? Double {
                metadata.additionalMetadata["frameWidth"] = String(doubleValue)
            } else if value is CGFloat {
                metadata.additionalMetadata["frameWidth"] = String(describing: value)
            }
        case "roundedCorners":
            if let boolValue = value as? Bool {
                metadata.additionalMetadata["roundedCorners"] = boolValue ? "true" : "false"
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
    func addToEditHistory(identifier: String, operation: MetadataEditOperation) -> Void {
        // 現在の履歴を取得または初期化
        var history = editHistoryCache[identifier] ?? []
        
        // 操作を追加
        history.append(operation)
        
        // キャッシュを更新
        editHistoryCache[identifier] = history
        
        // ストレージに保存 戻り値無視
        _ = saveEditHistoryToStorage(history, for: identifier)
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
            
            return true
        } catch {
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
            
            return true
        } catch {
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
            return nil
        }
    }
    
    /// 画像データにメタデータを適用
    private func applyMetadataToImageData(_ imageData: Data, metadata: ImageMetadata) -> Data? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return nil
        }
        
        let sourceType = CGImageSourceGetType(source)
        
        // メタデータをCFDictionaryに変換
        let metadataDict = createMetadataDictionary(from: metadata)
        
        // 出力データの作成
        let mutableData = NSMutableData()
        
        guard let destination = CGImageDestinationCreateWithData(
            mutableData as CFMutableData,
            sourceType!,
            1,
            nil
        ) else {
            return nil
        }
        
        // メタデータオプションを設定
        let options: [String: Any] = [
            kCGImageDestinationMergeMetadata as String: true,
            kCGImageDestinationMetadata as String: metadataDict
        ]
        
        // 元の画像とメタデータをコピー
        CGImageDestinationAddImageFromSource(
            destination,
            source,
            0,
            options as CFDictionary
        )
        
        if CGImageDestinationFinalize(destination) {
            return mutableData as Data
        } else {
            return nil
        }
    }
    
    /// メタデータオブジェクトからCFDictionaryを作成
    private func createMetadataDictionary(from metadata: ImageMetadata) -> [String: Any] {
        var dict = [String: Any]()
        
        // EXIFディクショナリ
        var exifDict = [String: Any]()
        if let dateTime = metadata.creationDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            exifDict[kCGImagePropertyExifDateTimeOriginal as String] = formatter.string(from: dateTime)
        }
        if let focalLength = metadata.focalLength {
            exifDict[kCGImagePropertyExifFocalLength as String] = focalLength
        }
        if let aperture = metadata.aperture {
            exifDict[kCGImagePropertyExifFNumber as String] = aperture
        }
        if let shutterSpeed = metadata.shutterSpeed {
            exifDict[kCGImagePropertyExifExposureTime as String] = shutterSpeed
        }
        if let iso = metadata.iso {
            exifDict[kCGImagePropertyExifISOSpeedRatings as String] = [iso]
        }
        if let flash = metadata.flash {
            exifDict[kCGImagePropertyExifFlash as String] = flash ? 1 : 0
        }
        
        // TIFFディクショナリ
        var tiffDict = [String: Any]()
        if let make = metadata.cameraMake {
            tiffDict[kCGImagePropertyTIFFMake as String] = make
        }
        if let model = metadata.cameraModel {
            tiffDict[kCGImagePropertyTIFFModel as String] = model
        }
        if let copyright = metadata.copyright {
            tiffDict[kCGImagePropertyTIFFCopyright as String] = copyright
        }
        if let artist = metadata.author {
            tiffDict[kCGImagePropertyTIFFArtist as String] = artist
        }
        
        // GPSディクショナリ
        var gpsDict = [String: Any]()
        if let latitude = metadata.latitude {
            gpsDict[kCGImagePropertyGPSLatitude as String] = abs(latitude)
            gpsDict[kCGImagePropertyGPSLatitudeRef as String] = latitude >= 0 ? "N" : "S"
        }
        if let longitude = metadata.longitude {
            gpsDict[kCGImagePropertyGPSLongitude as String] = abs(longitude)
            gpsDict[kCGImagePropertyGPSLongitudeRef as String] = longitude >= 0 ? "E" : "W"
        }
        if let altitude = metadata.altitude {
            gpsDict[kCGImagePropertyGPSAltitude as String] = abs(altitude)
            gpsDict[kCGImagePropertyGPSAltitudeRef as String] = altitude >= 0 ? 0 : 1
        }
        
        // IPTCディクショナリ
        var iptcDict = [String: Any]()
        if let title = metadata.title {
            iptcDict[kCGImagePropertyIPTCObjectName as String] = title
        }
        if let description = metadata.description {
            iptcDict[kCGImagePropertyIPTCCaptionAbstract as String] = description
        }
        if !metadata.keywords.isEmpty {
            iptcDict[kCGImagePropertyIPTCKeywords as String] = metadata.keywords
        }
        
        // メインディクショナリに追加
        if !exifDict.isEmpty {
            dict[kCGImagePropertyExifDictionary as String] = exifDict
        }
        if !tiffDict.isEmpty {
            dict[kCGImagePropertyTIFFDictionary as String] = tiffDict
        }
        if !gpsDict.isEmpty {
            dict[kCGImagePropertyGPSDictionary as String] = gpsDict
        }
        if !iptcDict.isEmpty {
            dict[kCGImagePropertyIPTCDictionary as String] = iptcDict
        }
        
        return dict
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
        
        // 文字列表現に変換
        let oldValueString = oldValue != nil ? String(describing: oldValue!) : nil
        let newValueString = newValue != nil ? String(describing: newValue!) : nil
        
        // 操作の種類を決定
        let operationType: MetadataEditOperationType
        if oldValue == nil && newValue != nil {
            operationType = .restore
        } else if oldValue != nil && newValue == nil {
            operationType = .delete
        } else {
            operationType = .edit
        }
        
        // メタデータ内のadditionalMetadataに直接値を保存
        if var metadata = metadata {
            if let newValue = newValue {
                // 値を文字列として保存
                metadata.additionalMetadata[fieldKey] = String(describing: newValue)
            } else {
                // nilの場合は削除
                metadata.additionalMetadata.removeValue(forKey: fieldKey)
            }
            
            // メタデータを更新
            self.metadata = metadata
            
            // 操作を作成
            let operation = MetadataEditOperation(
                type: operationType,
                fieldKey: fieldKey,
                oldValue: oldValueString,
                newValue: newValueString
            )
            
            // マネージャーを通して編集履歴に追加
            ImageMetadataManager.shared.addToEditHistory(identifier: identifier, operation: operation)
            
            // メタデータの保存
            _ = ImageMetadataManager.shared.saveMetadata(metadata, for: identifier)
        }
    }
    
    /// メタデータをリバート
    func revertMetadataToOriginal() -> Bool {
        guard let identifier = originalImageIdentifier else { return false }
        
        let result = ImageMetadataManager.shared.revertMetadata(for: identifier)
        
        switch result {
        case .success:
            // リバート後のメタデータを取得
            if let metadata = ImageMetadataManager.shared.getMetadata(for: identifier) {
                self.metadata = metadata
                
                // メタデータからプロパティを復元
                applyMetadataToProperties(metadata)
                
                // キャッシュをクリア
                cachedImage = nil
                
                return true
            }
        default:
            return false
        }
        return false
    }
    
    /// メタデータからプロパティを適用
    private func applyMetadataToProperties(_ metadata: ImageMetadata) {
        // フレーム太さ   Swiftでは文字列を直接CGFloatに変換出来ない
        if let frameWidthString = metadata.additionalMetadata["frameWidth"], // additionalMetadataの辞書型から"frameWidth"キーで値を取得 オプショナルではないことを確認（値が存在する場合のみ処理を続行）
            let frameWidthDouble = Double(frameWidthString) { // 取得した文字列をDouble型の数値に変換 変換が成功した場合のみ（文字列が有効な数値だった場合のみ）処理を続行
            self.frameWidth = CGFloat(frameWidthDouble) // DoubleをCGFloatにキャストしてframeWidthプロパティに代入 CGFloatは直接文字列から生成できないため、Double経由で変換が必要
        }
        
        // 角丸設定
        if let roundedCornersString = metadata.additionalMetadata["roundedCorners"] {
            self.roundedCorners = roundedCornersString == "true"
        }
        
        // 角丸半径
        if let cornerRadiusString = metadata.additionalMetadata["cornerRadius"],
           let cornerRadiusDouble = Double(cornerRadiusString) {
            self.cornerRadius = CGFloat(cornerRadiusDouble)
        }
        
        // フレーム表示
        if let showFrameString = metadata.additionalMetadata["showFrame"] {
            self.showFrame = showFrameString == "true"
        }
        
        // フレーム色（これはより複雑な処理が必要）
        if let frameColorString = metadata.additionalMetadata["frameColor"] {
            // UIColorを文字列から復元する適切な方法を実装する必要があります
            // ここでは簡略化します
            if frameColorString == "white" {
                self.frameColor = .white
            } else if frameColorString == "black" {
                self.frameColor = .black
            }
            
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
