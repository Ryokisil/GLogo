

import XCTest
@testable import GLogo
import SwiftUI

// ヘルパー関数を含む拡張
extension XCTestCase {
    // メモリリーク検出の汎用ヘルパー
    func assertNoMemoryLeak<T: AnyObject>(_ instance: () -> T, file: StaticString = #file, line: UInt = #line) {
        weak var weakInstance: T?
        
        autoreleasepool {
            let strongInstance = instance()
            weakInstance = strongInstance
            XCTAssertNotNil(weakInstance)
        }
        
        XCTAssertNil(weakInstance, "インスタンスがメモリリークしています", file: file, line: line)
    }
}

/// ViewModelのメモリリーク検証テストクラス 継承させるためにfinal
final class ViewModelMemoryLeakTests: XCTestCase {
    /// 基本的なEditorViewModelのメモリリークがないことを検証
    /// EditorViewModelが単体で適切に解放されることを確認する
    func testEditorViewModelDoesNotLeak() {
        assertNoMemoryLeak {
            return EditorViewModel()
        }
    }
    /// ElementViewModelと関連するEditorViewModelの間でメモリリークがないことを検証
    /// 両ViewModelの参照関係が正しく設計され、循環参照を作らないことを確認する
    func testElementViewModelDoesNotLeak() {
        assertNoMemoryLeak {
            let editorVM = EditorViewModel()
            return ElementViewModel(editorViewModel: editorVM)
        }
    }
    /// 要素選択操作を含む複雑なシナリオでもメモリリークが発生しないことを検証
    /// 実際の使用パターンに近い状態で、ViewModelと要素間の参照関係が適切に管理されているか確認する
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

// 操作に関するテスト
final class OperationMemoryLeakTests: XCTestCase {
    /// 要素操作（移動など）におけるメモリリークテスト
    ///
    /// 目的
    /// 要素の追加、選択、移動操作を行った後、EditorViewModelが適切に解放されることを確認
    /// 操作開始、操作続行、操作終了のシーケンスを実行し、操作履歴の管理が適切に行われているか検証
    ///
    /// 理由
    /// 操作履歴の記録時に循環参照が発生する可能性がある
    /// 特に操作イベントのコールバックやクロージャで自己参照を行う場合にリークの危険性がある
    func testManipulationDoesNotLeak() {
        weak var weakViewModel: EditorViewModel?
        
        autoreleasepool {
            let viewModel = EditorViewModel()
            weakViewModel = viewModel
            
            // 要素を追加
            let element = ShapeElement(shapeType: .rectangle)
            viewModel.addElement(element)
            viewModel.selectElement(element)
            
            // 操作を実行
            viewModel.startManipulation(.move, at: CGPoint(x: 0, y: 0))
            viewModel.continueManipulation(at: CGPoint(x: 100, y: 100))
            viewModel.endManipulation()
        }
        
        XCTAssertNil(weakViewModel, "操作処理中にメモリリークが発生しています")
    }
    /// アンドゥ・リドゥ操作におけるメモリリークテスト
    ///
    /// 目的
    /// 要素の追加、テキスト編集、アンドゥ、リドゥの操作を行った後、
    /// EditorViewModelが適切に解放されることを確認
    /// イベントソーシングによる操作履歴の実装が適切にメモリ管理されているか検証
    ///
    /// 理由
    /// 操作履歴スタックが要素やViewModelへの強参照を持ち続ける可能性がある
    /// アンドゥ・リドゥ操作はイベントの適用と取り消しを行うため、
    /// イベントオブジェクトとモデルオブジェクト間で循環参照を作りやすい
    func testUndoRedoDoesNotLeak() {
        weak var weakViewModel: EditorViewModel?
        
        autoreleasepool {
            let viewModel = EditorViewModel()
            weakViewModel = viewModel
            
            // アンドゥ用の操作を実行
            let element = TextElement(text: "テスト")
            viewModel.addElement(element)
            viewModel.selectElement(element)
            viewModel.updateTextContent(element, newText: "変更後")
            
            // アンドゥ・リドゥを実行
            viewModel.undo()
            viewModel.redo()
        }
        
        XCTAssertNil(weakViewModel, "アンドゥ・リドゥ処理中にメモリリークが発生しています")
    }
}
