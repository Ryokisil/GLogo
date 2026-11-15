// 履歴から外れた画像要素の、描画のキャッシュの画像そのものが、描画を挟まずに解放される時点を固定する。
// 上限の直前と Redo できる間は保持し、履歴の破棄の直後に解放する。所有を管理役へ移すとき（第21回）も、同じテストで確かめる。
// 観察は、エディタが持つ管理役（具体型）と同じインスタンスで行う。

import UIKit
import XCTest
@testable import GLogo

@MainActor
final class ImageRenderSessionReclamationTests: XCTestCase {
    /// 削除の履歴が上限で押し出された直後に、要素と4種類のキャッシュの画像が解放される。上限の直前までは保持する。
    func test_historyOverflow_releasesCachedImages() throws {
        let editor = EditorViewModel(project: LogoProject())
        let store = try XCTUnwrap(editor.managedRenderSessions as? ImageRenderSessionStore)
        var watched = Watched()
        do {
            let (image, source, preview) = makeImage()
            editor.addElement(image)
            watched = try warm(image, source: source, preview: preview, store: store)
            editor.selectElement(image)
            editor.deleteSelectedElement()
        }

        for index in 0..<99 {
            editor.updateProjectName("name\(index)")
        }
        watched.assertAlive("上限の直前")

        editor.updateProjectName("name99")
        watched.assertReleased("上限で押し出された直後")
    }

    /// 追加を Undo して Redo できる間は保持し、新しい操作で Redo の履歴が消えた直後に解放される。
    func test_redoClear_releasesCachedImages() throws {
        let editor = EditorViewModel(project: LogoProject())
        let store = try XCTUnwrap(editor.managedRenderSessions as? ImageRenderSessionStore)
        var watched = Watched()
        do {
            let (image, source, preview) = makeImage()
            editor.addElement(image)
            watched = try warm(image, source: source, preview: preview, store: store)
        }

        editor.undo()
        watched.assertAlive("Redo できる間")

        editor.updateProjectName("other")
        watched.assertReleased("Redo の履歴が消えた直後")
    }

    // MARK: - Helpers

    /// 呼ぶたびに新しい画像を返し、自分では弱くしか参照しない取得先と描画サービスを持つ画像要素。
    private func makeImage() -> (ImageElement, FreshSource, FreshPreview) {
        let source = FreshSource()
        let preview = FreshPreview()
        let image = ImageElement(source: .data(Data([1])), size: nil, sourceResolver: source, previewService: preview)
        return (image, source, preview)
    }

    /// 元画像・プロキシ・プレビュー元画像・表示画像をキャッシュに載せ、載っていることを確かめてから、弱参照を返す。
    private func warm(
        _ image: ImageElement, source: FreshSource, preview: FreshPreview, store: ImageRenderSessionStore
    ) throws -> Watched {
        let original = try XCTUnwrap(store.originalImage(of: image))
        XCTAssertNotNil(store.instantPreview(of: image))
        let rendered = try XCTUnwrap(store.displayImage(of: image))

        // 2回目は取得・生成し直さず、表示画像のキャッシュもある（4種類がキャッシュに載っている）。
        let counts = (source.originalCalls, source.editingCalls, preview.generateCalls)
        XCTAssertTrue(store.originalImage(of: image) === original)
        XCTAssertNotNil(store.instantPreview(of: image))
        XCTAssertEqual(source.originalCalls, counts.0, "元画像はキャッシュにある")
        XCTAssertEqual(source.editingCalls, counts.1, "プロキシはキャッシュにある")
        XCTAssertEqual(preview.generateCalls, counts.2, "プレビュー元画像はキャッシュにある")
        XCTAssertTrue(store.cachedRenderedImage(of: image) === rendered, "表示画像はキャッシュにある")

        return Watched(
            element: image, original: original, proxy: source.lastProxy,
            previewBase: preview.lastPreviewBase, rendered: rendered
        )
    }
}

/// 解放を見張る弱参照
@MainActor
private struct Watched {
    weak var element: ImageElement?
    weak var original: UIImage?
    weak var proxy: UIImage?
    weak var previewBase: UIImage?
    weak var rendered: UIImage?

    init(
        element: ImageElement? = nil, original: UIImage? = nil, proxy: UIImage? = nil,
        previewBase: UIImage? = nil, rendered: UIImage? = nil
    ) {
        self.element = element
        self.original = original
        self.proxy = proxy
        self.previewBase = previewBase
        self.rendered = rendered
    }

    func assertAlive(_ label: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNotNil(element, "\(label)：要素", file: file, line: line)
        XCTAssertNotNil(original, "\(label)：元画像", file: file, line: line)
        XCTAssertNotNil(proxy, "\(label)：プロキシ", file: file, line: line)
        XCTAssertNotNil(previewBase, "\(label)：プレビュー元画像", file: file, line: line)
        XCTAssertNotNil(rendered, "\(label)：表示画像", file: file, line: line)
    }

    func assertReleased(_ label: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNil(element, "\(label)：要素", file: file, line: line)
        XCTAssertNil(original, "\(label)：元画像", file: file, line: line)
        XCTAssertNil(proxy, "\(label)：プロキシ", file: file, line: line)
        XCTAssertNil(previewBase, "\(label)：プレビュー元画像", file: file, line: line)
        XCTAssertNil(rendered, "\(label)：表示画像", file: file, line: line)
    }
}

/// 呼ぶたびに新しい画像を返す取得先。返したプロキシは弱くだけ覚える。テストのスレッドから同期にだけ呼ばれる。
private final class FreshSource: ImageSourceResolving, @unchecked Sendable {
    private(set) var originalCalls = 0
    private(set) var editingCalls = 0
    private(set) weak var lastProxy: UIImage?

    func resolveOriginalImage(imageData: Data?, fileName: String?, url: URL?, path: String?) -> UIImage? {
        originalCalls += 1
        return freshImage(.red)
    }

    func resolveEditingImage(identifier: String?, fileName: String?, originalPath: String?,
                             originalImageProvider: () -> UIImage?, proxyTargetLongSide: CGFloat,
                             highResThresholdMP: CGFloat) -> UIImage? {
        editingCalls += 1
        let proxy = freshImage(.blue)
        lastProxy = proxy
        return proxy
    }
}

/// 呼ぶたびに新しい画像を返す描画サービス。返したプレビュー元画像は弱くだけ覚える。テストのスレッドから同期にだけ呼ばれる。
private final class FreshPreview: ImagePreviewing, @unchecked Sendable {
    private(set) var generateCalls = 0
    private(set) weak var lastPreviewBase: UIImage?

    func generatePreviewImage(editingImage: UIImage?, originalImage: UIImage?, mode: ImageRenderMode) -> UIImage? {
        generateCalls += 1
        let base = freshImage(.cyan)
        lastPreviewBase = base
        return base
    }

    func instantPreview(baseImage: UIImage?, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) -> UIImage? {
        freshImage(.magenta)
    }

    func applyFilters(to image: UIImage, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) -> UIImage? {
        freshImage(.green)
    }

    func applyFiltersAsync(to image: UIImage, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) async -> UIImage? {
        freshImage(.green)
    }

    func resetCache() {}
}

private func freshImage(_ color: UIColor) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8), format: format).image { context in
        color.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
    }
}
