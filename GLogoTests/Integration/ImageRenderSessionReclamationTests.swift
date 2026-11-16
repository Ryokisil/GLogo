// 履歴から外れた画像要素の、描画のキャッシュの画像そのものが、描画を挟まずに解放される時点を固定する。
// 上限の直前と Redo できる間は保持し、履歴の破棄の直後に解放する。所有を管理役へ移すとき（第21回）も、同じテストで確かめる。
// 非同期の処理が要素を持つあいだに履歴から外れた場合は、処理が終わったあとの次の回収の契機（新しい操作・Undo・Redo・メモリ警告の
// それぞれ）の直後に解放されることを確かめる。観察は、エディタが持つ管理役（具体型）と同じインスタンスで行う。

import Combine
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

    // MARK: - 履歴の外で要素が解放される経路

    // 非同期の処理（AI・フル品質の描画・間引きの予約・フィルターのサムネイル）は、終わるまで要素を持つため、
    // 履歴から押し出されても、要素は処理の終わりに解放される。ここでは、終わったあとの次の回収の契機（新しい操作・Undo・Redo・
    // メモリ警告）の直後には4種類の画像まで解放されていることだけを確かめる。契機ごとに回収の呼び出しが抜けたことを見分けるため、
    // 契機は1つずつ試し、Undo・Redo では新しい操作を記録しない。終わってから契機までのあいだは、要素がセッションを持つ形では
    // 終わった直後に解放され、管理役がセッションを持つ形（第21回）では契機まで残るため、ここでは確かめない。

    /// AI の処理（背景除去・背景ぼかし・高画質化）の途中で削除が押し出されても、処理が終わるまでは持ち、終わったあとの契機で解放する。
    func test_aiCompletion_releasesByNextTrigger() async throws {
        for operation in AIOperation.allCases {
            for trigger in Trigger.allCases {
                let label = "\(operation)・\(trigger)"
                let started = expectation(description: "開始: \(label)")
                let processor = ReleaseTimingAIProcessor(started: started)
                let (editor, signal) = makeEditor()
                let tools = AIToolsViewModel(
                    edits: editor.imageEdits, renderSessions: editor.renderSessions,
                    backgroundRemovalUseCase: processor,
                    imageUpscaleUseCase: ImageUpscaleUseCase(lanczosPipeline: processor, realESRGANPipeline: processor),
                    selection: editor.$selectedElement.eraseToAnyPublisher()
                )
                var watched = Watched()
                do {
                    let (image, source, preview) = makeImage()
                    editor.addElement(image)
                    editor.selectElement(image)
                    watched = try warm(image, source: source, preview: preview, store: editor.sessionStore)
                    switch operation {
                    case .removal: tools.requestAIBackgroundRemoval(for: image)
                    case .blur: tools.requestAIBackgroundBlur(for: image)
                    case .upscale: tools.requestImageUpscale(for: image, method: .lanczos)
                    }
                }
                await fulfillment(of: [started], timeout: 2)

                deleteAndOverflow(editor)
                prepare(trigger, editor: editor)
                watched.assertAlive("\(label)：処理中")

                let finished = expectation(description: "完了: \(label)")
                let processing = operation == .upscale ? tools.$isProcessingUpscale : tools.$isProcessingAI
                let observation = processing.dropFirst().filter { !$0 }.sink { _ in finished.fulfill() }
                await processor.finish(operation == .upscale ? "upscale" : "ai")
                await fulfillment(of: [finished], timeout: 2)
                await Task.yield()

                await fire(trigger, editor: editor, signal: signal)
                watched.assertReleased("\(label)：契機の直後")
                XCTAssertTrue(editor.project.elements.isEmpty, "\(label)：古い結果は適用しない")
                observation.cancel()
            }
        }
    }

    /// フル品質の描画の途中で削除が押し出され、取り消されても、描画が戻るまでは持ち、戻ったあとの契機で解放する。
    func test_renderCompletion_releasesByNextTrigger() async throws {
        for trigger in Trigger.allCases {
            let scheduler = ManualImageRenderScheduler()
            let renderer = ControlledImageRenderer()
            let refresh = ImageRenderRefreshUseCase(renderScheduler: scheduler, renderFullQuality: renderer.render)
            let (editor, signal) = makeEditor()
            let panels = ElementViewModel(editorViewModel: editor, imageRefresh: refresh)
            let started = expectation(description: "描画開始: \(trigger)")
            renderer.onStart = { started.fulfill() }
            var watched = Watched()
            do {
                let (image, source, preview) = makeImage()
                editor.addElement(image)
                editor.selectElement(image)
                panels.filters.applyFilterPreset(FilterCatalog.vintageWarm)
                scheduler.runPending()
                await fulfillment(of: [started], timeout: 2)
                // フィルターの適用で編集中になり、表示画像も失効するため、描画の途中で編集を終えてから4種類をキャッシュに載せる。
                editor.sessionStore.endEditing(image)
                watched = try warm(image, source: source, preview: preview, store: editor.sessionStore)
            }

            deleteAndOverflow(editor)
            prepare(trigger, editor: editor)
            watched.assertAlive("描画中・\(trigger)")

            let returned = expectation(description: "描画の戻り: \(trigger)")
            renderer.onReturn = { returned.fulfill() }
            renderer.finish(0, with: freshImage(.green))
            await fulfillment(of: [returned], timeout: 2)
            await Task.yield()

            await fire(trigger, editor: editor, signal: signal)
            watched.assertReleased("描画の戻りのあと・\(trigger)")
            withExtendedLifetime(panels) {}
        }
    }

    /// 間引きの予約は、取り消されても期限まで列に残って要素を持つ。期限で要素が解放されたあとの契機で、画像まで解放する。
    func test_pendingSchedule_releasesByNextTrigger() async throws {
        for trigger in Trigger.allCases {
            let renderer = ControlledImageRenderer()
            let refresh = ImageRenderRefreshUseCase(
                renderScheduler: RenderScheduler(debounce: 0.3), renderFullQuality: renderer.render
            )
            let (editor, signal) = makeEditor()
            let panels = ElementViewModel(editorViewModel: editor, imageRefresh: refresh)
            var startedCount = 0
            renderer.onStart = { startedCount += 1 }
            var watched = Watched()
            do {
                let (image, source, preview) = makeImage()
                editor.addElement(image)
                editor.selectElement(image)
                panels.filters.applyFilterPreset(FilterCatalog.vintageWarm)
                // フィルターの適用で編集中になるため、編集を終えてから4種類をキャッシュに載せる。
                editor.sessionStore.endEditing(image)
                watched = try warm(image, source: source, preview: preview, store: editor.sessionStore)
            }

            deleteAndOverflow(editor)
            prepare(trigger, editor: editor)
            watched.assertAlive("予約の期限の前・\(trigger)")

            // 期限は実時間で来るため、要素が解放されるまで待つ（取り消した予約は描画を始めない）。
            for _ in 0..<100 where watched.element != nil {
                try await Task.sleep(nanoseconds: 20_000_000)
            }
            XCTAssertNil(watched.element, "予約の期限のあと・\(trigger)：要素")
            XCTAssertEqual(startedCount, 0, "取り消した予約は描画を始めない")

            await fire(trigger, editor: editor, signal: signal)
            watched.assertReleased("予約の期限のあと・\(trigger)")
            withExtendedLifetime(panels) {}
        }
    }

    /// フィルターのサムネイルの生成の途中で削除が押し出されても、生成が戻るまでは持ち、戻ったあとの契機で解放する。
    func test_thumbnailCompletion_releasesByNextTrigger() async throws {
        for trigger in Trigger.allCases {
            let (editor, signal) = makeEditor()
            let panels = ElementViewModel(
                editorViewModel: editor, imageRefresh: ImageRenderRefreshUseCase(renderScheduler: ManualImageRenderScheduler())
            )
            let started = expectation(description: "生成開始: \(trigger)")
            var watched = Watched()
            var thumbnail: Task<Void, Never>?
            var suspendedPreview: FreshPreview?
            do {
                let (image, source, preview) = makeImage()
                editor.addElement(image)
                editor.selectElement(image)
                watched = try warm(image, source: source, preview: preview, store: editor.sessionStore)
                preview.suspendAsync(onStart: { started.fulfill() })
                suspendedPreview = preview
                thumbnail = Task { @MainActor in
                    _ = await panels.filters.generateFilterPreview(
                        for: FilterCatalog.vintageWarm, targetSize: CGSize(width: 4, height: 4)
                    )
                }
            }
            await fulfillment(of: [started], timeout: 2)

            deleteAndOverflow(editor)
            prepare(trigger, editor: editor)
            watched.assertAlive("生成中・\(trigger)")

            suspendedPreview?.resumeAsync()
            suspendedPreview = nil
            await thumbnail?.value
            thumbnail = nil
            await Task.yield()

            await fire(trigger, editor: editor, signal: signal)
            watched.assertReleased("生成の戻りのあと・\(trigger)")
            withExtendedLifetime(panels) {}
        }
    }

    // MARK: - Helpers

    private enum AIOperation: CaseIterable {
        case removal, blur, upscale
    }

    /// 非同期の処理が終わったあとの、次の回収の契機。
    private enum Trigger: CaseIterable {
        /// 新しい操作の記録
        case newEvent
        /// 残っている操作の Undo（新しい操作は記録しない）
        case undo
        /// Undo しておいた操作の Redo（新しい操作は記録しない）
        case redo
        case memoryWarning
    }

    /// メモリ警告の処理の終わりを知らせる既定の描画サービスを持つエディタ。
    private func makeEditor() -> (EditorViewModel, MemoryWarningSignal) {
        let signal = MemoryWarningSignal()
        return (EditorViewModel(project: LogoProject(), dependencies: .live(previewService: signal)), signal)
    }

    /// 選択中の要素を削除し、その削除の履歴を上限で押し出す。
    private func deleteAndOverflow(_ editor: EditorViewModel) {
        editor.deleteSelectedElement()
        for index in 0..<100 {
            editor.updateProjectName("name\(index)")
        }
    }

    /// 契機の準備を、非同期の処理が終わる前に済ませる。Redo では、ここで Undo して、やり直せる操作を用意する
    /// （この Undo の回収では、要素がまだ処理に持たれているため、何も解放されない）。
    private func prepare(_ trigger: Trigger, editor: EditorViewModel) {
        guard trigger == .redo else { return }
        editor.undo()
        XCTAssertTrue(editor.canRedo, "Redo できる操作を用意する")
    }

    private func fire(_ trigger: Trigger, editor: EditorViewModel, signal: MemoryWarningSignal) async {
        switch trigger {
        case .newEvent:
            editor.updateProjectName("after")
        case .undo:
            XCTAssertTrue(editor.canUndo, "Undo できる操作が残っている")
            editor.undo()
        case .redo:
            XCTAssertTrue(editor.canRedo, "Redo できる操作が残っている")
            editor.redo()
        case .memoryWarning:
            let released = expectation(description: "メモリ警告の処理の終了")
            signal.expectRelease(released)
            NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
            // エディタはメモリ警告を MainActor のタスクで処理し、既定の描画サービスは、回収と要素のキャッシュの解放のあとで解放される。
            await fulfillment(of: [released], timeout: 2)
        }
    }

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

/// メモリ警告の処理の最後に解放される、エディタの既定の描画サービス。解放されたことを、待っている期待に知らせる。
/// 解放は MainActor のタスクから呼ばれ、期待の設定はテストから行うため、期待だけを鍵で守る。
private final class MemoryWarningSignal: ImagePreviewing, @unchecked Sendable {
    private let lock = NSLock()
    private var released: XCTestExpectation?

    /// 次の解放で、この期待を満たす。
    func expectRelease(_ expectation: XCTestExpectation) {
        lock.withLock { released = expectation }
    }

    func releaseMemory() {
        let expectation = lock.withLock {
            defer { released = nil }
            return released
        }
        expectation?.fulfill()
    }

    func generatePreviewImage(editingImage: UIImage?, originalImage: UIImage?, mode: ImageRenderMode) -> UIImage? { nil }

    func instantPreview(baseImage: UIImage?, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) -> UIImage? {
        nil
    }

    func applyFilters(to image: UIImage, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) -> UIImage? {
        nil
    }

    func applyFiltersAsync(to image: UIImage, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) async -> UIImage? {
        nil
    }

    func resetCache() {}
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

/// 呼ぶたびに新しい画像を返す描画サービス。返したプレビュー元画像は弱くだけ覚える。
/// 同期の口はテストのスレッドからだけ呼ばれる。非同期の加工は別のスレッドから呼ばれうるため、止めておく継続だけを鍵で守る。
private final class FreshPreview: ImagePreviewing, @unchecked Sendable {
    private(set) var generateCalls = 0
    private(set) weak var lastPreviewBase: UIImage?
    private let lock = NSLock()
    private var onAsyncStart: (@Sendable () -> Void)?
    private var asyncContinuation: CheckedContinuation<Void, Never>?

    /// 以後の非同期の加工を、`resumeAsync()` まで止める。
    func suspendAsync(onStart: @escaping @Sendable () -> Void) {
        lock.withLock { onAsyncStart = onStart }
    }

    func resumeAsync() {
        let continuation = lock.withLock {
            defer { asyncContinuation = nil; onAsyncStart = nil }
            return asyncContinuation
        }
        continuation?.resume()
    }

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
        if let onStart = lock.withLock({ onAsyncStart }) {
            await withCheckedContinuation { continuation in
                lock.withLock { asyncContinuation = continuation }
                onStart()
            }
        }
        return freshImage(.green)
    }

    func resetCache() {}
}

/// AI の処理を、テストが終わらせるまで止めておく。結果は使われない（対象が履歴から外れているため）。
private actor ReleaseTimingAIProcessor: BackgroundRemovalProcessing, ImageUpscalingPipeline {
    nonisolated let method: ImageUpscaleMethod = .lanczos
    nonisolated let isAvailable = true
    private let started: XCTestExpectation
    private var continuations: [String: CheckedContinuation<UIImage, Error>] = [:]

    init(started: XCTestExpectation) {
        self.started = started
    }

    func removeBackground(from image: UIImage) async throws -> UIImage { try await suspend("ai") }
    func generateMask(from image: UIImage) async throws -> UIImage { try await suspend("ai") }

    func upscale(_ request: ImageUpscaleRequest) async throws -> ImageUpscaleResult {
        let image = try await suspend("upscale")
        return ImageUpscaleResult(image: image, appliedMethod: .lanczos, scaleFactor: .x2, actualScaleMultiplier: 2)
    }

    private func suspend(_ kind: String) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            continuations[kind] = continuation
            started.fulfill()
        }
    }

    func finish(_ kind: String) {
        continuations.removeValue(forKey: kind)?.resume(returning: freshImage(.white))
    }
}

private func freshImage(_ color: UIColor) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8), format: format).image { context in
        color.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
    }
}
