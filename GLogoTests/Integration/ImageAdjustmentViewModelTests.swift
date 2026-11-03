// 画像調整の履歴・選択境界と、フィルター描画との競合を検証する。

import CryptoKit
import UIKit
import XCTest
@testable import GLogo

final class ImageAdjustmentViewModelTests: XCTestCase {
    @MainActor
    private func makeContext(refresh: ImageRenderRefreshUseCase = ImageRenderRefreshUseCase()) throws
        -> (EditorViewModel, ElementViewModel, ImageElement) {
        let bitmap = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        let image = ImageElementFactory().makeElement(imageData: try XCTUnwrap(bitmap.pngData()), importOrder: 0)
        let project = LogoProject()
        project.addElement(image)
        let editor = EditorViewModel(project: project)
        let parent = ElementViewModel(editorViewModel: editor, imageRefresh: refresh)
        editor.selectElement(image)
        return (editor, parent, image)
    }

    @MainActor
    func test_adjustment_recordsHistoryAndMetadataOnCommit() throws {
        let (editor, parent, image) = try makeContext()
        let adjustment = parent.imageAdjustment
        let identifier = "adjustment_test_\(UUID().uuidString)"
        image.originalImageIdentifier = identifier
        let documents = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        let storageKey = SHA256.hash(data: Data(identifier.utf8)).map { String(format: "%02x", $0) }.joined()
        defer {
            for path in ["GLogo/Metadata/metadata_\(storageKey).json", "GLogo/History/history_\(storageKey).json"] {
                try? FileManager.default.removeItem(at: documents.appendingPathComponent(path))
            }
        }
        adjustment.beginImageAdjustmentEditing(.brightness)
        adjustment.updateImageAdjustment(.brightness, value: 0.2)
        adjustment.updateImageAdjustment(.brightness, value: 0.4)
        XCTAssertFalse(editor.canUndo)
        XCTAssertFalse(ImageMetadataManager.shared.hasEditHistory(for: identifier))
        adjustment.commitImageAdjustmentEditing(.brightness)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        // 綴りも既存の保存契約。キー移行は ViewModel 分離と混在させない。
        XCTAssertEqual(image.metadata?.additionalMetadata["brigthtnessAdjustment"], "0.4")
        XCTAssertEqual(ImageMetadataManager.shared.getEditHistory(for: identifier).filter {
            $0.fieldKey == "brigthtnessAdjustment"
        }.count, 1)
        adjustment.commitImageAdjustmentEditing(.brightness)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        // 現行のメタデータ層は同値の確定も記録する。共通編集履歴とは別の契約。
        XCTAssertEqual(ImageMetadataManager.shared.getEditHistory(for: identifier).count, 2)
        editor.undo()
        XCTAssertEqual(image.brightnessAdjustment, 0)
        editor.redo()
        XCTAssertEqual(image.brightnessAdjustment, 0.4)
    }

    @MainActor
    func test_selection_resetsStartValuesSynchronously() throws {
        let scheduler = ManualImageRenderScheduler()
        let (editor, parent, first) = try makeContext(refresh: ImageRenderRefreshUseCase(renderScheduler: scheduler))
        let second = ImageElementFactory().makeElement(imageData: try XCTUnwrap(first.imageData), importOrder: 1)
        second.brightnessAdjustment = 0.3
        editor.project.addElement(second)
        let adjustment = parent.imageAdjustment
        adjustment.beginImageAdjustmentEditing(.brightness)
        adjustment.updateImageAdjustment(.brightness, value: 0.1)
        adjustment.updateImageAdjustment(.gaussianBlur, value: 2)
        XCTAssertNotNil(scheduler.pending)
        editor.selectElement(second)
        XCTAssertTrue(adjustment.imageElement === second)
        XCTAssertTrue(parent.filters.imageElement === second)
        XCTAssertNil(scheduler.pending)
        adjustment.beginImageAdjustmentEditing(.brightness)
        adjustment.updateImageAdjustment(.brightness, value: 0.5)
        adjustment.commitImageAdjustmentEditing(.brightness)
        editor.undo()
        XCTAssertEqual(second.brightnessAdjustment, 0.3)
        XCTAssertEqual(first.brightnessAdjustment, 0.1)
        editor.clearSelection()
        XCTAssertNil(adjustment.imageElement)
        XCTAssertNil(parent.filters.imageElement)
        adjustment.updateImageAdjustment(.brightness, value: 0.9)
        parent.filters.applyFilterPreset(FilterCatalog.vintageWarm)
        XCTAssertEqual(second.brightnessAdjustment, 0.3)
        XCTAssertNil(second.appliedFilterPresetId)
    }

    @MainActor
    func test_manualEdits_invalidateRunningFilter() async throws {
        // 通常スライダー・予約付きカーブ・即時ティントの全経路で共有世代を使う。
        for edit in 0..<3 {
            let scheduler = ManualImageRenderScheduler()
            let renderer = ControlledImageRenderer()
            let refresh = ImageRenderRefreshUseCase(renderScheduler: scheduler, renderFullQuality: renderer.render)
            let (editor, parent, image) = try makeContext(refresh: refresh)
            let started = expectation(description: "フィルター描画開始")
            renderer.onStart = { started.fulfill() }
            parent.filters.applyFilterPreset(FilterCatalog.vintageWarm)
            scheduler.runPending()
            await fulfillment(of: [started], timeout: 1)
            switch edit {
            case 0:
                parent.imageAdjustment.beginImageAdjustmentEditing(.brightness)
                parent.imageAdjustment.updateImageAdjustment(.brightness, value: 0.4)
            case 1:
                var curve = ToneCurveData()
                curve.rgbPoints[1].output = 0.7
                parent.imageAdjustment.updateToneCurveData(curve)
                XCTAssertEqual(image.toneCurveData, curve)
                XCTAssertEqual(editor.getHistoryDescriptions().count, 1, "カーブは従来どおり履歴を追加しない")
            default:
                parent.imageAdjustment.updateTintColor(.blue, intensity: 0.5)
                XCTAssertEqual(editor.getHistoryDescriptions().count, 2)
            }
            let stale = UIImage()
            let returned = expectation(description: "古い描画復帰")
            renderer.onReturn = { returned.fulfill() }
            renderer.finish(0, with: stale)
            await fulfillment(of: [returned], timeout: 1)
            XCTAssertFalse(image.cachedImage === stale)
            let marker = UIImage()
            image.cachedImage = marker
            XCTAssertFalse(image.image === marker, "古いフィルター完了で手動調整のプレビューを終了しない")
            withExtendedLifetime(editor) {}
        }
    }

    @MainActor
    func test_reselection_discardsRunningFilter() async throws {
        let scheduler = ManualImageRenderScheduler()
        let renderer = ControlledImageRenderer()
        let refresh = ImageRenderRefreshUseCase(renderScheduler: scheduler, renderFullQuality: renderer.render)
        let (editor, parent, image) = try makeContext(refresh: refresh)
        let started = expectation(description: "フィルター描画開始")
        renderer.onStart = { started.fulfill() }
        parent.filters.applyFilterPreset(FilterCatalog.vintageWarm)
        scheduler.runPending()
        await fulfillment(of: [started], timeout: 1)
        editor.clearSelection()
        editor.selectElement(image)
        let marker = UIImage()
        image.cachedImage = marker
        let returned = expectation(description: "古い描画復帰")
        renderer.onReturn = { returned.fulfill() }
        renderer.finish(0, with: UIImage())
        await fulfillment(of: [returned], timeout: 1)
        XCTAssertTrue(image.cachedImage === marker, "同じ ID に戻っても旧要求は無効")
        XCTAssertTrue(parent.filters.imageElement === image)
    }

    @MainActor
    func test_pendingFilter_releasesPanelOwners() async throws {
        let scheduler = ManualImageRenderScheduler()
        let renderer = ControlledImageRenderer()
        var context: (EditorViewModel, ElementViewModel, ImageElement)? = try makeContext(
            refresh: ImageRenderRefreshUseCase(renderScheduler: scheduler, renderFullQuality: renderer.render)
        )
        weak var editor = context?.0
        weak var parent = context?.1
        weak var adjustment = context?.1.imageAdjustment
        weak var filters = context?.1.filters
        let started = expectation(description: "フィルター描画開始")
        renderer.onStart = { started.fulfill() }
        context?.1.filters.applyFilterPreset(FilterCatalog.vintageWarm)
        scheduler.runPending()
        await fulfillment(of: [started], timeout: 1)
        context = nil
        XCTAssertNil(editor)
        XCTAssertNil(parent)
        XCTAssertNil(adjustment)
        XCTAssertNil(filters)
        let returned = expectation(description: "所有者解放後の描画復帰")
        renderer.onReturn = { returned.fulfill() }
        renderer.finish(0, with: UIImage())
        await fulfillment(of: [returned], timeout: 1)
    }
}
