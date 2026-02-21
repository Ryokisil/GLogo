//
// 概要:
// UIImage / ImageElement から ImageMetadataManager を利用する橋渡し拡張。
//

import UIKit

/// UIImageからメタデータを抽出する拡張
extension UIImage {
    /// 画像からメタデータを抽出
    /// - Parameters: なし
    /// - Returns: 抽出結果。JPEGデータ化に失敗した場合は `nil`。
    var extractedMetadata: ImageMetadata? {
        guard let imageData = jpegData(compressionQuality: 1.0) else { return nil }
        return ImageMetadataManager.shared.extractMetadata(from: imageData)
    }
}

/// ImageElement連携拡張
extension ImageElement {
    /// 画像データからメタデータを抽出するメソッド
    /// - Parameters:
    ///   - imageData: 抽出対象の画像データ。
    /// - Returns: 抽出したメタデータ。抽出できない場合は `nil`。
    func extractMetadataFromImageData(_ imageData: Data) -> ImageMetadata? {
        return ImageMetadataManager.shared.extractMetadata(from: imageData)
    }

    /// メタデータ編集操作を記録
    /// - Parameters:
    ///   - fieldKey: 変更対象のメタデータキー。
    ///   - oldValue: 変更前の値。
    ///   - newValue: 変更後の値。
    /// - Returns: なし
    func recordMetadataEdit(fieldKey: String, oldValue: Any?, newValue: Any?) {
        guard let identifier = originalImageIdentifier else { return }

        if metadata == nil {
            metadata = ImageMetadata()
        }

        let oldValueString = oldValue.map { String(describing: $0) }
        let newValueString = newValue.map { String(describing: $0) }

        let operationType: MetadataEditOperationType
        if oldValue == nil && newValue != nil {
            operationType = .restore
        } else if oldValue != nil && newValue == nil {
            operationType = .delete
        } else {
            operationType = .edit
        }

        if var metadata {
            if let newValue {
                metadata.additionalMetadata[fieldKey] = String(describing: newValue)
            } else {
                metadata.additionalMetadata.removeValue(forKey: fieldKey)
            }

            self.metadata = metadata

            let operation = MetadataEditOperation(
                type: operationType,
                fieldKey: fieldKey,
                oldValue: oldValueString,
                newValue: newValueString
            )

            ImageMetadataManager.shared.addToEditHistory(identifier: identifier, operation: operation)
            _ = ImageMetadataManager.shared.saveMetadata(metadata, for: identifier)
        }
    }
}
