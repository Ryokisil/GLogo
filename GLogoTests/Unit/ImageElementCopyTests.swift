// 画像要素の UI 用複製（copy()）が、ソースの種類ごとに引き継ぐ値と作り直す値を固定する。
// 複製機能は UI 未公開だが、LogoElement.copy() の上書きとして挙動を維持する対象。

import UIKit
import XCTest
@testable import GLogo

final class ImageElementCopyTests: XCTestCase {
    func test_copy_dataSource_dropsMetadata() throws {
        let data = try pngData(size: CGSize(width: 40, height: 20))
        let original = makeDataElement(data)
        var supplied = ImageMetadata()
        supplied.title = "複製に引き継がない"
        original.metadata = supplied
        decorate(original)

        let copy = try XCTUnwrap(original.copy() as? ImageElement)
        assertRecreatedIdentity(copy, from: original)
        assertCopiedAppearance(copy, from: original)
        XCTAssertEqual(copy.imageData, data)
        XCTAssertNil(copy.originalImageURL)
        XCTAssertNil(copy.originalImagePath)
        XCTAssertNil(copy.imageFileName)
        XCTAssertNil(copy.metadata, "Data ソースの複製はメタデータを持たない")
    }

    func test_copy_urlSource_reloadsDataAndMetadata() throws {
        let fileData = try pngData(size: CGSize(width: 40, height: 20))
        let url = try temporaryFile(data: fileData)
        let original = makeElement(url: url)
        // URL は Data より優先され、複製時にファイルから読み直す。
        original.imageData = Data([9, 9, 9])
        decorate(original)

        let copy = try XCTUnwrap(original.copy() as? ImageElement)
        assertRecreatedIdentity(copy, from: original)
        assertCopiedAppearance(copy, from: original)
        XCTAssertEqual(copy.originalImageURL, url)
        XCTAssertEqual(copy.imageData, fileData)
        XCTAssertNotNil(copy.metadata)
        XCTAssertNil(copy.originalImagePath)
        XCTAssertNil(copy.imageFileName)
    }

    func test_copy_unreadableURL_keepsReferenceOnly() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let original = makeElement(url: url)
        decorate(original)

        let copy = try XCTUnwrap(original.copy() as? ImageElement)
        assertRecreatedIdentity(copy, from: original)
        assertCopiedAppearance(copy, from: original)
        XCTAssertEqual(copy.originalImageURL, url)
        XCTAssertNil(copy.imageData)
        XCTAssertNil(copy.metadata)
    }

    @MainActor
    func test_copy_undecodableURL_keepsReadData() throws {
        let fileData = Data([0, 1, 2, 3])
        let url = try temporaryFile(data: fileData)
        let original = makeElement(url: url)

        let copy = try XCTUnwrap(original.copy() as? ImageElement)
        XCTAssertEqual(copy.originalImageURL, url)
        XCTAssertEqual(copy.imageData, fileData)
        // URL経由はUIImageのデコード失敗時も抽出し、現行の抽出器は空の値を返す。
        XCTAssertNotNil(copy.metadata)
        XCTAssertNil(ImageRenderSessionStore().originalImage(of: copy))
    }

    func test_copy_pathAndFileName_keepReferenceOnly() throws {
        let fileData = try pngData(size: CGSize(width: 40, height: 20))
        let url = try temporaryFile(data: fileData)
        let pathElement = makeElement(path: url.path)
        let namedElement = makeElement(fileName: url.path)
        for original in [pathElement, namedElement] {
            decorate(original)
            let copy = try XCTUnwrap(original.copy() as? ImageElement)
            assertRecreatedIdentity(copy, from: original)
            assertCopiedAppearance(copy, from: original)
            XCTAssertNil(copy.imageData)
            XCTAssertNil(copy.metadata)
            XCTAssertNil(copy.originalImageURL)
        }
        let pathCopy = try XCTUnwrap(pathElement.copy() as? ImageElement)
        XCTAssertEqual(pathCopy.originalImagePath, url.path)
        XCTAssertNil(pathCopy.imageFileName)
        let namedCopy = try XCTUnwrap(namedElement.copy() as? ImageElement)
        XCTAssertEqual(namedCopy.imageFileName, url.path)
        XCTAssertNil(namedCopy.originalImagePath)
    }

    func test_copy_withoutSource_usesEmptyFileName() throws {
        let original = makeDataElement(try pngData(size: CGSize(width: 40, height: 20)))
        original.restoreImageSource(imageData: nil, fileName: nil, url: nil, path: nil,
                                    originalIdentifier: "none", hasAppliedUpscale: false)
        decorate(original)

        let copy = try XCTUnwrap(original.copy() as? ImageElement)
        assertRecreatedIdentity(copy, from: original)
        assertCopiedAppearance(copy, from: original)
        // ソースのない複製元は、従来どおり空のアセット名を参照として持つ。
        XCTAssertEqual(copy.imageFileName, "")
        XCTAssertNil(copy.imageData)
        XCTAssertNil(copy.originalImageURL)
        XCTAssertNil(copy.originalImagePath)
    }

    // MARK: - 生成

    /// 1番目のインポート（ベース画像）として作る（複製が役割と順序を引き継がないことを見るため）。
    private func makeDataElement(_ data: Data) -> ImageElement {
        ImageElementFactory().makeElement(imageData: data, importOrder: 1)
    }

    // 保存データ由来のソースは Model の初期化で直接作る。
    private func makeElement(url: URL) -> ImageElement {
        makeElement(source: .url(url))
    }

    private func makeElement(path: String) -> ImageElement {
        makeElement(source: .path(path))
    }

    private func makeElement(fileName: String) -> ImageElement {
        makeElement(source: .fileName(fileName))
    }

    private func makeElement(source: ImageElement.ImageSource) -> ImageElement {
        ImageElement(source: source, size: nil, sourceResolver: ImageSourceResolver(), previewService: ImagePreviewService.shared)
    }

    // MARK: - 検証

    /// 複製で作り直す値を既定値から外しておく。
    private func decorate(_ element: ImageElement) {
        element.name = "Logo"
        element.zIndex = 999
        element.imageRole = .base
        element.originalImageIdentifier = "original-id"
        element.position = CGPoint(x: 12, y: 34)
        element.size = CGSize(width: 77, height: 33)
        element.rotation = 0.5
        element.opacity = 0.4
        element.brightnessAdjustment = 0.3
        element.showFrame = true
        element.hasAppliedUpscale = true
    }

    private func assertRecreatedIdentity(
        _ copy: ImageElement, from original: ImageElement,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertNotEqual(copy.id, original.id, file: file, line: line)
        XCTAssertEqual(copy.name, "\(original.name) Copy", file: file, line: line)
        XCTAssertEqual(copy.imageRole, .overlay, "役割は引き継がない", file: file, line: line)
        XCTAssertEqual(copy.zIndex, ElementPriority.image.rawValue, file: file, line: line)
        XCTAssertEqual(copy.originalImportOrder, 0, file: file, line: line)
        XCTAssertNotNil(copy.originalImageIdentifier, file: file, line: line)
        XCTAssertNotEqual(copy.originalImageIdentifier, original.originalImageIdentifier, file: file, line: line)
    }

    private func assertCopiedAppearance(
        _ copy: ImageElement, from original: ImageElement,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(copy.position, original.position, file: file, line: line)
        XCTAssertEqual(copy.size, original.size, "生成時のサイズ計算ではなく複製元の値", file: file, line: line)
        XCTAssertEqual(copy.rotation, original.rotation, file: file, line: line)
        XCTAssertEqual(copy.opacity, original.opacity, file: file, line: line)
        XCTAssertEqual(copy.brightnessAdjustment, original.brightnessAdjustment, file: file, line: line)
        XCTAssertEqual(copy.showFrame, original.showFrame, file: file, line: line)
        XCTAssertEqual(copy.hasAppliedUpscale, original.hasAppliedUpscale, file: file, line: line)
        // 取得先の引き継ぎは ImageSourceIsolationTests が確認する。
        XCTAssertTrue(copy.previewService === original.previewService, file: file, line: line)
    }

    private func pngData(size: CGSize) throws -> Data {
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
            .appendingPathComponent("copy-\(UUID().uuidString).png")
        try data.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
