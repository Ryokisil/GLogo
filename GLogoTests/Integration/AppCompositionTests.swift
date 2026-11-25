// Composition Root が、アプリで使う実装をエディタごと・画面ごとに組み立てることを確かめる。

import UIKit
import XCTest
@testable import GLogo

final class AppCompositionTests: XCTestCase {
    @MainActor
    func test_editorImport_usesSharedPreviewService() throws {
        let editor = AppComposition.makeEditorViewModel()

        editor.addImageElement(imageData: try XCTUnwrap(snapshotImage(.green).pngData()), position: .zero)

        // 要素間で描画キャッシュを共有するため、取り込んだ画像は共有の描画サービスを使う。
        let image = try XCTUnwrap(editor.project.elements.compactMap { $0 as? ImageElement }.last)
        XCTAssertTrue(image.previewService === ImagePreviewService.shared)
    }

    /// 描画の更新は呼ぶたびに別の描画スケジューラを持つ。一方の取り消しは、他方の予約を消さない。
    @MainActor
    func test_renderRefresh_hasIndependentScheduler() async throws {
        let image = ImageElementFactory().makeElement(imageData: try XCTUnwrap(snapshotImage(.red).pngData()))
        let project = LogoProject()
        project.addElement(image)
        let editor = EditorViewModel(project: project, dependencies: .live())
        let first = AppComposition.makeImageRenderRefresh()
        let second = AppComposition.makeImageRenderRefresh()
        XCTAssertFalse(first === second)

        let kept = expectation(description: "別の更新を取り消しても予約は残る")
        first.scheduleFinalRefresh(for: image, edits: editor.imageEdits) { kept.fulfill() }
        second.cancelScheduledRefresh()
        await fulfillment(of: [kept], timeout: 2)

        // 対照：同じ更新で取り消すと、予約は実行されない。
        let cancelled = expectation(description: "取り消した予約は実行されない")
        cancelled.isInverted = true
        first.scheduleFinalRefresh(for: image, edits: editor.imageEdits) { cancelled.fulfill() }
        first.cancelScheduledRefresh()
        await fulfillment(of: [cancelled], timeout: 0.5)
    }

    @MainActor
    func test_screenFactories_createPerCall() {
        let dependencies = AppComposition.makeEditorDependencies()

        let first = dependencies.makeImageSourceResolver() as AnyObject
        let second = dependencies.makeImageSourceResolver() as AnyObject

        XCTAssertFalse(first === second, "画面を開くたびに新しく作る")
    }
}
