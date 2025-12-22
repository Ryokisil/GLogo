//
//  OperationMemoryLeakTests.swift
//  GLogoTests
//
//  概要:
//  編集操作まわりのメモリリークを単体で検証するテスト。
//

import XCTest
@testable import GLogo

final class OperationMemoryLeakTests: XCTestCase {
    /// 要素操作（移動など）におけるメモリリークテスト
    /// 操作履歴やコールバックで循環参照が発生しないことを確認
    @MainActor
    func testManipulationDoesNotLeak() {
        weak var weakViewModel: EditorViewModel?

        autoreleasepool {
            let viewModel = EditorViewModel()
            weakViewModel = viewModel

            let element = ShapeElement(shapeType: .rectangle)
            viewModel.addElement(element)
            viewModel.selectElement(element)

            viewModel.startManipulation(.move, at: CGPoint(x: 0, y: 0))
            viewModel.continueManipulation(at: CGPoint(x: 100, y: 100))
            viewModel.endManipulation()
        }

        XCTAssertNil(weakViewModel, "操作処理中にメモリリークが発生しています")
    }

    /// アンドゥ・リドゥ操作におけるメモリリークテスト
    /// イベントソーシング履歴が要素やViewModelに強参照を残さないことを確認
    @MainActor
    func testUndoRedoDoesNotLeak() {
        weak var weakViewModel: EditorViewModel?

        autoreleasepool {
            let viewModel = EditorViewModel()
            weakViewModel = viewModel

            let element = TextElement(text: "テスト")
            viewModel.addElement(element)
            viewModel.selectElement(element)
            viewModel.updateTextContent(element, newText: "変更後")

            viewModel.undo()
            viewModel.redo()
        }

        XCTAssertNil(weakViewModel, "アンドゥ・リドゥ処理中にメモリリークが発生しています")
    }
}
