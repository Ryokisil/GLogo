//
//  EditorChromeUITests.swift
//  GLogoUITests
//
//  概要:
//  エディタ画面の基本 chrome（TopBar / OverlayToolbar / BottomToolStrip）の
//  表示・シート開閉・基本導線を守る UI テスト。
//

import XCTest

final class EditorChromeUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// fixture なしで起動する
    @MainActor
    private func launchApp() {
        app = XCUIApplication()
        app.launchArguments += ["-hasSeenEditorIntro", "YES"]
        app.launch()
    }

    // MARK: - 基本 chrome テスト

    /// エディタ画面の基本 chrome（TopBar, OverlayToolbar, BottomToolStrip）が表示される
    @MainActor
    func testEditorScreen_LaunchesAndShowsCoreChrome() throws {
        launchApp()
        let saveButton = app.buttons["editor.topBar.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "保存ボタンが表示されるべき")

        let settingsButton = app.buttons["editor.overlay.settingsButton"]
        XCTAssertTrue(settingsButton.exists, "設定ボタンが表示されるべき")

        // ボトムツールストリップの存在はツールボタンで確認
        let adjustButton = app.buttons["editor.bottomTool.adjust"]
        XCTAssertTrue(adjustButton.exists, "ボトムツールストリップのボタンが表示されるべき")
    }

    /// 設定ボタンから AppSettingsView シートが開閉できる
    @MainActor
    func testEditor_AppSettingsSheet_OpenAndDismiss() throws {
        launchApp()
        let settingsButton = app.buttons["editor.overlay.settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))

        settingsButton.tap()

        // シートが表示されるのを待つ（NavigationBar タイトルまたは既知の要素で検証）
        let sheet = app.navigationBars.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 3), "設定シートが表示されるべき")

        // スワイプダウンで閉じる
        app.swipeDown()

        // シート解除後に設定ボタンが再び操作可能になるのを確認
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3), "設定シート閉じた後に設定ボタンが存在するべき")
    }

    /// Text ツールタップで TextPropertyPanel が表示される
    @MainActor
    func testEditor_TextTool_ShowsTextPropertyPanel() throws {
        launchApp()
        let textToolButton = app.buttons["editor.bottomTool.select"]
        XCTAssertTrue(textToolButton.waitForExistence(timeout: 5), "テキストツールボタンが表示されるべき")

        textToolButton.tap()

        // パネル内の閉じるボタンで表示を確認（container ではなく具体コントロール）
        let closeButton = app.buttons["editor.textPropertyPanel.closeButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3), "テキストプロパティパネルが表示されるべき")
    }

    /// 画像追加ボタンで picker シートが開始される
    @MainActor
    func testEditor_ImageAddFlow_PresentsPicker() throws {
        launchApp()
        let addImageButton = app.buttons["editor.overlay.addImageButton"]
        XCTAssertTrue(addImageButton.waitForExistence(timeout: 5), "画像追加ボタンが表示されるべき")

        addImageButton.tap()

        // シートが表示されるのを待つ（ナビゲーションバーまたはシート要素で検証）
        let sheetAppeared = app.sheets.firstMatch.waitForExistence(timeout: 3)
            || app.navigationBars.firstMatch.waitForExistence(timeout: 3)
            || app.otherElements["editor.overlay.addImageButton"].waitForNonExistence(timeout: 3)
        // picker の表示形態はOS/シミュレータ設定に依存するため、
        // ボタンタップ後に何らかのモーダルが出ることだけを確認
        XCTAssertTrue(sheetAppeared, "画像追加ボタンタップ後にシートが表示されるべき")
    }
}

private extension XCUIElement {
    /// 要素が消えるのを待つ（標準APIに存在しないため追加）
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}
