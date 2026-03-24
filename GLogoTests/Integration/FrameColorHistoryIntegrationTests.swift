//
//  FrameColorHistoryIntegrationTests.swift
//  GLogoTests
//
//  概要:
//  フレーム色の begin/preview/commit フローが履歴を1件単位で記録することを検証する結合テスト。
//

import XCTest
import UIKit
@testable import GLogo

/// フレーム色編集履歴の結合テスト
final class FrameColorHistoryIntegrationTests: XCTestCase {

    /// メインループを短時間回して Combine 通知を反映する
    /// - Parameters: なし
    /// - Returns: なし
    private func flushMainRunLoop() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }

    /// テスト用の画像編集コンテキストを生成する
    /// - Parameters: なし
    /// - Returns: LogoProject, ImageElement, EditorViewModel, ElementViewModel のタプル
    @MainActor
    private func makeImageEditingContext() throws -> (LogoProject, ImageElement, EditorViewModel, ElementViewModel) {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }
        let imageData = try XCTUnwrap(image.pngData())

        let project = LogoProject(name: "FrameColorHistory", canvasSize: CGSize(width: 1080, height: 1080))
        let imageElement = ImageElement(imageData: imageData, importOrder: 0)
        project.addElement(imageElement)

        let editorViewModel = EditorViewModel(project: project)
        let elementViewModel = ElementViewModel(editorViewModel: editorViewModel)

        editorViewModel.selectElement(imageElement)
        flushMainRunLoop()

        return (project, imageElement, editorViewModel, elementViewModel)
    }

    /// プレビュー中は履歴を積まず、commit 時に1件だけ履歴を積む
    /// - Parameters: なし
    /// - Returns: なし
    @MainActor
    func testFrameColorEditing_RecordsSingleHistoryOnCommit() throws {
        let (_, imageElement, editorViewModel, elementViewModel) = try makeImageEditingContext()
        let initialHistoryCount = editorViewModel.getHistoryDescriptions().count
        let originalHex = imageElement.frameColor.rgbaHexString

        elementViewModel.beginFrameColorEditing()
        elementViewModel.previewFrameColor(imageElement.frameColor.withAlphaComponent(0.42))
        elementViewModel.previewFrameColor(imageElement.frameColor.withAlphaComponent(0.28))

        XCTAssertEqual(editorViewModel.getHistoryDescriptions().count, initialHistoryCount)
        XCTAssertEqual(imageElement.frameColor.cgColor.alpha, 0.28, accuracy: 0.0001)

        elementViewModel.commitFrameColorEditing()

        XCTAssertEqual(editorViewModel.getHistoryDescriptions().count, initialHistoryCount + 1)
        XCTAssertEqual(imageElement.frameColor.cgColor.alpha, 0.28, accuracy: 0.0001)

        editorViewModel.undo()
        // UIColor インスタンス比較ではなく、保存フォーマット上の同値性を検証する。
        XCTAssertEqual(imageElement.frameColor.rgbaHexString, originalHex)
    }

    /// begin 後に見た目変更が無ければ commit しても履歴を積まない
    /// - Parameters: なし
    /// - Returns: なし
    @MainActor
    func testFrameColorEditing_WithoutChangeDoesNotRecordHistory() throws {
        let (_, imageElement, editorViewModel, elementViewModel) = try makeImageEditingContext()
        let initialHistoryCount = editorViewModel.getHistoryDescriptions().count
        let originalHex = imageElement.frameColor.rgbaHexString

        elementViewModel.beginFrameColorEditing()
        elementViewModel.previewFrameColor(imageElement.frameColor)
        elementViewModel.commitFrameColorEditing()

        XCTAssertEqual(editorViewModel.getHistoryDescriptions().count, initialHistoryCount)
        XCTAssertEqual(imageElement.frameColor.rgbaHexString, originalHex)
        XCTAssertFalse(editorViewModel.canUndo)
    }
}
