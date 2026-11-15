// 画像データからの生成で、配置サイズ・キャンバス・インポート順・メタデータの扱いを固定する。

import UIKit
import XCTest
@testable import GLogo

final class ImageElementFactoryTests: XCTestCase {
    func test_makeElement_preservesAspectAndMinimum() throws {
        let cases: [(CGSize, CGSize)] = [
            (CGSize(width: 40, height: 20), CGSize(width: 324, height: 162)),
            (CGSize(width: 20, height: 40), CGSize(width: 162, height: 324)),
            (CGSize(width: 20, height: 20), CGSize(width: 324, height: 324)),
            (CGSize(width: 400, height: 1), CGSize(width: 324, height: 1))
        ]
        for (input, expected) in cases {
            let data = try imageData(size: input)
            XCTAssertEqual(ImageElementFactory().makeElement(imageData: data).size, expected)
        }
    }

    func test_canvasSize_drivesLaterResizing() throws {
        let data = try imageData(size: CGSize(width: 40, height: 20))
        let custom = ImageElementFactory().makeElement(imageData: data, canvasSize: CGSize(width: 800, height: 600))
        XCTAssertEqual(custom.size, CGSize(width: 90, height: 45))
        let tiny = ImageElementFactory().makeElement(imageData: data, canvasSize: CGSize(width: 4, height: 2))
        XCTAssertEqual(tiny.size, CGSize(width: 1, height: 1))
        // 差し替え・履歴復元も生成時のキャンバスでサイズを決める。
        let portrait = try imageData(size: CGSize(width: 20, height: 40))
        custom.replaceImageSource(with: portrait, resetAdjustments: false)
        XCTAssertEqual(custom.size, CGSize(width: 45, height: 90))
        custom.restoreImageSource(imageData: data, fileName: nil, url: nil, path: nil,
                                  originalIdentifier: nil, hasAppliedUpscale: false)
        XCTAssertEqual(custom.size, CGSize(width: 90, height: 45))
    }

    func test_makeElement_doesNotExtractMetadata() throws {
        let data = try imageData(size: CGSize(width: 40, height: 20))
        XCTAssertNil(ImageElementFactory().makeElement(imageData: data).metadata)
        XCTAssertNil(ImageElementFactory().makeElement(
            imageData: data, canvasSize: CGSize(width: 800, height: 600)).metadata)
    }

    @MainActor
    func test_invalidData_keepsDataWithDefaultSize() {
        let store = ImageRenderSessionStore()
        let data = Data([0, 1, 2, 3])
        let elements = [ImageElementFactory().makeElement(imageData: data),
                        ImageElementFactory().makeElement(imageData: data, canvasSize: CGSize(width: 800, height: 600))]
        for element in elements {
            XCTAssertEqual(element.size, CGSize(width: 100, height: 100))
            XCTAssertEqual(element.imageData, data)
            XCTAssertNil(store.originalImage(of: element))
            XCTAssertNil(element.metadata)
        }
    }

    func test_importOrder_setsRoleAndIdentity() throws {
        let data = try imageData(size: CGSize(width: 40, height: 20))
        let first = ImageElementFactory().makeElement(imageData: data, importOrder: 1)
        let second = ImageElementFactory().makeElement(imageData: data, importOrder: 2)
        XCTAssertEqual(first.imageRole, .base, "1番目の画像はベース画像")
        XCTAssertEqual(second.imageRole, .overlay)
        XCTAssertEqual(first.originalImportOrder, 1)
        XCTAssertEqual(second.originalImportOrder, 2)
        for element in [first, second] {
            XCTAssertEqual(element.zIndex, ElementPriority.image.rawValue)
            XCTAssertEqual(element.name, "Image")
            XCTAssertNotNil(element.originalImageIdentifier)
            XCTAssertEqual(element.imageData, data)
            XCTAssertNil(element.originalImageURL)
            XCTAssertNil(element.originalImagePath)
            XCTAssertNil(element.imageFileName)
        }
        XCTAssertNotEqual(first.originalImageIdentifier, second.originalImageIdentifier)
    }

    func test_makeElement_usesInjectedLoader() {
        let loader = SizeLoaderStub(size: CGSize(width: 40, height: 20))
        let element = ImageElementFactory(loader: loader).makeElement(imageData: Data([1]))
        // デコードできない Data でも、境界から得た寸法で配置サイズを決める。
        XCTAssertEqual(element.size, CGSize(width: 324, height: 162))
        XCTAssertEqual(loader.receivedData, [Data([1])])
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
}

/// 読み取った Data を記録し、固定の寸法を返す読み込みスタブ。
private final class SizeLoaderStub: ImageInitializationLoading {
    let size: CGSize
    private(set) var receivedData: [Data] = []

    init(size: CGSize) {
        self.size = size
    }

    func imageSize(imageData: Data) -> CGSize? {
        receivedData.append(imageData)
        return size
    }
}
