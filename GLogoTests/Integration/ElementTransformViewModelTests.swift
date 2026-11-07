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
        // 同時に動かした回転と拡大縮小は、最後の終了で1件にまとまる。
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        XCTAssertTrue(editor.canUndo)
    }

    @MainActor
    func test_save_commitsGestureAndBlocksMutations() throws {
        let saver = PhotoLibrarySavingStub()
        let image = try makeImageElement()
        image.position = .zero
        let project = LogoProject()
        project.addElement(image)
        let editor = EditorViewModel(project: project, photoLibrarySaver: saver)
        editor.selectElement(image)
        let transform = editor.transform
        var historyCountAtSave: Int?
        saver.onSave = { [weak editor] in historyCountAtSave = editor?.getHistoryDescriptions().count }
        transform.startManipulation(.move, at: .zero)
        transform.continueManipulation(at: CGPoint(x: 5, y: 8))
        transform.applyGestureTransform(kind: .rotate, translation: nil, scale: nil, rotation: 0.3, ended: false)
        editor.saveToPhotoLibrary { _ in }
        // 保存入力を受け取る前に、未確定の回転を1件にする。座標操作（UIKit の経路）は従来どおり開始値だけを破棄する。
        XCTAssertEqual(historyCountAtSave, 1)
        transform.continueManipulation(at: CGPoint(x: 50, y: 80))
        transform.applyGestureTransform(kind: .rotate, translation: nil, scale: nil, rotation: 1, ended: false)
        transform.resetRotation()
        transform.updatePosition(.zero)
        transform.endManipulation()
        XCTAssertEqual(image.position, CGPoint(x: 5, y: 8))
        XCTAssertEqual(image.rotation, 0.3)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        let marker = makeImage()
        image.cachedImage = marker
        XCTAssertTrue(image.image === marker)
        XCTAssertFalse(transform.prepareImageRenderingForManipulation(in: project, highResolutionThreshold: 1))
        saver.finish(.success(()))
        transform.applyGestureTransform(kind: .rotate, translation: nil, scale: nil, rotation: 0.2, ended: false)
        XCTAssertEqual(image.rotation, 0.3, accuracy: 0.0001, "保存前から続く操作は、終わるまで適用しない")
        transform.applyGestureTransform(kind: .rotate, translation: nil, scale: nil, rotation: nil, ended: true)
        transform.applyGestureTransform(kind: .rotate, translation: nil, scale: nil, rotation: 0.2, ended: false)
        XCTAssertEqual(image.rotation, 0.5, accuracy: 0.0001, "保存前の累積基準を再利用しない")
        transform.applyGestureTransform(kind: .rotate, translation: nil, scale: nil, rotation: nil, ended: true)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 2)
        editor.undo()
        editor.undo()
        XCTAssertEqual(image.rotation, 0, accuracy: 0.0001, "保存の受付で確定した1件で、操作前の角度に戻る")
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

    // MARK: - ジェスチャーの履歴

    @MainActor
    func test_gesture_recordsOneEntry() {
        let (editor, shape) = makeEditorWithSelectedShape()
        let transform = editor.transform
        // 指を置いた直後の移動量ゼロの通知に、ドラッグの変化が続く（実際の UI で観測した順）。
        move(transform, 0, 0)
        move(transform, 30, 40)
        move(transform, 50, 60)
        XCTAssertTrue(editor.getHistoryDescriptions().isEmpty, "操作中は履歴を積まない")
        end(transform, .move)
        XCTAssertEqual(shape.position, CGPoint(x: 60, y: 80))
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        editor.undo()
        XCTAssertEqual(shape.position, CGPoint(x: 10, y: 20))
        editor.redo()
        XCTAssertEqual(shape.position, CGPoint(x: 60, y: 80))
        XCTAssertEqual(shape.size, CGSize(width: 100, height: 80), "動かしていない属性は変えない")
    }

    @MainActor
    func test_simultaneousGestures_recordOneEntry() {
        let (editor, shape) = makeEditorWithSelectedShape()
        let transform = editor.transform
        // 2本指のピンチと回転は交互に届き、最後の指を離すまで続く。
        magnify(transform, 1.5)
        rotate(transform, 0.3)
        magnify(transform, 1.6)
        end(transform, .rotate)
        XCTAssertTrue(editor.getHistoryDescriptions().isEmpty, "拡大縮小が続くあいだは確定しない")
        magnify(transform, 1.8)
        end(transform, .magnify)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        XCTAssertEqual(shape.size.width, 180, accuracy: 0.0001)
        XCTAssertEqual(shape.size.height, 144, accuracy: 0.0001)
        XCTAssertEqual(shape.rotation, 0.5, accuracy: 0.0001)
        editor.undo()
        XCTAssertEqual(shape.size, CGSize(width: 100, height: 80))
        XCTAssertEqual(shape.rotation, 0.2, accuracy: 0.0001)
        XCTAssertEqual(shape.position, CGPoint(x: 10, y: 20))
    }

    @MainActor
    func test_restartedDrag_staysInOneEntry() {
        let (editor, shape) = makeEditorWithSelectedShape()
        let transform = editor.transform
        move(transform, 30, 0)
        // 1本目のドラッグ中に2本目の指を置くと、終了通知なしで移動量ゼロからやり直す（実際の UI で観測）。
        move(transform, 0, 0)
        move(transform, 40, 0)
        end(transform, .move)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        // やり直し後も最初の基準値を使う既存の挙動（要素が飛ぶ不具合は README の残件で扱う）。
        XCTAssertEqual(shape.position, CGPoint(x: 50, y: 20))
        editor.undo()
        XCTAssertEqual(shape.position, CGPoint(x: 10, y: 20))
    }

    @MainActor
    func test_tapGesture_recordsNothing() {
        let (editor, _) = makeEditorWithSelectedShape()
        let transform = editor.transform
        move(transform, 0, 0)
        XCTAssertFalse(transform.hasPendingGestureTransform, "しきい値未満の通知では操作を始めない")
        end(transform, .move)
        XCTAssertFalse(editor.canUndo)
        XCTAssertFalse(editor.isProjectModified)
    }

    @MainActor
    func test_duplicateEnded_recordsOnce() {
        let (editor, shape) = makeEditorWithSelectedShape()
        let transform = editor.transform
        end(transform, .magnify)
        move(transform, 30, 0)
        end(transform, .move)
        end(transform, .move)
        end(transform, .rotate)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        XCTAssertEqual(shape.position, CGPoint(x: 40, y: 20))
    }

    @MainActor
    func test_undoRedo_blockedWhilePending() {
        let (editor, shape) = makeEditorWithSelectedShape()
        let transform = editor.transform
        // 履歴2件のうち1件を取り消し、Undo と Redo の両方が使える状態にする。
        move(transform, 10, 0)
        end(transform, .move)
        move(transform, 10, 0)
        end(transform, .move)
        editor.undo()
        XCTAssertTrue(editor.canUndo)
        XCTAssertTrue(editor.canRedo)
        XCTAssertEqual(shape.position, CGPoint(x: 20, y: 20))

        move(transform, 0, 0)
        XCTAssertTrue(editor.canUndo, "指を置いただけでは止めない")
        move(transform, 15, 0)
        XCTAssertFalse(editor.canUndo, "変化が始まった時点で表示を止める")
        XCTAssertFalse(editor.canRedo)
        editor.undo()
        editor.redo()
        XCTAssertEqual(shape.position, CGPoint(x: 35, y: 20), "操作中の Undo／Redo は実行しない")
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)

        // 通常の入力はしきい値のため開始値ちょうどに戻せない。ほかの経路で値が戻った場合を模擬し、変化なしで終える。
        shape.position = CGPoint(x: 20, y: 20)
        end(transform, .move)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1, "変化がなければ記録しない")
        XCTAssertTrue(editor.canUndo, "変化なしで終わっても使える状態に戻る")
        XCTAssertTrue(editor.canRedo, "記録がなければ Redo の履歴も残る")

        move(transform, 5, 0)
        end(transform, .move)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 2)
        XCTAssertTrue(editor.canUndo)
        XCTAssertFalse(editor.canRedo, "新しい操作の記録で Redo の履歴は消える")
    }

    @MainActor
    func test_resetRotation_blockedWhilePending() {
        let (editor, shape) = makeEditorWithSelectedShape()
        let transform = editor.transform
        rotate(transform, 0.3)
        // 操作中に2本目の指のタップでダブルタップが発火しても、操作中の要素は変えない。
        transform.resetRotation()
        XCTAssertEqual(shape.rotation, 0.5, accuracy: 0.0001)
        end(transform, .rotate)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        transform.resetRotation()
        XCTAssertEqual(shape.rotation, 0, accuracy: 0.0001)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 2)
    }

    @MainActor
    func test_removedOverlay_commitsOnlyCurrentGesture() {
        let (editor, shape) = makeEditorWithSelectedShape()
        let transform = editor.transform
        move(transform, 30, 0)
        transform.endGesturesForRemovedOverlay(showing: UUID())
        XCTAssertTrue(transform.hasPendingGestureTransform, "別の要素を表示していた選択枠の通知では終えない")
        // テキスト編集の開始などで表示中の選択枠が消えると、終了通知は届かないため、ここで1件にする。
        transform.endGesturesForRemovedOverlay(showing: shape.id)
        XCTAssertFalse(transform.hasPendingGestureTransform)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        move(transform, 5, 0)
        end(transform, .move)
        XCTAssertEqual(shape.position, CGPoint(x: 45, y: 20), "次の操作は現在の位置から始まる")
        editor.undo()
        editor.undo()
        XCTAssertEqual(shape.position, CGPoint(x: 10, y: 20))
    }

    // MARK: - 割り込みの境界

    @MainActor
    func test_selectionChange_ignoresWholeOldGesture() {
        let (editor, first, second) = makeEditorWithTwoShapes()
        let transform = editor.transform
        move(transform, 30, 0)
        // 操作中に、2本目の指のタップで選択が切り替わる（実際の UI で観測）。
        editor.selectElement(second)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1, "切り替え前の移動は、前の要素の1件になる")
        XCTAssertEqual(first.position, CGPoint(x: 40, y: 20))
        // 古い操作の続きと、あとから始まった拡大縮小・回転は、次の要素へ適用しない。
        move(transform, 50, 50)
        magnify(transform, 1.5)
        rotate(transform, 0.3)
        XCTAssertEqual(second.position, CGPoint(x: 200, y: 300))
        XCTAssertEqual(second.size, CGSize(width: 60, height: 60))
        XCTAssertEqual(second.rotation, 0)
        XCTAssertFalse(transform.hasPendingGestureTransform)
        end(transform, .move)
        magnify(transform, 1.6)
        XCTAssertEqual(second.size, CGSize(width: 60, height: 60), "古い操作の種類が残るあいだは適用しない")
        end(transform, .magnify)
        end(transform, .rotate)
        // 古い操作がすべて終わった後の新しい操作は、次の要素の現在値から始まる。
        move(transform, 10, 0)
        end(transform, .move)
        XCTAssertEqual(second.position, CGPoint(x: 210, y: 300))
        XCTAssertEqual(editor.getHistoryDescriptions().count, 2)
        editor.undo()
        XCTAssertEqual(second.position, CGPoint(x: 200, y: 300))
        editor.undo()
        XCTAssertEqual(first.position, CGPoint(x: 10, y: 20))
    }

    @MainActor
    func test_save_processesEndedWhileSaving() {
        let saver = PhotoLibrarySavingStub()
        let (editor, shape, _) = makeEditorWithTwoShapes(saver: saver)
        let transform = editor.transform
        move(transform, 30, 0)
        editor.saveToPhotoLibrary { _ in }
        XCTAssertTrue(editor.isSavingImage)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        // 保存中は値を変えないが、届いた終了通知では無視の印を外す。
        end(transform, .move)
        // 保存中に始まった操作は、保存が終わっても、その操作が終わるまで適用しない。
        rotate(transform, 0.3)
        saver.finish(.success(()))
        rotate(transform, 0.4)
        XCTAssertEqual(shape.rotation, 0.2, accuracy: 0.0001)
        end(transform, .rotate)
        move(transform, 5, 0)
        XCTAssertEqual(shape.position, CGPoint(x: 45, y: 20), "保存の前後の操作が終わった後は、現在値から始まる")
        end(transform, .move)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 2)
    }

    @MainActor
    func test_delete_commitsGestureBeforeRemoval() {
        let (editor, shape) = makeEditorWithSelectedShape()
        let transform = editor.transform
        move(transform, 30, 0)
        editor.deleteSelectedElement()
        XCTAssertEqual(editor.getHistoryDescriptions().count, 2, "変形・削除の2件になる")
        XCTAssertFalse(transform.hasPendingGestureTransform)
        editor.undo()
        XCTAssertTrue(editor.project.elements.contains { $0.id == shape.id })
        XCTAssertEqual(shape.position, CGPoint(x: 40, y: 20))
        editor.undo()
        XCTAssertEqual(shape.position, CGPoint(x: 10, y: 20))
    }

    @MainActor
    func test_oldOverlayRemoval_keepsNewGesture() {
        let (editor, first, second) = makeEditorWithTwoShapes()
        let transform = editor.transform
        move(transform, 30, 0)
        editor.selectElement(second)
        end(transform, .move)
        move(transform, 10, 0)
        // 前の要素を表示していた選択枠の消滅が遅れて届いても、新しい操作を確定・解除しない。
        transform.endGesturesForRemovedOverlay(showing: first.id)
        XCTAssertTrue(transform.hasPendingGestureTransform)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        move(transform, 20, 0)
        XCTAssertEqual(second.position, CGPoint(x: 220, y: 300), "新しい操作の基準値が残っている")
        end(transform, .move)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 2)
    }

    @MainActor
    func test_selectionCleared_overlayRemovalEndsSuppression() {
        let (editor, first, second) = makeEditorWithTwoShapes()
        let transform = editor.transform
        move(transform, 30, 0)
        editor.clearSelection()
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        // 選択枠が消えると、古い操作の終了通知は届かない（実際の UI で観測）。消滅の通知で無視の印を外す。
        transform.endGesturesForRemovedOverlay(showing: first.id)
        editor.selectElement(second)
        move(transform, 10, 0)
        end(transform, .move)
        XCTAssertEqual(second.position, CGPoint(x: 210, y: 300))
    }

    @MainActor
    func test_resetRotation_blockedWhileOldGestureContinues() {
        let (editor, _, second) = makeEditorWithTwoShapes(secondRotation: 1.0)
        let transform = editor.transform
        move(transform, 30, 0)
        editor.selectElement(second)
        // 古い操作の2本目の指のタップでダブルタップが発火しても、切り替え後の要素を変えない。
        transform.resetRotation()
        XCTAssertEqual(second.rotation, 1.0, accuracy: 0.0001)
        end(transform, .move)
        transform.resetRotation()
        XCTAssertEqual(second.rotation, 0, accuracy: 0.0001)
    }

    @MainActor
    func test_gestureEntry_includesOnlyMovedAttributes() {
        let (editor, shape) = makeEditorWithSelectedShape()
        let transform = editor.transform
        move(transform, 30, 0)
        // 操作中に、ほかの編集が同じ要素のサイズを変えた場合を模擬する。
        shape.size = CGSize(width: 150, height: 80)
        end(transform, .move)
        editor.undo()
        XCTAssertEqual(shape.position, CGPoint(x: 10, y: 20))
        XCTAssertEqual(shape.size, CGSize(width: 150, height: 80), "移動の履歴はサイズを戻さない")
    }

    /// 位置 (10, 20)・サイズ 100×80・回転 0.2 の図形を選択したエディタ。履歴は空。
    @MainActor
    private func makeEditorWithSelectedShape() -> (EditorViewModel, ShapeElement) {
        let shape = ShapeElement(shapeType: .rectangle)
        shape.position = CGPoint(x: 10, y: 20)
        shape.size = CGSize(width: 100, height: 80)
        shape.rotation = 0.2
        let project = LogoProject()
        project.addElement(shape)
        let editor = EditorViewModel(project: project)
        editor.selectElement(shape)
        return (editor, shape)
    }

    /// 1つ目（位置 (10, 20)・100×80・回転 0.2）を選択し、2つ目（位置 (200, 300)・60×60）も置いたエディタ。履歴は空。
    @MainActor
    private func makeEditorWithTwoShapes(
        secondRotation: CGFloat = 0,
        saver: PhotoLibrarySavingStub? = nil
    ) -> (EditorViewModel, ShapeElement, ShapeElement) {
        let first = ShapeElement(shapeType: .rectangle)
        first.position = CGPoint(x: 10, y: 20)
        first.size = CGSize(width: 100, height: 80)
        first.rotation = 0.2
        let second = ShapeElement(shapeType: .circle)
        second.position = CGPoint(x: 200, y: 300)
        second.size = CGSize(width: 60, height: 60)
        second.rotation = secondRotation
        let project = LogoProject()
        project.addElement(first)
        project.addElement(second)
        let editor = EditorViewModel(project: project, photoLibrarySaver: saver)
        editor.selectElement(first)
        return (editor, first, second)
    }

    @MainActor
    private func move(_ transform: ElementTransformViewModel, _ dx: CGFloat, _ dy: CGFloat) {
        transform.applyGestureTransform(
            kind: .move, translation: CGSize(width: dx, height: dy), scale: nil, rotation: nil, ended: false
        )
    }

    @MainActor
    private func magnify(_ transform: ElementTransformViewModel, _ scale: CGFloat) {
        transform.applyGestureTransform(kind: .magnify, translation: nil, scale: scale, rotation: nil, ended: false)
    }

    @MainActor
    private func rotate(_ transform: ElementTransformViewModel, _ rotation: CGFloat) {
        transform.applyGestureTransform(kind: .rotate, translation: nil, scale: nil, rotation: rotation, ended: false)
    }

    @MainActor
    private func end(_ transform: ElementTransformViewModel, _ kind: ElementGestureTransformKind) {
        transform.applyGestureTransform(kind: kind, translation: nil, scale: nil, rotation: nil, ended: true)
    }

    private func makeImageElement() throws -> ImageElement {
        ImageElementFactory().makeElement(imageData: try XCTUnwrap(makeImage().pngData()))
    }

    private func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }
    }
}
