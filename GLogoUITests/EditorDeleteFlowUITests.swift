//
//  EditorDeleteFlowUITests.swift
//  GLogoUITests
//
//  概要:
//  エディタ画面の要素削除フロー（確認ダイアログ・実削除・キャンセル）を守る UI テスト。
//  削除の成否は UI 状態変化（確認ダイアログ再出現の有無、パネル slider の有無）で検証する。
//
//  備考:
//  confirmationDialog の .cancel role ボタンは iOS の XCUI ツリーに出ないため、
//  キャンセル操作はアクションシートのスワイプダウンで代替する。
//  OK ボタンは SwiftUI 内部で重複レンダリングされるため .firstMatch で取得する。
//

import XCTest

final class EditorDeleteFlowUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// fixture 付きで起動する
    @MainActor
    private func launchApp(fixture: String) {
        app = XCUIApplication()
        app.launchArguments += ["-hasSeenEditorIntro", "YES"]
        app.launchArguments += ["-uiTestFixture", fixture]
        app.launch()
    }

    // MARK: - Delete フローテスト

    /// 選択済み画像に対して delete ボタンをタップすると確認ダイアログが表示される
    @MainActor
    func testEditor_DeleteFlow_ShowsConfirmationForSelectedImage() throws {
        launchApp(fixture: "selectedImage")

        let deleteButton = app.buttons["editor.overlay.deleteButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "削除ボタンが表示されるべき")
        deleteButton.tap()

        // 確認ダイアログの OK ボタンが表示されることで、ダイアログ出現を検証
        // SwiftUI の confirmationDialog は内部で重複レンダリングするため .firstMatch で取得
        let okButton = app.buttons.matching(
            NSPredicate(format: "identifier == 'editor.confirmation.okButton'")
        ).firstMatch
        XCTAssertTrue(okButton.waitForExistence(timeout: 3), "確認ダイアログが表示されるべき")
    }

    /// 確認ダイアログで OK をタップすると画像が削除される
    /// （削除後に再度 delete タップで確認ダイアログが出ないことで、選択要素の消失を検証）
    @MainActor
    func testEditor_DeleteFlow_ConfirmRemovesSelectedImage() throws {
        launchApp(fixture: "selectedImage")

        // delete → 確認ダイアログ → OK
        let deleteButton = app.buttons["editor.overlay.deleteButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        let okButton = app.buttons.matching(
            NSPredicate(format: "identifier == 'editor.confirmation.okButton'")
        ).firstMatch
        XCTAssertTrue(okButton.waitForExistence(timeout: 3))
        okButton.tap()

        // 確認ダイアログが閉じるのを待つ
        let dialogDismissed = NSPredicate(format: "exists == false")
        let dismissExpectation = XCTNSPredicateExpectation(predicate: dialogDismissed, object: okButton)
        let dismissResult = XCTWaiter().wait(for: [dismissExpectation], timeout: 3)
        XCTAssertEqual(dismissResult, .completed, "確認ダイアログが閉じるべき")

        // 削除後: delete ボタンを再タップ
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3))
        deleteButton.tap()

        // 選択要素がないため確認ダイアログは出ない（delete mode に入るだけ）
        let okButtonAgain = app.buttons.matching(
            NSPredicate(format: "identifier == 'editor.confirmation.okButton'")
        ).firstMatch
        XCTAssertFalse(
            okButtonAgain.waitForExistence(timeout: 2),
            "画像削除後は確認ダイアログが表示されないべき"
        )
    }

    /// 確認ダイアログをキャンセルすると選択状態が維持される
    /// （confirmationDialog の .cancel role ボタンは XCUI ツリーに出ないため、スワイプダウンで閉じる）
    @MainActor
    func testEditor_DeleteFlow_CancelKeepsSelection() throws {
        launchApp(fixture: "selectedImage")

        // delete → 確認ダイアログ表示
        let deleteButton = app.buttons["editor.overlay.deleteButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        // OK ボタンの出現でダイアログ表示を確認
        let okButton = app.buttons.matching(
            NSPredicate(format: "identifier == 'editor.confirmation.okButton'")
        ).firstMatch
        XCTAssertTrue(okButton.waitForExistence(timeout: 3), "確認ダイアログが表示されるべき")

        // アクションシート外（画面上部）をタップして閉じる（cancel 相当）
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()

        // ダイアログが閉じるのを待つ
        let dialogDismissed = NSPredicate(format: "exists == false")
        let dismissExpectation = XCTNSPredicateExpectation(predicate: dialogDismissed, object: okButton)
        let dismissResult = XCTWaiter().wait(for: [dismissExpectation], timeout: 3)
        XCTAssertEqual(dismissResult, .completed, "ダイアログが閉じるべき")

        // キャンセル後: delete ボタンを再タップして確認ダイアログが再び出ることで選択維持を検証
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3))
        deleteButton.tap()

        let okButtonAgain = app.buttons.matching(
            NSPredicate(format: "identifier == 'editor.confirmation.okButton'")
        ).firstMatch
        XCTAssertTrue(
            okButtonAgain.waitForExistence(timeout: 3),
            "キャンセル後は選択が維持され、再度確認ダイアログが表示されるべき"
        )
    }
}
