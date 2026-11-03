// 入力形式ごとの初期サイズ・ソース保持・メタデータ抽出条件を固定する。

import UIKit
import XCTest
@testable import GLogo

final class ImageElementInitializationTests: XCTestCase {
    func test_dynamicSize_preservesAspectAndMinimum() throws {
        let cases: [(CGSize, CGSize)] = [
            (CGSize(width: 40, height: 20), CGSize(width: 324, height: 162)),
            (CGSize(width: 20, height: 40), CGSize(width: 162, height: 324)),
            (CGSize(width: 20, height: 20), CGSize(width: 324, height: 324)),
            (CGSize(width: 400, height: 1), CGSize(width: 324, height: 1))
        ]
        for (input, expected) in cases {
            let data = try imageData(size: input)
            XCTAssertEqual(ImageElement(imageData: data).size, expected)
            XCTAssertEqual(ImageElement(imageData: data, metadata: nil).size, expected)
            XCTAssertEqual(ImageElement(imageData: data, isDynamicSizing: true).size, expected)
        }
    }

    func test_fixedAndCanvasSize_keepSeparateRules() throws {
        let data = try imageData(size: CGSize(width: 40, height: 20))
        XCTAssertEqual(ImageElement(imageData: data, isDynamicSizing: false).size,
                       CGSize(width: 40, height: 20))
        let custom = ImageElement(imageData: data, canvasSize: CGSize(width: 800, height: 600))
        XCTAssertEqual(custom.size, CGSize(width: 90, height: 45))
        let tiny = ImageElement(imageData: data, canvasSize: CGSize(width: 4, height: 2))
        XCTAssertEqual(tiny.size, CGSize(width: 1, height: 1))
        // 差し替え・履歴復元も生成時のキャンバスでサイズを決める。
        let portrait = try imageData(size: CGSize(width: 20, height: 40))
        custom.replaceImageSource(with: portrait, resetAdjustments: false)
        XCTAssertEqual(custom.size, CGSize(width: 45, height: 90))
        custom.restoreImageSource(imageData: data, fileName: nil, url: nil, path: nil,
                                  originalIdentifier: nil, hasAppliedUpscale: false)
        XCTAssertEqual(custom.size, CGSize(width: 90, height: 45))
    }

    func test_metadataExtraction_dependsOnInitializer() throws {
        let data = try imageData(size: CGSize(width: 40, height: 20))
        var supplied = ImageMetadata()
        supplied.title = "指定したメタデータ"
        supplied.additionalMetadata["fixture"] = "preserved"
        let explicit = ImageElement(imageData: data, metadata: supplied)
        XCTAssertEqual(explicit.metadata?.title, supplied.title)
        XCTAssertEqual(explicit.metadata?.additionalMetadata, supplied.additionalMetadata)
        XCTAssertNotNil(ImageElement(imageData: data, metadata: nil).metadata)
        XCTAssertNil(ImageElement(imageData: data).metadata)
        XCTAssertNil(ImageElement(imageData: data, isDynamicSizing: false).metadata)
        XCTAssertNil(ImageElement(imageData: data, canvasSize: CGSize(width: 800, height: 600)).metadata)
    }

    func test_fileSources_keepDistinctStoredReferences() throws {
        let data = try imageData(size: CGSize(width: 40, height: 20))
        let url = try temporaryFile(data: data)
        let pathElement = ImageElement(path: url.path)
        let urlElement = ImageElement(url: url)
        let namedElement = ImageElement(fileName: url.path)
        for element in [pathElement, urlElement, namedElement] {
            XCTAssertEqual(element.size, CGSize(width: 324, height: 162))
            XCTAssertNotNil(element.originalImage)
        }
        XCTAssertEqual(pathElement.originalImagePath, url.path)
        XCTAssertNil(pathElement.imageData)
        XCTAssertNil(pathElement.metadata)
        XCTAssertEqual(namedElement.imageFileName, url.path)
        XCTAssertNil(namedElement.imageData)
        XCTAssertNil(namedElement.metadata)
        XCTAssertEqual(urlElement.originalImageURL, url)
        XCTAssertEqual(urlElement.imageData, data)
        XCTAssertNotNil(urlElement.metadata)
        let copy = try XCTUnwrap(urlElement.copy() as? ImageElement)
        XCTAssertEqual(copy.size, urlElement.size)
        XCTAssertEqual(copy.originalImageURL, url)
        XCTAssertEqual(copy.imageData, data)
    }

    func test_invalidData_preservesDefaultSizeAndExplicitMetadata() {
        let data = Data([0, 1, 2, 3])
        var supplied = ImageMetadata()
        supplied.title = "デコード不能でも保持"
        let explicit = ImageElement(imageData: data, metadata: supplied)
        let elements = [explicit, ImageElement(imageData: data, metadata: nil),
                        ImageElement(imageData: data),
                        ImageElement(imageData: data, isDynamicSizing: false),
                        ImageElement(imageData: data, canvasSize: CGSize(width: 800, height: 600))]
        for element in elements {
            XCTAssertEqual(element.size, CGSize(width: 100, height: 100))
            XCTAssertEqual(element.imageData, data)
            XCTAssertNil(element.originalImage)
        }
        XCTAssertEqual(explicit.metadata?.title, supplied.title)
        XCTAssertNil(elements[1].metadata)
    }

    func test_unreadableFile_keepsReferenceWithoutData() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let urlElement = ImageElement(url: url)
        let pathElement = ImageElement(path: url.path)
        for element in [urlElement, pathElement, ImageElement(fileName: url.path)] {
            XCTAssertEqual(element.size, CGSize(width: 100, height: 100))
            XCTAssertNil(element.imageData)
            XCTAssertNil(element.metadata)
        }
        XCTAssertEqual(urlElement.originalImageURL, url)
        XCTAssertEqual(pathElement.originalImagePath, url.path)
    }

    func test_invalidFileURL_retainsReadData() throws {
        let data = Data([0, 1, 2, 3])
        let url = try temporaryFile(data: data)
        let element = ImageElement(url: url)
        XCTAssertEqual(element.originalImageURL, url)
        XCTAssertEqual(element.imageData, data)
        XCTAssertEqual(element.size, CGSize(width: 100, height: 100))
        // URL経由はUIImageのデコード失敗時も抽出し、現行の抽出器は空の値を返す。
        XCTAssertNotNil(element.metadata)
        XCTAssertNil(element.originalImage)
    }

    private func imageData(size: CGSize) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return try XCTUnwrap(image.pngData())
    }

    private func temporaryFile(data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("initialization-\(UUID().uuidString).png")
        try data.write(to: url)
        addTeardownBlock { try FileManager.default.removeItem(at: url) }
        return url
    }
}
