//
//  FilterPipeline.swift
//  GLogo
//
//  概要:
//  フィルター適用の実行経路を集約し、RenderPolicy/RenderContextを使って
//  調整ステージ＋トーンカーブ適用を1本のパイプラインとして実行する。
//  また、policyで指定された場合のみ出力後にリサイズ（フィルターは原寸で適用）を行う。

import CoreImage
import UIKit

/// 既存のフィルター適用経路をラップし、品質/ポリシーで切り替え可能にする。
final class FilterPipeline {
    private let toneCurveStage = ToneCurveStage()

    func applyAllFilters(to image: UIImage,toneCurveData: ToneCurveData,policy: RenderPolicy,context: RenderContext = .shared,adjustments: (inout CIImage) -> Void) -> UIImage? {
        guard let cgImage = image.cgImage else { return image }

        var ciImage = CIImage(
            cgImage: cgImage,
            options: [.colorSpace: context.colorSpace]
        )

        // 呼び出し元で既存の調整群を適用（順序は従来通り）
        adjustments(&ciImage)

        // トーンカーブ
        if let adjusted = toneCurveStage.apply(to: ciImage, curveData: toneCurveData, policy: policy, context: context) {
            ciImage = adjusted
        }

        // UIImageへ戻す（既存のCIContextを共有）
        guard let outputCG = context.ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        let baseImage = UIImage(cgImage: outputCG, scale: image.scale, orientation: image.imageOrientation)

        // targetMaxDimensionが指定されていれば、出力後にリサイズ（フィルターは原寸で適用）
        if let maxDim = policy.targetMaxDimension {
            let w = baseImage.size.width
            let h = baseImage.size.height
            let maxSide = max(w, h)
            if maxSide > maxDim {
                let scale = maxDim / maxSide
                let newSize = CGSize(width: w * scale, height: h * scale)
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                baseImage.draw(in: CGRect(origin: .zero, size: newSize))
                let resized = UIGraphicsGetImageFromCurrentImageContext() ?? baseImage
                UIGraphicsEndImageContext()
                return resized
            }
        }

        return baseImage
    }
}
