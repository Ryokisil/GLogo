//
//  ManualBackgroundRemovalUseCase.swift
//  GLogo
//
//  概要:
//  手動背景除去の画像処理ロジックを提供するユースケース。
//

import UIKit

struct ManualBackgroundRemovalUseCase {
    /// 初期マスク作成（白=表示）
    func createInitialMask(for image: UIImage) -> UIImage {
        let size = image.size
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = image.scale

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// マスクにブラシストロークを描画
    func drawBrush(on mask: UIImage, at point: CGPoint, size: CGFloat, mode: RemovalMode) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(mask.size, false, mask.scale)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return mask }

        // 既存マスクを描画
        mask.draw(in: CGRect(origin: .zero, size: mask.size))

        // CGImageMask用の色設定（白=表示、黒=透明）
        let brushColor = mode == .erase ? UIColor.black : UIColor.white
        context.setFillColor(brushColor.cgColor)

        context.fillEllipse(in: CGRect(
            x: point.x - size / 2,
            y: point.y - size / 2,
            width: size,
            height: size
        ))

        return UIGraphicsGetImageFromCurrentImageContext() ?? mask
    }

    /// 2点間に線を描画してマスクを更新
    func drawLine(on mask: UIImage, from startPoint: CGPoint, to endPoint: CGPoint, size: CGFloat, mode: RemovalMode) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(mask.size, false, mask.scale)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return mask }

        mask.draw(in: CGRect(origin: .zero, size: mask.size))

        let brushColor = mode == .erase ? UIColor.black : UIColor.white
        context.setLineCap(.round)
        context.setLineWidth(size)
        context.setStrokeColor(brushColor.cgColor)

        context.beginPath()
        context.move(to: startPoint)
        context.addLine(to: endPoint)
        context.strokePath()

        return UIGraphicsGetImageFromCurrentImageContext() ?? mask
    }

    /// マスクを画像に適用
    /// - Parameters:
    ///   - mask: 前景マスク（白=表示、黒=透明）
    ///   - image: 背景除去対象の画像
    /// - Returns: 背景除去後の画像（生成に失敗した場合はnil）
    func applyMask(_ mask: UIImage, to image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage,
              let maskCIImage = CIImage(image: mask) else {
            return nil
        }

        let originalImage = CIImage(cgImage: cgImage)
        let targetExtent = originalImage.extent
        let scaleX = targetExtent.width / maskCIImage.extent.width
        let scaleY = targetExtent.height / maskCIImage.extent.height
        let scaledMask = maskCIImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        let alphaMask = scaledMask.applyingFilter("CIMaskToAlpha")

        guard let blendFilter = CIFilter(name: "CIBlendWithAlphaMask") else {
            return nil
        }
        blendFilter.setValue(originalImage, forKey: kCIInputImageKey)
        blendFilter.setValue(CIImage.empty(), forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(alphaMask, forKey: kCIInputMaskImageKey)

        guard let outputImage = blendFilter.outputImage else { return nil }
        let croppedOutput = outputImage.cropped(to: targetExtent)
        let context = CIContext()
        guard let resultCGImage = context.createCGImage(croppedOutput, from: croppedOutput.extent) else {
            return nil
        }

        return UIImage(cgImage: resultCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
