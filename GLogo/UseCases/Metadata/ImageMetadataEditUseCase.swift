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
    /// 単一項目のメタデータ編集を必要時のみ記録する
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
        guard imageElement.originalImageIdentifier != nil else { return }
        imageElement.recordMetadataEdit(
            fieldKey: fieldKey,
            oldValue: oldValue,
            newValue: newValue
        )
    }
}
