// 機能別 UseCase と共通の選択・履歴・所有関係の接続を検証する。

import Combine
import UIKit
import XCTest
@testable import GLogo

final class ElementEditIntegrationTests: XCTestCase {
    @MainActor
    func test_edits_shareHistoryAndPreserveSelection() {
        let text = TextElement(text: "Before")
        let shape = ShapeElement(shapeType: .rectangle)
        let project = LogoProject()
        project.addElement(text)
        project.addElement(shape)
        let editor = EditorViewModel(project: project)
        editor.selectElement(text)
        var selections = 0
        let observation = editor.$selectedElement.dropFirst().sink { _ in selections += 1 }

        editor.shapeEdits.updateShapeType(shape, newType: .circle)
        XCTAssertTrue(editor.selectedElement === text)
        XCTAssertEqual(selections, 0)
        XCTAssertTrue(editor.isProjectModified)

        editor.textEdits.updateTextContent(text, newText: "After")
        XCTAssertTrue(editor.selectedElement === text)
        XCTAssertEqual(selections, 1)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 2)
        editor.undo()
        XCTAssertEqual(text.text, "Before")
        XCTAssertEqual(shape.shapeType, .circle)
        editor.undo()
        XCTAssertEqual(shape.shapeType, .rectangle)
        editor.redo()
        XCTAssertEqual(shape.shapeType, .circle)
        withExtendedLifetime(observation) {}
    }

    @MainActor
    func test_shapePanel_routesThroughUseCase() {
        let shape = ShapeElement(shapeType: .rectangle)
        let project = LogoProject()
        project.addElement(shape)
        let editor = EditorViewModel(project: project)
        let element = ElementViewModel(editorViewModel: editor)
        editor.selectElement(shape)
        element.shapeEditing.updateShapeType(.star)
        XCTAssertEqual(shape.shapeType, .star)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        editor.undo()
        XCTAssertEqual(shape.shapeType, .rectangle)
    }

    @MainActor
    func test_duplicate_keepsIndependentEffectsAndUndoRedo() throws {
        let text = TextElement(text: "Original")
        text.position = CGPoint(x: 10, y: 30)
        text.lineSpacing = 4
        let glow = GlowEffect(color: .red, radius: 8)
        text.effects = [glow]
        let project = LogoProject()
        project.addElement(text)
        let editor = EditorViewModel(project: project)
        let panel = ElementViewModel(editorViewModel: editor)
        editor.selectElement(text)

        editor.duplicateSelectedElement()
        let copy = try XCTUnwrap(editor.selectedElement as? TextElement)
        let copiedGlow = try XCTUnwrap(copy.effects.first as? GlowEffect)
        XCTAssertNotEqual(copy.id, text.id)
        XCTAssertFalse(copy === text)
        XCTAssertFalse(copiedGlow === glow)
        XCTAssertEqual(copy.position, CGPoint(x: 30, y: 50))
        XCTAssertEqual(copy.text, text.text)
        XCTAssertEqual(copy.lineSpacing, 4)
        XCTAssertTrue(panel.textEditing.textElement === copy)
        XCTAssertEqual(project.elements.map(\.id), [text.id, copy.id])
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        XCTAssertTrue(editor.isProjectModified)

        copiedGlow.radius = 20
        XCTAssertEqual(glow.radius, 8)
        editor.undo()
        XCTAssertEqual(project.elements.map(\.id), [text.id])
        XCTAssertNil(editor.selectedElement)
        XCTAssertNil(panel.textEditing.textElement)
        XCTAssertFalse(editor.canUndo)
        editor.redo()
        XCTAssertEqual(project.elements.map(\.id), [text.id, copy.id])
        XCTAssertTrue(project.elements.last === copy)
        XCTAssertEqual(copiedGlow.radius, 20)
        XCTAssertEqual(glow.radius, 8)
        XCTAssertEqual(text.position, CGPoint(x: 10, y: 30))
        XCTAssertFalse(editor.canRedo)
    }

    @MainActor
    func test_duplicate_withoutSelectionKeepsRedo() {
        let editor = EditorViewModel()
        editor.addTextElement(position: .zero)
        editor.undo()
        XCTAssertNil(editor.selectedElement)
        editor.duplicateSelectedElement()
        XCTAssertTrue(editor.project.elements.isEmpty)
        XCTAssertFalse(editor.canUndo)
        XCTAssertTrue(editor.canRedo)
        editor.redo()
        XCTAssertEqual(editor.project.elements.count, 1)
    }

    @MainActor
    func test_retainedUseCases_doNotRetainEditor() {
        var editor: EditorViewModel? = EditorViewModel()
        let useCases = (editor!.textEdits, editor!.shapeEdits, editor!.imageEdits)
        weak var weakEditor = editor
        editor = nil
        XCTAssertNil(weakEditor)
        withExtendedLifetime(useCases) {}
    }
}
