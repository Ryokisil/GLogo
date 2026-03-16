//
//  UpscaleTileProcessor.swift
//  GLogo
//
//  概要:
//  このファイルは固定入力サイズの超解像モデル向けに、
//  画像をタイル分割して順次推論し、最終画像として合成する処理を定義します。
//  大きな画像でもメモリ負荷を抑えて Core ML 推論を実行するための基盤です。
//

import CoreImage
import Foundation
import UIKit

/// タイル単位の超解像合成処理
struct UpscaleTileProcessor {
    let tileSize: Int
    let modelScaleFactor: CGFloat
    let outputScaleFactor: CGFloat
    let renderer: (CGImage) throws -> CGImage

    private let context = CIContext()

    /// タイル分割して超解像を実行する
    /// - Parameters:
    ///   - image: 処理対象の元画像
    /// - Returns: 合成済みの高画質化画像
    func process(image: CGImage) throws -> CGImage {
        let sourceWidth = image.width
        let sourceHeight = image.height
        let outputWidth = Int((CGFloat(sourceWidth) * outputScaleFactor).rounded())
        let outputHeight = Int((CGFloat(sourceHeight) * outputScaleFactor).rounded())

        guard let outputContext = CGContext(
            data: nil,
            width: outputWidth,
            height: outputHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ImageUpscaleError.imageGenerationFailed
        }

        outputContext.interpolationQuality = .high

        for y in stride(from: 0, to: sourceHeight, by: tileSize) {
            for x in stride(from: 0, to: sourceWidth, by: tileSize) {
                let cropRect = CGRect(
                    x: x,
                    y: y,
                    width: min(tileSize, sourceWidth - x),
                    height: min(tileSize, sourceHeight - y)
                )

                let paddedTile = try makePaddedTile(from: image, cropRect: cropRect)
                let upscaledTile = try renderer(paddedTile)
                let effectiveOutputRect = makeOutputRect(
                    for: cropRect,
                    outputHeight: CGFloat(outputHeight)
                )

                let modelTileRect = makeModelTileRect(for: cropRect)

                guard let croppedUpscaledTile = upscaledTile.cropping(to: modelTileRect) else {
                    throw ImageUpscaleError.imageGenerationFailed
                }

                outputContext.draw(croppedUpscaledTile, in: effectiveOutputRect)
            }
        }

        guard let outputImage = outputContext.makeImage() else {
            throw ImageUpscaleError.imageGenerationFailed
        }
        return outputImage
    }

    /// 出力コンテキストへ描画する矩形を計算する
    /// - Parameters:
    ///   - cropRect: 元画像上の切り出し矩形
    ///   - outputHeight: 出力画像の高さ
    /// - Returns: Core Graphics の座標系に合わせた描画先矩形
    private func makeOutputRect(
        for cropRect: CGRect,
        outputHeight: CGFloat
    ) -> CGRect {
        let scaledHeight = CGFloat(cropRect.height) * outputScaleFactor
        let scaledY = outputHeight - (CGFloat(cropRect.maxY) * outputScaleFactor)

        return CGRect(
            x: CGFloat(cropRect.minX) * outputScaleFactor,
            y: scaledY,
            width: CGFloat(cropRect.width) * outputScaleFactor,
            height: scaledHeight
        ).integral
    }

    /// モデル出力から有効領域だけを切り出す矩形を返す
    /// - Parameters:
    ///   - cropRect: 元画像上の切り出し矩形
    /// - Returns: モデル出力座標系での有効領域
    private func makeModelTileRect(for cropRect: CGRect) -> CGRect {
        let verticalPadding = max(CGFloat(tileSize) - CGFloat(cropRect.height), 0)

        return CGRect(
            x: 0,
            y: verticalPadding * modelScaleFactor,
            width: CGFloat(cropRect.width) * modelScaleFactor,
            height: CGFloat(cropRect.height) * modelScaleFactor
        ).integral
    }

    /// 端をクランプしながら固定サイズタイルを生成する
    /// - Parameters:
    ///   - image: 元画像
    ///   - cropRect: 切り出し矩形
    /// - Returns: 固定サイズへ拡張されたタイル画像
    private func makePaddedTile(from image: CGImage, cropRect: CGRect) throws -> CGImage {
        guard let croppedTile = image.cropping(to: cropRect) else {
            throw ImageUpscaleError.imageGenerationFailed
        }

        let clampedImage = CIImage(cgImage: croppedTile)
            .clampedToExtent()
            .cropped(to: CGRect(x: 0, y: 0, width: tileSize, height: tileSize))

        guard let paddedTile = context.createCGImage(
            clampedImage,
            from: CGRect(x: 0, y: 0, width: tileSize, height: tileSize)
        ) else {
            throw ImageUpscaleError.imageGenerationFailed
        }

        return paddedTile
    }
}
