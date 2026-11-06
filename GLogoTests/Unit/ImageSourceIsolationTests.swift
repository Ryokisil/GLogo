// 要素・コピー・復元・インポート間で取得依存とキャッシュが混ざらないことを検証する。

import UIKit
import XCTest
@testable import GLogo

final class ImageSourceIsolationTests: XCTestCase {
    func test_originalImages_keepIndependentCaches() {
        let red = SourceResolverSpy(image: snapshotImage(.red))
        let blue = SourceResolverSpy(image: snapshotImage(.blue))
        let first = ImageElementFactory(sourceResolver: red).makeElement(imageData: Data())
        let second = ImageElementFactory(sourceResolver: blue).makeElement(imageData: Data())
        XCTAssertTrue(first.originalImage === red.image)
        XCTAssertTrue(second.originalImage === blue.image)
        XCTAssertTrue(first.originalImage === red.image)
        XCTAssertEqual(red.originalCalls, 1)
        XCTAssertEqual(blue.originalCalls, 1)
        first.handleMemoryWarning()
        XCTAssertTrue(first.originalImage === red.image)
        XCTAssertTrue(second.originalImage === blue.image)
        XCTAssertEqual(red.originalCalls, 2)
        XCTAssertEqual(blue.originalCalls, 1)
    }

    func test_proxyImages_useEachResolverAndCache() {
        let firstResolver = SourceResolverSpy(image: snapshotImage(.red))
        let secondResolver = SourceResolverSpy(image: snapshotImage(.blue))
        let first = ImageElementFactory(sourceResolver: firstResolver).makeElement(imageData: Data())
        let second = ImageElementFactory(sourceResolver: secondResolver).makeElement(imageData: Data())
        first.originalImageIdentifier = "first-proxy"
        second.originalImageIdentifier = "second-proxy"
        XCTAssertNotNil(first.getInstantPreview())
        XCTAssertNotNil(second.getInstantPreview())
        XCTAssertNotNil(first.getInstantPreview())
        XCTAssertEqual(firstResolver.editingIdentifiers, ["first-proxy"])
        XCTAssertEqual(secondResolver.editingIdentifiers, ["second-proxy"])
        first.handleMemoryWarning()
        XCTAssertNotNil(first.getInstantPreview())
        XCTAssertNotNil(second.getInstantPreview())
        XCTAssertEqual(firstResolver.editingIdentifiers.count, 2)
        XCTAssertEqual(secondResolver.editingIdentifiers.count, 1)
    }

    func test_initializersAndCopies_keepResolver() throws {
        let resolver = SourceResolverSpy(image: snapshotImage(.orange))
        let missingPath = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        let factory = ImageElementFactory(sourceResolver: resolver)
        // 保存データ由来のソースは Model の初期化で直接作り、複製の各分岐も通す。
        let legacySources: [ImageElement.ImageSource] = [
            .fileName(""), .path(missingPath), .url(URL(fileURLWithPath: missingPath))
        ]
        let elements = [
            factory.makeElement(imageData: Data()),
            factory.makeElement(imageData: Data(), canvasSize: CGSize(width: 80, height: 80))
        ] + legacySources.map {
            ImageElement(source: $0, size: nil, sourceResolver: resolver, previewService: ImagePreviewService.shared)
        }
        for element in elements {
            XCTAssertTrue(element.originalImage === resolver.image)
            let beforeCopy = resolver.originalCalls
            let copy = try XCTUnwrap(element.copy() as? ImageElement)
            XCTAssertNotEqual(copy.id, element.id)
            XCTAssertTrue(copy.originalImage === resolver.image)
            XCTAssertEqual(resolver.originalCalls, beforeCopy + 1, "コピーは独自の元画像キャッシュを持つ")
            copy.handleMemoryWarning()
            XCTAssertTrue(copy.originalImage === resolver.image)
            XCTAssertTrue(element.originalImage === resolver.image)
            XCTAssertEqual(resolver.originalCalls, beforeCopy + 2)
        }
    }

    func test_restoreSource_usesResolverAndInvalidatesCache() {
        let resolver = SourceResolverSpy(image: snapshotImage(.red))
        let element = ImageElementFactory(sourceResolver: resolver).makeElement(imageData: Data())
        XCTAssertTrue(element.originalImage === resolver.image)
        resolver.image = snapshotImage(.blue)
        element.restoreImageSource(imageData: Data([1]), fileName: "ignored", url: nil,
                                   path: "/restored.png", originalIdentifier: "restored", hasAppliedUpscale: true)
        XCTAssertEqual(resolver.lastPath, "/restored.png")
        XCTAssertNil(resolver.lastData, "復元時もパスを優先し、下位ソースを残さない")
        XCTAssertEqual(resolver.originalCalls, 2, "サイズ復元はキャッシュを使わず取得する")
        XCTAssertTrue(element.originalImage === resolver.image)
        XCTAssertEqual(resolver.originalCalls, 3, "復元後の初回取得で元画像キャッシュを更新する")
        XCTAssertEqual(element.originalImageIdentifier, "restored")
        XCTAssertTrue(element.hasAppliedUpscale)
        element.clearRevertImageCaches()
        XCTAssertTrue(element.originalImage === resolver.image)
        XCTAssertEqual(resolver.originalCalls, 4)
    }

    func test_renderCopy_pinsResolvedImage() {
        let original = snapshotImage(.red)
        let resolver = SourceResolverSpy(image: original)
        let element = ImageElementFactory(sourceResolver: resolver).makeElement(imageData: Data())
        let copy = element.renderCopy()
        resolver.image = snapshotImage(.blue)
        element.handleMemoryWarning()
        XCTAssertTrue(element.originalImage === resolver.image)
        let count = resolver.originalCalls
        XCTAssertTrue(copy.originalImage === original)
        XCTAssertEqual(resolver.originalCalls, count, "保存用コピーは固定済み画像を使う")
        XCTAssertEqual(copy.id, element.id)
    }

    func test_projectDecode_isolatesResolverWithoutChangingFormat() throws {
        let project = LogoProject()
        project.addElement(ImageElementFactory().makeElement(imageData: snapshotImage(.green).pngData()!))
        let data = try JSONEncoder().encode(project)
        let firstResolver = SourceResolverSpy(image: snapshotImage(.red))
        let secondResolver = SourceResolverSpy(image: snapshotImage(.blue))
        let firstDecoder = JSONDecoder()
        firstDecoder.userInfo[.imageSourceResolver] = firstResolver
        let secondDecoder = JSONDecoder()
        secondDecoder.userInfo[.imageSourceResolver] = secondResolver
        let first = try firstDecoder.decode(LogoProject.self, from: data)
        let second = try secondDecoder.decode(LogoProject.self, from: data)
        XCTAssertTrue((first.elements.first as? ImageElement)?.originalImage === firstResolver.image)
        XCTAssertTrue((second.elements.first as? ImageElement)?.originalImage === secondResolver.image)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        XCTAssertEqual(try encoder.encode(first), try encoder.encode(second), "取得依存を保存形式に混ぜない")
        let normal = try JSONDecoder().decode(LogoProject.self, from: data)
        let normalImage = try XCTUnwrap((normal.elements.first as? ImageElement)?.originalImage)
        XCTAssertFalse(normalImage === firstResolver.image)
        XCTAssertFalse(normalImage === secondResolver.image)
        XCTAssertEqual(firstResolver.originalCalls, 1)
        XCTAssertEqual(secondResolver.originalCalls, 1)
    }

    func test_importBuilder_propagatesResolver() throws {
        for canvas in [nil, CGSize(width: 800, height: 600)] as [CGSize?] {
            let resolver = SourceResolverSpy(image: snapshotImage(.yellow))
            let coordinator = ImageImportCoordinator(useCase: ImageImportUseCase(
                elementBuilder: ImageImportElementBuilder(elementFactory: ImageElementFactory(sourceResolver: resolver))))
            let result = try XCTUnwrap(coordinator.importImage(
                source: .imageData(snapshotImage(.red).pngData()!), project: LogoProject(),
                viewportSize: CGSize(width: 320, height: 640), assetIdentifier: nil, canvasSize: canvas))
            XCTAssertTrue(result.element.originalImage === resolver.image)
            XCTAssertEqual(result.element.originalImportOrder, 1)
            XCTAssertEqual(result.element.imageRole, .base)
        }
    }
}

/// 取得先と元画像キャッシュの利用回数を、単一テストの要素群で観測する。
private final class SourceResolverSpy: ImageSourceResolving {
    var image: UIImage
    private(set) var originalCalls = 0
    private(set) var editingIdentifiers: [String?] = []
    private(set) var lastPath: String?
    private(set) var lastData: Data?

    init(image: UIImage) { self.image = image }

    func resolveOriginalImage(imageData: Data?, fileName: String?, url: URL?, path: String?) -> UIImage? {
        originalCalls += 1
        lastPath = path
        lastData = imageData
        return image
    }

    func resolveEditingImage(identifier: String?, fileName: String?, originalPath: String?,
                             originalImageProvider: () -> UIImage?, proxyTargetLongSide: CGFloat,
                             highResThresholdMP: CGFloat) -> UIImage? {
        editingIdentifiers.append(identifier)
        XCTAssertEqual(proxyTargetLongSide, 1920)
        XCTAssertEqual(highResThresholdMP, 18)
        return originalImageProvider()
    }
}
