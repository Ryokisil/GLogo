// キャッシュの無効化範囲と再取得を、エディタの管理役（ImageRenderSessionStore）の操作から検証する。
// 第20回から、Model の差し替え・復元・初期値への戻しは値だけを変え、キャッシュの失効は呼び出し側（履歴イベントの範囲）が管理役で行う。
// 観察は、操作に使ったのと同じ管理役のインスタンスで行う。

import UIKit
import XCTest
@testable import GLogo

@MainActor
final class ImageElementCacheTests: XCTestCase {
    func test_renderInvalidation_keepsSourceAndPreview() {
        withFixture { element, source, preview, store in
            warmCaches(element, store)
            store.invalidate(.rendered, of: element)
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertTrue(store.originalImage(of: element) === source.original)
            XCTAssertTrue(store.instantPreview(of: element) === source.proxy)
            XCTAssertTrue(store.displayImage(of: element) === preview.rendered)
            XCTAssertEqual(source.originalCalls, 1)
            XCTAssertEqual(source.proxyCalls, 1)
            XCTAssertEqual(preview.baseCalls, 1)
            XCTAssertEqual(preview.renderCalls, 2)
            XCTAssertEqual(preview.resetCalls, 0)
        }
    }

    func test_editing_clearsOnlyRendered() {
        withFixture { element, source, preview, store in
            warmCaches(element, store)
            store.startEditing(element)
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertTrue(store.displayImage(of: element) === source.proxy)
            XCTAssertEqual(preview.renderCalls, 1)
            store.endEditing(element)
            XCTAssertTrue(store.displayImage(of: element) === preview.rendered)
            XCTAssertTrue(store.instantPreview(of: element) === source.proxy)
            XCTAssertEqual(source.originalCalls, 1)
            XCTAssertEqual(source.proxyCalls, 1)
            XCTAssertEqual(preview.baseCalls, 1)
            XCTAssertEqual(preview.resetCalls, 0)
        }
    }

    func test_renderedCacheHit_skipsSourceFetch() {
        withFixture { element, source, preview, store in
            warmCaches(element, store)
            // 表示画像と元画像のキャッシュを消してから、表示画像だけを入れ直す。
            store.invalidate(.revert, of: element)
            let marker = snapshotImage(.purple)
            store.storeRenderedImage(marker, of: element)
            // 表示画像のキャッシュを先に確かめ、あれば元画像を取得しない（評価の順序を固定する）。
            XCTAssertTrue(store.displayImage(of: element) === marker)
            XCTAssertEqual(source.originalCalls, 1)
            XCTAssertEqual(preview.renderCalls, 1)
        }
    }

    func test_editing_fetchesFallbackEagerly() {
        withFixture { element, source, preview, store in
            warmCaches(element, store)
            // 元画像のキャッシュだけを消し、プレビュー元画像とプロキシは残す。
            store.invalidate(.revert, of: element)
            store.startEditing(element)
            // 即時プレビューがあっても、フォールバック候補の元画像を先に取得する（今の評価の順序。短絡評価への変更は別に判断する）。
            XCTAssertTrue(store.displayImage(of: element) === source.proxy)
            XCTAssertEqual(source.originalCalls, 2)
            XCTAssertEqual(source.proxyCalls, 1)
            XCTAssertEqual(preview.baseCalls, 1)
        }
    }

    /// 調整値の初期化（Model）は値だけを戻す。`.adjustments` の失効で、表示画像とプレビュー元画像を作り直す（元画像・プロキシは残す）。
    func test_adjustmentReset_rebuildsPreviewBase() {
        withFixture { element, source, preview, store in
            element.saturationAdjustment = 0.3
            warmCaches(element, store)
            element.resetToOriginal()
            XCTAssertEqual(element.saturationAdjustment, 1)
            XCTAssertNotNil(store.cachedRenderedImage(of: element), "Model は値だけを戻し、キャッシュには触れない")

            store.invalidate(.adjustments, of: element)
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertTrue(store.instantPreview(of: element) === source.proxy)
            XCTAssertTrue(store.displayImage(of: element) === preview.rendered)
            XCTAssertEqual(source.originalCalls, 1)
            XCTAssertEqual(source.proxyCalls, 1)
            XCTAssertEqual(preview.baseCalls, 2)
            XCTAssertEqual(preview.resetCalls, 0)
        }
    }

    /// `.revert` は表示画像と元画像だけを消す。Revert のイベントが示す `.adjustments` と `.revert` を合わせると、
    /// プレビュー元画像も作り直すが、プロキシは残す。
    func test_revertInvalidation_keepsPreviewAndProxy() {
        withFixture { element, source, preview, store in
            warmCaches(element, store)
            store.invalidate(.revert, of: element)
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertTrue(store.instantPreview(of: element) === source.proxy)
            XCTAssertEqual(source.originalCalls, 1, "既存プレビューの利用だけでは元画像を再取得しない")
            XCTAssertTrue(store.originalImage(of: element) === source.original)
            XCTAssertEqual(source.originalCalls, 2)
            XCTAssertEqual(source.proxyCalls, 1)
            XCTAssertEqual(preview.baseCalls, 1)

            element.resetAdjustmentsToInitialState()
            store.invalidate(.adjustments, of: element)
            store.invalidate(.revert, of: element)
            XCTAssertTrue(store.instantPreview(of: element) === source.proxy)
            XCTAssertEqual(source.originalCalls, 3)
            XCTAssertEqual(source.proxyCalls, 1)
            XCTAssertEqual(preview.baseCalls, 2)
            XCTAssertEqual(preview.resetCalls, 0)
        }
    }

    /// 差し替え・復元（Model）は値だけを変える。ソースの変更の失効で、4つのキャッシュと共有の描画サービスのキャッシュを消す。
    func test_sourceReplacement_invalidatesAllCaches() {
        withFixture { element, source, preview, store in
            warmCaches(element, store)
            source.original = snapshotImage(.green)
            source.proxy = snapshotImage(.yellow)
            element.replaceImageSource(with: Data([1]), resetAdjustments: false)
            XCTAssertNotNil(store.cachedRenderedImage(of: element), "Model は値だけを変え、キャッシュには触れない")
            XCTAssertEqual(preview.resetCalls, 0)

            store.invalidateForSourceChange(of: element)
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertTrue(store.originalImage(of: element) === source.original)
            XCTAssertTrue(store.instantPreview(of: element) === source.proxy)
            XCTAssertEqual(source.originalCalls, 2)
            XCTAssertEqual(source.proxyCalls, 2)
            XCTAssertEqual(preview.baseCalls, 2)
            XCTAssertEqual(preview.resetCalls, 1)

            element.restoreImageSource(imageData: Data([2]), fileName: nil, url: nil, path: nil,
                                       originalIdentifier: "restored", hasAppliedUpscale: false)
            XCTAssertEqual(source.originalCalls, 2, "復元では元画像を取得しない（第23回）")
            store.invalidateForSourceChange(of: element)
            XCTAssertTrue(store.instantPreview(of: element) === source.proxy)
            XCTAssertEqual(source.originalCalls, 3)
            XCTAssertEqual(source.proxyCalls, 3)
            XCTAssertEqual(preview.baseCalls, 3)
            XCTAssertEqual(preview.resetCalls, 2)
        }
    }

    func test_memoryWarning_releasesElementCachesOnly() {
        withFixture { element, source, preview, store in
            warmCaches(element, store)
            store.invalidate(.all, of: element)
            XCTAssertNil(store.cachedRenderedImage(of: element))
            XCTAssertTrue(store.originalImage(of: element) === source.original)
            XCTAssertTrue(store.instantPreview(of: element) === source.proxy)
            XCTAssertTrue(store.displayImage(of: element) === preview.rendered)
            XCTAssertEqual(source.originalCalls, 2)
            XCTAssertEqual(source.proxyCalls, 2)
            XCTAssertEqual(preview.baseCalls, 2)
            XCTAssertEqual(preview.renderCalls, 2)
            XCTAssertEqual(preview.resetCalls, 0, "共有サービスの解放はEditor側で担当する")
        }
    }

    func test_copies_keepIndependentCaches() throws {
        try withFixture { element, source, preview, store in
            warmCaches(element, store)
            let copy = try XCTUnwrap(element.copy() as? ImageElement)
            // 保存用の複製は、保存の範囲が受付時に元画像を固定したものを使う。範囲を持ち続け、範囲から観察する。
            let project = LogoProject()
            project.addElement(element)
            let snapshot = SaveProjectSnapshot(project: project, renderSessions: store)
            let renderCopy = try XCTUnwrap(snapshot.project.elements.first as? ImageElement)
            XCTAssertNil(store.cachedRenderedImage(of: copy))
            warmCaches(copy, store)
            XCTAssertEqual(source.originalCalls, 2)
            XCTAssertEqual(source.proxyCalls, 2)
            XCTAssertEqual(preview.baseCalls, 2)
            // 保存用の複製の表示画像のキャッシュは空から始まる（描画用の画像を求めると、加工する）。
            let renders = preview.renderCalls
            XCTAssertNotNil(snapshot.drawingImage(of: renderCopy))
            XCTAssertEqual(preview.renderCalls, renders + 1)
            let pinned = source.original
            source.original = snapshotImage(.cyan)
            source.proxy = snapshotImage(.magenta)
            store.invalidate(.all, of: copy)
            XCTAssertTrue(store.originalImage(of: copy) === source.original)
            XCTAssertTrue(store.originalImage(of: element) === pinned)
            XCTAssertTrue(snapshot.originalImage(of: renderCopy) === pinned)
            XCTAssertTrue(store.cachedRenderedImage(of: element) === preview.rendered)
            XCTAssertEqual(source.originalCalls, 3)
        }
    }

    func test_cacheLifecycle_preservesEncodedState() throws {
        try withFixture { element, _, _, store in
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let before = try encoder.encode(element)
            let revision = element.editRevision
            warmCaches(element, store)
            XCTAssertEqual(try encoder.encode(element), before)
            store.invalidate(.all, of: element)
            XCTAssertEqual(try encoder.encode(element), before)
            XCTAssertEqual(element.editRevision, revision)
            let decoded = try JSONDecoder.live().decode(ImageElement.self, from: before)
            XCTAssertNil(store.cachedRenderedImage(of: decoded))
        }
    }

    private func warmCaches(_ element: ImageElement, _ store: ImageRenderSessionStore) {
        XCTAssertNotNil(store.originalImage(of: element))
        XCTAssertNotNil(store.instantPreview(of: element))
        XCTAssertNotNil(store.displayImage(of: element))
    }

    /// 要素ごとの依存を渡し、他のテストや要素へ影響を与えない。操作と観察には、同じ管理役を使う。
    private func withFixture(
        _ body: (ImageElement, CacheSourceSpy, CachePreviewSpy, ImageRenderSessionStore) throws -> Void
    ) rethrows {
        let preview = CachePreviewSpy()
        let source = CacheSourceSpy()
        let element = ImageElementFactory(sourceResolver: source, previewService: preview).makeElement(imageData: Data())
        try body(element, source, preview, ImageRenderSessionStore())
    }
}

/// 元画像とプロキシの再解決を別々に観測する。
/// テストのスレッドから同期にだけ呼ばれる前提で、観測値をロックなしで持つ（並行に使うテストには使わない）。
private final class CacheSourceSpy: ImageSourceResolving, @unchecked Sendable {
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
