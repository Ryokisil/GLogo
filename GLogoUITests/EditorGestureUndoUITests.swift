//
//  EditorGestureUndoUITests.swift
//  GLogoUITests
//
//  概要:
//  キャンバス上の実際のドラッグ・ピンチを、Undo／Redo で戻せることを守る UI テスト。
//  要素の位置・サイズは、DEBUG ビルドで選択枠が公開するアクセシビリティ値（キャンバス座標）で比較する。
//
//  備考:
//  選択枠の識別子の frame は、要素ではなくキャンバス全体を返す（SwiftUI の位置指定の影響）。
//  そのため、操作する位置は frame の原点に値の座標を足して求め、ピンチの前には、ピンチの中心
//  （frame の中心）が要素の内側にあることを確かめる。
//

import XCTest

final class EditorGestureUndoUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - テスト

    /// ドラッグで動かした位置が、Undo で元に戻り、Redo で動かした位置へ進む
    @MainActor
    func test_drag_undoRedo_restoresPosition() throws {
        let selection = try launchWithOnScreenImage()
        let before = try XCTUnwrap(currentValue(of: selection))

        let rect = elementRect(of: selection, value: before)
        let start = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: rect.midX, dy: rect.midY))
        start.press(forDuration: 0.2, thenDragTo: start.withOffset(CGVector(dx: 60, dy: 40)))

        let moved = try XCTUnwrap(
            waitForValue(of: selection) { $0.x != before.x || $0.y != before.y },
            "ドラッグで位置が変わるべき（選択枠の frame: \(selection.frame)）"
        )
        XCTAssertEqual(moved.width, before.width, "ドラッグでサイズは変わらない")
        XCTAssertEqual(moved.height, before.height)

        undoButton.tap()
        XCTAssertNotNil(waitForValue(of: selection) { $0 == before }, "Undo で元の位置に戻るべき")

        redoButton.tap()
        XCTAssertNotNil(waitForValue(of: selection) { $0 == moved }, "Redo で動かした位置へ進むべき")
    }

    /// ピンチで変えたサイズが、Undo で元に戻り、Redo で変えたサイズへ進む
    @MainActor
    func test_pinch_undoRedo_restoresSize() throws {
        let selection = try launchWithOnScreenImage()
        let before = try XCTUnwrap(currentValue(of: selection))

        // pinch は frame の中心で2本の指を広げる。2本とも要素に乗るよう、中心の周りに余裕があることを確かめる。
        let rect = elementRect(of: selection, value: before)
        let pinchCenter = CGPoint(x: selection.frame.midX, y: selection.frame.midY)
        XCTAssertTrue(
            rect.insetBy(dx: 60, dy: 60).contains(pinchCenter),
            "ピンチの中心 \(pinchCenter) が要素の内側にあるべき（要素の画面上の矩形: \(rect)）"
        )

        selection.pinch(withScale: 1.6, velocity: 1.0)

        let scaled = try XCTUnwrap(
            waitForValue(of: selection) { $0.width > before.width && $0.height > before.height },
            "ピンチでサイズが大きくなるべき（選択枠の frame: \(selection.frame)）"
        )

        undoButton.tap()
        XCTAssertNotNil(waitForValue(of: selection) { $0 == before }, "Undo で元のサイズに戻るべき")

        redoButton.tap()
        XCTAssertNotNil(waitForValue(of: selection) { $0 == scaled }, "Redo で変えたサイズへ進むべき")
    }

    // MARK: - ヘルパー

    @MainActor private var undoButton: XCUIElement { app.buttons["editor.topBar.undoButton"] }
    @MainActor private var redoButton: XCUIElement { app.buttons["editor.topBar.redoButton"] }

    /// 画面内に画像要素を置いて選択した状態で起動し、選択枠を返す
    @MainActor
    private func launchWithOnScreenImage() throws -> XCUIElement {
        app = XCUIApplication()
        app.launchArguments += ["-hasSeenEditorIntro", "YES"]
        app.launchArguments += ["-uiTestFixture", "onScreenImage"]
        app.launch()

        let selection = app.otherElements["editor.canvas.selection"]
        XCTAssertTrue(selection.waitForExistence(timeout: 5), "選択枠が表示されるべき")
        return selection
    }

    /// 要素の画面上の矩形。frame がキャンバス全体なら、その原点にキャンバス座標の値を足す。
    /// frame が要素と同じ大きさなら（SwiftUI の扱いが変わった場合）、そのまま使う。
    @MainActor
    private func elementRect(of selection: XCUIElement, value: ElementTransformValue) -> CGRect {
        let frame = selection.frame
        let isCanvasFrame = frame.width > value.width + 1 || frame.height > value.height + 1
        guard isCanvasFrame else { return frame }
        return CGRect(x: frame.minX + value.x, y: frame.minY + value.y, width: value.width, height: value.height)
    }

    @MainActor
    private func currentValue(of selection: XCUIElement) -> ElementTransformValue? {
        (selection.value as? String).flatMap(ElementTransformValue.init)
    }

    /// 条件を満たす値になるまで待つ。SwiftUI の更新はジェスチャー・タップの直後に反映されないことがある。
    @MainActor
    private func waitForValue(
        of selection: XCUIElement,
        timeout: TimeInterval = 3,
        where condition: (ElementTransformValue) -> Bool
    ) -> ElementTransformValue? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let value = currentValue(of: selection), condition(value) {
                return value
            }
            Thread.sleep(forTimeInterval: 0.1)
        } while Date() < deadline
        return nil
    }
}

/// 選択枠のアクセシビリティ値（`x=… y=… w=… h=… r=…`）を読み取った値
private struct ElementTransformValue: Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let rotation: Double

    init?(_ text: String) {
        var values: [String: Double] = [:]
        for part in text.split(separator: " ") {
            let pair = part.split(separator: "=")
            guard pair.count == 2, let value = Double(pair[1]) else { return nil }
            values[String(pair[0])] = value
        }
        guard let x = values["x"], let y = values["y"], let width = values["w"],
              let height = values["h"], let rotation = values["r"] else { return nil }
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.rotation = rotation
    }
}
