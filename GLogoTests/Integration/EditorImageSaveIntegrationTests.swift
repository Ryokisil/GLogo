// 保存状態の親への通知、編集入力の抑止と親子の参照寿命を検証する。

import Combine
import XCTest
@testable import GLogo

final class EditorImageSaveIntegrationTests: XCTestCase {
    @MainActor
    func test_save_stateChanges_notifyEditor() {
        let saver = PhotoLibrarySavingStub()
        let editor = EditorViewModel(photoLibrarySaver: saver)
        var notificationCount = 0
        let observation = editor.objectWillChange.sink { notificationCount += 1 }

        editor.saveToPhotoLibrary { _ in }
        XCTAssertTrue(editor.isSavingImage)
        XCTAssertGreaterThan(notificationCount, 0)
        notificationCount = 0

        saver.finish(.failure(.permissionDenied))
        XCTAssertFalse(editor.isSavingImage)
        XCTAssertEqual(editor.lastPhotoLibrarySaveFailure, .permissionDenied)
        XCTAssertGreaterThan(notificationCount, 0)
        notificationCount = 0

        editor.saveCompositeToPhotoLibrary { _ in }
        XCTAssertTrue(editor.isSavingImage)
        XCTAssertNil(editor.lastPhotoLibrarySaveFailure)
        XCTAssertEqual(saver.compositeCount, 1)
        notificationCount = 0

        saver.finish(.success(()))
        XCTAssertFalse(editor.isSavingImage)
        XCTAssertGreaterThan(notificationCount, 0)
        withExtendedLifetime(observation) {}
    }

    @MainActor
    func test_save_gestureStopsUntilCompletion() throws {
        let saver = PhotoLibrarySavingStub()
        let editor = EditorViewModel(photoLibrarySaver: saver)
        editor.addTextElement(position: .zero)
        let element = try XCTUnwrap(editor.selectedElement)
        let transform = editor.transform
        transform.applyGestureTransform(
            kind: .move, translation: CGSize(width: 10, height: 0), scale: nil, rotation: nil, ended: false
        )
        let historyCountBeforeSave = editor.getHistoryDescriptions().count

        editor.saveToPhotoLibrary { _ in }
        XCTAssertTrue(saver.projects.first === editor.project)
        // 保存の受付で未確定の移動を1件にし、保存中は入力を止める。
        XCTAssertEqual(editor.getHistoryDescriptions().count, historyCountBeforeSave + 1)
        let positionAtSave = element.position
        transform.applyGestureTransform(
            kind: .move, translation: CGSize(width: 40, height: 0), scale: nil, rotation: nil, ended: false
        )
        XCTAssertEqual(element.position, positionAtSave)

        saver.finish(.success(()))
        // 保存完了後も、古い操作が終わるまでは適用しない。終わった後の新しい操作は受け付ける。
        transform.applyGestureTransform(
            kind: .move, translation: CGSize(width: 50, height: 0), scale: nil, rotation: nil, ended: false
        )
        XCTAssertEqual(element.position, positionAtSave)
        transform.applyGestureTransform(kind: .move, translation: nil, scale: nil, rotation: nil, ended: true)
        transform.applyGestureTransform(
            kind: .move, translation: CGSize(width: 5, height: 0), scale: nil, rotation: nil, ended: false
        )
        XCTAssertEqual(element.position.x, positionAtSave.x + 5, accuracy: 0.0001)
    }

    /// 両方の入口で、エディタは自分の管理役を保存の要求へ渡す（受付で元画像を受け取るため）。
    @MainActor
    func test_save_passesEditorRenderSessions() {
        let saver = PhotoLibrarySavingStub()
        let renderSessions = RenderSessionReadingSpy()
        let editor = EditorViewModel(
            dependencies: .live(photoLibrarySaver: saver), renderSessions: renderSessions
        )

        editor.saveToPhotoLibrary { _ in }
        saver.finish(.success(()))
        editor.saveCompositeToPhotoLibrary { _ in }
        saver.finish(.success(()))

        XCTAssertEqual(saver.renderSessions.count, 2)
        XCTAssertTrue(saver.renderSessions.allSatisfy { $0 === renderSessions })
        XCTAssertEqual(saver.compositeCount, 1)
    }

    @MainActor
    func test_save_pendingCompletion_doesNotRetainEditor() {
        let saver = PhotoLibrarySavingStub()
        var editor: EditorViewModel? = EditorViewModel(photoLibrarySaver: saver)
        weak var weakEditor = editor
        editor?.saveToPhotoLibrary { _ in
            XCTFail("画面の所有者が解放されたあとに完了通知してはいけない")
        }

        editor = nil

        XCTAssertNil(weakEditor)
        saver.finish(.success(()))
    }
}
