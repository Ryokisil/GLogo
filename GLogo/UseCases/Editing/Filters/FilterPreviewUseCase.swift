//
//  FilterPreviewUseCase.swift
//  GLogo
//
//  概要:
//  フィルタープリセットのプレビュー画像生成を担当します。
//  選択画像を小サイズ化し、filter + manual 調整の合成結果をサムネイルとして返します。
//

import Foundation
import UIKit

/// フィルタープレビュー生成ユースケース
enum FilterPreviewUseCase {

    /// プリセットのプレビュー画像を生成（filter + manual を合成）
    /// 合成規則は編集画面の描画と共通のため、適用後の見た目とサムネイルが一致する。
    /// - Parameters:
    ///   - sourceImage: プレビュー元の画像
    ///   - adjustments: 選択画像に設定された手動調整値
    ///   - preset: 適用するフィルタープリセット
    ///   - targetSize: サムネイルサイズ
    ///   - previewService: 選択画像と同じ描画依存。単独利用時は既定の共有サービス
    /// - Returns: プレビュー画像。生成に失敗した場合は nil
    static func generatePreview(
        sourceImage: UIImage,
        adjustments: ImageAdjustmentValues,
        preset: FilterPreset,
        targetSize: CGSize,
        previewService: any ImagePreviewing = ImagePreviewService.shared
    ) async -> UIImage? {
        let preparedImage = resizedImage(sourceImage, targetSize: targetSize)
        let params = ImageFilterParamsComposer.compose(adjustments, recipe: preset.recipe)
        let renderMode = ImageRenderMode.fromPresetId(preset.id)

        return await previewService.applyFiltersAsync(
            to: preparedImage,
            params: params,
            quality: .preview,
            mode: renderMode
        )
    }

    /// プレビュー用に画像を縮小
    /// - Parameters:
    ///   - image: 縮小対象の画像
    ///   - targetSize: 目標サイズ
    /// - Returns: 縮小後の画像
    private static func resizedImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let safeWidth = max(1, targetSize.width)
        let safeHeight = max(1, targetSize.height)
        let maxPixelSize = max(safeWidth, safeHeight) * 2

        let sourceSize = image.size
        let maxSourceSide = max(sourceSize.width, sourceSize.height)
        guard maxSourceSide > maxPixelSize else { return image }

        let ratio = maxPixelSize / maxSourceSide
        let resizedSize = CGSize(
            width: max(1, floor(sourceSize.width * ratio)),
            height: max(1, floor(sourceSize.height * ratio))
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: resizedSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: resizedSize))
        }
    }
}
