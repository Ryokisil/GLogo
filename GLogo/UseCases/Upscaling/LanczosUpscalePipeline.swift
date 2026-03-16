//
//  LanczosUpscalePipeline.swift
//  GLogo
//
//  概要:
//  このファイルは Core Image の Lanczos 拡大を利用した高画質化パイプラインを定義します。
//  API や Core ML モデルに依存せず、オンデバイスで即時に動作する既定の高画質化処理を提供します。
//

import CoreImage
import Foundation
import UIKit

/// Core Image ベースの既定高画質化パイプライン
struct LanczosUpscalePipeline: ImageUpscalingPipeline {
    private let context = CIContext()
    private let memoryPolicy = UpscaleMemoryPolicy()

    var method: ImageUpscaleMethod {
        .lanczos
    }

    var isAvailable: Bool {
        true
    }

    /// Lanczos 拡大と軽いシャープ化で高画質化する
    /// - Parameters:
    ///   - request: 実行対象のリクエスト
    /// - Returns: 高画質化結果
    func upscale(_ request: ImageUpscaleRequest) async throws -> ImageUpscaleResult {
        guard let inputCIImage = CIImage(image: request.sourceImage) else {
            throw ImageUpscaleError.missingCGImage
        }
        let sourcePixelSize = CGSize(
            width: request.sourceImage.size.width * request.sourceImage.scale,
            height: request.sourceImage.size.height * request.sourceImage.scale
        )
        let actualScale = memoryPolicy.safeScale(
            requestedScale: request.scaleFactor.multiplier,
            sourcePixelSize: sourcePixelSize
        )
        guard actualScale >= 1 else {
            throw ImageUpscaleError.sourceImageTooLarge
        }
        guard let lanczosFilter = CIFilter(name: "CILanczosScaleTransform") else {
            throw ImageUpscaleError.filterUnavailable(name: "CILanczosScaleTransform")
        }

        lanczosFilter.setValue(inputCIImage, forKey: kCIInputImageKey)
        lanczosFilter.setValue(actualScale, forKey: kCIInputScaleKey)
        lanczosFilter.setValue(1.0, forKey: kCIInputAspectRatioKey)

        guard let scaledImage = lanczosFilter.outputImage else {
            throw ImageUpscaleError.imageGenerationFailed
        }

        let outputImage = try applySharpeningIfNeeded(
            to: scaledImage,
            shouldApply: request.appliesSharpening
        )

        guard let outputCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            throw ImageUpscaleError.imageGenerationFailed
        }

        let upscaledImage = UIImage(
            cgImage: outputCGImage,
            scale: request.sourceImage.scale,
            orientation: request.sourceImage.imageOrientation
        )

        return ImageUpscaleResult(
            image: upscaledImage,
            appliedMethod: method,
            scaleFactor: request.scaleFactor,
            actualScaleMultiplier: actualScale
        )
    }

    /// 必要な場合のみ軽いシャープ化を適用する
    /// - Parameters:
    ///   - image: シャープ化対象の CIImage
    ///   - shouldApply: シャープ化適用フラグ
    /// - Returns: 変換後の CIImage
    private func applySharpeningIfNeeded(
        to image: CIImage,
        shouldApply: Bool
    ) throws -> CIImage {
        guard shouldApply else {
            return image
        }
        guard let unsharpMaskFilter = CIFilter(name: "CIUnsharpMask") else {
            throw ImageUpscaleError.filterUnavailable(name: "CIUnsharpMask")
        }

        unsharpMaskFilter.setValue(image, forKey: kCIInputImageKey)
        unsharpMaskFilter.setValue(0.6, forKey: kCIInputRadiusKey)
        unsharpMaskFilter.setValue(0.35, forKey: kCIInputIntensityKey)

        return unsharpMaskFilter.outputImage ?? image
    }
}
