// 画像識別子ごとのメタデータと編集履歴を読み書きする境界を定義する。

import Foundation

/// メタデータの永続化と編集履歴の巻き戻しを担う能力。実装はファイル保存と履歴管理を持つ。
protocol ImageMetadataStoring {
    func getMetadata(for identifier: String) -> ImageMetadata?

    /// - Returns: 保存に成功した場合は `true`
    @discardableResult
    func saveMetadata(_ metadata: ImageMetadata, for identifier: String) -> Bool

    func hasEditHistory(for identifier: String) -> Bool

    func addToEditHistory(identifier: String, operation: MetadataEditOperation)

    /// - Parameters:
    ///   - operationId: 巻き戻し先の操作。`nil` の場合は初期状態まで戻す
    func revertMetadata(for identifier: String, to operationId: UUID?) -> MetadataOperationResult
}
