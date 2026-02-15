//
//  HDRImageFilterUtility.swift
//  GLogo
//
//  概要:
//  Display P3色空間での画像変換・背景ぼかし・ティントオーバーレイを提供する。
//  色空間非依存のCIFilter操作（applyBasicColorAdjustment等）はImageFilterUtilityを
//  そのまま利用し、P3固有の変換のみをここで実装する。

import UIKit
import CoreImage

/// HDR（Display P3）用の画像フィルターユーティリティ
class HDRImageFilterUtility {

    // MARK: - Properties

    /// P3用共有CIContext
    private static let sharedContext: CIContext = RenderContext.hdr.ciContext

    /// P3色空間
    private static let p3ColorSpace: CGColorSpace = RenderContext.hdr.colorSpace

    // MARK: - UIImage変換

    /// CIImageをUIImageに変換（P3 CIContext使用）
    /// - Parameters:
    ///   - ciImage: 入力CIImage
    ///   - scale: 画像スケール
    ///   - orientation: 画像の向き
    /// - Returns: 変換後のUIImage
    static func convertToUIImage(_ ciImage: CIImage, scale: CGFloat, orientation: UIImage.Orientation) -> UIImage? {
        guard let cgImage = sharedContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: scale, orientation: orientation)
    }

    // MARK: - 背景ぼかし

    /// 背景ぼかし合成を適用（UIImage版・P3変換）
    /// - Parameters:
    ///   - image: 元画像
    ///   - maskData: 前景マスクのPNGデータ
    ///   - radius: ぼかし半径
    /// - Returns: 背景がぼかされた合成画像
    static func applyBackgroundBlur(to image: UIImage, maskData: Data, radius: CGFloat) -> UIImage? {
        guard let cgImage = image.cgImage,
              let maskUIImage = UIImage(data: maskData),
              let maskCGImage = maskUIImage.cgImage else {
            return image
        }

        let ciImage = CIImage(cgImage: cgImage)
        let maskCIImage = CIImage(cgImage: maskCGImage)

        // CIImageレベルのぼかし合成はImageFilterUtilityを再利用
        guard let resultCIImage = ImageFilterUtility.applyBackgroundBlur(to: ciImage, mask: maskCIImage, radius: radius) else {
            return image
        }

        // P3 CIContextでUIImageに変換
        return convertToUIImage(resultCIImage, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - ティントオーバーレイ

    /// ティントカラーオーバーレイを適用（広色域対応）
    /// - Parameters:
    ///   - image: 元画像
    ///   - color: ティントカラー
    ///   - intensity: ティント強度
    /// - Returns: ティント適用済み画像
    static func applyTintOverlay(to image: UIImage, color: UIColor, intensity: CGFloat) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.preferredRange = .extended  // 広色域レンダリング

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: image.size)
            image.draw(in: rect)

            color.withAlphaComponent(intensity).setFill()
            context.fill(rect, blendMode: .overlay)
        }
    }
}
