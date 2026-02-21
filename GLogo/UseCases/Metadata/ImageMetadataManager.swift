//
// 概要:
// 画像メタデータの抽出・キャッシュ・履歴リバートを管理する。
// 永続化は MetadataFileStore に委譲する。
//

import Foundation
import UIKit
import Photos
import CoreLocation
import ImageIO
import OSLog

/// メタデータマネージャークラス
final class ImageMetadataManager {
    /// シングルトンインスタンス
    static let shared = ImageMetadataManager()

    /// メタデータ処理ログ
    private let logger = Logger(subsystem: "com.silvia.GLogo", category: "Metadata")

    /// 永続化ストア
    private let fileStore = MetadataFileStore()

    /// 編集履歴キャッシュ - 画像IDをキーとしたディクショナリ
    private var editHistoryCache: [String: [MetadataEditOperation]] = [:]

    /// メタデータキャッシュ - 画像IDをキーとしたディクショナリ
    private var metadataCache: [String: ImageMetadata] = [:]

    /// 変更通知
    var onMetadataChanged: ((String, ImageMetadata) -> Void)?

    /// プライベートイニシャライザ（シングルトンパターン）
    private init() {}

    // MARK: - 公開メソッド

    /// 画像データからメタデータを抽出
    /// - Parameters:
    ///   - imageData: 抽出対象の画像バイナリ。
    /// - Returns: 抽出結果。読み取り不能な場合は `nil`。
    func extractMetadata(from imageData: Data) -> ImageMetadata? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return nil
        }
        return extractMetadataFromImageSource(source)
    }

    /// 画像URLからメタデータを抽出
    /// - Parameters:
    ///   - url: 抽出対象の画像URL。
    /// - Returns: 抽出結果。読み取り不能な場合は `nil`。
    func extractMetadata(from url: URL) -> ImageMetadata? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        return extractMetadataFromImageSource(source)
    }

    /// PHAssetからメタデータを抽出
    /// - Parameters:
    ///   - asset: 抽出対象の `PHAsset`。
    /// - Returns: 抽出結果。入力解決に失敗した場合は `nil`。
    func extractMetadata(from asset: PHAsset) -> ImageMetadata? {
        var metadata = ImageMetadata()

        metadata.creationDate = asset.creationDate
        metadata.modificationDate = asset.modificationDate

        if let location = asset.location {
            metadata.latitude = location.coordinate.latitude
            metadata.longitude = location.coordinate.longitude
            metadata.altitude = location.altitude
        }

        let resources = PHAssetResource.assetResources(for: asset)
        if let resource = resources.first {
            metadata.additionalMetadata["originalFilename"] = resource.originalFilename
            if let fileSizeBytes = resource.value(forKey: "fileSize") as? Int64 {
                metadata.additionalMetadata["fileSize"] = String(fileSizeBytes)
            }
        }

        let options = PHContentEditingInputRequestOptions()
        options.canHandleAdjustmentData = { _ in true }

        let semaphore = DispatchSemaphore(value: 0)
        asset.requestContentEditingInput(with: options) { contentEditingInput, _ in
            defer { semaphore.signal() }

            guard let contentEditingInput,
                  let url = contentEditingInput.fullSizeImageURL else {
                return
            }

            if let additionalMetadata = self.extractMetadata(from: url) {
                metadata.cameraMake = additionalMetadata.cameraMake
                metadata.cameraModel = additionalMetadata.cameraModel
                metadata.focalLength = additionalMetadata.focalLength
                metadata.aperture = additionalMetadata.aperture
                metadata.shutterSpeed = additionalMetadata.shutterSpeed
                metadata.iso = additionalMetadata.iso
                metadata.flash = additionalMetadata.flash

                if metadata.latitude == nil {
                    metadata.latitude = additionalMetadata.latitude
                    metadata.longitude = additionalMetadata.longitude
                    metadata.altitude = additionalMetadata.altitude
                }

                for (key, value) in additionalMetadata.additionalMetadata {
                    metadata.additionalMetadata[key] = value
                }
            }
        }

        _ = semaphore.wait(timeout: .now() + 5.0)
        return metadata
    }

    /// 指定した画像のメタデータを取得
    /// - Parameters:
    ///   - identifier: 画像識別子。
    /// - Returns: キャッシュまたはストレージから取得したメタデータ。未保存時は `nil`。
    func getMetadata(for identifier: String) -> ImageMetadata? {
        if let cachedMetadata = metadataCache[identifier] {
            return cachedMetadata
        }

        if let metadata = fileStore.loadMetadata(for: identifier) {
            metadataCache[identifier] = metadata
            return metadata
        }

        return nil
    }

    /// メタデータを保存
    /// - Parameters:
    ///   - metadata: 保存対象メタデータ。
    ///   - identifier: 画像識別子。
    /// - Returns: 保存成功時は `true`、失敗時は `false`。
    func saveMetadata(_ metadata: ImageMetadata, for identifier: String) -> Bool {
        metadataCache[identifier] = metadata
        return fileStore.saveMetadata(metadata, for: identifier)
    }

    /// 編集履歴を取得
    /// - Parameters:
    ///   - identifier: 画像識別子。
    /// - Returns: 編集履歴配列。未保存時は空配列。
    func getEditHistory(for identifier: String) -> [MetadataEditOperation] {
        if let cachedHistory = editHistoryCache[identifier] {
            return cachedHistory
        }

        if let history = fileStore.loadEditHistory(for: identifier) {
            editHistoryCache[identifier] = history
            return history
        }

        return []
    }

    /// 指定した画像の編集履歴があるかを確認
    /// - Parameters:
    ///   - identifier: 画像識別子。
    /// - Returns: 履歴が1件以上存在する場合は `true`。
    func hasEditHistory(for identifier: String) -> Bool {
        let history = getEditHistory(for: identifier)
        return !history.isEmpty
    }

    /// 特定のポイントまでメタデータをリバート
    /// - Parameters:
    ///   - identifier: 画像識別子。
    ///   - operationId: 戻し先操作ID。`nil` の場合は初期状態まで戻す。
    /// - Returns: リバート処理の結果。
    func revertMetadata(for identifier: String, to operationId: UUID? = nil) -> MetadataOperationResult {
        let history = getEditHistory(for: identifier)
        guard !history.isEmpty else {
            return .noChanges
        }

        guard var metadata = getMetadata(for: identifier) else {
            return .notFound
        }

        let targetIndex: Int
        if let operationId {
            guard let index = history.firstIndex(where: { $0.id == operationId }) else {
                return .failure(MetadataError.operationNotFound)
            }
            targetIndex = index
        } else {
            targetIndex = 0
        }

        for i in stride(from: history.count - 1, to: targetIndex - 1, by: -1) {
            let operation = history[i]
            switch operation.type {
            case .edit, .delete, .update:
                if let oldValue = operation.oldValue {
                    _ = updateField(in: &metadata, fieldKey: operation.fieldKey, valueString: oldValue)
                }
            case .batchEdit:
                if let oldValues = operation.metadata {
                    for (key, value) in oldValues {
                        _ = updateField(in: &metadata, fieldKey: key, valueString: value)
                    }
                }
            case .restore:
                _ = updateField(in: &metadata, fieldKey: operation.fieldKey, value: nil)
            }
        }

        metadataCache[identifier] = metadata
        let updatedHistory = Array(history.prefix(targetIndex))
        editHistoryCache[identifier] = updatedHistory

        onMetadataChanged?(identifier, metadata)
        return .success
    }

    /// 編集履歴に操作を追加
    /// - Parameters:
    ///   - identifier: 画像識別子。
    ///   - operation: 追加する操作イベント。
    /// - Returns: なし
    func addToEditHistory(identifier: String, operation: MetadataEditOperation) {
        var history = editHistoryCache[identifier] ?? []
        history.append(operation)
        editHistoryCache[identifier] = history
        _ = fileStore.saveEditHistory(history, for: identifier)
    }

    /// 画像データにメタデータを適用
    /// - Note: テスト可観測性のため internal（@testable import で検証）
    /// - Parameters:
    ///   - imageData: メタデータを付与する元画像データ。
    ///   - metadata: 付与するメタデータ。
    /// - Returns: 適用後データ。適用不能時は `nil`。
    func applyMetadataToImageData(_ imageData: Data, metadata: ImageMetadata) -> Data? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return nil
        }

        guard let sourceType = CGImageSourceGetType(source) else {
            logger.warning("画像メタデータ適用のsourceType取得に失敗")
            return nil
        }

        let metadataDict = createMetadataDictionary(from: metadata)
        let mutableData = NSMutableData()

        guard let destination = CGImageDestinationCreateWithData(
            mutableData as CFMutableData,
            sourceType,
            1,
            nil
        ) else {
            return nil
        }

        let options: [String: Any] = [
            kCGImageDestinationMergeMetadata as String: true,
            kCGImageDestinationMetadata as String: metadataDict
        ]

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

    // MARK: - プライベートメソッド

    /// 画像ソースからメタデータ骨格を作成する。
    /// - Parameters:
    ///   - source: 読み取り元の `CGImageSource`。
    /// - Returns: 抽出したメタデータ。未取得項目は `nil` / 空値。
    private func extractMetadataFromImageSource(_ source: CGImageSource) -> ImageMetadata {
        let metadata = ImageMetadata()

        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return metadata
        }

        _ = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
        _ = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        _ = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any]
        _ = properties[kCGImagePropertyIPTCDictionary as String] as? [String: Any]

        return metadata
    }

    /// メタデータの指定キーを文字列表現で取得する。
    /// - Parameters:
    ///   - metadata: 参照元メタデータ。
    ///   - fieldKey: 取得対象キー。
    /// - Returns: 文字列表現。キー未存在時は `nil`。
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
            return metadata.additionalMetadata[fieldKey]
        }
    }

    /// メタデータの指定キーを値型に応じて更新する。
    /// - Parameters:
    ///   - metadata: 更新対象メタデータ。
    ///   - fieldKey: 更新対象キー。
    ///   - value: 設定値。`nil` の場合は削除扱い。
    /// - Returns: 更新結果。
    private func updateField(in metadata: inout ImageMetadata, fieldKey: String, value: Any?) -> MetadataOperationResult {
        if value == nil {
            return deleteField(in: &metadata, fieldKey: fieldKey)
        }

        if let stringValue = value as? String {
            return updateField(in: &metadata, fieldKey: fieldKey, valueString: stringValue)
        }

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
            metadata.additionalMetadata[fieldKey] = String(describing: value)
        }

        return .success
    }

    /// 文字列入力を型変換してメタデータへ反映する。
    /// - Parameters:
    ///   - metadata: 更新対象メタデータ。
    ///   - fieldKey: 更新対象キー。
    ///   - valueString: 文字列入力値。
    /// - Returns: 更新結果。
    private func updateField(in metadata: inout ImageMetadata, fieldKey: String, valueString: String) -> MetadataOperationResult {
        switch fieldKey {
        case "title", "description", "author", "copyright", "cameraMake", "cameraModel":
            return updateField(in: &metadata, fieldKey: fieldKey, value: valueString)

        case "keywords":
            let keywords = valueString.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
            return updateField(in: &metadata, fieldKey: fieldKey, value: keywords)

        case "creationDate", "modificationDate":
            if let date = DateFormatter.iso8601.date(from: valueString) {
                return updateField(in: &metadata, fieldKey: fieldKey, value: date)
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
                if let date = formatter.date(from: valueString) {
                    return updateField(in: &metadata, fieldKey: fieldKey, value: date)
                }
            }
            return .failure(MetadataError.invalidData)

        case "latitude", "longitude", "altitude", "focalLength", "aperture", "shutterSpeed":
            if let doubleValue = Double(valueString) {
                return updateField(in: &metadata, fieldKey: fieldKey, value: doubleValue)
            }
            return .failure(MetadataError.invalidData)

        case "iso":
            if let intValue = Int(valueString) {
                return updateField(in: &metadata, fieldKey: fieldKey, value: intValue)
            }
            return .failure(MetadataError.invalidData)

        case "flash":
            let lowercased = valueString.lowercased()
            if lowercased == "true" || lowercased == "yes" || lowercased == "1" {
                return updateField(in: &metadata, fieldKey: fieldKey, value: true)
            } else if lowercased == "false" || lowercased == "no" || lowercased == "0" {
                return updateField(in: &metadata, fieldKey: fieldKey, value: false)
            }
            return .failure(MetadataError.invalidData)

        default:
            metadata.additionalMetadata[fieldKey] = valueString
            return .success
        }
    }

    /// メタデータの指定キーを削除（初期化）する。
    /// - Parameters:
    ///   - metadata: 更新対象メタデータ。
    ///   - fieldKey: 削除対象キー。
    /// - Returns: 削除結果。
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
            metadata.additionalMetadata.removeValue(forKey: fieldKey)
        }

        return .success
    }

    /// `ImageMetadata` を ImageIO 書き込み用辞書へ変換する。
    /// - Parameters:
    ///   - metadata: 変換元メタデータ。
    /// - Returns: ImageIO に渡すメタデータ辞書。
    private func createMetadataDictionary(from metadata: ImageMetadata) -> [String: Any] {
        var dict = [String: Any]()

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
