// 画像の差し替えと Revert（それぞれの Undo／Redo を含む）で、描画のキャッシュに以前の画像が残らないことと、
// 消す範囲（プロキシを残すか、共有の描画サービスをどこまでリセットするか）を、失敗や境界の条件も含めて固定する。
// 観察は、エディタが持つ管理役（具体型）と同じインスタンスで行う。

import UIKit
import XCTest
@testable import GLogo

@MainActor
final class ImageSourceChangeEdgeTests: XCTestCase {
    private let oldData = Data([1])
    private let newData = Data([2])
    private let red = edgeImage(.red)
    private let blue = edgeImage(.blue)

    /// キャッシュが空でも載っていても、差し替えのあとは新しい画像だけを使い、Undo・Redo でも以前の画像を残さない。
    /// 共有の描画サービスのリセットは、差し替え・復元ごとに1回。
    func test_replacement_dropsOldImages() throws {
        for warmFirst in [false, true] {
            let source = EdgeSource(dataImages: [oldData: red, newData: blue])
            let preview = EdgePreview()
            let (editor, store, image) = try makeEditor(source: .data(oldData), resolver: source, preview: preview)
            if warmFirst {
                XCTAssertTrue(store.displayImage(of: image) === red)
                XCTAssertNotNil(store.cachedRenderedImage(of: image))
            }

            replace(image, with: newData, in: editor)
            XCTAssertNil(store.cachedRenderedImage(of: image), "キャッシュあり: \(warmFirst)")
            XCTAssertTrue(store.displayImage(of: image) === blue, "キャッシュあり: \(warmFirst)")
            XCTAssertEqual(preview.resets, 1)

            editor.undo()
            XCTAssertTrue(store.displayImage(of: image) === red, "Undo（キャッシュあり: \(warmFirst)）")
            XCTAssertEqual(preview.resets, 2)

            editor.redo()
            XCTAssertTrue(store.displayImage(of: image) === blue, "Redo（キャッシュあり: \(warmFirst)）")
            XCTAssertEqual(preview.resets, 3)
        }
    }

    /// 差し替えのデータから画像を作れなくても、以前の画像を表示し続けない。Undo では以前の画像に戻る。
    func test_corruptedReplacement_keepsNoOldImage() throws {
        let source = EdgeSource(dataImages: [oldData: red])
        let (editor, store, image) = try makeEditor(source: .data(oldData), resolver: source, preview: EdgePreview())
        XCTAssertTrue(store.displayImage(of: image) === red)

        replace(image, with: newData, in: editor)
        XCTAssertNil(store.originalImage(of: image))
        XCTAssertNil(store.displayImage(of: image))

        editor.undo()
        XCTAssertTrue(store.displayImage(of: image) === red)
    }

    /// Undo で戻す元のファイルを取得できなくても、差し替えた画像も以前のキャッシュも表示しない。
    func test_undoWithMissingOriginalFile_keepsNoStaleImage() throws {
        let source = EdgeSource(dataImages: [newData: blue], pathImages: ["old.png": red])
        let (editor, store, image) = try makeEditor(source: .path("old.png"), resolver: source, preview: EdgePreview())
        XCTAssertTrue(store.displayImage(of: image) === red)
        replace(image, with: newData, in: editor)
        XCTAssertTrue(store.displayImage(of: image) === blue)

        source.pathImages["old.png"] = nil
        editor.undo()
        XCTAssertNil(store.originalImage(of: image))
        XCTAssertNil(store.displayImage(of: image))
    }

    /// 差し替えは、その要素の描画サービスだけをリセットし、別の描画サービスとほかの要素のキャッシュには触れない。
    func test_replacement_resetsOnlyOwnServiceAndElement() throws {
        let ownPreview = EdgePreview()
        let otherPreview = EdgePreview()
        let otherSource = EdgeSource(dataImages: [oldData: red])
        let (editor, store, image) = try makeEditor(
            source: .data(oldData), resolver: EdgeSource(dataImages: [oldData: red, newData: blue]), preview: ownPreview
        )
        let other = ImageElement(source: .data(oldData), size: nil, sourceResolver: otherSource, previewService: otherPreview)
        editor.addElement(other)
        XCTAssertNotNil(store.displayImage(of: image))
        let otherRendered = try XCTUnwrap(store.displayImage(of: other))
        let otherCalls = otherSource.originalCalls

        replace(image, with: newData, in: editor)

        XCTAssertEqual(ownPreview.resets, 1)
        XCTAssertEqual(otherPreview.resets, 0, "別の描画サービスはリセットしない")
        XCTAssertTrue(store.cachedRenderedImage(of: other) === otherRendered, "ほかの要素の表示画像は残る")
        XCTAssertNotNil(store.originalImage(of: other))
        XCTAssertEqual(otherSource.originalCalls, otherCalls, "ほかの要素の元画像は取得し直さない")
    }


    /// 差し替え前のソースの種類によらず、差し替えの適用・Undo・Redo は配置サイズを変えない（各操作の直前の値のまま）。
    /// 差し替えの画像はデコードできる PNG にし、取得先はソースのある4通りとも、配置サイズと縦横比の違う画像を返す
    /// （配置サイズを画像から計算し直すと値が変わり、検出できる）。
    func test_replacement_keepsSizeForEachSource() throws {
        let path = "/edge/old.png"
        let url = URL(fileURLWithPath: "/edge/old-url.png")
        let fileName = "edge-old"
        let replacement = try XCTUnwrap(blue.pngData())
        let sources: [(String, ImageElement.ImageSource?)] = [
            ("データ", .data(oldData)), ("パス", .path(path)), ("ファイル URL", .url(url)),
            ("ファイル名", .fileName(fileName)), ("なし", nil)
        ]
        for (label, oldSource) in sources {
            let resolver = EdgeSource(
                dataImages: [oldData: red, replacement: blue], pathImages: [path: red],
                urlImages: [url: red], fileNameImages: [fileName: red]
            )
            let (editor, store, image) = try makeEditor(source: oldSource, resolver: resolver, preview: EdgePreview())

            image.size = CGSize(width: 77, height: 33)
            replace(image, with: replacement, in: editor)
            XCTAssertEqual(image.imageData, replacement, label)
            XCTAssertEqual(image.size, CGSize(width: 77, height: 33), "\(label)：適用の直前の配置サイズを保つ")

            image.size = CGSize(width: 55, height: 44)
            editor.undo()
            XCTAssertEqual(image.size, CGSize(width: 55, height: 44), "\(label)：Undo の直前の配置サイズを保つ")
            let restored = store.originalImage(of: image)
            if oldSource == nil {
                XCTAssertNil(restored, "\(label)：ソースのない状態に戻る")
            } else {
                XCTAssertTrue(restored === red, "\(label)：以前のソースに戻る")
            }

            image.size = CGSize(width: 66, height: 22)
            editor.redo()
            XCTAssertEqual(image.size, CGSize(width: 66, height: 22), "\(label)：Redo の直前の配置サイズを保つ")
        }
    }

    /// メタデータの識別子がない・履歴がない・巻き戻しに失敗・見つからないときも、Revert は編集値を初期化し、
    /// 表示画像・元画像・プレビュー元画像を失効させる（プロキシと共有の描画サービスのキャッシュは残す）。
    func test_revertWithoutMetadataRestore_stillInvalidates() throws {
        let variants: [(String, MetadataOperationResult, Bool)] = [
            ("識別子なし", .success, true),
            ("履歴なし", .noChanges, false),
            ("巻き戻しの失敗", .failure(NSError(domain: "edge", code: 1)), false),
            ("見つからない", .notFound, false)
        ]
        for (label, result, dropsIdentifier) in variants {
            let metadata = MetadataStoreSpy()
            metadata.revertResult = result
            let source = EdgeSource(dataImages: [oldData: red])
            let preview = EdgePreview()
            let (editor, store, image) = try makeEditor(
                source: .data(oldData), resolver: source, preview: preview, metadataStore: metadata
            )
            let initialSaturation = image.saturationAdjustment
            image.saturationAdjustment = initialSaturation + 0.5
            if dropsIdentifier { image.originalImageIdentifier = nil }
            XCTAssertNotNil(store.originalImage(of: image))
            XCTAssertNotNil(store.instantPreview(of: image))
            XCTAssertNotNil(store.displayImage(of: image))
            let counts = (source.originalCalls, source.editingCalls, preview.generateCalls)

            editor.revertSelectedImageToInitialState()

            XCTAssertEqual(image.saturationAdjustment, initialSaturation, accuracy: 0.0001, label)
            XCTAssertNil(store.cachedRenderedImage(of: image), "\(label)：表示画像")
            XCTAssertNotNil(store.originalImage(of: image))
            XCTAssertEqual(source.originalCalls, counts.0 + 1, "\(label)：元画像を取得し直す")
            XCTAssertNotNil(store.instantPreview(of: image))
            XCTAssertEqual(preview.generateCalls, counts.2 + 1, "\(label)：プレビュー元画像を作り直す")
            XCTAssertEqual(source.editingCalls, counts.1, "\(label)：プロキシは残す")
            XCTAssertEqual(preview.resets, 0, "\(label)：共有の描画サービスはリセットしない")
        }
    }

    /// Revert の適用・Undo・Redo は画像ソースを変えないため、どれも共有の描画サービスをリセットしない。
    /// 履歴の操作が実際に行われたことは、編集値と表示画像の失効で確かめる。
    func test_revertUndoRedo_keepsSharedService() throws {
        let preview = EdgePreview()
        let (editor, store, image) = try makeEditor(
            source: .data(oldData), resolver: EdgeSource(dataImages: [oldData: red]), preview: preview,
            metadataStore: MetadataStoreSpy()
        )
        let initialSaturation = image.saturationAdjustment
        image.saturationAdjustment = initialSaturation + 0.5

        func assertStep(_ label: String, saturation: CGFloat, line: UInt = #line) {
            XCTAssertEqual(image.saturationAdjustment, saturation, accuracy: 0.0001, label, line: line)
            XCTAssertNil(store.cachedRenderedImage(of: image), "\(label)：表示画像を失効させる", line: line)
            XCTAssertEqual(preview.resets, 0, "\(label)：共有の描画サービスはリセットしない", line: line)
            // 次の段階で失効を見分けるため、表示画像をキャッシュし直す。
            XCTAssertNotNil(store.displayImage(of: image), line: line)
        }

        XCTAssertNotNil(store.displayImage(of: image))
        editor.revertSelectedImageToInitialState()
        assertStep("適用", saturation: initialSaturation)
        editor.undo()
        assertStep("Undo", saturation: initialSaturation + 0.5)
        editor.redo()
        assertStep("Redo", saturation: initialSaturation)
    }

    // MARK: - Helpers

    /// 画像要素を1つ追加して選んだエディタと、エディタが持つ管理役（同じインスタンス）。
    private func makeEditor(
        source: ImageElement.ImageSource?,
        resolver: EdgeSource,
        preview: EdgePreview,
        metadataStore: (any ImageMetadataStoring)? = nil
    ) throws -> (EditorViewModel, ImageRenderSessionStore, ImageElement) {
        let editor = EditorViewModel(project: LogoProject(), dependencies: .live(metadataStore: metadataStore))
        let store = try XCTUnwrap(editor.managedRenderSessions as? ImageRenderSessionStore)
        let image = ImageElement(source: source, size: nil, sourceResolver: resolver, previewService: preview)
        editor.addElement(image)
        editor.selectElement(image)
        return (editor, store, image)
    }

    /// 背景除去・高画質化の結果の適用と同じく、差し替えのイベントを履歴へ積む。
    private func replace(_ image: ImageElement, with data: Data, in editor: EditorViewModel) {
        let event = ImageContentReplacedEvent(
            element: image, newImageData: data, newOriginalImageIdentifier: "replaced", newHasAppliedUpscale: false
        )
        editor.applyImageEvents([event], elementId: image.id, selectsResult: false)
    }
}

/// データ・パス・URL・ファイル名ごとに返す画像を決めておく取得先。決めていないものには nil（読めない）を返す。
/// 使うソースは、本番の取得先と同じ優先順位（パス > URL > ファイル名 > データ）で選ぶ。
/// テストのスレッドから同期にだけ呼ばれる。
private final class EdgeSource: ImageSourceResolving, @unchecked Sendable {
    var dataImages: [Data: UIImage]
    var pathImages: [String: UIImage]
    var urlImages: [URL: UIImage]
    var fileNameImages: [String: UIImage]
    private(set) var originalCalls = 0
    private(set) var editingCalls = 0

    init(
        dataImages: [Data: UIImage] = [:], pathImages: [String: UIImage] = [:],
        urlImages: [URL: UIImage] = [:], fileNameImages: [String: UIImage] = [:]
    ) {
        self.dataImages = dataImages
        self.pathImages = pathImages
        self.urlImages = urlImages
        self.fileNameImages = fileNameImages
    }

    func resolveOriginalImage(imageData: Data?, fileName: String?, url: URL?, path: String?) -> UIImage? {
        originalCalls += 1
        return image(imageData: imageData, fileName: fileName, url: url, path: path)
    }

    func resolveEditingImage(identifier: String?, fileName: String?, originalPath: String?,
                             originalImageProvider: () -> UIImage?, proxyTargetLongSide: CGFloat,
                             highResThresholdMP: CGFloat) -> UIImage? {
        editingCalls += 1
        return originalImageProvider()
    }

    private func image(imageData: Data?, fileName: String?, url: URL?, path: String?) -> UIImage? {
        if let path { return pathImages[path] }
        if let url { return urlImages[url] }
        if let fileName { return fileNameImages[fileName] }
        if let imageData { return dataImages[imageData] }
        return nil
    }
}

/// 入力の画像をそのまま返し、プレビュー元画像の生成とリセットの回数を数える描画サービス。テストのスレッドから同期にだけ呼ばれる。
private final class EdgePreview: ImagePreviewing, @unchecked Sendable {
    private(set) var generateCalls = 0
    private(set) var resets = 0

    func generatePreviewImage(editingImage: UIImage?, originalImage: UIImage?, mode: ImageRenderMode) -> UIImage? {
        generateCalls += 1
        return editingImage ?? originalImage
    }

    func instantPreview(baseImage: UIImage?, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) -> UIImage? {
        baseImage
    }

    func applyFilters(to image: UIImage, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) -> UIImage? {
        image
    }

    func applyFiltersAsync(to image: UIImage, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) async -> UIImage? {
        image
    }

    func resetCache() {
        resets += 1
    }
}

private func edgeImage(_ color: UIColor) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8), format: format).image { context in
        color.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
    }
}
