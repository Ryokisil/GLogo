// 管理役（ImageRenderSessionStore）が、要素自身のセッションと同じ画像を返し、取得・加工の回数も変えないことを確かめる。
// 第17回の時点では、管理役は要素のセッションを返すだけなので、キャッシュと編集中の状態も要素の API と共有する。

import UIKit
import XCTest
@testable import GLogo

@MainActor
final class ImageRenderSessionStoreTests: XCTestCase {
    func test_images_matchElementSession() {
        let fixture = Fixture()
        let element = fixture.element
        let store = ImageRenderSessionStore()

        let original = store.originalImage(of: element)
        XCTAssertTrue(original === fixture.source.original)
        XCTAssertTrue(element.originalImage === original, "元画像のキャッシュを要素と共有する")
        XCTAssertEqual(fixture.source.originalCount, 1, "管理役と要素の API を合わせて、取得は1回")

        let display = store.displayImage(of: element)
        XCTAssertTrue(display === fixture.preview.fullQuality)
        XCTAssertTrue(element.cachedImage === display, "表示画像のキャッシュを要素と共有する")
        XCTAssertTrue(element.image === display)
        XCTAssertTrue(store.drawingImage(of: element) === display, "編集中でなければ、表示画像を描く")
        XCTAssertEqual(fixture.preview.counts.applyFull, 1, "フル品質の加工は1回")

        XCTAssertTrue(store.previewService(of: element) === element.previewService)
    }

    func test_editingState_sharedWithElement() {
        let fixture = Fixture()
        let element = fixture.element
        let store = ImageRenderSessionStore()

        element.startEditing()
        XCTAssertTrue(store.drawingImage(of: element) === fixture.preview.instant, "要素の API で始めた編集中の状態を、管理役も使う")

        element.endEditing()
        XCTAssertTrue(store.drawingImage(of: element) === fixture.preview.fullQuality)
    }

    /// 同じ手順を、管理役と Model の API（キャンバスの以前の経路の draw(in:) を含む）で行い、
    /// 取得先と描画サービスの呼び出しの回数が、手順ごとに同じになることを確かめる。
    func test_callCounts_matchModelRoute() throws {
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

        _ = store.originalImage(of: viaStore.element)
        _ = viaModel.element.originalImage
        assertSameCounts("元画像")

        _ = store.displayImage(of: viaStore.element)
        _ = viaModel.element.image
        assertSameCounts("表示画像")

        _ = store.drawingImage(of: viaStore.element)
        viaModel.element.draw(in: context)
        assertSameCounts("キャンバスに描く画像")

        viaStore.element.startEditing()
        viaModel.element.startEditing()
        _ = store.drawingImage(of: viaStore.element)
        viaModel.element.draw(in: context)
        assertSameCounts("編集中のキャンバスに描く画像")

        _ = store.displayImage(of: viaStore.element)
        _ = viaModel.element.image
        assertSameCounts("編集中の表示画像")

        viaStore.element.endEditing()
        viaModel.element.endEditing()
        _ = store.drawingImage(of: viaStore.element)
        viaModel.element.draw(in: context)
        assertSameCounts("編集を終えたあとのキャンバスに描く画像")
    }

    /// 保存用の複製は元の要素と同じ ID を持つが、インスタンスが違うので、セッションもキャッシュも共有しない。
    func test_renderCopy_usesSeparateSession() {
        let fixture = Fixture()
        let element = fixture.element
        let store = ImageRenderSessionStore()
        let copy = element.renderCopy()
        XCTAssertEqual(copy.id, element.id)

        XCTAssertNotNil(store.displayImage(of: copy))

        XCTAssertNotNil(copy.cachedImage)
        XCTAssertNil(element.cachedImage, "同じ ID でも、インスタンスが違えばキャッシュを共有しない")
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
