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
}
