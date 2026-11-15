// 管理役（ImageRenderSessionStore）が、要素ごとのセッションの画像を返し、キャッシュと編集中の状態を、同じ管理役の操作で変えることを確かめる。
// 第20回で Model の取得・キャッシュの API を外したため、比べる相手は Model の draw(in:)（第21回まで残る）だけにした。

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

    /// 同じ手順で、管理役の描く画像と Model の draw(in:)（第21回まで残る入口）が、
    /// 取得先と描画サービスを同じ回数だけ呼ぶことを確かめる。編集中の切り替えは、どちらも管理役で行う。
    func test_callCounts_matchModelDraw() throws {
        let viaStore = Fixture()
        let viaModel = Fixture()
        let store = ImageRenderSessionStore()
        let context = try makeContext()

        func assertSameCounts(_ step: String, file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertEqual(viaStore.source.originalCount, viaModel.source.originalCount, "元画像の取得: \(step)",
                           file: file, line: line)
            XCTAssertEqual(viaStore.source.editingCount, viaModel.source.editingCount, "プロキシの取得: \(step)",
                           file: file, line: line)
            XCTAssertEqual(viaStore.preview.counts, viaModel.preview.counts, "描画サービス: \(step)", file: file, line: line)
        }

        _ = store.drawingImage(of: viaStore.element)
        viaModel.element.draw(in: context)
        assertSameCounts("キャンバスに描く画像")

        store.startEditing(viaStore.element)
        store.startEditing(viaModel.element)
        _ = store.drawingImage(of: viaStore.element)
        viaModel.element.draw(in: context)
        assertSameCounts("編集中のキャンバスに描く画像")

        store.endEditing(viaStore.element)
        store.endEditing(viaModel.element)
        _ = store.drawingImage(of: viaStore.element)
        viaModel.element.draw(in: context)
        assertSameCounts("編集を終えたあとのキャンバスに描く画像")
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

    private func makeContext() throws -> CGContext {
        try XCTUnwrap(CGContext(
            data: nil, width: 40, height: 40, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
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
