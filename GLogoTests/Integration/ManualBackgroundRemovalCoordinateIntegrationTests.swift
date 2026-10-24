// 手動除去の表示座標が、画像デコード・縮小編集・確定・PNG再読込を通して一致することを検証する。

import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import GLogo

final class ManualBackgroundRemovalCoordinateIntegrationTests: XCTestCase {
    @MainActor
    func testPNGAndJPEGPreviewCompletionAndReloadKeepErasedPosition() throws {
        for type in [UTType.png, .jpeg] {
            for orientation in [1, 3, 6, 8] {
                for usesProxy in [false, true] {
                    try verifyEditingFlow(type: type, orientation: orientation, usesProxy: usesProxy)
                }
            }
        }
    }

    @MainActor
    func testHEICPreviewCompletionAndReloadKeepErasedPosition() throws {
        for usesProxy in [false, true] {
            try verifyEditingFlow(type: .heic, orientation: 6, usesProxy: usesProxy)
        }
    }

    @MainActor
    private func verifyEditingFlow(type: UTType, orientation: Int, usesProxy: Bool) throws {
        let sourceData = try makeEncodedImage(type: type, orientation: orientation)
        let element = ImageElement(imageData: sourceData)
        let source = try XCTUnwrap(element.originalImage)
        var completedImage: UIImage?
        let viewModel = ManualBackgroundRemovalViewModel(
            imageElement: element,
            completion: { completedImage = $0 },
            imageSourceResolver: EditingResolutionResolver(usesProxy: usesProxy)
        )
        let label = "\(type.identifier), EXIF=\(orientation), proxy=\(usesProxy)"
        XCTAssertEqual(viewModel.originalImage.size != source.size, usesProxy, label)
        let editingSize = viewModel.originalImage.size
        let point = CGPoint(x: editingSize.width * 0.7, y: editingSize.height * 0.25)
        viewModel.setBrushSize(20)
        viewModel.applyBrushLine(from: point, to: CGPoint(x: point.x + 5, y: point.y + 10))
        let preview = try XCTUnwrap(viewModel.getMaskedImage())
        viewModel.complete()
        let result = try XCTUnwrap(completedImage)
        XCTAssertEqual(result.size, source.size, label)
        XCTAssertEqual(result.size.width * result.scale, source.size.width * source.scale, label)

        // エディタ確定と同じ PNG 差し替え経路を通し、通常の画像レンダラーも確認する。
        let reloadedElement = ImageElement(imageData: try XCTUnwrap(result.pngData()))
        let reloaded = try XCTUnwrap(reloadedElement.originalImage)
        let rendered = try XCTUnwrap(reloadedElement.getFilteredImageForce())
        for image in [preview, result, reloaded, rendered] {
            XCTAssertLessThan(try alpha(in: image, x: 0.7, y: 0.25), 0.05, label)
            XCTAssertGreaterThan(try alpha(in: image, x: 0.7, y: 0.75), 0.95, label)
            XCTAssertGreaterThan(try alpha(in: image, x: 0.3, y: 0.25), 0.95, label)
        }

        // 復元後はキャッシュされた消去プレビューを返さない。
        viewModel.toggleMode()
        viewModel.applyBrushStroke(at: point)
        XCTAssertGreaterThan(try alpha(in: XCTUnwrap(viewModel.getMaskedImage()), x: 0.7, y: 0.25), 0.95, label)
        viewModel.complete()
        XCTAssertGreaterThan(try alpha(in: XCTUnwrap(completedImage), x: 0.7, y: 0.25), 0.95, label)
    }

    private func makeEncodedImage(type: UTType, orientation: Int) throws -> Data {
        let size = CGSize(width: 320, height: 240)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 160, height: 120))
        }
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(image.cgImage), [
            kCGImagePropertyOrientation: orientation,
            kCGImageDestinationLossyCompressionQuality: 1.0
        ] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    /// UIKit の表示座標で1ピクセルだけ描画し、アルファを読む。
    private func alpha(in image: UIImage, x: CGFloat, y: CGFloat) throws -> CGFloat {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        let pixel = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1), format: format).image { _ in
            image.draw(in: CGRect(x: -image.size.width * x, y: -image.size.height * y,
                                  width: image.size.width, height: image.size.height))
        }
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8,
                                             bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(try XCTUnwrap(pixel.cgImage), in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return CGFloat(bytes[3]) / 255
    }
}

/// 小さい画像でも実際のリポジトリの縮小経路を通すため、テスト時だけ解像度しきい値を下げる。
private struct EditingResolutionResolver: ImageSourceResolving {
    let usesProxy: Bool

    func resolveOriginalImage(imageData: Data?, fileName: String?, url: URL?, path: String?) -> UIImage? {
        ImageSourceResolver().resolveOriginalImage(imageData: imageData, fileName: fileName, url: url, path: path)
    }

    func resolveEditingImage(identifier: String?, fileName: String?, originalPath: String?,
                             originalImageProvider: () -> UIImage?, proxyTargetLongSide: CGFloat,
                             highResThresholdMP: CGFloat) -> UIImage? {
        guard usesProxy else { return originalImageProvider() }
        return ImageSourceResolver().resolveEditingImage(
            identifier: identifier, fileName: fileName, originalPath: originalPath,
            originalImageProvider: originalImageProvider,
            proxyTargetLongSide: 160, highResThresholdMP: 0
        )
    }
}
