// CanvasView が、同じプロジェクトを設定し直したときに再描画を要求する契約を検証する。

import XCTest
@testable import GLogo

final class CanvasViewTests: XCTestCase {
    @MainActor
    func test_sameProjectReassigned_requestsRedraw() {
        let shape = ShapeElement(shapeType: .rectangle)
        let project = LogoProject()
        project.addElement(shape)
        let canvas = RedrawRequestCountingCanvasView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        canvas.project = project
        // 初期化と最初の設定での要求は数えない。
        let baseline = canvas.redrawRequestCount

        // CanvasViewRepresentable.updateUIView と同じく、同じインスタンスの中の要素を変えてから設定し直す。
        shape.position = CGPoint(x: 50, y: 60)
        canvas.project = project

        XCTAssertGreaterThan(
            canvas.redrawRequestCount, baseline,
            "同じインスタンスの設定し直しでも再描画を要求する（要素の変更は、この要求で描画に反映される）"
        )
    }
}

/// 再描画の要求（setNeedsDisplay）を数える CanvasView。実際の描画の回数やタイミングは確かめない。
private final class RedrawRequestCountingCanvasView: CanvasView {
    private(set) var redrawRequestCount = 0

    override func setNeedsDisplay() {
        redrawRequestCount += 1
        super.setNeedsDisplay()
    }
}
