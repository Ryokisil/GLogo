// 変形の共有状態、履歴、選択・保存境界と Canvas 接続を検証する。

import Combine
import SwiftUI
import XCTest
@testable import GLogo

final class ElementTransformViewModelTests: XCTestCase {
    @MainActor
    func test_manipulations_preserveUndoRedo() {
        let cases: [(ElementManipulationType, CGPoint, CGPoint, CGPoint, CGSize, CGFloat)] = [
            (.move, .zero, CGPoint(x: 30, y: 40), CGPoint(x: 40, y: 60), CGSize(width: 100, height: 80), 0.2),
            (.resize, .zero, CGPoint(x: -200, y: 20), CGPoint(x: 10, y: 20), CGSize(width: 10, height: 100), 0.2),
            (.rotate, CGPoint(x: 110, y: 60), CGPoint(x: 60, y: 110), CGPoint(x: 10, y: 20), CGSize(width: 100, height: 80), 0.2 + .pi / 2)
        ]
        for (kind, start, end, position, size, rotation) in cases {
            let element = ShapeElement(shapeType: .rectangle)
            element.position = CGPoint(x: 10, y: 20)
            element.size = CGSize(width: 100, height: 80)
            element.rotation = 0.2
            let project = LogoProject()
            project.addElement(element)
            let editor = EditorViewModel(project: project)
            editor.selectElement(element)
            editor.transform.startManipulation(kind, at: start)
            editor.transform.continueManipulation(at: end)
            editor.transform.continueManipulation(at: end)
            XCTAssertEqual(element.position, position)
            XCTAssertEqual(element.size, size)
            XCTAssertEqual(element.rotation, rotation, accuracy: 0.0001)
            XCTAssertFalse(editor.canUndo, "プレビュー中は履歴を積まない")
            editor.transform.endManipulation()
            editor.transform.endManipulation()
            XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
            XCTAssertEqual(editor.transform.manipulationType, .none)
            editor.undo()
            XCTAssertEqual(element.position, CGPoint(x: 10, y: 20))
            XCTAssertEqual(element.size, CGSize(width: 100, height: 80))
            XCTAssertEqual(element.rotation, 0.2)
            editor.redo()
            XCTAssertEqual(element.position, position)
            XCTAssertEqual(element.size, size)
            XCTAssertEqual(element.rotation, rotation, accuracy: 0.0001)
        }
    }

    @MainActor
    func test_selection_discardsPendingManipulationImmediately() {
        let first = ShapeElement(shapeType: .rectangle)
        let second = ShapeElement(shapeType: .circle)
        second.position = CGPoint(x: 200, y: 300)
        let project = LogoProject()
        project.addElement(first)
        project.addElement(second)
        let editor = EditorViewModel(project: project)
        editor.selectElement(first)
        editor.transform.startManipulation(.move, at: .zero)
        editor.transform.continueManipulation(at: CGPoint(x: 20, y: 20))
        editor.selectElement(second)
        editor.transform.continueManipulation(at: CGPoint(x: 50, y: 50))
        editor.transform.endManipulation()
        XCTAssertEqual(second.position, CGPoint(x: 200, y: 300))
        XCTAssertFalse(editor.canUndo)
        editor.transform.startManipulation(.move, at: .zero)
        editor.transform.continueManipulation(at: CGPoint(x: 10, y: 15))
        editor.transform.endManipulation()
        XCTAssertEqual(second.position, CGPoint(x: 210, y: 315))
        editor.undo()
        XCTAssertEqual(second.position, CGPoint(x: 200, y: 300))
        editor.clearSelection()
        editor.transform.startManipulation(.move, at: .zero)
        XCTAssertEqual(editor.transform.manipulationType, .none)
    }

    @MainActor
    func test_concurrentGestures_finishRenderingAfterLastEnd() throws {
        let image = try makeImageElement()
        let project = LogoProject()
        project.addElement(image)
        let editor = EditorViewModel(project: project)
        editor.selectElement(image)
        let transform = editor.transform
        transform.applyGestureTransform(kind: .rotate, translation: nil, scale: nil, rotation: 0.3, ended: false)
        transform.applyGestureTransform(kind: .magnify, translation: nil, scale: 1.5, rotation: nil, ended: false)
        transform.applyGestureTransform(kind: .magnify, translation: nil, scale: nil, rotation: nil, ended: true)
        let fullQualityMarker = makeImage()
        image.cachedImage = fullQualityMarker
        XCTAssertFalse(image.image === fullQualityMarker, "回転が続く間はプレビュー経路を維持する")
        transform.applyGestureTransform(kind: .rotate, translation: nil, scale: nil, rotation: nil, ended: true)
        XCTAssertTrue(image.image === fullQualityMarker)
        XCTAssertTrue(editor.isProjectModified)
        // SwiftUI 側は従来どおり変更フラグのみ。履歴方針の統合はこの分離の範囲外。
        XCTAssertFalse(editor.canUndo)
    }

    @MainActor
    func test_save_discardsBothInputsAndBlocksMutations() throws {
        let saver = PhotoLibrarySavingStub()
        let image = try makeImageElement()
        image.position = .zero
        let project = LogoProject()
        project.addElement(image)
        let editor = EditorViewModel(project: project, photoLibrarySaver: saver)
        editor.selectElement(image)
        let transform = editor.transform
        transform.startManipulation(.move, at: .zero)
        transform.continueManipulation(at: CGPoint(x: 5, y: 8))
        transform.applyGestureTransform(kind: .rotate, translation: nil, scale: nil, rotation: 0.3, ended: false)
        editor.saveToPhotoLibrary { _ in }
        transform.continueManipulation(at: CGPoint(x: 50, y: 80))
        transform.applyGestureTransform(kind: .rotate, translation: nil, scale: nil, rotation: 1, ended: false)
        transform.resetRotation()
        transform.updatePosition(.zero)
        transform.endManipulation()
        XCTAssertEqual(image.position, CGPoint(x: 5, y: 8))
        XCTAssertEqual(image.rotation, 0.3)
        XCTAssertFalse(editor.canUndo)
        let marker = makeImage()
        image.cachedImage = marker
        XCTAssertTrue(image.image === marker)
        XCTAssertFalse(transform.prepareImageRenderingForManipulation(in: project, highResolutionThreshold: 1))
        saver.finish(.success(()))
        transform.applyGestureTransform(kind: .rotate, translation: nil, scale: nil, rotation: 0.2, ended: false)
        XCTAssertEqual(image.rotation, 0.5, accuracy: 0.0001, "保存前の累積基準を再利用しない")
    }

    @MainActor
    func test_selection_finishesPreparedRendering() throws {
        let first = try makeImageElement()
        let second = try makeImageElement()
        let project = LogoProject()
        project.addElement(first)
        project.addElement(second)
        let editor = EditorViewModel(project: project)
        editor.selectElement(first)
        XCTAssertTrue(editor.transform.prepareImageRenderingForManipulation(in: project, highResolutionThreshold: 1))
        editor.transform.startManipulation(.move, at: .zero)
        let marker = makeImage()
        first.cachedImage = marker
        second.cachedImage = marker
        XCTAssertFalse(first.image === marker)
        editor.selectElement(second)
        XCTAssertTrue(first.image === marker)
        XCTAssertTrue(second.image === marker)
        XCTAssertEqual(editor.transform.manipulationType, .none)
    }

    @MainActor
    func test_reselection_delayedNotificationKeepsNewPreview() throws {
        let first = try makeImageElement()
        let second = try makeImageElement()
        let project = LogoProject()
        project.addElement(first)
        project.addElement(second)
        let editor = EditorViewModel(project: project)
        let panel = ElementViewModel(editorViewModel: editor)
        editor.selectElement(first)
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        editor.selectElement(second)
        editor.selectElement(first)
        panel.transform.applyGestureTransform(kind: .rotate, translation: nil, scale: nil, rotation: 0.3, ended: false)
        // 親の非同期選択購読が、子の同期選択・操作開始より後に届く順序を再現する。
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        let marker = makeImage()
        first.cachedImage = marker
        XCTAssertFalse(first.image === marker)
        panel.transform.applyGestureTransform(kind: .rotate, translation: nil, scale: nil, rotation: 0.5, ended: false)
        XCTAssertEqual(first.rotation, 0.5)
        withExtendedLifetime(panel) {}
    }

    @MainActor
    func test_sharedChild_notifiesAndDoesNotRetainEditor() {
        var editor: EditorViewModel? = EditorViewModel()
        let panel = ElementViewModel(editorViewModel: editor!)
        let transform = panel.transform
        XCTAssertTrue(transform === editor?.transform)
        let shape = ShapeElement(shapeType: .rectangle)
        editor?.addElement(shape)
        var notifications = 0
        let observation = editor!.objectWillChange.sink { notifications += 1 }
        transform.startManipulation(.move, at: .zero)
        XCTAssertGreaterThan(notifications, 0)
        let isReleased = { [weak editor] in editor == nil }
        editor = nil
        XCTAssertTrue(isReleased())
        let oldPosition = shape.position
        transform.continueManipulation(at: CGPoint(x: 100, y: 100))
        XCTAssertEqual(shape.position, oldPosition)
        withExtendedLifetime(observation) {}
    }

    @MainActor
    func test_canvasCallbacks_useSharedTransform() {
        let editor = EditorViewModel()
        let shape = ShapeElement(shapeType: .rectangle)
        shape.position = .zero
        editor.addElement(shape)
        let representable = CanvasViewRepresentable(viewModel: editor, deleteEffect: .constant(DeleteEffectState()))
        let coordinator = CanvasViewRepresentable.Coordinator(representable)
        let canvas = CanvasView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        canvas.project = editor.project
        coordinator.setupCallbacks(canvasView: canvas)
        let historyCount = editor.getHistoryDescriptions().count
        canvas.onManipulationStarted?(.move, .zero)
        canvas.onManipulationChanged?(CGPoint(x: 20, y: 30))
        canvas.onManipulationEnded?()
        XCTAssertEqual(shape.position, CGPoint(x: 20, y: 30))
        XCTAssertEqual(editor.getHistoryDescriptions().count, historyCount + 1)
        editor.undo()
        XCTAssertEqual(shape.position, .zero)
    }

    @MainActor
    func test_noChange_doesNotRecordHistory() {
        let shape = ShapeElement(shapeType: .rectangle)
        let project = LogoProject()
        project.addElement(shape)
        let editor = EditorViewModel(project: project)
        editor.selectElement(shape)
        editor.transform.startManipulation(.move, at: .zero)
        editor.transform.endManipulation()
        XCTAssertFalse(editor.canUndo)
        XCTAssertFalse(editor.isProjectModified)
    }

    private func makeImageElement() throws -> ImageElement {
        ImageElement(imageData: try XCTUnwrap(makeImage().pngData()))
    }

    private func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }
    }
}
