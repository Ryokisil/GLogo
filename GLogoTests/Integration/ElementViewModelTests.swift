// 共通属性の更新が選択と同期し、別要素や削除済み要素を変更しないことを検証する。

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
    private func editCommonProperties(_ panel: ElementViewModel) {
        panel.updateName("After")
        panel.updateOpacity(0.4)
        panel.updateVisibility(false)
        panel.updateLock(true)
    }

    @MainActor
    private func assertUnchanged(_ text: TextElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(text.name, "Before", file: file, line: line)
        XCTAssertEqual(text.opacity, 1, file: file, line: line)
        XCTAssertTrue(text.isVisible, file: file, line: line)
        XCTAssertFalse(text.isLocked, file: file, line: line)
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
    func test_selectionSwitch_editsOnlyCurrentElement() async {
        let targets: [LogoElement] = [TextElement(text: "Next"), ShapeElement(shapeType: .rectangle),
                                     ImageElement(imageData: snapshotImage(.blue).pngData()!)]
        for target in targets {
            let (editor, panel, original) = await makeContext()
            editor.project.addElement(target)
            editor.selectElement(target)
            // RunLoopを進めず操作し、旧要素へ書き込まないことを確認する。
            editCommonProperties(panel)
            assertUnchanged(original)
            XCTAssertEqual(target.name, "After")
            XCTAssertEqual(target.opacity, 0.4)
            XCTAssertFalse(target.isVisible)
            XCTAssertTrue(target.isLocked)
            XCTAssertTrue(editor.selectedElement === target)
            XCTAssertTrue(panel.element === target)
            XCTAssertEqual(panel.elementType, target.type)
            if let image = target as? ImageElement {
                XCTAssertTrue(panel.imageElement === image)
            } else {
                XCTAssertNil(panel.imageElement)
            }
            XCTAssertTrue(editor.isProjectModified)
            // 共通属性は既存どおり履歴を積まない。履歴仕様の変更とは分ける。
            XCTAssertFalse(editor.canUndo)
        }
    }

    @MainActor
    func test_clearSelection_ignoresImmediateEdits() async {
        let (editor, panel, text) = await makeContext()
        editor.clearSelection()
        editCommonProperties(panel)
        assertUnchanged(text)
        XCTAssertNil(editor.selectedElement)
        XCTAssertNil(panel.element)
        XCTAssertNil(panel.elementType)
        XCTAssertFalse(editor.isProjectModified)
        XCTAssertFalse(editor.canUndo)
    }

    @MainActor
    func test_deleteSelection_ignoresEditsBeforeUndo() async {
        let (editor, panel, text) = await makeContext()
        editor.deleteSelectedElement()
        editCommonProperties(panel)
        assertUnchanged(text)
        XCTAssertTrue(editor.project.elements.isEmpty)
        XCTAssertNil(panel.element)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        editor.undo()
        XCTAssertTrue(editor.project.elements.first === text)
        assertUnchanged(text)
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

    @MainActor
    func test_commonEdits_notifyAndKeepRedo() async {
        let (editor, panel, text) = await makeContext()
        editor.textEdits.updateTextContent(text, newText: "Changed")
        editor.undo()
        var notifications = 0
        let observation = panel.objectWillChange.sink { notifications += 1 }
        editCommonProperties(panel)
        XCTAssertGreaterThan(notifications, 0)
        XCTAssertTrue(editor.canRedo)
        XCTAssertFalse(editor.canUndo)
        editor.redo()
        XCTAssertEqual(text.text, "Changed")
        XCTAssertEqual(text.name, "After")
        XCTAssertEqual(text.opacity, 0.4)
        XCTAssertFalse(text.isVisible)
        XCTAssertTrue(text.isLocked)
        XCTAssertTrue(editor.selectedElement === text)
        withExtendedLifetime(observation) {}
    }
}
