// エディタ画面が、パネル用の描画の更新を表示したときに2つだけ作り、再描画では作り直さないことを確かめる。
// 作る関数は StateObject が ElementViewModel を作る式の中でだけ呼ばれる、という前提を実際の表示で確認する。

import SwiftUI
import XCTest
@testable import GLogo

final class EditorViewDependencyTests: XCTestCase {
    @MainActor
    func test_editorScreen_createsPanelRefreshesOnce() {
        let counter = RefreshCounter()
        let editor = EditorViewModel(dependencies: .live(makeImageRenderRefresh: counter.makeImageRenderRefresh))
        XCTAssertEqual(counter.count, 0, "エディタの初期化では作らない")

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        defer { window.isHidden = true }
        let host = UIHostingController(rootView: EditorView(viewModel: editor))
        window.rootViewController = host
        window.makeKeyAndVisible()
        settle(host.view)
        XCTAssertEqual(counter.count, 2, "表示したときに、調整・フィルターの共有分とフレーム用の2つを作る")

        // 親の再描画で画面の値が作り直されても、保持中のパネルの依存は作り直さない。
        host.rootView = EditorView(viewModel: editor)
        settle(host.view)
        XCTAssertEqual(counter.count, 2, "再描画では作り直さない")
    }

    /// 表示の更新を反映させる。
    @MainActor
    private func settle(_ view: UIView) {
        view.setNeedsLayout()
        view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    }
}

/// 描画の更新を作った回数を数える。
@MainActor
private final class RefreshCounter {
    private(set) var count = 0

    func makeImageRenderRefresh() -> ImageRenderRefreshUseCase {
        count += 1
        return AppComposition.makeImageRenderRefresh()
    }
}
