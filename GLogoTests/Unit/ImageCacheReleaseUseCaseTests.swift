// メモリ警告の解放（ImageCacheReleaseUseCase）が、プロジェクトの要素と、プロジェクトにない要素で消す範囲を固定する（第22回）。
// プロジェクトにない要素は、取り直して同じ画像に戻ると言える場合（データだけを持ち、元画像がキャッシュにある）だけ4種類とも消し、
// それ以外は表示画像とプレビュー元画像だけを消す。観察は、解放に渡したのと同じ管理役で、取得も生成もしない口で行う。

import UIKit
import XCTest
@testable import GLogo

@MainActor
final class ImageCacheReleaseUseCaseTests: XCTestCase {
    /// データだけを持ち、元画像がキャッシュにある、プロジェクトにない要素は、4種類とも消す。
    func test_detachedDataSource_releasesAll() throws {
        let store = ImageRenderSessionStore()
        let fixture = Fixture(.data(Data([1])))
        try warm(fixture, in: store)

        release(projectElements: [], store: store)

        assertCache(store, fixture, kept: [], "データの要素")
        XCTAssertTrue(store.hasSession(for: fixture.element), "要素が生きている間は、セッションは表に残る")
    }

    /// パス・ファイル URL・ファイル名（同梱の名前・絶対パス）を持つ要素は、元画像とプロキシを残し、表示画像とプレビュー元画像だけを消す。
    /// データも持つ要素（保存データの復元では両方のキーが入りうる）も同じ。取得先は、これらをデータより先に使うため。
    func test_detachedFileSources_keepSourceImages() throws {
        let path = "/nonexistent/\(UUID().uuidString).png"
        let references: [(String, (ImageElement) -> Void)] = [
            ("パス", { $0.originalImagePath = path }),
            ("ファイル URL", { $0.originalImageURL = URL(fileURLWithPath: path) }),
            ("同梱の名前", { $0.imageFileName = "Sample" }),
            ("絶対パスのファイル名", { $0.imageFileName = path }),
        ]
        for (reference, addReference) in references {
            for hasData in [false, true] {
                let label = "\(reference)・データ\(hasData ? "あり" : "なし")"
                let store = ImageRenderSessionStore()
                let fixture = Fixture(.data(Data([1])))
                if !hasData {
                    fixture.element.imageData = nil
                }
                addReference(fixture.element)
                try warm(fixture, in: store)

                release(projectElements: [], store: store)

                assertCache(store, fixture, kept: [.original, .proxy], label)
            }
        }
    }

    /// 元画像がキャッシュにない要素は、データを持っていても、プロキシを残す（外部のプロキシのファイルから読んだものかもしれないため）。
    func test_detachedWithoutOriginal_keepsProxy() throws {
        let store = ImageRenderSessionStore()
        let fixture = Fixture(.data(Data([1])), resolvesOriginal: false)
        XCTAssertNotNil(store.instantPreview(of: fixture.element), "プロキシからプレビュー元画像を作る")
        let cache = try XCTUnwrap(store.cachedImages(of: fixture.element))
        XCTAssertNil(cache.originalImage)
        XCTAssertNotNil(cache.proxyImage)

        release(projectElements: [], store: store)

        let released = try XCTUnwrap(store.cachedImages(of: fixture.element))
        XCTAssertTrue(released.proxyImage === fixture.source.proxy, "プロキシは残す")
        XCTAssertNil(released.previewBaseImage, "プレビュー元画像は消す")
    }

    /// プロジェクトにある要素は、ソースによらず4種類とも消す（第21回までと同じ。次の描画で取り直す）。
    func test_projectElements_releaseAll() throws {
        let store = ImageRenderSessionStore()
        let data = Fixture(.data(Data([1])))
        let file = Fixture(.path("/nonexistent/\(UUID().uuidString).png"))
        try warm(data, in: store)
        try warm(file, in: store)

        release(projectElements: [data.element, file.element], store: store)

        assertCache(store, data, kept: [], "プロジェクトのデータの要素")
        assertCache(store, file, kept: [], "プロジェクトのパスの要素")
    }

    /// プロジェクトの要素と同じ ID を持つ別のインスタンスも、プロジェクトにない要素として範囲を決める（ID で取り違えない）。
    func test_sameIDDetached_isReleased() throws {
        let store = ImageRenderSessionStore()
        let inProject = Fixture(.path("/nonexistent/\(UUID().uuidString).png"))
        let detached = Fixture(.path("/nonexistent/\(UUID().uuidString).png"))
        detached.element.id = inProject.element.id
        try warm(inProject, in: store)
        try warm(detached, in: store)

        release(projectElements: [inProject.element], store: store)

        assertCache(store, inProject, kept: [], "プロジェクトの要素")
        assertCache(store, detached, kept: [.original, .proxy], "同じ ID のプロジェクトにない要素")
    }

    /// プロジェクトにない要素の描画サービスも、既定やプロジェクトの要素と重複なく1回だけ解放する。
    func test_detachedServices_releaseOnce() throws {
        let store = ImageRenderSessionStore()
        let shared = CountingPreview()
        let separate = CountingPreview()
        let defaultService = CountingPreview()
        let inProject = Fixture(.data(Data([1])), preview: shared)
        let detachedShared = Fixture(.data(Data([1])), preview: shared)
        let detachedSeparate = Fixture(.data(Data([1])), preview: separate)
        for fixture in [inProject, detachedShared, detachedSeparate] {
            try warm(fixture, in: store)
        }

        ImageCacheReleaseUseCase.releaseCaches(in: [inProject.element], defaultService: defaultService, renderSessions: store)

        XCTAssertEqual(defaultService.releases, 1)
        XCTAssertEqual(shared.releases, 1, "プロジェクトの要素と共有するサービスは1回だけ")
        XCTAssertEqual(separate.releases, 1, "プロジェクトにない要素だけが使うサービスも解放する")
    }

    // MARK: - Helpers

    private enum CachedKind {
        case original, proxy, previewBase, rendered
    }

    /// 4種類（元画像・プロキシ・プレビュー元画像・表示画像）をキャッシュに載せ、載っていることを確かめる。
    private func warm(_ fixture: Fixture, in store: ImageRenderSessionStore) throws {
        XCTAssertNotNil(store.displayImage(of: fixture.element))
        XCTAssertNotNil(store.instantPreview(of: fixture.element))
        let cache = try XCTUnwrap(store.cachedImages(of: fixture.element))
        XCTAssertNotNil(cache.originalImage)
        XCTAssertNotNil(cache.proxyImage)
        XCTAssertNotNil(cache.previewBaseImage)
        XCTAssertNotNil(cache.renderedImage)
    }

    private func release(projectElements: [ImageElement], store: ImageRenderSessionStore) {
        ImageCacheReleaseUseCase.releaseCaches(in: projectElements, defaultService: CountingPreview(), renderSessions: store)
    }

    /// `kept` に挙げた種類だけが、解放の前と同じ画像のまま残っていることを確かめる。
    private func assertCache(
        _ store: ImageRenderSessionStore, _ fixture: Fixture, kept: Set<CachedKind>, _ label: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        guard let cache = store.cachedImages(of: fixture.element) else {
            return XCTFail("\(label)：セッションがない", file: file, line: line)
        }
        let expected: [(CachedKind, UIImage?, UIImage)] = [
            (.original, cache.originalImage, fixture.source.original),
            (.proxy, cache.proxyImage, fixture.source.proxy),
            (.previewBase, cache.previewBaseImage, fixture.preview.previewBase),
            (.rendered, cache.renderedImage, fixture.preview.rendered),
        ]
        for (kind, cached, warmed) in expected {
            if kept.contains(kind) {
                XCTAssertTrue(cached === warmed, "\(label)：\(kind) は残す", file: file, line: line)
            } else {
                XCTAssertNil(cached, "\(label)：\(kind) は消す", file: file, line: line)
            }
        }
    }
}

// MARK: - 偽物

/// 決まった画像を返す取得先と描画サービスを持つ画像要素。
@MainActor
private struct Fixture {
    let source: FixedSource
    let preview: CountingPreview
    let element: ImageElement

    init(_ imageSource: ImageElement.ImageSource, resolvesOriginal: Bool = true, preview: CountingPreview = CountingPreview()) {
        source = FixedSource(resolvesOriginal: resolvesOriginal)
        self.preview = preview
        element = ImageElement(
            source: imageSource, size: CGSize(width: 32, height: 24), sourceResolver: source, previewService: preview
        )
    }
}

/// 元画像とプロキシに、それぞれ決まった画像を返す取得先（ソースの種類は見ない）。元画像を返さない設定にもできる。
private final class FixedSource: ImageSourceResolving, @unchecked Sendable {
    let original = snapshotImage(.red)
    let proxy = snapshotImage(.blue)
    private let resolvesOriginal: Bool

    init(resolvesOriginal: Bool) {
        self.resolvesOriginal = resolvesOriginal
    }

    func resolveOriginalImage(imageData: Data?, fileName: String?, url: URL?, path: String?) -> UIImage? {
        resolvesOriginal ? original : nil
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

/// 決まった画像を返し、メモリ警告の解放の回数を数える描画サービス。テストは MainActor の上でだけ使う。
private final class CountingPreview: ImagePreviewing, @unchecked Sendable {
    let previewBase = snapshotImage(.cyan)
    let rendered = snapshotImage(.green)
    private(set) var releases = 0

    func generatePreviewImage(editingImage: UIImage?, originalImage: UIImage?, mode: ImageRenderMode) -> UIImage? {
        previewBase
    }

    func instantPreview(baseImage: UIImage?, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) -> UIImage? {
        snapshotImage(.magenta)
    }

    func applyFilters(to image: UIImage, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) -> UIImage? {
        rendered
    }

    func applyFiltersAsync(to image: UIImage, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) async -> UIImage? {
        rendered
    }

    func resetCache() {}

    func releaseMemory() {
        releases += 1
    }
}
