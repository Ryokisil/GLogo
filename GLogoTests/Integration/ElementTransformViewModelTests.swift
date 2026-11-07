// 変形の共有状態、ジェスチャーの履歴、選択・保存・削除の境界を検証する。

import Combine
import UIKit
import XCTest
@testable import GLogo

final class ElementTransformViewModelTests: XCTestCase {
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
        transform.applyGestureTransform(kind: .rotate, translation: nil, scale: nil, rotation: 0.3, ended: false)
        editor.saveToPhotoLibrary { _ in }
        // 保存入力を受け取る前に、未確定の回転を1件にする。
        XCTAssertEqual(historyCountAtSave, 1)
        // 保存中は、続きの操作・保存中に始まった操作・回転リセットを受け付けない。
        transform.applyGestureTransform(kind: .rotate, translation: nil, scale: nil, rotation: 1, ended: false)
        transform.applyGestureTransform(
            kind: .move, translation: CGSize(width: 50, height: 80), scale: nil, rotation: nil, ended: false
        )
        transform.resetRotation()
        XCTAssertEqual(image.position, .zero)
        XCTAssertEqual(image.rotation, 0.3)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        // 保存の受付で、操作中の描画は通常の描画に戻っている。
        let marker = makeImage()
        image.cachedImage = marker
        XCTAssertTrue(image.image === marker)
        saver.finish(.success(()))
        transform.applyGestureTransform(kind: .rotate, translation: nil, scale: nil, rotation: 0.2, ended: false)
        XCTAssertEqual(image.rotation, 0.3, accuracy: 0.0001, "保存前から続く操作は、終わるまで適用しない")
        transform.applyGestureTransform(kind: .rotate, translation: nil, scale: nil, rotation: nil, ended: true)
        transform.applyGestureTransform(
            kind: .move, translation: CGSize(width: 60, height: 90), scale: nil, rotation: nil, ended: false
        )
        XCTAssertEqual(image.position, .zero, "保存中に始まった操作も、終わるまで適用しない")
        transform.applyGestureTransform(kind: .move, translation: nil, scale: nil, rotation: nil, ended: true)
        // 古い操作がすべて終わった後の新しい操作は受け付ける。
        transform.applyGestureTransform(kind: .rotate, translation: nil, scale: nil, rotation: 0.2, ended: false)
        XCTAssertEqual(image.rotation, 0.5, accuracy: 0.0001, "保存前の累積基準を再利用しない")
        transform.applyGestureTransform(kind: .rotate, translation: nil, scale: nil, rotation: nil, ended: true)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 2)
        editor.undo()
        editor.undo()
        XCTAssertEqual(image.rotation, 0, accuracy: 0.0001, "保存の受付で確定した1件で、操作前の角度に戻る")
    }

    @MainActor
    func test_selection_endsGesturePreview() throws {
        let first = try makeImageElement()
        let second = try makeImageElement()
        let project = LogoProject()
        project.addElement(first)
        project.addElement(second)
        let editor = EditorViewModel(project: project)
        editor.selectElement(first)
        // 選択中の画像は、ジェスチャーのあいだ操作中の描画になる。
        editor.transform.applyGestureTransform(kind: .rotate, translation: nil, scale: nil, rotation: 0.3, ended: false)
        let marker = makeImage()
        first.cachedImage = marker
        XCTAssertFalse(first.image === marker)
        // 選択を切り替えると、切り替え前の画像の操作中の描画を終える。
        editor.selectElement(second)
        XCTAssertTrue(first.image === marker)
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
        transform.applyGestureTransform(
            kind: .move, translation: CGSize(width: 10, height: 0), scale: nil, rotation: nil, ended: false
        )
        XCTAssertGreaterThan(notifications, 0)
        let isReleased = { [weak editor] in editor == nil }
        editor = nil
        XCTAssertTrue(isReleased())
        // エディタが解放された後の入力は、要素を変えない。
        let oldPosition = shape.position
        transform.applyGestureTransform(
            kind: .move, translation: CGSize(width: 100, height: 100), scale: nil, rotation: nil, ended: false
        )
        XCTAssertEqual(shape.position, oldPosition)
        withExtendedLifetime(observation) {}
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
    func test_restartedDrag_continuesFromCurrentPosition() {
        let (editor, shape) = makeEditorWithSelectedShape()
        let transform = editor.transform
        let first = CGPoint(x: 115, y: 319)
        let second = CGPoint(x: 185, y: 319)
        move(transform, 0, 0, start: first)
        move(transform, 30, 0, start: first)
        XCTAssertEqual(shape.position, CGPoint(x: 40, y: 20))
        // 1本目のドラッグ中に2本目の指を置くと、終了通知なしで、始点の変わった移動量ゼロの通知から追い直す（実際の UI で観測）。
        move(transform, 0, 0, start: second)
        XCTAssertEqual(shape.position, CGPoint(x: 40, y: 20), "やり直しの時点では動かない")
        move(transform, 40, 0, start: second)
        XCTAssertEqual(shape.position, CGPoint(x: 80, y: 20), "現在の位置から、新しい指の動きの分だけ動く")
        XCTAssertTrue(editor.getHistoryDescriptions().isEmpty, "操作中は履歴を積まない")
        end(transform, .move)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1, "やり直しを含めて操作全体で1件")
        editor.undo()
        XCTAssertEqual(shape.position, CGPoint(x: 10, y: 20), "Undo 用の開始値は、やり直しで変えない")
        editor.redo()
        XCTAssertEqual(shape.position, CGPoint(x: 80, y: 20))
    }

    @MainActor
    func test_restartBeforeMovement_startsFromCurrentPosition() {
        let (editor, shape) = makeEditorWithSelectedShape()
        let transform = editor.transform
        // しきい値を超える前のやり直しは、置き換える基準がまだないため、そのまま現在の位置から始まる。
        move(transform, 0, 0, start: CGPoint(x: 100, y: 100))
        move(transform, 0, 0, start: CGPoint(x: 160, y: 100))
        move(transform, 20, 0, start: CGPoint(x: 160, y: 100))
        end(transform, .move)
        XCTAssertEqual(shape.position, CGPoint(x: 30, y: 20))
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
    }

    @MainActor
    func test_sameMoveStart_keepsBase() {
        let (editor, shape) = makeEditorWithSelectedShape()
        let transform = editor.transform
        let start = CGPoint(x: 115, y: 319)
        move(transform, 30, 0, start: start)
        // 同じ区間で指を戻しただけなら、やり直しではない。基準はそのままで、移動量どおりに戻る。
        move(transform, 10, 0, start: start)
        XCTAssertEqual(shape.position, CGPoint(x: 20, y: 20))
        end(transform, .move)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
    }

    @MainActor
    func test_restartWhileSuppressed_staysIgnored() {
        let (editor, _, second) = makeEditorWithTwoShapes()
        let transform = editor.transform
        move(transform, 30, 0, start: CGPoint(x: 115, y: 319))
        editor.selectElement(second)
        // 割り込みの後のやり直しは、古い操作の続きとして無視し続ける（古い操作から編集を再開しない）。
        move(transform, 0, 0, start: CGPoint(x: 185, y: 319))
        move(transform, 40, 0, start: CGPoint(x: 185, y: 319))
        XCTAssertEqual(second.position, CGPoint(x: 200, y: 300))
        end(transform, .move)
        move(transform, 10, 0, start: CGPoint(x: 300, y: 400))
        end(transform, .move)
        XCTAssertEqual(second.position, CGPoint(x: 210, y: 300), "古い操作が終わった後の新しい操作は効く")
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

    /// 区間の始点を添えた移動の通知（選択枠の DragGesture と同じ形）
    @MainActor
    private func move(_ transform: ElementTransformViewModel, _ dx: CGFloat, _ dy: CGFloat, start: CGPoint) {
        transform.applyGestureTransform(
            kind: .move, translation: CGSize(width: dx, height: dy), scale: nil, rotation: nil,
            moveStart: start, ended: false
        )
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
