//
// 概要:
// メタデータ編集で共通利用する型定義をまとめる。
//

import Foundation

/// メタデータ編集操作の種類
enum MetadataEditOperationType: String, Codable {
    case edit
    case update
    case delete
    case restore
    case batchEdit
}

/// メタデータ編集操作を表す構造体
struct MetadataEditOperation: Codable, Identifiable {
    let id: UUID
    let type: MetadataEditOperationType
    let timestamp: Date
    let fieldKey: String
    let oldValue: String?
    let newValue: String?
    let metadata: [String: String]?

    /// メタデータ編集操作を初期化する。
    /// - Parameters:
    ///   - type: 操作種別。
    ///   - fieldKey: 変更対象フィールドキー。
    ///   - oldValue: 変更前の値。
    ///   - newValue: 変更後の値。
    ///   - metadata: 一括編集時に保持する旧値辞書。
    /// - Returns: なし
    init(
        type: MetadataEditOperationType,
        fieldKey: String,
        oldValue: String? = nil,
        newValue: String? = nil,
        metadata: [String: String]? = nil
    ) {
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

    /// エラーの日本語説明を返す。
    /// - Parameters: なし
    /// - Returns: 表示用メッセージ。未定義の場合は `nil`。
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

// MARK: - Utility

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
