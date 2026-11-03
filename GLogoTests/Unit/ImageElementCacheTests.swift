// キャッシュの無効化範囲と再取得を、ImageElementの公開操作から検証する。

import UIKit
import XCTest
@testable import GLogo

final class ImageElementCacheTests: XCTestCase {
    func test_renderInvalidation_keepsSourceAndPreview() {
        withFixture { element, source, preview in
            warmCaches(element)
            element.invalidateRenderedImageCache()
            XCTAssertNil(element.cachedImage)
            XCTAssertTrue(element.originalImage === source.original)
            XCTAssertTrue(element.getInstantPreview() === source.proxy)
            XCTAssertTrue(element.image === preview.rendered)
            XCTAssertEqual(source.originalCalls, 1)
            XCTAssertEqual(source.proxyCalls, 1)
            XCTAssertEqual(preview.baseCalls, 1)
            XCTAssertEqual(preview.renderCalls, 2)
            XCTAssertEqual(preview.resetCalls, 0)
        }
    }

    func test_editingAndRecord_clearOnlyRendered() {
        withFixture { element, source, preview in
            warmCaches(element)
            element.startEditing()
            XCTAssertNil(element.cachedImage)
            XCTAssertTrue(element.image === source.proxy)
            XCTAssertEqual(preview.renderCalls, 1)
            element.endEditing()
            XCTAssertTrue(element.image === preview.rendered)
            element.recordEdit(operation: ImageEditOperation(type: .adjustSaturation))
            XCTAssertNil(element.cachedImage)
            XCTAssertTrue(element.getInstantPreview() === source.proxy)
            XCTAssertEqual(source.originalCalls, 1)
            XCTAssertEqual(source.proxyCalls, 1)
            XCTAssertEqual(preview.baseCalls, 1)
            XCTAssertEqual(preview.resetCalls, 0)
        }
    }

    func test_adjustmentReset_rebuildsPreviewBase() {
        withFixture { element, source, preview in
            element.saturationAdjustment = 0.3
            warmCaches(element)
            element.resetToOriginal()
            XCTAssertNil(element.cachedImage)
            XCTAssertEqual(element.saturationAdjustment, 1)
            XCTAssertTrue(element.getInstantPreview() === source.proxy)
            XCTAssertTrue(element.image === preview.rendered)
            XCTAssertEqual(source.originalCalls, 1)
            XCTAssertEqual(source.proxyCalls, 1)
            XCTAssertEqual(preview.baseCalls, 2)
            XCTAssertEqual(preview.resetCalls, 0)
        }
    }

    func test_revertInvalidation_keepsPreviewAndProxy() {
        withFixture { element, source, preview in
            warmCaches(element)
            element.clearRevertImageCaches()
            XCTAssertNil(element.cachedImage)
            XCTAssertTrue(element.getInstantPreview() === source.proxy)
            XCTAssertEqual(source.originalCalls, 1, "既存プレビューの利用だけでは元画像を再取得しない")
            XCTAssertTrue(element.originalImage === source.original)
            XCTAssertEqual(source.originalCalls, 2)
            XCTAssertEqual(source.proxyCalls, 1)
            XCTAssertEqual(preview.baseCalls, 1)

            element.resetAdjustmentsToInitialState()
            XCTAssertTrue(element.getInstantPreview() === source.proxy)
            XCTAssertEqual(source.originalCalls, 3)
            XCTAssertEqual(source.proxyCalls, 1)
            XCTAssertEqual(preview.baseCalls, 2)
            XCTAssertEqual(preview.resetCalls, 0)
        }
    }

    func test_sourceReplacement_invalidatesAllCaches() {
        withFixture { element, source, preview in
            warmCaches(element)
            source.original = snapshotImage(.green)
            source.proxy = snapshotImage(.yellow)
            element.replaceImageSource(with: Data([1]), resetAdjustments: false)
            XCTAssertNil(element.cachedImage)
            XCTAssertTrue(element.originalImage === source.original)
            XCTAssertTrue(element.getInstantPreview() === source.proxy)
            XCTAssertEqual(source.originalCalls, 2)
            XCTAssertEqual(source.proxyCalls, 2)
            XCTAssertEqual(preview.baseCalls, 2)
            XCTAssertEqual(preview.resetCalls, 1)

            element.restoreImageSource(imageData: Data([2]), fileName: nil, url: nil, path: nil,
                                       originalIdentifier: "restored", hasAppliedUpscale: false)
            XCTAssertEqual(source.originalCalls, 3, "復元時のサイズ取得は元画像キャッシュとは独立")
            XCTAssertTrue(element.getInstantPreview() === source.proxy)
            XCTAssertEqual(source.originalCalls, 4)
            XCTAssertEqual(source.proxyCalls, 3)
            XCTAssertEqual(preview.baseCalls, 3)
            XCTAssertEqual(preview.resetCalls, 2)
        }
    }

    func test_memoryWarning_releasesElementCachesOnly() {
        withFixture { element, source, preview in
            warmCaches(element)
            element.handleMemoryWarning()
            XCTAssertNil(element.cachedImage)
            XCTAssertTrue(element.originalImage === source.original)
            XCTAssertTrue(element.getInstantPreview() === source.proxy)
            XCTAssertTrue(element.image === preview.rendered)
            XCTAssertEqual(source.originalCalls, 2)
            XCTAssertEqual(source.proxyCalls, 2)
            XCTAssertEqual(preview.baseCalls, 2)
            XCTAssertEqual(preview.renderCalls, 2)
            XCTAssertEqual(preview.resetCalls, 0, "共有サービスの解放はEditor側で担当する")
        }
    }

    func test_copies_keepIndependentCaches() throws {
        try withFixture { element, source, preview in
            warmCaches(element)
            let copy = try XCTUnwrap(element.copy() as? ImageElement)
            let renderCopy = element.renderCopy()
            XCTAssertNil(copy.cachedImage)
            XCTAssertNil(renderCopy.cachedImage)
            warmCaches(copy)
            XCTAssertEqual(source.originalCalls, 2)
            XCTAssertEqual(source.proxyCalls, 2)
            XCTAssertEqual(preview.baseCalls, 2)
            let pinned = source.original
            source.original = snapshotImage(.cyan)
            source.proxy = snapshotImage(.magenta)
            copy.handleMemoryWarning()
            XCTAssertTrue(copy.originalImage === source.original)
            XCTAssertTrue(element.originalImage === pinned)
            XCTAssertTrue(renderCopy.originalImage === pinned)
            XCTAssertTrue(element.cachedImage === preview.rendered)
            XCTAssertEqual(source.originalCalls, 3)
        }
    }

    func test_cacheLifecycle_preservesEncodedState() throws {
        try withFixture { element, _, _ in
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let before = try encoder.encode(element)
            let revision = element.editRevision
            warmCaches(element)
            XCTAssertEqual(try encoder.encode(element), before)
            element.handleMemoryWarning()
            XCTAssertEqual(try encoder.encode(element), before)
            XCTAssertEqual(element.editRevision, revision)
            let decoded = try JSONDecoder().decode(ImageElement.self, from: before)
            XCTAssertNil(decoded.cachedImage)
        }
    }

    private func warmCaches(_ element: ImageElement) {
        XCTAssertNotNil(element.originalImage)
        XCTAssertNotNil(element.getInstantPreview())
        XCTAssertNotNil(element.image)
    }

    /// 要素ごとの依存を渡し、他のテストや要素へ影響を与えない。
    private func withFixture(_ body: (ImageElement, CacheSourceSpy, CachePreviewSpy) throws -> Void) rethrows {
        let preview = CachePreviewSpy()
        let source = CacheSourceSpy()
        try body(ImageElement(imageData: Data(), sourceResolver: source, previewService: preview), source, preview)
    }
}

/// 元画像とプロキシの再解決を別々に観測する。
private final class CacheSourceSpy: ImageSourceResolving {
    var original = snapshotImage(.red)
    var proxy = snapshotImage(.blue)
    var originalCalls = 0
    var proxyCalls = 0

    func resolveOriginalImage(imageData: Data?, fileName: String?, url: URL?, path: String?) -> UIImage? {
        originalCalls += 1
        return original
    }

    func resolveEditingImage(identifier: String?, fileName: String?, originalPath: String?,
                             originalImageProvider: () -> UIImage?, proxyTargetLongSide: CGFloat,
                             highResThresholdMP: CGFloat) -> UIImage? {
        proxyCalls += 1
        return proxy
    }
}

/// 実際のフィルター計算をせず、ロックで保護した回数だけを観測する。
private final class CachePreviewSpy: ImagePreviewing, @unchecked Sendable {
    let rendered = snapshotImage(.orange)
    private let lock = NSLock()
    private var counts = (base: 0, render: 0, reset: 0)
    var baseCalls: Int { lock.withLock { counts.base } }
    var renderCalls: Int { lock.withLock { counts.render } }
    var resetCalls: Int { lock.withLock { counts.reset } }

    func generatePreviewImage(editingImage: UIImage?, originalImage: UIImage?, mode: ImageRenderMode) -> UIImage? {
        lock.withLock { counts.base += 1 }
        return editingImage ?? originalImage
    }

    func instantPreview(baseImage: UIImage?, params: ImageFilterParams,
                        quality: ToneCurveFilter.Quality, mode: ImageRenderMode) -> UIImage? {
        baseImage
    }

    func applyFilters(to image: UIImage, params: ImageFilterParams,
                      quality: ToneCurveFilter.Quality, mode: ImageRenderMode) -> UIImage? {
        lock.withLock { counts.render += 1 }
        return rendered
    }

    func applyFiltersAsync(to image: UIImage, params: ImageFilterParams,
                           quality: ToneCurveFilter.Quality, mode: ImageRenderMode) async -> UIImage? {
        applyFilters(to: image, params: params, quality: quality, mode: mode)
    }

    func resetCache() { lock.withLock { counts.reset += 1 } }
}
