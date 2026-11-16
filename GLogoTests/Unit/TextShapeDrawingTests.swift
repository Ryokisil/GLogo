// キャンバスの描き方（drawOnCanvas）と保存の合成（ImageProcessingService）で、テキストと図形がそれぞれ画素として描かれることを確かめる。
// 描画の入口を、自分で描く要素だけが採用する形にしたとき（第21回）、採用漏れで描画だけが消えることを防ぐ。

import UIKit
import XCTest
@testable import GLogo

@MainActor
final class TextShapeDrawingTests: XCTestCase {
    private let canvasSize = CGSize(width: 100, height: 100)

    /// キャンバスの描き方で、テキストと図形が要素の枠の中に描かれる（背景は透明）。
    func test_canvas_drawsTextAndShape() throws {
        for (label, element) in makeElements() {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = false
            let canvas = UIGraphicsImageRenderer(size: canvasSize, format: format).image { context in
                element.drawOnCanvas(in: context.cgContext, renderSessions: ImageRenderSessionStore())
            }

            let inked = try countPixels(in: canvas, rect: element.frame) { $0[3] > 0 }
            XCTAssertGreaterThan(inked, 0, "\(label)：キャンバスに描かれる")
        }
    }

    /// 保存の合成（本番と同じく保存の範囲を通す）で、テキストと図形が白いベース画像の上に描かれる。
    func test_composite_drawsTextAndShape() throws {
        for (label, element) in makeElements() {
            let project = LogoProject(name: "Drawing", canvasSize: canvasSize)
            let base = ImageElementFactory().makeElement(imageData: try whitePNG(), importOrder: 0)
            base.position = .zero
            base.size = canvasSize
            base.imageRole = .base
            project.addElement(base)
            project.addElement(element)
            let snapshot = SaveProjectSnapshot(project: project, renderSessions: ImageRenderSessionStore())
            let snapshotBase = try XCTUnwrap(snapshot.project.elements.first { $0.id == base.id } as? ImageElement)

            let composite = try XCTUnwrap(ImageProcessingService().makeCompositeImage(
                baseElement: snapshotBase, project: snapshot.project, images: snapshot
            ), label)

            let inked = try countPixels(in: composite, rect: element.frame) { $0[0] < 128 || $0[1] < 128 || $0[2] < 128 }
            XCTAssertGreaterThan(inked, 0, "\(label)：保存の合成に描かれる")
        }
    }

    // MARK: - Helpers

    /// 枠の中を、黒の文字と赤の塗りで描く要素。
    private func makeElements() -> [(String, LogoElement)] {
        let text = TextElement(text: "W", fontName: "HelveticaNeue", fontSize: 40, textColor: .black)
        text.position = CGPoint(x: 20, y: 20)
        text.size = CGSize(width: 60, height: 50)
        let shape = ShapeElement(shapeType: .rectangle, fillColor: .red)
        shape.position = CGPoint(x: 20, y: 20)
        shape.size = CGSize(width: 40, height: 40)
        return [("テキスト", text), ("図形", shape)]
    }

    private func whitePNG() throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: canvasSize, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))
        }
        return try XCTUnwrap(image.pngData())
    }

    /// 画像の指定範囲（上からの座標）で、条件に合う画素（RGBA 成分 0〜255）を数える。
    private func countPixels(in image: UIImage, rect: CGRect, where matches: ([UInt8]) -> Bool) throws -> Int {
        let cgImage = try XCTUnwrap(image.cgImage)
        let width = cgImage.width
        let height = cgImage.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        let context = try XCTUnwrap(CGContext(
            data: &buffer, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo
        ))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let bounds = rect.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        var count = 0
        for y in Int(bounds.minY)..<Int(bounds.maxY) {
            for x in Int(bounds.minX)..<Int(bounds.maxX) {
                let offset = (y * width + x) * 4
                if matches(Array(buffer[offset..<(offset + 4)])) { count += 1 }
            }
        }
        return count
    }
}
