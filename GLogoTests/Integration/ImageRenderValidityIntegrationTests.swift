// 履歴移動・加工結果・対象置換をまたぐ描画と、調整の遅延通知の適用条件を検証する。

import Combine
import UIKit
import XCTest
@testable import GLogo

final class ImageRenderValidityIntegrationTests: XCTestCase {
    private enum Change: CaseIterable {
        case undo, undoRedo, unrelatedUndo, removal, blur, upscale, revert
        case deleteUndo, sameIDReplacement, adjustmentRestored, frame, removed
    }

    @MainActor
    func test_invalidRender_propagatesCancellation() async {
        for change in 0..<3 {
            let scheduler = ManualImageRenderScheduler()
            let started = expectation(description: "描画開始")
            let finished = expectation(description: "キャンセルで描画終了")
            let refresh = ImageRenderRefreshUseCase(renderScheduler: scheduler, renderFullQuality: { _ in
                started.fulfill()
                do {
                    try await Task.sleep(nanoseconds: 30_000_000_000)
                    XCTFail("キャンセルが届いていない")
                } catch {
                    XCTAssertTrue(Task.isCancelled)
                }
                finished.fulfill()
                return nil
            })
            let (editor, panels, image) = makeContext(refresh)
            panels.filters.applyFilterPreset(FilterCatalog.vintageWarm)
            scheduler.runPending()
            await fulfillment(of: [started], timeout: 1)
            switch change {
            case 0: editor.undo()
            case 1: editor.clearSelection()
            default: panels.imageAdjustment.updateImageAdjustment(.brightness, value: 0.5)
            }
            await fulfillment(of: [finished], timeout: 1)
            XCTAssertNil(editor.sessionStore.cachedRenderedImage(of: image))
            withExtendedLifetime(panels) {}
        }
    }

    @MainActor
    private func makeContext(_ refresh: ImageRenderRefreshUseCase) -> (EditorViewModel, ElementViewModel, ImageElement) {
        let image = ImageElementFactory().makeElement(imageData: snapshotImage(.red).pngData()!)
        let project = LogoProject()
        project.addElement(image)
        let editor = EditorViewModel(project: project)
        let panels = ElementViewModel(editorViewModel: editor, imageRefresh: refresh)
        editor.selectElement(image)
        return (editor, panels, image)
    }

    @MainActor
    private func apply(_ change: Change, to image: ImageElement, editor: EditorViewModel) {
        switch change {
        case .undo: editor.undo()
        case .undoRedo:
            editor.undo()
            editor.redo()
        case .unrelatedUndo:
            editor.updateProjectName("Changed")
            editor.undo()
        case .removal: editor.aiTools.applyManualBackgroundRemovalResult(snapshotImage(.green), to: image)
        case .blur: XCTAssertTrue(editor.imageEdits.applyAIBackgroundBlurMask(snapshotImage(.white), to: image))
        case .upscale: editor.imageEdits.applyUpscaledImageResult(snapshotImage(.green), to: image)
        case .revert: editor.revertSelectedImageToInitialState()
        case .deleteUndo:
            editor.deleteSelectedElement()
            editor.undo()
        case .sameIDReplacement:
            let replacement = ImageElementFactory().makeElement(imageData: snapshotImage(.green).pngData()!)
            replacement.id = image.id
            editor.project.elements = [replacement]
            editor.selectElement(replacement)
        case .adjustmentRestored:
            image.brightnessAdjustment = 0.5
            image.brightnessAdjustment = 0
        case .frame: editor.imageEdits.updateImageShowFrame(image, oldValue: false, newValue: true)
        case .removed:
            // 選択通知による予約取消がなくても、所属確認で古い実体を拒否する。
            editor.project.elements.removeAll()
        }
    }

    @MainActor
    func test_runningRender_discardsInvalidatedResult() async {
        for change in Change.allCases {
            let scheduler = ManualImageRenderScheduler()
            let renderer = ControlledImageRenderer()
            let refresh = ImageRenderRefreshUseCase(renderScheduler: scheduler, renderFullQuality: renderer.render)
            let (editor, panels, image) = makeContext(refresh)
            let started = expectation(description: "描画開始: \(change)")
            renderer.onStart = { started.fulfill() }
            panels.filters.applyFilterPreset(FilterCatalog.vintageWarm)
            scheduler.runPending()
            await fulfillment(of: [started], timeout: 1)

            apply(change, to: image, editor: editor)
            let marker = UIImage()
            editor.sessionStore.storeRenderedImage(marker, of: image)
            let wasUsingCache = editor.sessionStore.displayImage(of: image) === marker
            let selected = editor.selectedElement
            let history = editor.getHistoryDescriptions()
            let modified = editor.isProjectModified
            var notifications = 0
            let observation = editor.objectWillChange.sink { notifications += 1 }
            let returned = expectation(description: "旧描画復帰: \(change)")
            renderer.onReturn = { returned.fulfill() }
            renderer.finish(0, with: UIImage())
            await fulfillment(of: [returned], timeout: 1)

            XCTAssertTrue(editor.sessionStore.cachedRenderedImage(of: image) === marker, "\(change)")
            XCTAssertEqual(editor.sessionStore.displayImage(of: image) === marker, wasUsingCache, "古い完了で編集状態を変えない: \(change)")
            XCTAssertTrue(editor.selectedElement === selected)
            XCTAssertEqual(editor.getHistoryDescriptions(), history)
            XCTAssertEqual(editor.isProjectModified, modified)
            XCTAssertEqual(notifications, 0)
            withExtendedLifetime((panels, observation)) {}
        }
    }

    @MainActor
    func test_queuedRender_doesNotStartAfterInvalidation() async throws {
        for change in Change.allCases {
            let scheduler = ManualImageRenderScheduler()
            let started = expectation(description: "失効した描画は開始しない: \(change)")
            started.isInverted = true
            let refresh = ImageRenderRefreshUseCase(renderScheduler: scheduler, renderFullQuality: { _ in
                started.fulfill()
                return UIImage()
            })
            let (editor, panels, image) = makeContext(refresh)
            panels.filters.applyFilterPreset(FilterCatalog.vintageWarm)
            let dispatched = try XCTUnwrap(scheduler.pending)
            apply(change, to: image, editor: editor)
            // 取消済みの DispatchWorkItem が既に取り出されていた場合も再現する。
            dispatched()
            await fulfillment(of: [started], timeout: 0.05)
            withExtendedLifetime(panels) {}
        }
    }

    @MainActor
    func test_validRender_preservesUnrelatedChanges() async {
        let scheduler = ManualImageRenderScheduler()
        let renderer = ControlledImageRenderer()
        let refresh = ImageRenderRefreshUseCase(renderScheduler: scheduler, renderFullQuality: renderer.render)
        let (editor, panels, image) = makeContext(refresh)
        let started = expectation(description: "描画開始")
        renderer.onStart = { started.fulfill() }
        panels.filters.applyFilterPreset(FilterCatalog.vintageWarm)
        scheduler.runPending()
        await fulfillment(of: [started], timeout: 1)
        editor.updateProjectName("Changed")
        image.position = CGPoint(x: 10, y: 20)
        editor.sessionStore.storeRenderedImage(UIImage(), of: image)
        editor.selectElement(image)
        let history = editor.getHistoryDescriptions()
        let result = UIImage()
        let returned = expectation(description: "有効な描画復帰")
        renderer.onReturn = { returned.fulfill() }
        renderer.finish(0, with: result)
        await fulfillment(of: [returned], timeout: 1)
        XCTAssertTrue(editor.sessionStore.cachedRenderedImage(of: image) === result)
        XCTAssertTrue(editor.sessionStore.displayImage(of: image) === result, "有効な描画完了でプレビュー状態を終了する")
        XCTAssertEqual(image.position, CGPoint(x: 10, y: 20))
        XCTAssertEqual(editor.getHistoryDescriptions(), history)
        withExtendedLifetime(panels) {}
    }

    @MainActor
    func test_delayedAdjustment_discardsInvalidatedCallback() async throws {
        for curve in [false, true] {
            for change in Change.allCases {
                let scheduler = ManualImageRenderScheduler()
                let (editor, panels, image) = makeContext(ImageRenderRefreshUseCase(renderScheduler: scheduler))
                editor.updateProjectName("Undo target")
                if curve {
                    var data = ToneCurveData()
                    data.rgbPoints[1].output = 0.7
                    panels.imageAdjustment.updateToneCurveData(data)
                } else {
                    panels.imageAdjustment.beginImageAdjustmentEditing(.gaussianBlur)
                    panels.imageAdjustment.updateImageAdjustment(.gaussianBlur, value: 2)
                }
                let dispatched = try XCTUnwrap(scheduler.pending)
                apply(change, to: image, editor: editor)
                let marker = UIImage()
                editor.sessionStore.storeRenderedImage(marker, of: image)
                let wasUsingCache = editor.sessionStore.displayImage(of: image) === marker
                let changed = expectation(description: "失効した通知は届かない")
                changed.isInverted = true
                let observation = editor.objectWillChange.sink { changed.fulfill() }
                dispatched()
                await fulfillment(of: [changed], timeout: 0.05)
                XCTAssertTrue(editor.sessionStore.cachedRenderedImage(of: image) === marker, "\(curve) / \(change)")
                XCTAssertEqual(editor.sessionStore.displayImage(of: image) === marker, wasUsingCache)
                withExtendedLifetime((panels, observation)) {}
            }
        }
    }

    @MainActor
    func test_gaussianCommit_keepsFinalRefresh() async throws {
        let scheduler = ManualImageRenderScheduler()
        let (editor, panels, image) = makeContext(ImageRenderRefreshUseCase(renderScheduler: scheduler))
        panels.imageAdjustment.beginImageAdjustmentEditing(.gaussianBlur)
        panels.imageAdjustment.updateImageAdjustment(.gaussianBlur, value: 2)
        let previewCallback = try XCTUnwrap(scheduler.pending)
        panels.imageAdjustment.commitImageAdjustmentEditing(.gaussianBlur)
        let changed = expectation(description: "確定後の表示更新は一度だけ")
        changed.assertForOverFulfill = true
        let observation = editor.$selectedElement.dropFirst().sink { _ in changed.fulfill() }
        previewCallback()
        scheduler.runPending()
        await fulfillment(of: [changed], timeout: 1)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        XCTAssertNil(editor.sessionStore.cachedRenderedImage(of: image))
        let marker = UIImage()
        editor.sessionStore.storeRenderedImage(marker, of: image)
        XCTAssertTrue(editor.sessionStore.displayImage(of: image) === marker)
        withExtendedLifetime((panels, observation)) {}
    }

    @MainActor
    func test_sameIDReplacement_resetsAdjustmentStart() {
        let scheduler = ManualImageRenderScheduler()
        let (editor, panels, image) = makeContext(ImageRenderRefreshUseCase(renderScheduler: scheduler))
        panels.imageAdjustment.beginImageAdjustmentEditing(.brightness)
        panels.imageAdjustment.updateImageAdjustment(.brightness, value: 0.2)
        let replacement = ImageElementFactory().makeElement(imageData: snapshotImage(.green).pngData()!)
        replacement.id = image.id
        replacement.brightnessAdjustment = 0.3
        editor.project.elements = [replacement]
        editor.selectElement(replacement)
        panels.imageAdjustment.beginImageAdjustmentEditing(.brightness)
        panels.imageAdjustment.updateImageAdjustment(.brightness, value: 0.6)
        panels.imageAdjustment.commitImageAdjustmentEditing(.brightness)
        editor.undo()
        XCTAssertEqual(replacement.brightnessAdjustment, 0.3, "以前の実体の開始値を引き継がない")
        XCTAssertTrue(panels.imageAdjustment.imageElement === replacement)
        XCTAssertTrue(panels.filters.imageElement === replacement)
    }

    @MainActor
    func test_historyAndAI_endInvalidatedPreview() {
        for change in [Change.undo, .undoRedo, .unrelatedUndo, .removal, .blur, .upscale, .revert] {
            let scheduler = ManualImageRenderScheduler()
            let (editor, panels, image) = makeContext(ImageRenderRefreshUseCase(renderScheduler: scheduler))
            panels.filters.applyFilterPreset(FilterCatalog.vintageWarm)
            apply(change, to: image, editor: editor)
            let marker = UIImage()
            editor.sessionStore.storeRenderedImage(marker, of: image)
            XCTAssertTrue(editor.sessionStore.displayImage(of: image) === marker, "古い描画を待たず確定品質へ戻る: \(change)")
            withExtendedLifetime(panels) {}
        }
    }
}
