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
    /// ImagePreviewServiceの委譲先検証用スパイ
    private final class PreviewServiceSpy: ImagePreviewing {
        var generatePreviewImageCallCount = 0
        var instantPreviewCallCount = 0
        var applyFiltersCallCount = 0
        var applyFiltersAsyncCallCount = 0
        var resetCacheCallCount = 0
        var lastMode: ImageRenderMode?

        var nextImage: UIImage?

        func generatePreviewImage(
            editingImage: UIImage?,
            originalImage: UIImage?,
            mode: ImageRenderMode
        ) -> UIImage? {
            _ = editingImage
            _ = originalImage
            generatePreviewImageCallCount += 1
            lastMode = mode
            return nextImage
        }

        func instantPreview(
            baseImage: UIImage?,
            params: ImageFilterParams,
            quality: ToneCurveFilter.Quality,
            mode: ImageRenderMode
        ) -> UIImage? {
            _ = baseImage
            _ = params
            _ = quality
            instantPreviewCallCount += 1
            lastMode = mode
            return nextImage
        }

        func applyFilters(
            to image: UIImage,
            params: ImageFilterParams,
            quality: ToneCurveFilter.Quality,
            mode: ImageRenderMode
        ) -> UIImage? {
            _ = image
            _ = params
            _ = quality
            applyFiltersCallCount += 1
            lastMode = mode
            return nextImage
        }

        func applyFiltersAsync(
            to image: UIImage,
            params: ImageFilterParams,
            quality: ToneCurveFilter.Quality,
            mode: ImageRenderMode
        ) async -> UIImage? {
            _ = image
            _ = params
            _ = quality
            applyFiltersAsyncCallCount += 1
            lastMode = mode
            return nextImage
        }

        func resetCache() {
            resetCacheCallCount += 1
        }
    }

    /// テスト用プロジェクトと画像要素を作成する
    /// - Parameters: なし
    /// - Returns: LogoProject と ImageElement のタプル
    private func makeProjectWithImageElement() -> (LogoProject, ImageElement) {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        let image = renderer.image { context in
            UIColor.systemRed.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }

        let project = LogoProject(name: "FilterAdjust分離テスト", canvasSize: CGSize(width: 300, height: 300))
        let element = ImageElement(imageData: image.pngData() ?? Data(), importOrder: 0)
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

    /// フィルター適用時に manual 側調整値が上書きされないことを確認
    @MainActor
    func testApplyFilterPreset_DoesNotOverwriteManualAdjustments() {
        let (project, element) = makeProjectWithImageElement()
        let editorViewModel = EditorViewModel(project: project)
        let elementViewModel = ElementViewModel(editorViewModel: editorViewModel)

        editorViewModel.selectElement(element)
        flushMainRunLoop()

        elementViewModel.beginImageAdjustmentEditing(.contrast)
        elementViewModel.updateImageAdjustment(.contrast, value: 1.30)
        elementViewModel.commitImageAdjustmentEditing(.contrast)
        let manualContrast = element.contrastAdjustment
        let historyCountBefore = editorViewModel.getHistoryDescriptions().count

        elementViewModel.applyFilterPreset(FilterCatalog.vintageWarm)

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

        elementViewModel.beginImageAdjustmentEditing(.brightness)
        elementViewModel.updateImageAdjustment(.brightness, value: 0.20)
        elementViewModel.commitImageAdjustmentEditing(.brightness)
        let manualBrightness = element.brightnessAdjustment

        elementViewModel.applyFilterPreset(FilterCatalog.vintageWarm)
        elementViewModel.resetFilterPresets()

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

        elementViewModel.beginImageAdjustmentEditing(.hue)
        elementViewModel.updateImageAdjustment(.hue, value: 24.0)
        elementViewModel.commitImageAdjustmentEditing(.hue)
        let manualHue = element.hueAdjustment

        elementViewModel.applyFilterPreset(FilterCatalog.crisp)
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

        elementViewModel.applyFilterPreset(FilterCatalog.noir)
        let historyCountAfterFirstApply = editorViewModel.getHistoryDescriptions().count

        elementViewModel.applyFilterPreset(FilterCatalog.noir)
        let historyCountAfterSecondApply = editorViewModel.getHistoryDescriptions().count

        XCTAssertEqual(historyCountAfterSecondApply, historyCountAfterFirstApply)
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
