// エディタでの画像要素と描画のキャッシュの寿命（削除・Undo・履歴の上限・Redo の履歴の破棄・メモリ警告）の振る舞いを固定する。
// 第21回で所有を管理役へ移したあとも同じ期待値で成り立つ。第22回で、メモリ警告のときに削除した要素のキャッシュも消す形に変えた
// （変わったのはメモリ警告のテストの期待値だけ。そのあとの Undo の表示が変わらないことも、ここで確かめる）。
// キャッシュは、エディタが持つ管理役（同じインスタンス）で観察する（第20回で、要素の API から移した）。

import UIKit
import XCTest
@testable import GLogo

@MainActor
final class ImageRenderSessionLifetimeTests: XCTestCase {
    /// 削除した要素は削除のイベントが持ち、キャッシュも残る。Undo では同じインスタンスが、そのキャッシュごと戻る。
    func test_delete_keepsElementAndCacheForUndo() throws {
        let editor = EditorViewModel(project: LogoProject())
        weak var weakImage: ImageElement?
        do {
            let image = try makeImage(in: editor)
            weakImage = image
            editor.addElement(image)
            XCTAssertNotNil(editor.renderSessions.displayImage(of: image))
            editor.selectElement(image)
            editor.deleteSelectedElement()
        }
        XCTAssertNotNil(weakImage, "削除のイベントが要素を持つ")
        XCTAssertNotNil(weakImage.flatMap { editor.sessionStore.cachedRenderedImage(of: $0) }, "削除してもキャッシュは残る")

        editor.undo()

        let restored = try XCTUnwrap(weakImage)
        XCTAssertTrue(editor.project.elements.contains { $0 === restored }, "削除の Undo は同じインスタンスを戻す")
        XCTAssertNotNil(editor.sessionStore.cachedRenderedImage(of: restored), "戻した要素は、残っていたキャッシュを使う")
    }

    /// メモリ警告では、プロジェクトにある要素に加えて、削除した要素（履歴が持つ）のキャッシュも消す（第22回で変えた）。
    /// 削除した要素は、データを持ち元画像がキャッシュにあるため、元画像を含めて消す。セッションは表に残る（要素が生きているため）。
    func test_memoryWarning_releasesDeletedElementCache() async throws {
        let released = expectation(description: "メモリ警告の処理の終了")
        let defaultService = ReleaseSignalingPreviewService { released.fulfill() }
        let editor = EditorViewModel(project: LogoProject(), dependencies: .live(previewService: defaultService))
        let kept = try makeImage(in: editor)
        let deleted = try makeImage(in: editor)
        editor.addElement(kept)
        editor.addElement(deleted)
        XCTAssertNotNil(editor.renderSessions.displayImage(of: kept))
        XCTAssertNotNil(editor.renderSessions.displayImage(of: deleted))
        XCTAssertNotNil(editor.sessionStore.instantPreview(of: deleted), "プロキシとプレビュー元画像もキャッシュに載せる")
        editor.selectElement(deleted)
        editor.deleteSelectedElement()
        let warmed = try XCTUnwrap(editor.sessionStore.cachedImages(of: deleted))
        XCTAssertTrue(
            warmed.renderedImage != nil && warmed.originalImage != nil && warmed.proxyImage != nil && warmed.previewBaseImage != nil,
            "警告の前は、削除した要素の4種類がキャッシュにある"
        )

        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        // 既定の描画サービスは、要素のキャッシュをすべて消したあとで解放される。
        await fulfillment(of: [released], timeout: 2)

        XCTAssertNil(editor.sessionStore.cachedRenderedImage(of: kept), "プロジェクトにある要素のキャッシュは消える")
        let deletedCache = try XCTUnwrap(editor.sessionStore.cachedImages(of: deleted), "削除した要素のセッションは表に残る")
        XCTAssertNil(deletedCache.renderedImage, "削除した要素の表示画像も消える")
        XCTAssertNil(deletedCache.originalImage, "削除した要素の元画像も消える")
        XCTAssertNil(deletedCache.proxyImage)
        XCTAssertNil(deletedCache.previewBaseImage)
    }

    /// 削除のイベントが履歴の上限（100件）で押し出されると、削除した要素はキャッシュごと解放される。
    func test_historyOverflow_releasesDeletedElement() throws {
        let editor = EditorViewModel(project: LogoProject())
        weak var weakImage: ImageElement?
        do {
            let image = try makeImage(in: editor)
            weakImage = image
            editor.addElement(image)
            XCTAssertNotNil(editor.renderSessions.displayImage(of: image))
            editor.selectElement(image)
            editor.deleteSelectedElement()
        }

        for index in 0..<99 {
            editor.updateProjectName("name\(index)")
        }
        XCTAssertNotNil(weakImage, "上限に達するまでは、削除のイベントが持つ")

        editor.updateProjectName("name99")
        XCTAssertNil(weakImage, "削除のイベントが押し出されると解放される")
    }

    /// 追加を Undo した要素は Redo の履歴が持ち、新しい操作で Redo の履歴が消えると解放される。
    func test_newEventAfterUndoAdd_releasesElement() throws {
        let editor = EditorViewModel(project: LogoProject())
        weak var weakImage: ImageElement?
        do {
            let image = try makeImage(in: editor)
            weakImage = image
            editor.addElement(image)
            XCTAssertNotNil(editor.renderSessions.displayImage(of: image))
        }

        editor.undo()
        XCTAssertNotNil(weakImage, "追加の Undo のあとは、Redo の履歴が持つ")
        XCTAssertNotNil(weakImage.flatMap { editor.sessionStore.cachedRenderedImage(of: $0) }, "キャッシュも残る")

        editor.updateProjectName("other")
        XCTAssertNil(weakImage, "新しい操作で Redo の履歴が消えると解放される")
    }

    /// 削除そのものは編集中の状態を終えない（画面では、選択の解除を受けた編集パネルが終える）。
    func test_delete_keepsEditingState() throws {
        let editor = EditorViewModel(project: LogoProject())
        let image = try makeImage(in: editor)
        editor.addElement(image)
        editor.sessionStore.startEditing(image)
        editor.selectElement(image)
        editor.deleteSelectedElement()
        editor.undo()

        XCTAssertNotNil(editor.renderSessions.displayImage(of: image))
        XCTAssertNil(editor.sessionStore.cachedRenderedImage(of: image), "戻した要素は編集中のままで、表示画像をキャッシュしない（即時プレビューを返す）")
    }

    // MARK: - メモリ警告のあとの削除の Undo

    // 第22回で、メモリ警告のときにプロジェクトにない要素のキャッシュも消す。消したあとの Undo で表示が変わらないことを、
    // 削除した要素のキャッシュを残す今のコードで先に固定する（取り直して同じ画像に戻らない元画像・プロキシは、消さない範囲にする）。

    /// データを持つ要素は、メモリ警告のあとに削除を Undo しても、削除の前と同じ色で表示する。
    func test_memoryWarningUndo_dataSource_keepsPixels() async throws {
        let (editor, signal) = makeSignalingEditor()
        let image = try makeImage(in: editor)
        editor.addElement(image)
        let before = try XCTUnwrap(editor.renderSessions.displayImage(of: image))
        editor.selectElement(image)
        editor.deleteSelectedElement()

        await signal.postWarningAndWait(in: self)
        editor.undo()

        let after = try XCTUnwrap(editor.renderSessions.displayImage(of: image))
        XCTAssertEqual(after.size, before.size)
        XCTAssertEqual(centerColor(of: after), centerColor(of: before))
        assertRed(after, "削除の前と同じ色")
    }

    /// ファイルを参照する要素（パス・ファイル URL・絶対パスのファイル名）は、メモリ警告のあとにファイルが変わったり消えたりしても、
    /// 削除の Undo では、削除の前の元画像で表示する（ファイルを読み直さない）。データも持つ要素（保存データの復元では両方の
    /// キーが入りうる）も同じ。取得先は、ファイルの参照をデータより先に使う。
    /// ファイル名の組み合わせは、`UIImage(named:)` がシステムのキャッシュから前の画像を返すことがあり、元画像まで消しても
    /// ここでは違いが出ないことがある（第22回の変異確認）。ファイル名を残す範囲に入れる判定は、ImageCacheReleaseUseCaseTests で守る。
    func test_memoryWarningUndo_externalSources_keepOriginal() async throws {
        let redData = try XCTUnwrap(snapshotImage(.red).pngData())
        for source in ExternalSource.allCases {
            for change in FileChange.allCases {
                for hasData in [false, true] {
                    try await assertUndoKeepsOriginal(source, change, data: hasData ? redData : nil)
                }
            }
        }
    }

    /// 1つの組み合わせで、表示 → 削除 → メモリ警告 → ファイルの変化 → Undo のあとも、削除の前の元画像で表示することを確かめる。
    /// 表示できなかった場合も失敗を記録して戻るだけにし、ほかの組み合わせを止めない（投げるのはファイルの準備の失敗だけ）。
    private func assertUndoKeepsOriginal(_ source: ExternalSource, _ change: FileChange, data: Data?) async throws {
        let label = "\(source)・\(change)・データ\(data == nil ? "なし" : "あり")"
        let fileURL = try writeTemporaryImage(.red)
        let (editor, signal) = makeSignalingEditor()
        let image = ImageElement(
            source: source.imageSource(fileURL), size: CGSize(width: 32, height: 24),
            sourceResolver: ImageSourceResolver(), previewService: ImagePreviewService.shared
        )
        image.imageData = data
        editor.addElement(image)
        guard let before = editor.renderSessions.displayImage(of: image) else {
            return XCTFail("\(label)：削除の前に表示できない")
        }
        assertRed(before, "\(label)：削除の前")
        editor.selectElement(image)
        editor.deleteSelectedElement()

        await signal.postWarningAndWait(in: self)
        switch change {
        case .modified: try XCTUnwrap(snapshotImage(.green).pngData()).write(to: fileURL)
        case .removed: try FileManager.default.removeItem(at: fileURL)
        }
        editor.undo()

        guard let after = editor.renderSessions.displayImage(of: image) else {
            return XCTFail("\(label)：Undo のあとに表示できない（ファイルを読み直した）")
        }
        assertRed(after, "\(label)：削除の前の元画像で表示する")
    }

    /// 元画像が取れず、プロキシだけを外部（プロキシのファイル）から取れた要素は、メモリ警告のあとに削除を Undo しても、
    /// プロキシを取り直さない（プロキシのファイルが変わっていても、削除の前と同じプロキシで表示する）。
    func test_memoryWarningUndo_proxyOnly_keepsProxy() async throws {
        let (editor, signal) = makeSignalingEditor()
        let source = ProxyOnlySource(proxy: snapshotImage(.red))
        let image = ImageElement(
            source: .data(Data([1])), size: CGSize(width: 32, height: 24),
            sourceResolver: source, previewService: ImagePreviewService.shared
        )
        editor.addElement(image)
        editor.sessionStore.startEditing(image)
        XCTAssertNotNil(editor.renderSessions.displayImage(of: image), "編集中は、プロキシから即時プレビューを作る")
        XCTAssertEqual(source.editingCalls, 1)
        editor.selectElement(image)
        editor.deleteSelectedElement()

        await signal.postWarningAndWait(in: self)
        source.proxy = snapshotImage(.green)
        editor.undo()

        let after = try XCTUnwrap(editor.renderSessions.displayImage(of: image))
        XCTAssertEqual(source.editingCalls, 1, "プロキシは取り直さない")
        assertRed(after, "削除の前のプロキシで表示する")
    }

    private func makeImage(in editor: EditorViewModel) throws -> ImageElement {
        ImageElementFactory().makeElement(
            imageData: try XCTUnwrap(snapshotImage(.red).pngData()),
            canvasSize: editor.project.canvasSize
        )
    }

    /// メモリ警告の処理の終わりを知らせる既定の描画サービスを持つエディタ。
    private func makeSignalingEditor() -> (EditorViewModel, MemoryWarningSignal) {
        let signal = MemoryWarningSignal()
        return (EditorViewModel(project: LogoProject(), dependencies: .live(previewService: signal)), signal)
    }

    /// 一時ファイルに単色の画像を書き、テストの終わりに消す。
    private func writeTemporaryImage(_ color: UIColor) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
        try XCTUnwrap(snapshotImage(color).pngData()).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    /// ファイルを参照する画像ソース。ファイル名には、取得先が読める絶対パスを入れる。
    private enum ExternalSource: CaseIterable {
        case path, fileURL, absoluteFileName

        func imageSource(_ url: URL) -> ImageElement.ImageSource {
            switch self {
            case .path: .path(url.path)
            case .fileURL: .url(url)
            case .absoluteFileName: .fileName(url.path)
            }
        }
    }

    /// メモリ警告のあとの、参照先のファイルの変化
    private enum FileChange: CaseIterable {
        case modified, removed
    }

    /// 画像の中央の色（RGBA）。単色の画像の比較に使う。
    private func centerColor(of image: UIImage) -> [UInt8] {
        var pixel = [UInt8](repeating: 0, count: 4)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let sampled = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1), format: format).image { _ in
            image.draw(at: CGPoint(x: -image.size.width / 2, y: -image.size.height / 2))
        }
        guard let cgImage = sampled.cgImage,
              let context = CGContext(
                  data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return pixel }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return pixel
    }

    private func assertRed(_ image: UIImage, _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let color = centerColor(of: image)
        XCTAssertTrue(color[0] > 200 && color[1] < 60 && color[2] < 60, "\(label)：赤ではない \(color)", file: file, line: line)
    }
}

/// 元画像を返さず、プロキシだけを返す取得先（元画像が壊れていて、外部のプロキシのファイルだけが読める状態）。
private final class ProxyOnlySource: ImageSourceResolving, @unchecked Sendable {
    var proxy: UIImage
    private(set) var editingCalls = 0

    init(proxy: UIImage) {
        self.proxy = proxy
    }

    func resolveOriginalImage(imageData: Data?, fileName: String?, url: URL?, path: String?) -> UIImage? {
        nil
    }

    func resolveEditingImage(identifier: String?, fileName: String?, originalPath: String?,
                             originalImageProvider: () -> UIImage?, proxyTargetLongSide: CGFloat,
                             highResThresholdMP: CGFloat) -> UIImage? {
        editingCalls += 1
        return proxy
    }
}

/// メモリ警告で解放されたことを知らせる描画サービス。エディタの既定の描画サービスとしてだけ使い、画像は作らない。
private final class ReleaseSignalingPreviewService: ImagePreviewing {
    private let onRelease: @Sendable () -> Void

    init(onRelease: @escaping @Sendable () -> Void) {
        self.onRelease = onRelease
    }

    func generatePreviewImage(editingImage: UIImage?, originalImage: UIImage?, mode: ImageRenderMode) -> UIImage? {
        nil
    }

    func instantPreview(
        baseImage: UIImage?,
        params: ImageFilterParams,
        quality: RenderQuality,
        mode: ImageRenderMode
    ) -> UIImage? {
        nil
    }

    func applyFilters(to image: UIImage, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) -> UIImage? {
        nil
    }

    func applyFiltersAsync(
        to image: UIImage,
        params: ImageFilterParams,
        quality: RenderQuality,
        mode: ImageRenderMode
    ) async -> UIImage? {
        nil
    }

    func resetCache() {
        onRelease()
    }
}
