// 要素・コピー・復元・インポート間で取得依存とキャッシュが混ざらないことを検証する。
// キャッシュは、テストごとに1つ作った管理役（同じインスタンス）で観察する。

import UIKit
import XCTest
@testable import GLogo

@MainActor
final class ImageSourceIsolationTests: XCTestCase {
    func test_originalImages_keepIndependentCaches() {
        let store = ImageRenderSessionStore()
        let red = SourceResolverSpy(image: snapshotImage(.red))
        let blue = SourceResolverSpy(image: snapshotImage(.blue))
        let first = ImageElementFactory(sourceResolver: red).makeElement(imageData: Data())
        let second = ImageElementFactory(sourceResolver: blue).makeElement(imageData: Data())
        XCTAssertTrue(store.originalImage(of: first) === red.image)
        XCTAssertTrue(store.originalImage(of: second) === blue.image)
        XCTAssertTrue(store.originalImage(of: first) === red.image)
        XCTAssertEqual(red.originalCalls, 1)
        XCTAssertEqual(blue.originalCalls, 1)
        store.invalidate(.all, of: first)
        XCTAssertTrue(store.originalImage(of: first) === red.image)
        XCTAssertTrue(store.originalImage(of: second) === blue.image)
        XCTAssertEqual(red.originalCalls, 2)
        XCTAssertEqual(blue.originalCalls, 1)
    }

    func test_proxyImages_useEachResolverAndCache() {
        let store = ImageRenderSessionStore()
        let firstResolver = SourceResolverSpy(image: snapshotImage(.red))
        let secondResolver = SourceResolverSpy(image: snapshotImage(.blue))
        let first = ImageElementFactory(sourceResolver: firstResolver).makeElement(imageData: Data())
        let second = ImageElementFactory(sourceResolver: secondResolver).makeElement(imageData: Data())
        first.originalImageIdentifier = "first-proxy"
        second.originalImageIdentifier = "second-proxy"
        XCTAssertNotNil(store.instantPreview(of: first))
        XCTAssertNotNil(store.instantPreview(of: second))
        XCTAssertNotNil(store.instantPreview(of: first))
        XCTAssertEqual(firstResolver.editingIdentifiers, ["first-proxy"])
        XCTAssertEqual(secondResolver.editingIdentifiers, ["second-proxy"])
        store.invalidate(.all, of: first)
        XCTAssertNotNil(store.instantPreview(of: first))
        XCTAssertNotNil(store.instantPreview(of: second))
        XCTAssertEqual(firstResolver.editingIdentifiers.count, 2)
        XCTAssertEqual(secondResolver.editingIdentifiers.count, 1)
    }

    func test_initializersAndCopies_keepResolver() throws {
        let store = ImageRenderSessionStore()
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
            XCTAssertTrue(store.originalImage(of: element) === resolver.image)
            let beforeCopy = resolver.originalCalls
            let copy = try XCTUnwrap(element.copy() as? ImageElement)
            XCTAssertNotEqual(copy.id, element.id)
            XCTAssertTrue(store.originalImage(of: copy) === resolver.image)
            XCTAssertEqual(resolver.originalCalls, beforeCopy + 1, "コピーは独自の元画像キャッシュを持つ")
            store.invalidate(.all, of: copy)
            XCTAssertTrue(store.originalImage(of: copy) === resolver.image)
            XCTAssertTrue(store.originalImage(of: element) === resolver.image)
            XCTAssertEqual(resolver.originalCalls, beforeCopy + 2)
        }
    }

    func test_restoreSource_usesResolverAndInvalidatesCache() {
        let store = ImageRenderSessionStore()
        let resolver = SourceResolverSpy(image: snapshotImage(.red))
        let element = ImageElementFactory(sourceResolver: resolver).makeElement(imageData: Data())
        XCTAssertTrue(store.originalImage(of: element) === resolver.image)
        resolver.image = snapshotImage(.blue)
        element.restoreImageSource(imageData: Data([1]), fileName: "ignored", url: nil,
                                   path: "/restored.png", originalIdentifier: "restored", hasAppliedUpscale: true)
        XCTAssertEqual(resolver.lastPath, "/restored.png")
        XCTAssertNil(resolver.lastData, "復元時もパスを優先し、下位ソースを残さない")
        XCTAssertEqual(resolver.originalCalls, 2, "サイズ復元はキャッシュを使わず取得する")
        // キャッシュの失効は、差し替えのイベントの巻き戻しの範囲（ソースの変更）で、履歴が管理役に求める。
        store.invalidateForSourceChange(of: element)
        XCTAssertTrue(store.originalImage(of: element) === resolver.image)
        XCTAssertEqual(resolver.originalCalls, 3, "復元後の初回取得で元画像キャッシュを更新する")
        XCTAssertEqual(element.originalImageIdentifier, "restored")
        XCTAssertTrue(element.hasAppliedUpscale)
        store.invalidate(.revert, of: element)
        XCTAssertTrue(store.originalImage(of: element) === resolver.image)
        XCTAssertEqual(resolver.originalCalls, 4)
    }

    /// 保存の範囲は、受付時に解決済みの元画像を複製へ固定する（第18回で、固定を renderCopy() から範囲へ移した）。
    @MainActor
    func test_saveSnapshot_pinsResolvedImage() throws {
        let store = ImageRenderSessionStore()
        let original = snapshotImage(.red)
        let resolver = SourceResolverSpy(image: original)
        let element = ImageElementFactory(sourceResolver: resolver).makeElement(imageData: Data())
        let project = LogoProject()
        project.addElement(element)
        let snapshot = SaveProjectSnapshot(project: project, renderSessions: store)
        let copy = try XCTUnwrap(snapshot.project.elements.first as? ImageElement)
        resolver.image = snapshotImage(.blue)
        store.invalidate(.all, of: element)
        XCTAssertTrue(store.originalImage(of: element) === resolver.image)
        let count = resolver.originalCalls
        XCTAssertTrue(snapshot.originalImage(of: copy) === original)
        XCTAssertEqual(resolver.originalCalls, count, "保存用コピーは固定済み画像を使う")
        XCTAssertEqual(copy.id, element.id)
    }

    func test_projectDecode_isolatesResolverWithoutChangingFormat() throws {
        let store = ImageRenderSessionStore()
        let project = LogoProject()
        project.addElement(ImageElementFactory().makeElement(imageData: snapshotImage(.green).pngData()!))
        let data = try JSONEncoder().encode(project)
        let firstResolver = SourceResolverSpy(image: snapshotImage(.red))
        let secondResolver = SourceResolverSpy(image: snapshotImage(.blue))
        let firstDecoder = JSONDecoder.live(sourceResolver: firstResolver)
        let secondDecoder = JSONDecoder.live(sourceResolver: secondResolver)
        let first = try firstDecoder.decode(LogoProject.self, from: data)
        let second = try secondDecoder.decode(LogoProject.self, from: data)
        XCTAssertTrue(store.originalImage(of: try XCTUnwrap(first.elements.first as? ImageElement)) === firstResolver.image)
        XCTAssertTrue(store.originalImage(of: try XCTUnwrap(second.elements.first as? ImageElement)) === secondResolver.image)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        XCTAssertEqual(try encoder.encode(first), try encoder.encode(second), "取得依存を保存形式に混ぜない")
        let normal = try JSONDecoder.live().decode(LogoProject.self, from: data)
        let normalImage = try XCTUnwrap(store.originalImage(of: try XCTUnwrap(normal.elements.first as? ImageElement)))
        XCTAssertFalse(normalImage === firstResolver.image)
        XCTAssertFalse(normalImage === secondResolver.image)
        XCTAssertEqual(firstResolver.originalCalls, 1)
        XCTAssertEqual(secondResolver.originalCalls, 1)
    }

    func test_importBuilder_propagatesResolver() throws {
        let store = ImageRenderSessionStore()
        for canvas in [nil, CGSize(width: 800, height: 600)] as [CGSize?] {
            let resolver = SourceResolverSpy(image: snapshotImage(.yellow))
            let coordinator = ImageImportCoordinator(useCase: ImageImportUseCase(
                elementBuilder: ImageImportElementBuilder(elementFactory: ImageElementFactory(sourceResolver: resolver))))
            let result = try XCTUnwrap(coordinator.importImage(
                source: .imageData(snapshotImage(.red).pngData()!), project: LogoProject(),
                viewportSize: CGSize(width: 320, height: 640), assetIdentifier: nil, canvasSize: canvas))
            XCTAssertTrue(store.originalImage(of: result.element) === resolver.image)
            XCTAssertEqual(result.element.originalImportOrder, 1)
            XCTAssertEqual(result.element.imageRole, .base)
        }
    }
}

/// 取得先と元画像キャッシュの利用回数を、単一テストの要素群で観測する。
/// テストのスレッドから同期にだけ呼ばれる前提で、観測値をロックなしで持つ（並行に使うテストには使わない）。
private final class SourceResolverSpy: ImageSourceResolving, @unchecked Sendable {
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
