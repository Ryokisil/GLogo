//
//  ImageMetadataEditUseCase.swift
//  GLogo
//
//  概要:
//  ImageElement に対するメタデータ編集記録の条件分岐をまとめるユースケース。
//

import Foundation
import UIKit

/// 画像メタデータ編集記録ユースケース
struct ImageMetadataEditUseCase {
    /// メタデータと編集履歴の保存先
    private let store: any ImageMetadataStoring

    init(store: any ImageMetadataStoring = ImageMetadataManager.shared) {
        self.store = store
    }

    /// 単一項目のメタデータ編集を必要時のみ記録する
    /// 画像識別子がない要素は保存先を特定できないため記録しない。
    /// - Parameters:
    ///   - imageElement: 対象画像要素
    ///   - fieldKey: 編集対象キー
    ///   - oldValue: 変更前の値
    ///   - newValue: 変更後の値
    /// - Returns: なし
    func recordEditIfNeeded(
        for imageElement: ImageElement,
        fieldKey: String,
        oldValue: Any?,
        newValue: Any?
    ) {
        guard let identifier = imageElement.originalImageIdentifier else { return }

        // 値の有無の変化から操作種別を決める。履歴の巻き戻しはこの種別に従う。
        let operationType: MetadataEditOperationType
        if oldValue == nil && newValue != nil {
            operationType = .restore
        } else if oldValue != nil && newValue == nil {
            operationType = .delete
        } else {
            operationType = .edit
        }

        var metadata = imageElement.metadata ?? ImageMetadata()
        if let newValue {
            metadata.additionalMetadata[fieldKey] = String(describing: newValue)
        } else {
            metadata.additionalMetadata.removeValue(forKey: fieldKey)
        }
        imageElement.metadata = metadata

        let operation = MetadataEditOperation(
            type: operationType,
            fieldKey: fieldKey,
            oldValue: oldValue.map { String(describing: $0) },
            newValue: newValue.map { String(describing: $0) }
        )
        store.addToEditHistory(identifier: identifier, operation: operation)
        store.saveMetadata(metadata, for: identifier)
    }
}
