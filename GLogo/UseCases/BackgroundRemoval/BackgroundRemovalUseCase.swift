//
//  BackgroundRemovalUseCase.swift
//  GLogo
//
//  概要:
//  VisionとCore Imageを用いた背景除去処理を提供するユースケース。
//

import CoreImage
import UIKit
import Vision

struct BackgroundRemovalUseCase {
    /// Vision フレームワークを使用した背景除去処理（解像度保持版）
    /// - Parameters:
    ///   - image: 背景除去対象の画像
    /// - Returns: 背景除去後の画像
    func removeBackground(from image: UIImage) async throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw NSError(
                domain: "ImageCropError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "CGImageの作成に失敗"]
            )
        }

        let request = VNGenerateForegroundInstanceMaskRequest()

        return try await withCheckedThrowingContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: cgImage)

            do {
                try handler.perform([request])

                guard let result = request.results?.first else {
                    continuation.resume(throwing: NSError(
                        domain: "VisionError",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "前景マスクの生成に失敗"]
                    ))
                    return
                }

                // AI分析結果から低解像度マスクを取得（精度はそのまま保持）
                let lowResMask = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
                let lowResMaskImage = CIImage(cvPixelBuffer: lowResMask)

                // 元画像の実解像度を取得
                let originalSize = image.size
                let originalScale = image.scale
                let pixelSize = CGSize(
                    width: originalSize.width * originalScale,
                    height: originalSize.height * originalScale
                )

                // 低解像度マスクを元画像解像度にアップスケール
                let highResMaskImage = upscaleMask(lowResMaskImage, to: pixelSize)

                // 浸透効果用のソフトマスクを高解像度マスクから作成
                let featheredMask = createFeatheredMask(from: highResMaskImage)

                // 元画像のCIImage（フル解像度）
                let originalCIImage = CIImage(cgImage: cgImage)

                guard let filter = CIFilter(name: "CIBlendWithMask") else {
                    continuation.resume(throwing: NSError(
                        domain: "CoreImageError",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "CIBlendWithMaskフィルターが利用不可"]
                    ))
                    return
                }

                // フィルター設定（高解像度フェザーマスクを使用）
                filter.setValue(originalCIImage, forKey: kCIInputImageKey)
                filter.setValue(featheredMask, forKey: kCIInputMaskImageKey)
                filter.setValue(CIImage.empty(), forKey: kCIInputBackgroundImageKey)

                guard let outputImage = filter.outputImage else {
                    continuation.resume(throwing: NSError(
                        domain: "CoreImageError",
                        code: 4,
                        userInfo: [NSLocalizedDescriptionKey: "フィルター処理に失敗"]
                    ))
                    return
                }

                // CIImage → UIImage変換（フル解像度）
                let context = CIContext()
                guard let resultCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
                    continuation.resume(throwing: NSError(
                        domain: "CoreImageError",
                        code: 5,
                        userInfo: [NSLocalizedDescriptionKey: "最終画像の生成に失敗"]
                    ))
                    return
                }

                // 元画像のスケールを保持して最終UIImageを作成
                let resultImage = UIImage(cgImage: resultCGImage, scale: originalScale, orientation: image.imageOrientation)
                continuation.resume(returning: resultImage)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Vision フレームワークで前景マスクを生成
    /// - Parameters:
    ///   - image: マスク生成対象の画像
    /// - Returns: 前景マスク画像（白=前景、黒=背景）
    func generateMask(from image: UIImage) async throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw NSError(
                domain: "ImageCropError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "CGImageの作成に失敗"]
            )
        }

        let request = VNGenerateForegroundInstanceMaskRequest()

        return try await withCheckedThrowingContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: cgImage)

            do {
                try handler.perform([request])

                guard let result = request.results?.first else {
                    continuation.resume(throwing: NSError(
                        domain: "VisionError",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "前景マスクの生成に失敗"]
                    ))
                    return
                }

                let lowResMask = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
                let lowResMaskImage = CIImage(cvPixelBuffer: lowResMask)

                let originalSize = image.size
                let originalScale = image.scale
                let pixelSize = CGSize(
                    width: originalSize.width * originalScale,
                    height: originalSize.height * originalScale
                )

                let highResMaskImage = upscaleMask(lowResMaskImage, to: pixelSize)
                let featheredMask = createFeatheredMask(from: highResMaskImage)
                    .cropped(to: CGRect(origin: .zero, size: pixelSize))

                let context = CIContext()
                guard let resultCGImage = context.createCGImage(featheredMask, from: featheredMask.extent) else {
                    continuation.resume(throwing: NSError(
                        domain: "CoreImageError",
                        code: 5,
                        userInfo: [NSLocalizedDescriptionKey: "マスク画像の生成に失敗"]
                    ))
                    return
                }

                let maskImage = UIImage(
                    cgImage: resultCGImage,
                    scale: originalScale,
                    orientation: image.imageOrientation
                )
                continuation.resume(returning: maskImage)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// AI生成マスクを高解像度にアップスケール（キャラクター検出精度を保持）
    /// - Parameters:
    ///   - lowResMask: 低解像度マスク画像
    ///   - targetSize: アップスケール先のピクセルサイズ
    /// - Returns: アップスケール後のマスク画像
    private func upscaleMask(_ lowResMask: CIImage, to targetSize: CGSize) -> CIImage {
        let currentExtent = lowResMask.extent
        let currentSize = currentExtent.size

        let scaleX = targetSize.width / currentSize.width
        let scaleY = targetSize.height / currentSize.height

        guard let scaleFilter = CIFilter(name: "CILanczosScaleTransform") else {
            print("WARNING: CILanczosScaleTransform が利用不可 - バイリニア補間を使用")
            return lowResMask.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        }

        scaleFilter.setValue(lowResMask, forKey: kCIInputImageKey)
        scaleFilter.setValue(scaleX, forKey: kCIInputScaleKey)
        scaleFilter.setValue(1.0, forKey: kCIInputAspectRatioKey)

        guard let scaledMask = scaleFilter.outputImage else {
            print("WARNING: Lanczosスケーリングに失敗 - アフィン変換を使用")
            return lowResMask.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        }

        if abs(scaleX - scaleY) > 0.01 {
            let additionalScaleY = scaleY / scaleX
            return scaledMask.transformed(by: CGAffineTransform(scaleX: 1.0, y: additionalScaleY))
        }

        return scaledMask
    }

    /// AIマスクに浸透効果を適用（高精度を保持しつつエッジを柔らかく）
    /// - Parameters:
    ///   - originalMask: 元のマスク画像
    /// - Returns: ぼかし・ガンマ調整後のマスク画像
    private func createFeatheredMask(from originalMask: CIImage) -> CIImage {
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else {
            print("WARNING: CIGaussianBlur が利用できません - 元のマスクを使用")
            return originalMask
        }

        let maskSize = originalMask.extent.size
        let baseRadius: CGFloat = 6.0
        let scaleFactor = max(maskSize.width, maskSize.height) / 1024.0
        _ = baseRadius * max(1.0, scaleFactor)

        blurFilter.setValue(originalMask, forKey: kCIInputImageKey)
        blurFilter.setValue(6.0, forKey: kCIInputRadiusKey)
        // blurFilter.setValue(adjustedRadius, forKey: kCIInputRadiusKey)

        guard let blurredMask = blurFilter.outputImage else {
            print("WARNING: ブラー処理に失敗 - 元のマスクを使用")
            return originalMask
        }

        guard let gammaFilter = CIFilter(name: "CIGammaAdjust") else {
            return blurredMask
        }

        gammaFilter.setValue(blurredMask, forKey: kCIInputImageKey)
        gammaFilter.setValue(0.8, forKey: "inputPower")

        return gammaFilter.outputImage ?? blurredMask
    }
}
