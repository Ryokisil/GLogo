// 背景ぼかしの表示座標を、合成・確定・再読込・再編集まで検証する。
import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import GLogo

final class BackgroundBlurCoordinateIntegrationTests: XCTestCase {
    func test_blur_preservesDisplayCoordinates() throws {
        let orientations: [UIImage.Orientation] = [.up, .down, .left, .right, .upMirrored, .downMirrored, .leftMirrored, .rightMirrored]
        for orientation in orientations {
            for scale: CGFloat in [1, 2] {
                let image = UIImage(cgImage: try XCTUnwrap(stripes().cgImage), scale: scale, orientation: orientation)
                let brush = ManualBackgroundRemovalUseCase()
                let point = CGPoint(x: image.size.width * 0.7, y: image.size.height * 0.25)
                let mask = brush.drawBrush(on: brush.createInitialMask(for: image), at: point, size: 30, mode: .erase)
                let data = try XCTUnwrap(mask.pngData())
                let results = [
                    ImageFilterUtility.applyBackgroundBlur(to: image, maskData: data, radius: 6),
                    HDRImageFilterUtility.applyBackgroundBlur(to: image, maskData: data, radius: 6)
                ]
                for result in results {
                    let output = try XCTUnwrap(result)
                    let label = "orientation=\(orientation.rawValue), scale=\(scale)"
                    XCTAssertEqual(output.size, image.size, label)
                    XCTAssertEqual(output.scale, image.scale, label)
                    try assertBlurLocation(output, original: image, label: label)
                }
            }
        }
    }

    @MainActor
    func test_manualBlur_completionReloadAndReopen() throws {
        let encoded = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(encoded, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(stripes().cgImage), [kCGImagePropertyOrientation: 6] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        for proxy in [false, true] {
            let element = ImageElement(imageData: encoded as Data)
            let original = try XCTUnwrap(element.originalImage)
            let resolver = BlurEditingResolver(proxy: proxy)
            var outputMask: Data?
            let viewModel = BackgroundBlurMaskEditViewModel(imageElement: element, initialMaskData: nil,
                blurRadius: 6, completion: { outputMask = $0 }, imageSourceResolver: resolver)
            let size = viewModel.originalImage.size
            let point = CGPoint(x: size.width * 0.7, y: size.height * 0.25)
            viewModel.setBrushSize(30)
            viewModel.applyBrushStroke(at: point)
            try assertBlurLocation(XCTUnwrap(viewModel.getBackgroundBlurPreview()), original: viewModel.originalImage)
            viewModel.complete()
            element.backgroundBlurMaskData = try XCTUnwrap(outputMask)
            element.backgroundBlurRadius = 6
            // 保存対象の属性を Codable で往復し、通常レンダラーにも同じマスクを渡す。
            let reloaded = try JSONDecoder().decode(ImageElement.self, from: JSONEncoder().encode(element))
            let rendered = try XCTUnwrap(reloaded.getFilteredImageForce())
            try assertBlurLocation(rendered, original: original)
            let exported = try XCTUnwrap(UIImage(data: XCTUnwrap(rendered.pngData())))
            try assertBlurLocation(exported, original: original)
            reloaded.position = .zero
            reloaded.size = original.size
            reloaded.cornerRadius = 0
            let project = LogoProject(name: "blur-coordinate-save", canvasSize: original.size)
            project.elements = [reloaded]
            let composite = try XCTUnwrap(ImageProcessingService().makeCompositeImage(baseElement: reloaded, project: project))
            try assertBlurLocation(composite, original: original)
            let reopened = BackgroundBlurMaskEditViewModel(imageElement: reloaded,
                initialMaskData: reloaded.backgroundBlurMaskData, blurRadius: 6,
                completion: { _ in }, imageSourceResolver: resolver)
            XCTAssertEqual(try XCTUnwrap(reopened.state.maskImage).size, reopened.originalImage.size)
            reopened.setBrushSize(30)
            reopened.toggleMode()
            reopened.applyBrushStroke(at: point)
            let restored = try XCTUnwrap(reopened.getBackgroundBlurPreview())
            XCTAssertEqual(try sample(restored, x: 0.7, y: 0.25), try sample(reopened.originalImage, x: 0.7, y: 0.25), accuracy: 5)
        }
    }

    private func assertBlurLocation(_ image: UIImage, original: UIImage, label: String = "", file: StaticString = #filePath, line: UInt = #line) throws {
        let blurred = try sample(image, x: 0.7, y: 0.25)
        // 白黒縞の対象位置だけが灰色に均され、離れた場所は元の画素を維持する。
        XCTAssertGreaterThan(blurred, 30, label, file: file, line: line)
        XCTAssertLessThan(blurred, 230, label, file: file, line: line)
        for point in [CGPoint(x: 0.2, y: 0.75), CGPoint(x: 0.7, y: 0.75)] {
            XCTAssertEqual(try sample(image, x: point.x, y: point.y), try sample(original, x: point.x, y: point.y), accuracy: 5, label, file: file, line: line)
        }
    }

    private func stripes() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: CGSize(width: 160, height: 120), format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 160, height: 120))
            UIColor.black.setFill()
            for x in stride(from: 0, to: 160, by: 8) {
                ctx.fill(CGRect(x: x, y: 0, width: 4, height: 120))
            }
        }
    }

    private func sample(_ image: UIImage, x: CGFloat, y: CGFloat) throws -> Int {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        let pixel = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1), format: format).image { _ in
            image.draw(in: CGRect(x: -floor(image.size.width * x), y: -floor(image.size.height * y), width: image.size.width, height: image.size.height))
        }
        var bytes = [UInt8](repeating: 0, count: 4)
        let ctx = try XCTUnwrap(CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.draw(try XCTUnwrap(pixel.cgImage), in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return Int(bytes[0])
    }
}

private struct BlurEditingResolver: ImageSourceResolving {
    let proxy: Bool
    func resolveOriginalImage(imageData: Data?, fileName: String?, url: URL?, path: String?) -> UIImage? {
        ImageSourceResolver().resolveOriginalImage(imageData: imageData, fileName: fileName, url: url, path: path)
    }
    func resolveEditingImage(identifier: String?, fileName: String?, originalPath: String?, originalImageProvider: () -> UIImage?, proxyTargetLongSide: CGFloat, highResThresholdMP: CGFloat) -> UIImage? {
        guard proxy else { return originalImageProvider() }
        return ImageSourceResolver().resolveEditingImage(identifier: identifier, fileName: fileName, originalPath: originalPath, originalImageProvider: originalImageProvider, proxyTargetLongSide: 80, highResThresholdMP: 0)
    }
}
