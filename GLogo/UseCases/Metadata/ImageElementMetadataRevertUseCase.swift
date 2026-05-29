//
//  ImageElementMetadataRevertUseCase.swift
//  GLogo
//
//  概要:
//  ImageElement の初期状態リバート時に必要なメタデータ復元を調整します。
//

import Foundation

/// 画像要素の初期状態リバートとメタデータ復元を調整するユースケース
struct ImageElementMetadataRevertUseCase {
    /// メタデータ永続化と履歴操作の委譲先
    private let metadataManager: ImageMetadataManager

    /// ユースケースを初期化する
    /// - Parameters:
    ///   - metadataManager: メタデータ永続化と履歴操作の委譲先
    /// - Returns: なし
    init(metadataManager: ImageMetadataManager = .shared) {
        self.metadataManager = metadataManager
    }

    /// 画像要素を初期状態へ戻し、関連するメタデータ履歴も巻き戻す
    /// - Parameters:
    ///   - imageElement: リバート対象の画像要素
    /// - Returns: メタデータ履歴のリバート結果。対象履歴がない場合は `.noChanges`
    @discardableResult
    func revertToInitialState(_ imageElement: ImageElement) -> MetadataOperationResult {
        imageElement.resetAdjustmentsToInitialState()
        let result = revertMetadataIfNeeded(for: imageElement)
        imageElement.clearRevertImageCaches()
        return result
    }

    /// 画像要素のメタデータ編集履歴有無を確認する
    /// - Parameters:
    ///   - imageElement: 確認対象の画像要素
    /// - Returns: メタデータ編集履歴がある場合は `true`
    func hasEditHistory(for imageElement: ImageElement) -> Bool {
        guard let identifier = imageElement.originalImageIdentifier else { return false }
        return metadataManager.hasEditHistory(for: identifier)
    }

    /// 画像要素が初期状態へ戻せるかを判定する
    /// - Parameters:
    ///   - imageElement: 判定対象の画像要素
    /// - Returns: メタデータ履歴または調整値変更がある場合は `true`
    func canRevertToInitialState(_ imageElement: ImageElement) -> Bool {
        hasEditHistory(for: imageElement) || imageElement.hasAdjustmentChangesFromInitialState
    }

    /// メタデータ履歴がある場合のみ巻き戻し、画像要素の表示プロパティへ反映する
    /// - Parameters:
    ///   - imageElement: メタデータ反映先の画像要素
    /// - Returns: メタデータ履歴のリバート結果。画像識別子がない場合は `.noChanges`
    private func revertMetadataIfNeeded(for imageElement: ImageElement) -> MetadataOperationResult {
        guard let identifier = imageElement.originalImageIdentifier else {
            return .noChanges
        }

        let result = metadataManager.revertMetadata(for: identifier)
        guard case .success = result,
              let metadata = metadataManager.getMetadata(for: identifier) else {
            return result
        }

        imageElement.metadata = metadata
        imageElement.applyMetadataToImageProperties(metadata)
        return result
    }
}
