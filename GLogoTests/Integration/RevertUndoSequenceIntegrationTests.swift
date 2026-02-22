//
//  RevertUndoSequenceIntegrationTests.swift
//  GLogoTests
//
//  概要:
//  Revert後のUndo挙動が直感に沿うこと（1回目でRevert前の調整へ戻る）を検証する結合テスト。
//

import XCTest
import UIKit
@testable import GLogo

/// RevertとUndoの連続操作を検証する結合テスト
final class RevertUndoSequenceIntegrationTests: XCTestCase {

    /// 手順:
    /// 1) 画像追加
    /// 2) 彩度を2.0へ変更
    /// 3) Revert（彩度1.0へ戻る）
    /// 4) Undoを1回実行
    /// 5) Undoを2回実行
    /// 6) Undoを3回実行
    ///
    /// 期待:
    /// - Undo1回目でRevert前の調整（彩度2.0）へ戻る
    /// - Undo2回目で彩度変更前（1.0）へ戻る
    /// - Undo3回目で要素追加が取り消され、画像要素が消える
    @MainActor
    func testRevertThenUndo_UndoFirstRestoresPreRevertAdjustment() throws {
        let canvasSize = CGSize(width: 1080, height: 1920)
        let project = LogoProject(name: "revert-undo-sequence", canvasSize: canvasSize)
        let viewModel = EditorViewModel(project: project)

        let imageData = try XCTUnwrap(makeSolidImage(color: .white, size: CGSize(width: 64, height: 64)).pngData())
        let imageElement = ImageElement(imageData: imageData, importOrder: 0)

        // 1) 画像追加（履歴: ElementAdded）
        viewModel.addElement(imageElement)
        XCTAssertEqual(project.elements.count, 1)
        XCTAssertEqual(viewModel.getHistoryDescriptions().count, 1)

        // 2) 彩度を2.0へ変更（履歴: ImageSaturationChanged）
        let saturationEvent = ImageSaturationChangedEvent(
            elementId: imageElement.id,
            oldSaturation: 1.0,
            newSaturation: 2.0
        )
        viewModel.applyEvent(saturationEvent)
        XCTAssertEqual(imageElement.saturationAdjustment, 2.0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.getHistoryDescriptions().count, 2)

        // 3) Revert（履歴イベントとして記録される経路を使用）
        viewModel.revertSelectedImageToInitialState()
        XCTAssertEqual(imageElement.saturationAdjustment, 1.0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.getHistoryDescriptions().count, 3, "RevertはUndo対象として履歴に積まれるべき")

        // 4) Undo 1回目（Revertを取り消し、彩度2.0へ戻る）
        viewModel.undo()
        XCTAssertEqual(project.elements.count, 1)
        let elementAfterFirstUndo = try XCTUnwrap(project.elements.first as? ImageElement)
        XCTAssertEqual(elementAfterFirstUndo.saturationAdjustment, 2.0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.getHistoryDescriptions().count, 2)

        // 5) Undo 2回目（彩度イベントを取り消して1.0へ戻る）
        viewModel.undo()
        XCTAssertEqual(project.elements.count, 1)
        let elementAfterSecondUndo = try XCTUnwrap(project.elements.first as? ImageElement)
        XCTAssertEqual(elementAfterSecondUndo.saturationAdjustment, 1.0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.getHistoryDescriptions().count, 1)

        // 6) Undo 3回目（追加イベント取り消しで要素削除）
        viewModel.undo()
        XCTAssertEqual(project.elements.count, 0)
        XCTAssertEqual(viewModel.getHistoryDescriptions().count, 0)
    }

    // MARK: - Helpers

    /// 単色画像を生成する
    /// - Parameters:
    ///   - color: 塗りつぶし色
    ///   - size: 画像サイズ
    /// - Returns: 生成したUIImage
    private func makeSolidImage(color: UIColor, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
