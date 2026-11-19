// 状態を変える側（編集中の切り替え・キャッシュの失効と書き込み・確定の加工・メモリ警告）が、
// エディタの管理役を通ることを、要求を記録する偽物の管理役で確かめる（第19回）。
// 偽物は記録してからアプリと同じ管理役へ渡すため、編集中の状態やキャッシュはこれまでどおり変わる。

import Photos
import UIKit
import XCTest
@testable import GLogo

@MainActor
final class ImageRenderSessionControlRouteTests: XCTestCase {
    private typealias Control = RenderSessionSpy.Control

    /// ジェスチャーの操作中は編集中にし、終わったら編集中を終える。
    func test_gesture_routesEditingThroughStore() {
        let context = makeContext()
        let image = context.image

        context.editor.transform.applyGestureTransform(
            kind: .move, translation: CGSize(width: 5, height: 0), scale: nil, rotation: nil, ended: false
        )
        XCTAssertEqual(context.spy.controls, [Control(.startEditing, image)])

        context.spy.removeAllRequests()
        context.editor.transform.applyGestureTransform(kind: .move, translation: nil, scale: nil, rotation: nil, ended: true)
        XCTAssertEqual(context.spy.controls, [Control(.endEditing, image)])
    }

    /// スライダーは開始と変更で編集中にし、確定で編集中を終えてから、履歴が表示画像を失効させる。
    func test_adjustmentSlider_routesThroughStore() {
        let context = makeContext()
        let image = context.image
        let adjustment = context.panels.imageAdjustment

        adjustment.beginImageAdjustmentEditing(.brightness)
        adjustment.updateImageAdjustment(.brightness, value: 0.3)
        adjustment.commitImageAdjustmentEditing(.brightness)

        XCTAssertEqual(context.spy.controls, [
            Control(.startEditing, image), Control(.startEditing, image),
            Control(.endEditing, image), Control(.invalidate(.rendered), image)
        ])
    }

    /// トーンカーブのプレビューは表示画像を失効させて編集中にし、確定の予約で編集中を終えて、もう一度失効させる。
    func test_toneCurve_routesThroughStore() async {
        let context = makeContext()
        let image = context.image
        var curve = image.toneCurveData
        curve.rgbPoints[1].output = 0.7

        context.panels.imageAdjustment.updateToneCurveData(curve)
        XCTAssertEqual(context.spy.controls, [Control(.invalidate(.rendered), image), Control(.startEditing, image)])

        context.spy.removeAllRequests()
        context.scheduler.runPending()
        await waitUntil { !context.spy.controls.isEmpty }
        XCTAssertEqual(context.spy.controls, [Control(.endEditing, image), Control(.invalidate(.rendered), image)])
    }

    /// フィルターのプリセットは、適用の失効（UseCase と履歴）と編集中のあと、
    /// 管理役のフル品質の加工が画像を返してから、書き込みと編集中の終了を求める。
    func test_filterPreset_routesFullQualityThroughStore() async {
        let context = makeContext()
        let image = context.image

        context.panels.filters.applyFilterPreset(FilterCatalog.vintageWarm)
        context.scheduler.runPending()
        await waitUntil { context.spy.controls.contains(Control(.endEditing, image)) }

        XCTAssertEqual(context.spy.controls, [
            Control(.invalidate(.rendered), image), Control(.invalidate(.rendered), image),
            Control(.startEditing, image),
            Control(.fullQualityImage, image), Control(.storeRenderedImage, image), Control(.endEditing, image)
        ])
        XCTAssertNotNil(context.spy.forwarding.cachedRenderedImage(of: image), "書き込んだ表示画像が残る")
    }

    /// 古くなった加工の結果（新しい予約・編集で失効）は、書き込みも編集中の終了も求めない。
    func test_staleFullQualityResult_neitherStoresNorEndsEditing() async {
        let context = makeContext()
        let image = context.image
        let renderer = ControlledImageRenderer()
        let refresh = ImageRenderRefreshUseCase(renderScheduler: context.scheduler, renderFullQuality: renderer.render)
        let edits = context.editor.imageEdits

        // 新しい予約で古くなった結果
        for index in 0..<2 {
            let started = expectation(description: "描画開始 \(index)")
            renderer.onStart = { started.fulfill() }
            refresh.scheduleFullQualityRefresh(for: image, edits: edits, renderSessions: context.spy) {}
            context.scheduler.runPending()
            await fulfillment(of: [started], timeout: 1)
        }
        context.spy.removeAllRequests()
        await finish(renderer, 0)
        XCTAssertEqual(context.spy.controls, [], "古い予約の結果")
        await finish(renderer, 1)
        XCTAssertEqual(context.spy.controls, [Control(.storeRenderedImage, image), Control(.endEditing, image)])

        // 描画中の編集で古くなった結果
        let started = expectation(description: "描画開始 2")
        renderer.onStart = { started.fulfill() }
        refresh.scheduleFullQualityRefresh(for: image, edits: edits, renderSessions: context.spy) {}
        context.scheduler.runPending()
        await fulfillment(of: [started], timeout: 1)
        context.spy.removeAllRequests()
        image.brightnessAdjustment = 0.4
        await finish(renderer, 2)
        XCTAssertEqual(context.spy.controls, [], "描画中に編集された要素の結果")
    }

    /// Revert の適用と Redo は、調整値の初期化の範囲（`.adjustments`）と初期状態への戻しの範囲（`.revert`）を、Undo は表示画像だけを失効させる。
    /// 失効させない範囲（Undo の元画像・プロキシ・プレビュー元画像、適用のプロキシ）は、取得し直さないことで確かめる。
    func test_revertHistory_invalidatesScopesThroughStore() {
        let source = CountingSource()
        let preview = CountingPreview()
        let context = makeContext(image: ImageElementFactory(sourceResolver: source, previewService: preview)
            .makeElement(imageData: snapshotImage(.red).pngData()!))
        let image = context.image
        image.saturationAdjustment = 0.5
        warm(image, context.spy.forwarding)

        context.editor.revertSelectedImageToInitialState()
        XCTAssertEqual(context.spy.controls, [
            Control(.endEditing, image), Control(.invalidate(.adjustments), image), Control(.invalidate(.revert), image)
        ])
        var counts = (source.originalCalls, source.editingCalls, preview.generateCalls)
        warm(image, context.spy.forwarding)
        XCTAssertEqual(source.originalCalls, counts.0 + 1, "適用：元画像を取得し直す")
        XCTAssertEqual(source.editingCalls, counts.1, "適用：プロキシは残る")
        XCTAssertEqual(preview.generateCalls, counts.2 + 1, "適用：調整値の初期化の範囲で、プレビュー元画像を作り直す")

        context.spy.removeAllRequests()
        context.editor.undo()
        XCTAssertEqual(context.spy.controls, [Control(.invalidate(.rendered), image), Control(.endEditing, image)])
        XCTAssertEqual(image.saturationAdjustment, 0.5, accuracy: 0.0001)
        counts = (source.originalCalls, source.editingCalls, preview.generateCalls)
        let fullCalls = preview.fullCalls
        warm(image, context.spy.forwarding)
        XCTAssertEqual(source.originalCalls, counts.0, "Undo：元画像は残る")
        XCTAssertEqual(source.editingCalls, counts.1, "Undo：プロキシは残る")
        XCTAssertEqual(preview.generateCalls, counts.2, "Undo：プレビュー元画像は残る")
        XCTAssertEqual(preview.fullCalls, fullCalls + 1, "Undo：表示画像だけを作り直す")

        context.spy.removeAllRequests()
        context.editor.redo()
        XCTAssertEqual(context.spy.controls, [
            Control(.invalidate(.adjustments), image), Control(.invalidate(.revert), image), Control(.endEditing, image)
        ])
        counts = (source.originalCalls, source.editingCalls, preview.generateCalls)
        warm(image, context.spy.forwarding)
        XCTAssertEqual(source.originalCalls, counts.0 + 1, "Redo：元画像を取得し直す")
        XCTAssertEqual(source.editingCalls, counts.1, "Redo：プロキシは残る")
    }

    /// AI の結果などのイベントの適用では、履歴の失効のあとで、対象の画像要素の編集中を終える。
    func test_imageEventsApplication_endsEditingThroughStore() {
        let context = makeContext()
        let image = context.image

        context.editor.applyImageEvents(
            [ImageSaturationChangedEvent(elementId: image.id, oldSaturation: 1.0, newSaturation: 1.4)],
            elementId: image.id, selectsResult: false
        )

        XCTAssertEqual(context.spy.controls, [Control(.invalidate(.rendered), image), Control(.endEditing, image)])
    }

    /// 保存の準備では、プロジェクトのすべての画像要素の編集中を終える。
    func test_savePreparation_endsEditingThroughStore() {
        let context = makeContext()
        let second = ImageElementFactory().makeElement(imageData: snapshotImage(.blue).pngData()!)
        context.editor.addElement(second)
        context.spy.removeAllRequests()

        context.editor.saveToPhotoLibrary { _ in }

        XCTAssertEqual(context.spy.controls, [Control(.endEditing, context.image), Control(.endEditing, second)])
    }

    /// メモリ警告では、プロジェクトの画像要素ごとに、管理役ですべてのキャッシュを消し、描画サービスを引き当てる。
    func test_memoryWarning_releasesThroughStore() async {
        let released = expectation(description: "既定の描画サービスの解放")
        let context = makeContext(defaultService: ReleaseSignalingService { released.fulfill() })
        let second = ImageElementFactory().makeElement(imageData: snapshotImage(.blue).pngData()!)
        context.editor.addElement(second)
        context.spy.removeAllRequests()

        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        await fulfillment(of: [released], timeout: 2)

        XCTAssertEqual(context.spy.controls, [Control(.invalidate(.all), context.image), Control(.invalidate(.all), second)])
        XCTAssertEqual(context.spy.requests, [
            RenderSessionSpy.Request(.previewService, context.image), RenderSessionSpy.Request(.previewService, second)
        ])
    }

    /// メモリ警告では、削除した要素（プロジェクトにない要素）も、管理役で元画像のキャッシュを確かめて範囲を決めて消し、
    /// 描画サービスを引き当てる（第22回）。元画像を中の管理役のキャッシュに載せたデータの要素なので、すべてのキャッシュを消す。
    func test_memoryWarning_releasesDetachedThroughStore() async {
        let released = expectation(description: "既定の描画サービスの解放")
        let context = makeContext(defaultService: ReleaseSignalingService { released.fulfill() })
        let deleted = ImageElementFactory().makeElement(imageData: snapshotImage(.blue).pngData()!)
        context.editor.addElement(deleted)
        warm(deleted, context.spy.forwarding)
        context.editor.selectElement(deleted)
        context.editor.deleteSelectedElement()
        context.spy.removeAllRequests()
        let reclaimsBefore = context.spy.reclaimCount

        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        await fulfillment(of: [released], timeout: 2)

        XCTAssertEqual(context.spy.reclaimCount, reclaimsBefore + 1, "回収を1回求める")
        XCTAssertEqual(context.spy.controls, [Control(.invalidate(.all), context.image), Control(.invalidate(.all), deleted)])
        XCTAssertEqual(context.spy.requests, [
            RenderSessionSpy.Request(.previewService, context.image),
            RenderSessionSpy.Request(.hasCachedOriginalImage, deleted),
            RenderSessionSpy.Request(.previewService, deleted),
        ])
    }

    // MARK: - Helpers

    private struct Context {
        let editor: EditorViewModel
        let panels: ElementViewModel
        let spy: RenderSessionSpy
        let scheduler: ManualImageRenderScheduler
        let image: ImageElement
    }

    /// 偽物の管理役を持つエディタと編集パネル。画像要素を1つ追加して選び、そこまでの記録は消す。
    private func makeContext(
        image: ImageElement? = nil,
        defaultService: (any ImagePreviewing)? = nil
    ) -> Context {
        let spy = RenderSessionSpy()
        let saver = PhotoLibrarySavingStub()
        let editor = EditorViewModel(
            project: LogoProject(),
            dependencies: .live(photoLibrarySaver: saver, previewService: defaultService),
            renderSessions: spy
        )
        let scheduler = ManualImageRenderScheduler()
        let panels = ElementViewModel(editorViewModel: editor, imageRefresh: ImageRenderRefreshUseCase(renderScheduler: scheduler))
        let image = image ?? ImageElementFactory().makeElement(imageData: snapshotImage(.red).pngData()!)
        editor.addElement(image)
        editor.selectElement(image)
        spy.removeAllRequests()
        return Context(editor: editor, panels: panels, spy: spy, scheduler: scheduler, image: image)
    }

    /// 元画像・プレビュー元画像（とプロキシ）・表示画像を、キャッシュに載せる。偽物の記録に残さないよう、偽物の中の管理役を使う。
    private func warm(_ image: ImageElement, _ store: ImageRenderSessionStore) {
        _ = store.originalImage(of: image)
        _ = store.instantPreview(of: image)
        _ = store.displayImage(of: image)
    }

    private func finish(_ renderer: ControlledImageRenderer, _ id: Int) async {
        let returned = expectation(description: "描画復帰 \(id)")
        renderer.onReturn = { returned.fulfill() }
        renderer.finish(id, with: snapshotImage(.green))
        await fulfillment(of: [returned], timeout: 1)
        // 復帰のあとの判定と書き込みは、同じタスクの続きで行われる。
        await Task.yield()
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}

/// 元画像とプロキシの取得の回数を数える取得先。テストのスレッドから同期にだけ呼ばれる。
private final class CountingSource: ImageSourceResolving, @unchecked Sendable {
    private(set) var originalCalls = 0
    private(set) var editingCalls = 0

    func resolveOriginalImage(imageData: Data?, fileName: String?, url: URL?, path: String?) -> UIImage? {
        originalCalls += 1
        return snapshotImage(.red)
    }

    func resolveEditingImage(identifier: String?, fileName: String?, originalPath: String?,
                             originalImageProvider: () -> UIImage?, proxyTargetLongSide: CGFloat,
                             highResThresholdMP: CGFloat) -> UIImage? {
        editingCalls += 1
        return snapshotImage(.blue)
    }
}

/// プレビュー元画像の生成とフル品質の加工の回数を数える描画サービス。テストのスレッドから同期にだけ呼ばれる。
private final class CountingPreview: ImagePreviewing, @unchecked Sendable {
    private(set) var generateCalls = 0
    private(set) var fullCalls = 0

    func generatePreviewImage(editingImage: UIImage?, originalImage: UIImage?, mode: ImageRenderMode) -> UIImage? {
        generateCalls += 1
        return snapshotImage(.cyan)
    }

    func instantPreview(baseImage: UIImage?, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) -> UIImage? {
        baseImage
    }

    func applyFilters(to image: UIImage, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) -> UIImage? {
        if quality == .full { fullCalls += 1 }
        return image
    }

    func applyFiltersAsync(to image: UIImage, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) async -> UIImage? {
        image
    }

    func resetCache() {}
}

/// 解放されたことを知らせる既定の描画サービス。画像は作らない。
private final class ReleaseSignalingService: ImagePreviewing, @unchecked Sendable {
    private let onRelease: @Sendable () -> Void

    init(onRelease: @escaping @Sendable () -> Void) {
        self.onRelease = onRelease
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

    func resetCache() {
        onRelease()
    }
}
