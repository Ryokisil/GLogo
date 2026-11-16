// 管理役（ImageRenderSessionStore）が、要素ごとのセッションの画像を返し、キャッシュと編集中の状態を、同じ管理役の操作で変えることを確かめる。
// 第21回で管理役がセッションを持つ形にしたため、別の管理役との独立・回収・管理役自身の解放もここで確かめる。
// Model の取得・キャッシュの API（第20回）と、画像を受け取らずに描く Model の入口（第21回）を外したため、Model の経路とは比べない。

import UIKit
import XCTest
@testable import GLogo

@MainActor
final class ImageRenderSessionStoreTests: XCTestCase {
    func test_images_returnSessionResults() {
        let fixture = Fixture()
        let element = fixture.element
        let store = ImageRenderSessionStore()

        let original = store.originalImage(of: element)
        XCTAssertTrue(original === fixture.source.original)
        XCTAssertTrue(store.originalImage(of: element) === original, "2回目は元画像のキャッシュを使う")
        XCTAssertEqual(fixture.source.originalCount, 1)

        let display = store.displayImage(of: element)
        XCTAssertTrue(display === fixture.preview.fullQuality)
        XCTAssertTrue(store.cachedRenderedImage(of: element) === display, "表示画像をキャッシュする")
        XCTAssertTrue(store.drawingImage(of: element) === display, "編集中でなければ、表示画像を描く")
        XCTAssertEqual(fixture.preview.counts.applyFull, 1, "フル品質の加工は1回")

        XCTAssertTrue(store.previewService(of: element) === element.previewService)
    }

    func test_editingState_followsStoreControls() {
        let fixture = Fixture()
        let element = fixture.element
        let store = ImageRenderSessionStore()

        store.startEditing(element)
        XCTAssertTrue(store.drawingImage(of: element) === fixture.preview.instant, "編集中は即時プレビューを描く")

        store.endEditing(element)
        XCTAssertTrue(store.drawingImage(of: element) === fixture.preview.fullQuality)
    }

    /// 管理役は要素を ID ではなくインスタンスで識別するため、同じ ID を持つ別の要素のキャッシュを取り違えない。
    /// 保存用の複製の独立は、保存の範囲を通したテスト（`SaveProjectSnapshotTests` の
    /// `test_snapshot_servesOnlyOwnCopies` と `test_snapshots_keepIndependentCaches`）で確かめる。
    func test_sameIDElements_keepSeparateCaches() {
        let element = Fixture().element
        let other = Fixture().element
        other.id = element.id
        let store = ImageRenderSessionStore()

        XCTAssertNotNil(store.displayImage(of: other))

        XCTAssertNotNil(store.cachedRenderedImage(of: other))
        XCTAssertNil(store.cachedRenderedImage(of: element), "同じ ID でも、インスタンスが違えばキャッシュを共有しない")
    }

    /// セッションは管理役が持つため、別の管理役とは、同じ要素でも取得・キャッシュ・編集中の状態を共有しない。
    func test_separateStores_keepSeparateState() {
        let fixture = Fixture()
        let element = fixture.element
        let first = ImageRenderSessionStore()
        let second = ImageRenderSessionStore()

        XCTAssertNotNil(first.displayImage(of: element))
        first.startEditing(element)

        XCTAssertNil(second.cachedRenderedImage(of: element), "表示画像のキャッシュは、もう一方に届かない")
        XCTAssertTrue(second.drawingImage(of: element) === fixture.preview.fullQuality, "編集中の状態も届かない")
        XCTAssertEqual(fixture.source.originalCount, 2, "元画像は、それぞれの管理役が取得する")
        XCTAssertTrue(first.drawingImage(of: element) === fixture.preview.instant)
    }

    /// 回収は、解放された要素のセッションだけを、キャッシュの画像ごと捨てる。生きている要素のキャッシュには触れない。
    /// 件数と有無の確認は、回収もセッションの生成もしない口で行う。
    func test_reclaim_dropsOnlyReleasedSessions() throws {
        let store = ImageRenderSessionStore()
        let alive = Fixture()
        weak var releasedElement: ImageElement?
        weak var releasedImage: UIImage?
        XCTAssertEqual(store.registeredSessionCount, 0)
        XCTAssertFalse(store.hasSession(for: alive.element))
        _ = store.previewService(of: alive.element)
        XCTAssertFalse(store.hasSession(for: alive.element), "描画サービスの引き当てでは、セッションを作らない")

        let aliveRendered = try XCTUnwrap(store.displayImage(of: alive.element))
        do {
            let released = ImageElement(
                source: .data(Data()), size: nil, sourceResolver: FreshImageSource(), previewService: CountingPreview()
            )
            releasedElement = released
            releasedImage = store.originalImage(of: released)
        }
        XCTAssertNil(releasedElement, "管理役は要素を弱く持つ")
        XCTAssertNotNil(releasedImage, "回収の前は、解放された要素のキャッシュも残る")
        XCTAssertEqual(store.registeredSessionCount, 2, "観察では回収しない")

        store.reclaimReleasedSessions()

        XCTAssertNil(releasedImage, "解放された要素のキャッシュの画像まで解放する")
        XCTAssertEqual(store.registeredSessionCount, 1)
        XCTAssertTrue(store.hasSession(for: alive.element))
        XCTAssertTrue(store.cachedRenderedImage(of: alive.element) === aliveRendered, "生きている要素のキャッシュは残す")
        XCTAssertEqual(alive.source.originalCount, 1)
    }

    /// 管理役が解放されると、要素が生きていても、管理役が持っていたセッションとキャッシュの画像は解放される。
    func test_storeRelease_releasesSessions() throws {
        let element = ImageElement(
            source: .data(Data()), size: nil, sourceResolver: FreshImageSource(), previewService: CountingPreview()
        )
        weak var store: ImageRenderSessionStore?
        weak var original: UIImage?
        do {
            let owned = ImageRenderSessionStore()
            store = owned
            original = owned.originalImage(of: element)
            XCTAssertNotNil(original)
        }

        XCTAssertNil(store)
        XCTAssertNil(original, "要素はキャッシュを持たない")
        XCTAssertNotNil(ImageRenderSessionStore().originalImage(of: element), "要素の依存は残り、別の管理役が取得し直せる")
    }
}

// MARK: - 偽物

/// 呼び出しを数える取得先と描画サービスを持つ画像要素。
@MainActor
private struct Fixture {
    let source = CountingSource()
    let preview = CountingPreview()
    let element: ImageElement

    init() {
        element = ImageElement(source: .data(Data()), size: nil, sourceResolver: source, previewService: preview)
        element.position = CGPoint(x: 10, y: 10)
        element.size = CGSize(width: 20, height: 20)
    }
}

/// 取得の回数を数え、元画像とプロキシに別の画像を返す取得先。
/// 回数を書き換えるため Sendable を検査付きで満たせないが、テストは MainActor の上でだけ使う。
private final class CountingSource: ImageSourceResolving, @unchecked Sendable {
    let original = snapshotImage(.red)
    let proxy = snapshotImage(.blue)
    private(set) var originalCount = 0
    private(set) var editingCount = 0

    func resolveOriginalImage(imageData: Data?, fileName: String?, url: URL?, path: String?) -> UIImage? {
        originalCount += 1
        return original
    }

    func resolveEditingImage(
        identifier: String?,
        fileName: String?,
        originalPath: String?,
        originalImageProvider: () -> UIImage?,
        proxyTargetLongSide: CGFloat,
        highResThresholdMP: CGFloat
    ) -> UIImage? {
        editingCount += 1
        return proxy
    }
}

/// 呼ぶたびに新しい元画像を返し、自分では持たない取得先。キャッシュの画像の解放を弱参照で確かめるのに使う。
private final class FreshImageSource: ImageSourceResolving, @unchecked Sendable {
    func resolveOriginalImage(imageData: Data?, fileName: String?, url: URL?, path: String?) -> UIImage? {
        snapshotImage(.red)
    }

    func resolveEditingImage(
        identifier: String?,
        fileName: String?,
        originalPath: String?,
        originalImageProvider: () -> UIImage?,
        proxyTargetLongSide: CGFloat,
        highResThresholdMP: CGFloat
    ) -> UIImage? {
        originalImageProvider()
    }
}

/// 呼び出しを種類ごとに数え、品質ごとに別の画像を返す描画サービス。
/// 回数を書き換えるため Sendable を検査付きで満たせないが、テストは MainActor の上でだけ使う。
private final class CountingPreview: ImagePreviewing, @unchecked Sendable {
    struct Counts: Equatable {
        var generatePreview = 0
        var instant = 0
        var applyFull = 0
        var applyPreview = 0
        var applyAsync = 0
        var resets = 0
    }

    let fullQuality = snapshotImage(.green)
    let previewQuality = snapshotImage(.yellow)
    let previewBase = snapshotImage(.cyan)
    let instant = snapshotImage(.magenta)
    private(set) var counts = Counts()

    func generatePreviewImage(editingImage: UIImage?, originalImage: UIImage?, mode: ImageRenderMode) -> UIImage? {
        counts.generatePreview += 1
        return previewBase
    }

    func instantPreview(
        baseImage: UIImage?,
        params: ImageFilterParams,
        quality: RenderQuality,
        mode: ImageRenderMode
    ) -> UIImage? {
        counts.instant += 1
        return instant
    }

    func applyFilters(to image: UIImage, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) -> UIImage? {
        if quality == .full {
            counts.applyFull += 1
            return fullQuality
        }
        counts.applyPreview += 1
        return previewQuality
    }

    func applyFiltersAsync(
        to image: UIImage,
        params: ImageFilterParams,
        quality: RenderQuality,
        mode: ImageRenderMode
    ) async -> UIImage? {
        counts.applyAsync += 1
        return quality == .full ? fullQuality : previewQuality
    }

    func resetCache() {
        counts.resets += 1
    }
}
