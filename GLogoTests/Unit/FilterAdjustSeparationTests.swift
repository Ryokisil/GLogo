//
//  FilterAdjustSeparationTests.swift
//  GLogoTests
//
//  概要:
//  Filter と Adjust の状態分離、およびフィルタープリセット履歴の整合性を検証するテスト。
//

import XCTest
import UIKit
@testable import GLogo

/// Filter と Adjust の分離仕様を検証するテスト
final class FilterAdjustSeparationTests: XCTestCase {
    /// 非同期描画からも呼ばれるため、観測値と応答キューはロック下で扱う。
    private final class PreviewServiceSpy: ImagePreviewing, @unchecked Sendable {
        private struct State {
            var generatePreviewImageCallCount: Int = 0
            var instantPreviewCallCount: Int = 0
            var applyFiltersCallCount: Int = 0
            var applyFiltersAsyncCallCount: Int = 0
            var resetCacheCallCount: Int = 0
            var lastMode: ImageRenderMode? = nil
            var nextImage: UIImage? = nil
            var queuedAsyncImages: [UIImage] = []
            var asyncDelayNanoseconds: UInt64 = 0
        }
        private let lock = NSLock()
        private var state = State()

        var generatePreviewImageCallCount: Int {
            get { lock.withLock { state.generatePreviewImageCallCount } }
        }
        var instantPreviewCallCount: Int {
            get { lock.withLock { state.instantPreviewCallCount } }
        }
        var applyFiltersCallCount: Int {
            get { lock.withLock { state.applyFiltersCallCount } }
        }
        var applyFiltersAsyncCallCount: Int {
            get { lock.withLock { state.applyFiltersAsyncCallCount } }
        }
        var resetCacheCallCount: Int {
            get { lock.withLock { state.resetCacheCallCount } }
        }
        var lastMode: ImageRenderMode? {
            get { lock.withLock { state.lastMode } }
        }
        var nextImage: UIImage? {
            get { lock.withLock { state.nextImage } }
            set { lock.withLock { state.nextImage = newValue } }
        }
        var queuedAsyncImages: [UIImage] {
            get { lock.withLock { state.queuedAsyncImages } }
            set { lock.withLock { state.queuedAsyncImages = newValue } }
        }
        var asyncDelayNanoseconds: UInt64 {
            get { lock.withLock { state.asyncDelayNanoseconds } }
            set { lock.withLock { state.asyncDelayNanoseconds = newValue } }
        }

        func generatePreviewImage(editingImage: UIImage?, originalImage: UIImage?, mode: ImageRenderMode) -> UIImage? {
            lock.withLock {
                state.generatePreviewImageCallCount += 1
                state.lastMode = mode
                return state.nextImage
            }
        }

        func instantPreview(baseImage: UIImage?, params: ImageFilterParams,
                            quality: ToneCurveFilter.Quality, mode: ImageRenderMode) -> UIImage? {
            lock.withLock {
                state.instantPreviewCallCount += 1
                state.lastMode = mode
                return state.nextImage
            }
        }

        func applyFilters(to image: UIImage, params: ImageFilterParams,
                          quality: ToneCurveFilter.Quality, mode: ImageRenderMode) -> UIImage? {
            lock.withLock {
                state.applyFiltersCallCount += 1
                state.lastMode = mode
                return state.nextImage
            }
        }

        func applyFiltersAsync(to image: UIImage, params: ImageFilterParams,
                               quality: ToneCurveFilter.Quality, mode: ImageRenderMode) async -> UIImage? {
            let delay = lock.withLock {
                state.applyFiltersAsyncCallCount += 1
                state.lastMode = mode
                return state.asyncDelayNanoseconds
            }
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            // 従来どおり、完了順に応答キューを取り出す。
            return lock.withLock {
                if !state.queuedAsyncImages.isEmpty {
                    return state.queuedAsyncImages.removeFirst()
                }
                return state.nextImage
            }
        }

        func resetCache() {
            lock.withLock { state.resetCacheCallCount += 1 }
        }
    }

    /// テスト用プロジェクトと画像要素を作成する
    /// - Parameters: なし
    /// - Returns: LogoProject と ImageElement のタプル
    private func makeProjectWithImageElement(previewService: any ImagePreviewing = ImagePreviewService.shared) -> (LogoProject, ImageElement) {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        let image = renderer.image { context in
            UIColor.systemRed.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }

        let project = LogoProject(name: "FilterAdjust分離テスト", canvasSize: CGSize(width: 300, height: 300))
        let element = ImageElementFactory(previewService: previewService).makeElement(imageData: image.pngData() ?? Data(), importOrder: 0)
        project.addElement(element)
        return (project, element)
    }

    /// メインループを短時間回して Combine 通知を反映する
    /// - Parameters: なし
    /// - Returns: なし
    private func flushMainRunLoop() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }

    /// テスト用の最小フィルターパラメータを生成
    /// - Parameters: なし
    /// - Returns: ImageFilterParams
    private func makeFilterParams() -> ImageFilterParams {
        ImageFilterParams(
            toneCurveData: ToneCurveData(),
            saturation: 1.0,
            brightness: 0.0,
            contrast: 1.0,
            highlights: 0.0,
            shadows: 0.0,
            hue: 0.0,
            sharpness: 0.0,
            gaussianBlurRadius: 0.0,
            tintColor: nil,
            tintIntensity: 0.0
        )
    }

    /// テスト用の単色画像を生成
    /// - Parameters: なし
    /// - Returns: UIImage
    private func makeTestImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        return renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }

    /// 比較しやすい単色画像を生成
    /// - Parameter color: 塗りつぶし色
    /// - Returns: 単色画像
    private func makeSolidImage(color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 6, height: 6))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 6, height: 6))
        }
    }

    /// 条件が成立するまでメインループを回す
    /// - Parameters:
    ///   - timeout: 待機上限秒数
    ///   - condition: 成立待ち条件
    /// - Returns: 条件成立時は true
    @discardableResult
    private func waitUntil(timeout: TimeInterval, condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        return condition()
    }

    /// フィルター適用時に manual 側調整値が上書きされないことを確認
    @MainActor
    func testApplyFilterPreset_DoesNotOverwriteManualAdjustments() {
        let (project, element) = makeProjectWithImageElement()
        let editorViewModel = EditorViewModel(project: project)
        let elementViewModel = ElementViewModel(editorViewModel: editorViewModel)

        editorViewModel.selectElement(element)
        flushMainRunLoop()

        elementViewModel.imageAdjustment.beginImageAdjustmentEditing(.contrast)
        elementViewModel.imageAdjustment.updateImageAdjustment(.contrast, value: 1.30)
        elementViewModel.imageAdjustment.commitImageAdjustmentEditing(.contrast)
        let manualContrast = element.contrastAdjustment
        let historyCountBefore = editorViewModel.getHistoryDescriptions().count

        elementViewModel.filters.applyFilterPreset(FilterCatalog.vintageWarm)

        XCTAssertEqual(element.contrastAdjustment, manualContrast, accuracy: 0.0001)
        XCTAssertEqual(element.appliedFilterPresetId, FilterCatalog.vintageWarm.id)
        XCTAssertEqual(element.appliedFilterRecipe, FilterCatalog.vintageWarm.recipe)
        XCTAssertEqual(editorViewModel.getHistoryDescriptions().count, historyCountBefore + 1)
    }

    /// フィルターリセット時に manual 側調整値が維持されることを確認
    @MainActor
    func testResetFilterPresets_ClearsOnlyFilterState() {
        let (project, element) = makeProjectWithImageElement()
        let editorViewModel = EditorViewModel(project: project)
        let elementViewModel = ElementViewModel(editorViewModel: editorViewModel)

        editorViewModel.selectElement(element)
        flushMainRunLoop()

        elementViewModel.imageAdjustment.beginImageAdjustmentEditing(.brightness)
        elementViewModel.imageAdjustment.updateImageAdjustment(.brightness, value: 0.20)
        elementViewModel.imageAdjustment.commitImageAdjustmentEditing(.brightness)
        let manualBrightness = element.brightnessAdjustment

        elementViewModel.filters.applyFilterPreset(FilterCatalog.vintageWarm)
        elementViewModel.filters.resetFilterPresets()

        XCTAssertEqual(element.brightnessAdjustment, manualBrightness, accuracy: 0.0001)
        XCTAssertNil(element.appliedFilterRecipe)
        XCTAssertNil(element.appliedFilterPresetId)
    }

    /// フィルター変更の Undo/Redo が manual 側調整値を巻き戻さないことを確認
    @MainActor
    func testUndoRedoFilterPresetChange_DoesNotAffectManualAdjustments() {
        let (project, element) = makeProjectWithImageElement()
        let editorViewModel = EditorViewModel(project: project)
        let elementViewModel = ElementViewModel(editorViewModel: editorViewModel)

        editorViewModel.selectElement(element)
        flushMainRunLoop()

        elementViewModel.imageAdjustment.beginImageAdjustmentEditing(.hue)
        elementViewModel.imageAdjustment.updateImageAdjustment(.hue, value: 24.0)
        elementViewModel.imageAdjustment.commitImageAdjustmentEditing(.hue)
        let manualHue = element.hueAdjustment

        elementViewModel.filters.applyFilterPreset(FilterCatalog.crisp)
        XCTAssertEqual(element.appliedFilterPresetId, FilterCatalog.crisp.id)

        editorViewModel.undo()
        XCTAssertEqual(element.hueAdjustment, manualHue, accuracy: 0.0001)
        XCTAssertNil(element.appliedFilterRecipe)
        XCTAssertNil(element.appliedFilterPresetId)

        editorViewModel.redo()
        XCTAssertEqual(element.hueAdjustment, manualHue, accuracy: 0.0001)
        XCTAssertEqual(element.appliedFilterPresetId, FilterCatalog.crisp.id)
        XCTAssertEqual(element.appliedFilterRecipe, FilterCatalog.crisp.recipe)
    }

    /// tintColor のみ変更でプレビュー再生成キーが変わることを確認
    @MainActor
    func testAdjustmentFingerprint_ChangesWhenTintColorChanges() {
        let (_, element) = makeProjectWithImageElement()

        let fingerprintBefore = FiltersPanelView.adjustmentFingerprint(for: element)

        element.tintColor = UIColor.blue
        let fingerprintAfterColor = FiltersPanelView.adjustmentFingerprint(for: element)
        XCTAssertNotEqual(fingerprintBefore, fingerprintAfterColor,
                          "tintColor 変更でフィンガープリントが変化すべき")

        element.tintColor = UIColor.red
        let fingerprintAfterColor2 = FiltersPanelView.adjustmentFingerprint(for: element)
        XCTAssertNotEqual(fingerprintAfterColor, fingerprintAfterColor2,
                          "異なる tintColor でフィンガープリントが変化すべき")
    }

    /// 同一プリセットの再タップで no-op 履歴が積まれないことを確認
    @MainActor
    func testApplySameFilterPresetTwice_DoesNotAppendNoOpHistory() {
        let (project, element) = makeProjectWithImageElement()
        let editorViewModel = EditorViewModel(project: project)
        let elementViewModel = ElementViewModel(editorViewModel: editorViewModel)

        editorViewModel.selectElement(element)
        flushMainRunLoop()

        elementViewModel.filters.applyFilterPreset(FilterCatalog.noir)
        let historyCountAfterFirstApply = editorViewModel.getHistoryDescriptions().count

        elementViewModel.filters.applyFilterPreset(FilterCatalog.noir)
        let historyCountAfterSecondApply = editorViewModel.getHistoryDescriptions().count

        XCTAssertEqual(historyCountAfterSecondApply, historyCountAfterFirstApply)
    }

    /// プリセット適用時は即時プレビューを先に表示し、後段で async 高品質反映することを確認
    @MainActor
    func testApplyFilterPreset_UsesInstantPreviewBeforeAsyncFullQualityRefresh() {
        let spy = PreviewServiceSpy()
        spy.nextImage = makeSolidImage(color: .systemBlue)

        let (project, element) = makeProjectWithImageElement(previewService: spy)
        let editorViewModel = EditorViewModel(project: project)
        let elementViewModel = ElementViewModel(editorViewModel: editorViewModel)

        editorViewModel.selectElement(element)
        flushMainRunLoop()

        elementViewModel.filters.applyFilterPreset(FilterCatalog.noir)
        _ = editorViewModel.sessionStore.displayImage(of: element)

        XCTAssertEqual(spy.generatePreviewImageCallCount, 1)
        XCTAssertEqual(spy.instantPreviewCallCount, 1)
        XCTAssertEqual(spy.applyFiltersCallCount, 0)
        XCTAssertTrue(waitUntil(timeout: 1.0) { spy.applyFiltersAsyncCallCount == 1 })

        _ = editorViewModel.sessionStore.displayImage(of: element)

        XCTAssertEqual(spy.applyFiltersAsyncCallCount, 1)
        XCTAssertEqual(spy.applyFiltersCallCount, 0)
    }

    /// 古い async 完了が新しいプリセット選択中プレビューを中断しないことを確認
    @MainActor
    func testApplyFilterPreset_DoesNotApplyStaleAsyncRefreshOverNewerSelection() {
        let spy = PreviewServiceSpy()
        let previewImage = makeSolidImage(color: .systemBlue)
        let firstFullImage = makeSolidImage(color: .systemRed)
        let secondFullImage = makeSolidImage(color: .systemGreen)
        spy.nextImage = previewImage
        spy.queuedAsyncImages = [firstFullImage, secondFullImage]
        spy.asyncDelayNanoseconds = 250_000_000

        let (project, element) = makeProjectWithImageElement(previewService: spy)
        let editorViewModel = EditorViewModel(project: project)
        let elementViewModel = ElementViewModel(editorViewModel: editorViewModel)

        editorViewModel.selectElement(element)
        flushMainRunLoop()

        elementViewModel.filters.applyFilterPreset(FilterCatalog.noir)
        XCTAssertEqual(editorViewModel.sessionStore.displayImage(of: element)?.pngData(), previewImage.pngData())
        XCTAssertTrue(waitUntil(timeout: 0.3) { spy.applyFiltersAsyncCallCount == 1 })

        elementViewModel.filters.applyFilterPreset(FilterCatalog.crisp)
        XCTAssertEqual(editorViewModel.sessionStore.displayImage(of: element)?.pngData(), previewImage.pngData())

        RunLoop.main.run(until: Date().addingTimeInterval(0.20))
        XCTAssertEqual(
            editorViewModel.sessionStore.displayImage(of: element)?.pngData(),
            previewImage.pngData(),
            "古い async 完了で新しいプリセット選択中のプレビューが終了しないこと"
        )

        XCTAssertTrue(waitUntil(timeout: 1.0) { spy.applyFiltersAsyncCallCount == 2 })
        RunLoop.main.run(until: Date().addingTimeInterval(0.30))

        XCTAssertEqual(editorViewModel.sessionStore.displayImage(of: element)?.pngData(), secondFullImage.pngData())
    }

    /// プリセットIDからレンダリング経路が正しく判定されることを確認
    func testImageRenderModeFromPresetId_ResolvesHDRAndSDR() {
        XCTAssertEqual(ImageRenderMode.fromPresetId(nil), .sdr)
        XCTAssertEqual(ImageRenderMode.fromPresetId(FilterCatalog.crisp.id), .sdr)
        XCTAssertEqual(ImageRenderMode.fromPresetId(HDRFilterCatalog.vivid.id), .hdr)
        XCTAssertTrue(HDRFilterCatalog.allPresets.allSatisfy { $0.id.hasPrefix("hdr_") })
    }

    /// SDRモード時にSDRサービスへ委譲されることを確認
    func testImagePreviewService_DelegatesToSDRServiceWhenModeIsSDR() async {
        let sdrSpy = PreviewServiceSpy()
        let hdrSpy = PreviewServiceSpy()
        let service = ImagePreviewService(sdrService: sdrSpy, hdrService: hdrSpy)
        let image = makeTestImage()
        let params = makeFilterParams()

        _ = service.generatePreviewImage(editingImage: image, originalImage: nil, mode: .sdr)
        _ = service.instantPreview(baseImage: image, params: params, quality: .preview, mode: .sdr)
        _ = service.applyFilters(to: image, params: params, quality: .full, mode: .sdr)
        _ = await service.applyFiltersAsync(to: image, params: params, quality: .preview, mode: .sdr)
        service.resetCache()

        XCTAssertEqual(sdrSpy.generatePreviewImageCallCount, 1)
        XCTAssertEqual(sdrSpy.instantPreviewCallCount, 1)
        XCTAssertEqual(sdrSpy.applyFiltersCallCount, 1)
        XCTAssertEqual(sdrSpy.applyFiltersAsyncCallCount, 1)
        XCTAssertEqual(sdrSpy.resetCacheCallCount, 1)

        XCTAssertEqual(hdrSpy.generatePreviewImageCallCount, 0)
        XCTAssertEqual(hdrSpy.instantPreviewCallCount, 0)
        XCTAssertEqual(hdrSpy.applyFiltersCallCount, 0)
        XCTAssertEqual(hdrSpy.applyFiltersAsyncCallCount, 0)
        XCTAssertEqual(hdrSpy.resetCacheCallCount, 1)
    }

    /// HDRモード時にHDRサービスへ委譲されることを確認
    func testImagePreviewService_DelegatesToHDRServiceWhenModeIsHDR() async {
        let sdrSpy = PreviewServiceSpy()
        let hdrSpy = PreviewServiceSpy()
        let service = ImagePreviewService(sdrService: sdrSpy, hdrService: hdrSpy)
        let image = makeTestImage()
        let params = makeFilterParams()

        _ = service.generatePreviewImage(editingImage: nil, originalImage: image, mode: .hdr)
        _ = service.instantPreview(baseImage: image, params: params, quality: .preview, mode: .hdr)
        _ = service.applyFilters(to: image, params: params, quality: .full, mode: .hdr)
        _ = await service.applyFiltersAsync(to: image, params: params, quality: .preview, mode: .hdr)
        service.resetCache()

        XCTAssertEqual(hdrSpy.generatePreviewImageCallCount, 1)
        XCTAssertEqual(hdrSpy.instantPreviewCallCount, 1)
        XCTAssertEqual(hdrSpy.applyFiltersCallCount, 1)
        XCTAssertEqual(hdrSpy.applyFiltersAsyncCallCount, 1)
        XCTAssertEqual(hdrSpy.resetCacheCallCount, 1)

        XCTAssertEqual(sdrSpy.generatePreviewImageCallCount, 0)
        XCTAssertEqual(sdrSpy.instantPreviewCallCount, 0)
        XCTAssertEqual(sdrSpy.applyFiltersCallCount, 0)
        XCTAssertEqual(sdrSpy.applyFiltersAsyncCallCount, 0)
        XCTAssertEqual(sdrSpy.resetCacheCallCount, 1)
    }
}
