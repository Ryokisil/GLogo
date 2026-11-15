//
//  ImageElementMetadataRevertUseCase.swift
//  GLogo
//
//  概要:
//  ImageElement の初期状態リバート時に必要なメタデータ復元を調整します。
//

import UIKit

/// 画像要素の初期状態リバートとメタデータ復元を調整するユースケース
struct ImageElementMetadataRevertUseCase {
    /// メタデータ永続化と履歴操作の委譲先
    private let store: any ImageMetadataStoring

    /// ユースケースを初期化する
    /// - Parameters:
    ///   - store: メタデータ永続化と履歴操作の委譲先
    /// - Returns: なし
    init(store: any ImageMetadataStoring) {
        self.store = store
    }

    /// 画像要素を初期状態へ戻し、関連するメタデータ履歴も巻き戻す
    ///
    /// ここでは値だけを戻す。描画キャッシュの失効（表示画像・プレビュー元画像・元画像）は、Revert のイベントが示し、
    /// 履歴が適用の直後にエディタの管理役で行う。
    /// - Parameters:
    ///   - imageElement: リバート対象の画像要素
    /// - Returns: メタデータ履歴のリバート結果。対象履歴がない場合は `.noChanges`
    @discardableResult
    func revertToInitialState(_ imageElement: ImageElement) -> MetadataOperationResult {
        imageElement.resetAdjustmentsToInitialState()
        return revertMetadataIfNeeded(for: imageElement)
    }

    /// 画像要素のメタデータ編集履歴有無を確認する
    /// - Parameters:
    ///   - imageElement: 確認対象の画像要素
    /// - Returns: メタデータ編集履歴がある場合は `true`
    func hasEditHistory(for imageElement: ImageElement) -> Bool {
        guard let identifier = imageElement.originalImageIdentifier else { return false }
        return store.hasEditHistory(for: identifier)
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

        let result = store.revertMetadata(for: identifier, to: nil)
        guard case .success = result,
              let metadata = store.getMetadata(for: identifier) else {
            return result
        }

        imageElement.metadata = metadata
        applyFrameProperties(from: metadata, to: imageElement)
        return result
    }

    /// メタデータの追加情報に記録されたフレーム・角丸の値を画像要素へ戻す。
    /// 文字列の解釈規則は、追加情報へ書き込む `ImageMetadataManager` の記録形式に合わせる。
    /// - Parameters:
    ///   - metadata: 巻き戻し後のメタデータ
    ///   - imageElement: 反映先の画像要素
    /// - Returns: なし
    private func applyFrameProperties(from metadata: ImageMetadata, to imageElement: ImageElement) {
        if let frameWidthString = metadata.additionalMetadata["frameWidth"],
           let frameWidthValue = Double(frameWidthString) {
            imageElement.frameWidth = CGFloat(frameWidthValue)
        }

        if let frameStyleString = metadata.additionalMetadata["frameStyle"],
           let decodedFrameStyle = ImageFrameStyle(rawValue: frameStyleString) {
            imageElement.frameStyle = decodedFrameStyle
        }

        if let roundedCornersString = metadata.additionalMetadata["roundedCorners"] {
            imageElement.roundedCorners = roundedCornersString == "true"
        }

        if let cornerRadiusString = metadata.additionalMetadata["cornerRadius"],
           let cornerRadiusValue = Double(cornerRadiusString) {
            imageElement.cornerRadius = CGFloat(cornerRadiusValue)
        }

        if let showFrameString = metadata.additionalMetadata["showFrame"] {
            imageElement.showFrame = showFrameString == "true"
        }

        if let frameColorString = metadata.additionalMetadata["frameColor"],
           let frameColor = UIColor(rgbaHex: frameColorString) ?? UIColor(hex: frameColorString) {
            imageElement.frameColor = frameColor
        }
    }
}
