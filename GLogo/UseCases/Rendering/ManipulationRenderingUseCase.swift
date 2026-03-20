//
//  ManipulationRenderingUseCase.swift
//  GLogo
//
//  概要:
//  ジェスチャー操作中の画像描画経路切り替えルールを提供するユースケース。
//

import UIKit

/// ジェスチャー操作中の描画戦略を扱うユースケース
struct ManipulationRenderingUseCase {
    /// ジェスチャー操作開始時に画像要素の描画経路を準備する
    /// - Parameters:
    ///   - project: 対象プロジェクト
    ///   - highResolutionThreshold: 高解像度判定しきい値
    /// - Returns: 品質低下描画を有効にすべき場合は true
    func prepare(
        in project: LogoProject?,
        highResolutionThreshold: CGFloat
    ) -> Bool {
        guard let project else { return false }

        var shouldReduceQuality = false

        for element in project.elements {
            guard let imageElement = element as? ImageElement,
                  let originalImage = imageElement.originalImage else {
                continue
            }

            let pixelCount = originalImage.size.width
                * originalImage.size.height
                * originalImage.scale
                * originalImage.scale

            if pixelCount > highResolutionThreshold {
                shouldReduceQuality = true
            }

            guard pixelCount > highResolutionThreshold,
                  imageElement.shouldUseInstantPreviewForManipulation else {
                continue
            }

            imageElement.startEditing()
        }

        return shouldReduceQuality
    }

    /// ジェスチャー操作終了時に画像要素の描画状態を戻す
    /// - Parameters:
    ///   - project: 対象プロジェクト
    /// - Returns: なし
    func finish(in project: LogoProject?) {
        guard let project else { return }

        for element in project.elements {
            guard let imageElement = element as? ImageElement else { continue }
            imageElement.endEditing()
        }
    }
}
