// キャンバスの描画（draw(in:)）と削除のエフェクト（renderSnapshot()）が、どの画像を描くかを、描かれた色で検証する。
// 取得先と描画サービスは、画像ごと・品質ごとに別の単色を返す偽物にし、取り違えを色の違いで見分ける。

import UIKit
import XCTest
@testable import GLogo

final class ImageElementDrawingTests: XCTestCase {
    func test_draw_notEditing_drawsFullQuality() throws {
        let element = makeElement(
            source: DrawingSourceStub(original: Colors.original, proxy: Colors.proxy),
            preview: DrawingPreviewStub(fullQuality: Colors.fullQuality, previewQuality: Colors.previewQuality,
                                        previewBase: Colors.previewBase, instant: Colors.instant)
        )

        try assertDrawn(element, color: .green, "編集中でなければ、フル品質で加工した画像を描く")
    }

    func test_draw_editing_drawsInstantPreview() throws {
        let element = makeElement(
            source: DrawingSourceStub(original: Colors.original, proxy: Colors.proxy),
            preview: DrawingPreviewStub(fullQuality: Colors.fullQuality, previewQuality: Colors.previewQuality,
                                        previewBase: Colors.previewBase, instant: Colors.instant)
        )
        element.startEditing()

        try assertDrawn(element, color: .magenta, "編集中は、即時プレビューを描く")
    }

    func test_draw_editingWithoutInstantPreview_drawsPreviewQuality() throws {
        let element = makeElement(
            source: DrawingSourceStub(original: Colors.original, proxy: Colors.proxy),
            preview: DrawingPreviewStub(fullQuality: Colors.fullQuality, previewQuality: Colors.previewQuality,
                                        previewBase: nil, instant: nil)
        )
        element.startEditing()

        try assertDrawn(element, color: .yellow, "即時プレビューがなければ、フォールバックの画像をプレビュー品質で加工して描く")
    }

    func test_draw_editingFallback_usesProxyOnly() throws {
        let element = makeElement(
            source: DrawingSourceStub(original: nil, proxy: Colors.proxy),
            preview: DrawingPreviewStub(fullQuality: Colors.fullQuality, previewQuality: nil,
                                        previewBase: nil, instant: nil)
        )
        element.startEditing()

        try assertDrawn(element, color: .blue, "元画像が取れず、プロキシだけが取れるときは、プロキシをそのまま描く")
    }

    func test_draw_editingFallback_usesOriginalOnly() throws {
        let element = makeElement(
            source: DrawingSourceStub(original: Colors.original, proxy: nil),
            preview: DrawingPreviewStub(fullQuality: Colors.fullQuality, previewQuality: nil,
                                        previewBase: nil, instant: nil)
        )
        element.startEditing()

        try assertDrawn(element, color: .red, "プロキシが取れず、元画像だけが取れるときは、元画像をそのまま描く")
    }

    func test_draw_nothingAvailable_drawsNothing() throws {
        for editing in [false, true] {
            let element = makeElement(
                source: DrawingSourceStub(original: nil, proxy: nil),
                preview: DrawingPreviewStub(fullQuality: Colors.fullQuality, previewQuality: Colors.previewQuality,
                                            previewBase: Colors.previewBase, instant: Colors.instant)
            )
            if editing { element.startEditing() }

            try assertDrawn(element, color: nil, "元画像もプロキシも取れなければ、何も描かない（編集中: \(editing)）")
        }
    }

    // MARK: - Helpers

    /// キャンバスと同じく位置をずらして置いた要素。キャンバスの中央に要素の中央が来る配置にする。
    private func makeElement(source: DrawingSourceStub, preview: DrawingPreviewStub) -> ImageElement {
        let element = ImageElement(source: .data(Data()), size: nil, sourceResolver: source, previewService: preview)
        element.position = CGPoint(x: 10, y: 10)
        element.size = CGSize(width: 20, height: 20)
        return element
    }

    /// draw(in:) と renderSnapshot() の両方で、要素の中央に描かれた色を確かめる。nil は「何も描かない」。
    private func assertDrawn(
        _ element: ImageElement,
        color expected: UIColor?,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let canvas = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40), format: format).image { context in
            element.draw(in: context.cgContext)
        }
        try assertColor(of: canvas, at: CGPoint(x: 20, y: 20), equals: expected, "draw(in:): \(message)", file: file, line: line)

        let snapshot = try XCTUnwrap(element.renderSnapshot(), file: file, line: line)
        try assertColor(of: snapshot, at: CGPoint(x: 10, y: 10), equals: expected, "renderSnapshot(): \(message)",
                        file: file, line: line)
    }

    private func assertColor(
        of image: UIImage,
        at point: CGPoint,
        equals expected: UIColor?,
        _ message: String,
        file: StaticString,
        line: UInt
    ) throws {
        let actual = try rgba(of: image, at: point)
        guard let expected else {
            XCTAssertEqual(actual[3], 0, "\(message)（色: \(actual)）", file: file, line: line)
            return
        }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        expected.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let expectedComponents = [red, green, blue, alpha].map { Int(($0 * 255).rounded()) }
        for (index, value) in actual.enumerated() {
            XCTAssertLessThanOrEqual(abs(Int(value) - expectedComponents[index]), 8,
                                     "\(message)（期待: \(expectedComponents)、実際: \(actual)）", file: file, line: line)
        }
    }

    /// 画像の指定位置（上からの座標）の RGBA 成分（0〜255）
    private func rgba(of image: UIImage, at point: CGPoint) throws -> [UInt8] {
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
        let offset = (Int(point.y) * width + Int(point.x)) * 4
        return Array(buffer[offset..<(offset + 4)])
    }
}

/// 画像と品質ごとの単色。どれも異なる色にし、描かれた色から取得・加工の経路を見分ける。
private enum Colors {
    static let original = snapshotImage(.red)
    static let proxy = snapshotImage(.blue)
    static let fullQuality = snapshotImage(.green)
    static let previewQuality = snapshotImage(.yellow)
    static let previewBase = snapshotImage(.cyan)
    static let instant = snapshotImage(.magenta)
}

/// 元画像とプロキシで、取得できる画像を別々に指定できる取得先。nil は「取得できない」。不変の値だけを持つ。
private struct DrawingSourceStub: ImageSourceResolving {
    let original: UIImage?
    let proxy: UIImage?

    func resolveOriginalImage(imageData: Data?, fileName: String?, url: URL?, path: String?) -> UIImage? {
        original
    }

    func resolveEditingImage(
        identifier: String?,
        fileName: String?,
        originalPath: String?,
        originalImageProvider: () -> UIImage?,
        proxyTargetLongSide: CGFloat,
        highResThresholdMP: CGFloat
    ) -> UIImage? {
        proxy
    }
}

/// 品質ごとに別の単色を返す描画サービス。nil は「生成できない」。不変の値だけを持つ。
private final class DrawingPreviewStub: ImagePreviewing {
    let fullQuality: UIImage?
    let previewQuality: UIImage?
    let previewBase: UIImage?
    let instant: UIImage?

    init(fullQuality: UIImage?, previewQuality: UIImage?, previewBase: UIImage?, instant: UIImage?) {
        self.fullQuality = fullQuality
        self.previewQuality = previewQuality
        self.previewBase = previewBase
        self.instant = instant
    }

    // 実際のサービスと同じく、元になる画像がなければプレビュー元画像も即時プレビューも作れない。
    func generatePreviewImage(editingImage: UIImage?, originalImage: UIImage?, mode: ImageRenderMode) -> UIImage? {
        (editingImage ?? originalImage) == nil ? nil : previewBase
    }

    func instantPreview(
        baseImage: UIImage?,
        params: ImageFilterParams,
        quality: RenderQuality,
        mode: ImageRenderMode
    ) -> UIImage? {
        baseImage == nil ? nil : instant
    }

    func applyFilters(to image: UIImage, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) -> UIImage? {
        quality == .full ? fullQuality : previewQuality
    }

    func applyFiltersAsync(
        to image: UIImage,
        params: ImageFilterParams,
        quality: RenderQuality,
        mode: ImageRenderMode
    ) async -> UIImage? {
        applyFilters(to: image, params: params, quality: quality, mode: mode)
    }

    func resetCache() {}
}
