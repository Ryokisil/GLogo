//
//  BackgroundBlurUseCase.swift
//  GLogo
//
//  概要:
//  背景ぼかしマスクの適用ルールと履歴イベント生成を提供するユースケース。
//

import UIKit

/// 背景ぼかし更新の適用計画
struct BackgroundBlurUpdatePlan {
    /// マスク変更イベント
    let maskEvent: ImageBackgroundBlurMaskChangedEvent
    /// 必要な場合のみ付随する半径変更イベント
    let radiusEvent: ImageBackgroundBlurRadiusChangedEvent?
}

/// 背景ぼかしマスクの適用ルールを扱うユースケース
struct BackgroundBlurUseCase {
    /// 背景ぼかしのデフォルト半径
    private let defaultBlurRadius: CGFloat = 12.0

    /// AI が生成したマスク画像から更新計画を作成する
    /// - Parameters:
    ///   - maskImage: AI が生成したマスク画像
    ///   - imageElement: 更新対象の画像要素
    /// - Returns: 更新が必要な場合の適用計画。マスク変換に失敗した場合は nil
    func makeAIMaskUpdatePlan(
        maskImage: UIImage,
        for imageElement: ImageElement
    ) -> BackgroundBlurUpdatePlan? {
        guard let maskData = maskImage.pngData() else {
            return nil
        }

        return makeMaskUpdatePlan(
            maskData: maskData,
            for: imageElement,
            defaultRadiusWhenMissing: defaultBlurRadius
        )
    }

    /// 背景ぼかしマスク更新の適用計画を作成する
    /// - Parameters:
    ///   - maskData: 更新後のマスクデータ
    ///   - imageElement: 更新対象の画像要素
    /// - Returns: 変更がある場合の適用計画。変更がない場合は nil
    func makeMaskUpdatePlan(
        maskData: Data?,
        for imageElement: ImageElement
    ) -> BackgroundBlurUpdatePlan? {
        makeMaskUpdatePlan(
            maskData: maskData,
            for: imageElement,
            defaultRadiusWhenMissing: defaultBlurRadius
        )
    }

    /// 背景ぼかしマスク削除の適用計画を作成する
    /// - Parameters:
    ///   - imageElement: 更新対象の画像要素
    /// - Returns: 削除が必要な場合の適用計画。変更がない場合は nil
    func makeRemoveMaskPlan(for imageElement: ImageElement) -> BackgroundBlurUpdatePlan? {
        let oldMaskData = imageElement.backgroundBlurMaskData
        let oldRadius = imageElement.backgroundBlurRadius

        guard oldMaskData != nil || oldRadius != 0 else {
            return nil
        }

        let maskEvent = ImageBackgroundBlurMaskChangedEvent(
            elementId: imageElement.id,
            oldMaskData: oldMaskData,
            newMaskData: nil
        )

        let radiusEvent: ImageBackgroundBlurRadiusChangedEvent?
        if oldRadius != 0 {
            radiusEvent = ImageBackgroundBlurRadiusChangedEvent(
                elementId: imageElement.id,
                oldRadius: oldRadius,
                newRadius: 0
            )
        } else {
            radiusEvent = nil
        }

        return BackgroundBlurUpdatePlan(maskEvent: maskEvent, radiusEvent: radiusEvent)
    }

    /// 背景ぼかしマスク更新の適用計画を内部生成する
    /// - Parameters:
    ///   - maskData: 更新後のマスクデータ
    ///   - imageElement: 更新対象の画像要素
    ///   - defaultRadiusWhenMissing: 半径未設定時に適用するデフォルト値
    /// - Returns: 変更がある場合の適用計画。変更がない場合は nil
    private func makeMaskUpdatePlan(
        maskData: Data?,
        for imageElement: ImageElement,
        defaultRadiusWhenMissing: CGFloat
    ) -> BackgroundBlurUpdatePlan? {
        let oldMaskData = imageElement.backgroundBlurMaskData
        let oldRadius = imageElement.backgroundBlurRadius

        guard maskData != oldMaskData else {
            return nil
        }

        let maskEvent = ImageBackgroundBlurMaskChangedEvent(
            elementId: imageElement.id,
            oldMaskData: oldMaskData,
            newMaskData: maskData
        )

        let shouldApplyDefaultRadius = maskData != nil && oldRadius == 0
        let radiusEvent: ImageBackgroundBlurRadiusChangedEvent?
        if shouldApplyDefaultRadius {
            radiusEvent = ImageBackgroundBlurRadiusChangedEvent(
                elementId: imageElement.id,
                oldRadius: oldRadius,
                newRadius: defaultRadiusWhenMissing
            )
        } else {
            radiusEvent = nil
        }

        return BackgroundBlurUpdatePlan(maskEvent: maskEvent, radiusEvent: radiusEvent)
    }
}
