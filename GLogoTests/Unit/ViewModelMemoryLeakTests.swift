//
//  ViewModelMemoryLeakTests.swift
//  GLogoTests
//
//  概要:
//  EditorViewModel / ElementViewModel のメモリリークを単体で検証するテスト。
//

import XCTest
@testable import GLogo

final class ViewModelMemoryLeakTests: XCTestCase {
    /// 基本的なEditorViewModelのメモリリークがないことを検証
    /// EditorViewModelが単体で適切に解放されることを確認する
    @MainActor
    func testEditorViewModelDoesNotLeak() {
        assertNoMemoryLeak {
            return EditorViewModel()
        }
    }

    /// ElementViewModelと関連するEditorViewModelの間でメモリリークがないことを検証
    /// 両ViewModelの参照関係が正しく設計され、循環参照を作らないことを確認する
    @MainActor
    func testElementViewModelDoesNotLeak() {
        assertNoMemoryLeak {
            let editorVM = EditorViewModel()
            return ElementViewModel(editorViewModel: editorVM)
        }
    }

    /// 要素選択操作を含む複雑なシナリオでもメモリリークが発生しないことを検証
    /// 実際の使用パターンに近い状態で、ViewModelと要素間の参照関係が適切に管理されているか確認する
    @MainActor
    func testElementViewModelWithSelectedElementDoesNotLeak() {
        assertNoMemoryLeak {
            let editorVM = EditorViewModel()
            let elementVM = ElementViewModel(editorViewModel: editorVM)

            // テスト要素を作成し、追加・選択操作を実行
            let textElement = TextElement(text: "テスト")
            editorVM.addElement(textElement)
            editorVM.selectElement(textElement)

            return elementVM
        }
    }
}
