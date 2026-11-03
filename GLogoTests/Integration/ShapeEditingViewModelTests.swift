// 図形編集の同期選択、履歴・通知、無変更操作と親子の寿命を検証する。

import Combine
import UIKit
import XCTest
@testable import GLogo

final class ShapeEditingViewModelTests: XCTestCase {
    @MainActor
    private func makeContext() -> (EditorViewModel, ShapeEditingViewModel, ShapeElement) {
        let shape = ShapeElement(shapeType: .rectangle)
        let project = LogoProject()
        project.addElement(shape)
        let editor = EditorViewModel(project: project)
        editor.selectElement(shape)
        let child = ShapeEditingViewModel(edits: editor.shapeEdits, selection: editor.$selectedElement.eraseToAnyPublisher())
        return (editor, child, shape)
    }

    @MainActor
    func test_fillEdits_preserveUndoRedo() {
        let (editor, child, shape) = makeContext()
        child.updateFillMode(.gradient)
        child.updateFillColor(.orange)
        child.updateGradientColors(startColor: .red, endColor: .green)
        XCTAssertEqual(shape.fillMode, .gradient)
        XCTAssertTrue(shape.fillColor.isEqual(UIColor.orange))
        XCTAssertTrue(shape.gradientStartColor.isEqual(UIColor.red))
        XCTAssertTrue(shape.gradientEndColor.isEqual(UIColor.green))
        XCTAssertEqual(editor.getHistoryDescriptions().count, 3)
        editor.undo()
        XCTAssertTrue(shape.gradientStartColor.isEqual(UIColor.blue))
        XCTAssertTrue(shape.gradientEndColor.isEqual(UIColor.purple))
        XCTAssertTrue(shape.fillColor.isEqual(UIColor.orange))
        editor.undo()
        XCTAssertTrue(shape.fillColor.isEqual(UIColor.white))
        XCTAssertEqual(shape.fillMode, .gradient)
        editor.undo()
        XCTAssertEqual(shape.fillMode, .solid)
        XCTAssertFalse(editor.canUndo)
        editor.redo()
        editor.redo()
        editor.redo()
        XCTAssertEqual(shape.fillMode, .gradient)
        XCTAssertTrue(shape.fillColor.isEqual(UIColor.orange))
        XCTAssertTrue(shape.gradientStartColor.isEqual(UIColor.red))
        XCTAssertTrue(shape.gradientEndColor.isEqual(UIColor.green))
        XCTAssertTrue(child.shapeElement === shape)
        XCTAssertFalse(editor.canRedo)
    }

    @MainActor
    func test_strokeEdits_preserveUndoRedo() {
        let (editor, child, shape) = makeContext()
        child.updateStrokeMode(.none)
        child.updateStrokeColor(.red)
        child.updateStrokeWidth(9)
        XCTAssertEqual(shape.strokeMode, .none)
        XCTAssertTrue(shape.strokeColor.isEqual(UIColor.red))
        XCTAssertEqual(shape.strokeWidth, 9)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 3)
        editor.undo()
        XCTAssertEqual(shape.strokeWidth, 2)
        editor.undo()
        XCTAssertTrue(shape.strokeColor.isEqual(UIColor.black))
        editor.undo()
        XCTAssertEqual(shape.strokeMode, .solid)
        editor.redo()
        editor.redo()
        editor.redo()
        XCTAssertEqual(shape.strokeMode, .none)
        XCTAssertTrue(shape.strokeColor.isEqual(UIColor.red))
        XCTAssertEqual(shape.strokeWidth, 9)
        XCTAssertTrue(editor.selectedElement === shape)
    }

    @MainActor
    func test_geometryEdits_preserveUndoRedo() {
        let (editor, child, shape) = makeContext()
        child.updateShapeCornerRadius(18)
        child.updateShapeType(.polygon)
        child.updateSides(8)
        XCTAssertEqual(shape.cornerRadius, 18)
        XCTAssertEqual(shape.shapeType, .polygon)
        XCTAssertEqual(shape.sides, 8)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 3)
        editor.undo()
        XCTAssertEqual(shape.sides, 5)
        editor.undo()
        XCTAssertEqual(shape.shapeType, .rectangle)
        editor.undo()
        XCTAssertEqual(shape.cornerRadius, 10)
        editor.redo()
        editor.redo()
        editor.redo()
        XCTAssertEqual(shape.cornerRadius, 18)
        XCTAssertEqual(shape.shapeType, .polygon)
        XCTAssertEqual(shape.sides, 8)
    }

    @MainActor
    func test_unchangedGradient_keepsRedo() {
        let (editor, child, shape) = makeContext()
        // 開始色だけの変更も受け付け、同値の再通知はRedoを破棄しない。
        child.updateGradientColors(startColor: .red, endColor: shape.gradientEndColor)
        editor.undo()
        child.updateGradientColors(startColor: shape.gradientStartColor, endColor: shape.gradientEndColor)
        XCTAssertFalse(editor.canUndo)
        XCTAssertTrue(editor.canRedo)
        editor.redo()
        XCTAssertTrue(shape.gradientStartColor.isEqual(UIColor.red))
        XCTAssertTrue(shape.gradientEndColor.isEqual(UIColor.purple))
        child.updateGradientColors(startColor: shape.gradientStartColor, endColor: .green)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 2)
        editor.undo()
        XCTAssertTrue(shape.gradientStartColor.isEqual(UIColor.red))
        XCTAssertTrue(shape.gradientEndColor.isEqual(UIColor.purple))
    }

    @MainActor
    func test_selection_editsNewShapeImmediately() {
        let first = ShapeElement(shapeType: .rectangle)
        let second = ShapeElement(shapeType: .circle)
        let project = LogoProject()
        project.addElement(first)
        project.addElement(second)
        let editor = EditorViewModel(project: project)
        let parent = ElementViewModel(editorViewModel: editor)
        editor.selectElement(first)
        let oldWidth = first.strokeWidth
        editor.selectElement(second)
        parent.shapeEditing.updateStrokeWidth(9)
        XCTAssertTrue(parent.shapeEditing.shapeElement === second)
        XCTAssertEqual(first.strokeWidth, oldWidth)
        XCTAssertEqual(second.strokeWidth, 9)
        editor.undo()
        XCTAssertEqual(second.strokeWidth, oldWidth)
    }

    @MainActor
    func test_nonShapeSelection_ignoresEdits() {
        let shape = ShapeElement(shapeType: .rectangle)
        let text = TextElement(text: "Selected")
        let project = LogoProject()
        project.addElement(shape)
        project.addElement(text)
        let editor = EditorViewModel(project: project)
        let parent = ElementViewModel(editorViewModel: editor)
        editor.selectElement(shape)
        editor.selectElement(text)
        XCTAssertNil(parent.shapeEditing.shapeElement)
        parent.shapeEditing.updateShapeType(.star)
        parent.shapeEditing.updateCustomPoints([.zero])
        editor.clearSelection()
        parent.shapeEditing.updateShapeType(.polygon)
        XCTAssertNil(parent.shapeEditing.shapeElement)
        XCTAssertEqual(shape.shapeType, .rectangle)
        XCTAssertTrue(shape.customPoints.isEmpty)
        XCTAssertFalse(editor.canUndo)
        XCTAssertFalse(editor.isProjectModified)
    }

    @MainActor
    func test_unchangedValues_doNotRecordHistory() {
        let shape = ShapeElement(shapeType: .rectangle)
        let project = LogoProject()
        project.addElement(shape)
        let editor = EditorViewModel(project: project)
        let parent = ElementViewModel(editorViewModel: editor)
        editor.selectElement(shape)
        let child = parent.shapeEditing
        child.updateShapeType(shape.shapeType)
        child.updateFillMode(shape.fillMode)
        child.updateFillColor(shape.fillColor)
        child.updateGradientColors(startColor: shape.gradientStartColor, endColor: shape.gradientEndColor)
        child.updateGradientAngle(shape.gradientAngle)
        child.updateStrokeMode(shape.strokeMode)
        child.updateStrokeColor(shape.strokeColor)
        child.updateStrokeWidth(shape.strokeWidth)
        child.updateShapeCornerRadius(shape.cornerRadius)
        child.updateSides(shape.sides)
        XCTAssertFalse(editor.canUndo)
        XCTAssertFalse(editor.isProjectModified)
    }

    @MainActor
    func test_editsAndUndoRedo_notifyPanel() {
        let shape = ShapeElement(shapeType: .rectangle)
        let project = LogoProject()
        project.addElement(shape)
        let editor = EditorViewModel(project: project)
        editor.selectElement(shape)
        // 初期化時に現在の選択を受け取れることも確認する。
        let parent = ElementViewModel(editorViewModel: editor)
        let child = parent.shapeEditing
        XCTAssertTrue(child.shapeElement === shape)
        var angles: [CGFloat?] = []
        let observation = child.$shapeElement.dropFirst().sink { angles.append($0?.gradientAngle) }
        child.updateGradientAngle(90)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        editor.undo()
        editor.redo()
        XCTAssertEqual(angles, [90, 0, 90])
        XCTAssertTrue(editor.selectedElement === shape)
        withExtendedLifetime(observation) {}
    }

    @MainActor
    func test_customPoints_preserveHistoryFreeUpdates() {
        let shape = ShapeElement(shapeType: .custom)
        let project = LogoProject()
        project.addElement(shape)
        let editor = EditorViewModel(project: project)
        let parent = ElementViewModel(editorViewModel: editor)
        editor.selectElement(shape)
        var notifications = 0
        let observation = parent.shapeEditing.objectWillChange.sink { notifications += 1 }
        let points = [CGPoint.zero, CGPoint(x: 20, y: 0), CGPoint(x: 0, y: 20)]
        parent.shapeEditing.updateCustomPoints(points)
        XCTAssertEqual(shape.customPoints, points)
        XCTAssertTrue(editor.isProjectModified)
        XCTAssertTrue(editor.selectedElement === shape)
        XCTAssertFalse(editor.canUndo)
        XCTAssertGreaterThan(notifications, 0)
        withExtendedLifetime(observation) {}
    }

    @MainActor
    func test_childLifetime_doesNotRetainOwners() {
        var editor: EditorViewModel? = EditorViewModel()
        var parent: ElementViewModel? = ElementViewModel(editorViewModel: editor!)
        var child: ShapeEditingViewModel? = parent?.shapeEditing
        let editorReleased = { [weak editor] in editor == nil }
        let parentReleased = { [weak parent] in parent == nil }
        let childReleased = { [weak child] in child == nil }
        parent = nil
        editor = nil
        XCTAssertTrue(editorReleased())
        XCTAssertTrue(parentReleased())
        XCTAssertFalse(childReleased())
        child = nil
        XCTAssertTrue(childReleased())
    }
}
