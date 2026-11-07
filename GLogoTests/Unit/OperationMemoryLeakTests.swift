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

            let transform = viewModel.transform
            transform.applyGestureTransform(kind: .move, translation: .zero, scale: nil, rotation: nil, ended: false)
            transform.applyGestureTransform(
                kind: .move, translation: CGSize(width: 100, height: 100), scale: nil, rotation: nil, ended: false
            )
            transform.applyGestureTransform(kind: .move, translation: nil, scale: nil, rotation: nil, ended: true)
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
