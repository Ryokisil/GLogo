//
//  HDRFilterPipeline.swift
//  GLogo
//
//  概要:
//  HDR用フィルター適用パイプライン。Display P3色空間でトーンカーブ＋調整ステージを
//  1本のパイプラインとして実行する。SDR版FilterPipelineと同構造で、色空間のみP3に切替。

import CoreImage
import UIKit

/// HDR（Display P3）用フィルターパイプライン
final class HDRFilterPipeline {
    private let toneCurveStage = HDRToneCurveStage()

    /// すべてのフィルターを適用
    /// - Parameters:
    ///   - image: 入力画像
    ///   - toneCurveData: トーンカーブデータ
    ///   - policy: レンダリングポリシー
    ///   - context: レンダリングコンテキスト（デフォルト: HDR）
    ///   - adjustments: 調整ステージクロージャ
    /// - Returns: フィルター適用済み画像
    func applyAllFilters(to image: UIImage, toneCurveData: ToneCurveData, policy: RenderPolicy, context: RenderContext = .hdr, adjustments: (inout CIImage) -> Void) -> UIImage? {
        guard let cgImage = image.cgImage else { return image }

        var ciImage = CIImage(
            cgImage: cgImage,
            options: [.colorSpace: context.colorSpace]
        )

        // 調整群を適用（AdjustmentStagesのCIFilter操作は色空間非依存）
        adjustments(&ciImage)

        // トーンカーブ（P3色空間のLUTで適用）
        if let adjusted = toneCurveStage.apply(to: ciImage, curveData: toneCurveData, policy: policy, context: context) {
            ciImage = adjusted
        }

        // P3 CIContextでUIImageへ戻す
        guard let outputCG = context.ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        let baseImage = UIImage(cgImage: outputCG, scale: image.scale, orientation: image.imageOrientation)

        // targetMaxDimensionが指定されていれば出力後にリサイズ
        if let maxDim = policy.targetMaxDimension {
            let w = baseImage.size.width
            let h = baseImage.size.height
            let maxSide = max(w, h)
            if maxSide > maxDim {
                let scale = maxDim / maxSide
                let newSize = CGSize(width: w * scale, height: h * scale)
                let format = UIGraphicsImageRendererFormat()
                format.scale = 1.0
                format.preferredRange = .extended  // 広色域を維持
                let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
                return renderer.image { _ in
                    baseImage.draw(in: CGRect(origin: .zero, size: newSize))
                }
            }
        }

        return baseImage
    }
}
