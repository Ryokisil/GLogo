// CanvasView が、同じプロジェクトを設定し直したときに再描画を要求する契約と、描くたびに背景画像を取得する契約を検証する。

import SwiftUI
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

    // MARK: - 背景画像（第26回）

    /// 実際のエディタ画面のキャンバスは、描くたびに背景画像を取得する。
    /// 受付で固定する保存とは違い、ファイルの更新は次の描画に出る。
    @MainActor
    func test_editorCanvas_drawsCurrentBackgroundImage() throws {
        var windows: [UIWindow] = []
        defer { windows.forEach { $0.isHidden = true } }
        let file = BackgroundAssetFile()
        defer { file.remove() }
        file.write(snapshotImage(.red))
        let project = LogoProject()
        project.backgroundSettings.type = .image
        project.backgroundSettings.imageFileName = file.name
        let canvas = try showCanvas(of: EditorViewModel(project: project), in: &windows)

        try assertRGBA(of: render(canvas), at: CGPoint(x: 10, y: 10), equals: BackgroundPixel.red,
                       "取得した背景画像（赤）を描く")

        file.write(snapshotImage(.blue))

        try assertRGBA(of: render(canvas), at: CGPoint(x: 10, y: 10), equals: BackgroundPixel.blue,
                       "描き直すと、更新したファイル（青）で描く")
    }

    /// 実際のエディタ画面を表示し、その中のキャンバスを取り出す（CanvasViewRepresentable の設定を通す）。
    @MainActor
    private func showCanvas(of editor: EditorViewModel, in windows: inout [UIWindow]) throws -> CanvasView {
        let host = UIHostingController(rootView: EditorView(viewModel: editor))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        windows.append(window)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        return try XCTUnwrap(findCanvas(in: host.view), "エディタ画面の中にキャンバスがある")
    }

    @MainActor
    private func findCanvas(in view: UIView) -> CanvasView? {
        if let canvas = view as? CanvasView { return canvas }
        for subview in view.subviews {
            if let canvas = findCanvas(in: subview) { return canvas }
        }
        return nil
    }

    /// キャンバスの描画（draw(_:)）を、キャンバスの左上 40×40 の範囲で行う。
    @MainActor
    private func render(_ canvas: CanvasView) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let rect = CGRect(x: 0, y: 0, width: 40, height: 40)
        return UIGraphicsImageRenderer(size: rect.size, format: format).image { _ in
            canvas.draw(rect)
        }
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
