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
    func test_save_manipulation_stopsUntilCompletion() {
        let saver = PhotoLibrarySavingStub()
        let editor = EditorViewModel(photoLibrarySaver: saver)
        editor.addTextElement(position: .zero)
        editor.transform.startManipulation(.move, at: .zero)
        XCTAssertEqual(editor.transform.manipulationType, .move)
        let historyBeforeSave = editor.getHistoryDescriptions()

        editor.saveToPhotoLibrary { _ in }
        XCTAssertTrue(saver.projects.first === editor.project)
        XCTAssertEqual(editor.transform.manipulationType, .none)
        editor.transform.startManipulation(.move, at: .zero)
        XCTAssertEqual(editor.transform.manipulationType, .none)
        editor.transform.endManipulation()
        XCTAssertEqual(editor.getHistoryDescriptions(), historyBeforeSave)

        saver.finish(.success(()))
        editor.transform.startManipulation(.move, at: .zero)
        XCTAssertEqual(editor.transform.manipulationType, .move)
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
