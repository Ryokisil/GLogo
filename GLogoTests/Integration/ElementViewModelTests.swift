// 選択の変更・削除が、パネルの参照する要素と種類へ即座に反映されることを検証する。

import Combine
import UIKit
import XCTest
@testable import GLogo

final class ElementViewModelTests: XCTestCase {
    @MainActor
    private func makeContext() async -> (EditorViewModel, ElementViewModel, TextElement) {
        let text = TextElement(text: "Original")
        text.name = "Before"
        let project = LogoProject()
        project.addElement(text)
        let editor = EditorViewModel(project: project)
        editor.selectElement(text)
        let panel = ElementViewModel(editorViewModel: editor)
        // 初期選択だけ待ち、以降の選択変更と操作は同じMainActorの処理内で行う。
        let selected = expectation(description: "初期選択を受信")
        let observation = panel.$element.filter { $0 === text }.prefix(1).sink { _ in selected.fulfill() }
        await fulfillment(of: [selected], timeout: 1)
        withExtendedLifetime(observation) {}
        return (editor, panel, text)
    }

    @MainActor
    func test_initialSelection_isAvailableImmediately() {
        let text = TextElement(text: "Selected")
        let project = LogoProject()
        project.addElement(text)
        let editor = EditorViewModel(project: project)
        editor.selectElement(text)
        let panel = ElementViewModel(editorViewModel: editor)
        XCTAssertTrue(panel.element === text)
        XCTAssertEqual(panel.elementType, .text)
        XCTAssertTrue(panel.textEditing.textElement === text)
    }

    @MainActor
    func test_selectionSwitch_updatesReferencesImmediately() async {
        let targets: [LogoElement] = [TextElement(text: "Next"), ShapeElement(shapeType: .rectangle),
                                     ImageElement(imageData: snapshotImage(.blue).pngData()!)]
        for target in targets {
            let (editor, panel, _) = await makeContext()
            editor.project.addElement(target)
            editor.selectElement(target)
            // RunLoopを進めずに確認し、次の操作が旧要素へ届かないことの前提とする。
            XCTAssertTrue(editor.selectedElement === target)
            XCTAssertTrue(panel.element === target)
            XCTAssertEqual(panel.elementType, target.type)
            if let image = target as? ImageElement {
                XCTAssertTrue(panel.imageElement === image)
            } else {
                XCTAssertNil(panel.imageElement)
            }
        }
    }

    @MainActor
    func test_deleteSelection_clearsReferencesAndUndoRestores() async {
        let (editor, panel, text) = await makeContext()
        editor.deleteSelectedElement()
        XCTAssertTrue(editor.project.elements.isEmpty)
        XCTAssertNil(panel.element)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        editor.undo()
        XCTAssertTrue(editor.project.elements.first === text)
        XCTAssertFalse(editor.canUndo)
        editor.redo()
        XCTAssertTrue(editor.project.elements.isEmpty)
    }

    @MainActor
    func test_imageSelection_clearsImageReferencesImmediately() {
        let image = ImageElement(imageData: snapshotImage(.blue).pngData()!)
        let text = TextElement(text: "Next")
        let project = LogoProject()
        project.addElement(image)
        project.addElement(text)
        let editor = EditorViewModel(project: project)
        let panel = ElementViewModel(editorViewModel: editor)
        editor.selectElement(image)
        XCTAssertTrue(panel.imageElement === image)
        XCTAssertTrue(panel.canRequestUpscale)
        editor.selectElement(text)
        XCTAssertNil(panel.imageElement)
        XCTAssertFalse(panel.canRequestUpscale)
        XCTAssertTrue(panel.textEditing.textElement === text)
        editor.selectElement(image)
        editor.clearSelection()
        XCTAssertNil(panel.imageElement)
        XCTAssertNil(panel.element)
        XCTAssertNil(panel.elementType)
        XCTAssertFalse(panel.canRequestUpscale)
    }
}
