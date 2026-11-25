// 予約取消、完了順の逆転、所有者解放時に古い画像を反映しない契約を検証する。

import UIKit
import XCTest
@testable import GLogo

final class ImageRenderRefreshUseCaseTests: XCTestCase {
    @MainActor
    private func makeContext() -> (ImageElement, EditorViewModel) {
        let image = ImageElementFactory().makeElement(imageData: Data(), importOrder: 0)
        let project = LogoProject()
        project.addElement(image)
        return (image, EditorViewModel(project: project))
    }

    @MainActor
    func test_cancel_discardsDispatchedCallback() async throws {
        let scheduler = ManualImageRenderScheduler()
        let refresh = ImageRenderRefreshUseCase(renderScheduler: scheduler)
        let (image, editor) = makeContext()
        defer { withExtendedLifetime(editor) {} }
        let stale = expectation(description: "取消済み通知")
        stale.isInverted = true
        refresh.scheduleFinalRefresh(for: image, edits: editor.imageEdits) { stale.fulfill() }
        let dispatched = try XCTUnwrap(scheduler.pending)
        refresh.cancelScheduledRefresh()
        // DispatchWorkItem の取消後にも、既に取り出された処理が到着し得る。
        dispatched()
        let latest = expectation(description: "最新通知")
        refresh.scheduleFinalRefresh(for: image, edits: editor.imageEdits) { latest.fulfill() }
        scheduler.runPending()
        await fulfillment(of: [latest, stale], timeout: 0.2)
    }

    @MainActor
    func test_render_latestCompletionWins() async {
        let scheduler = ManualImageRenderScheduler()
        let renderer = ControlledImageRenderer()
        let refresh = ImageRenderRefreshUseCase(renderScheduler: scheduler, renderFullQuality: renderer.render)
        let (image, editor) = makeContext()
        defer { withExtendedLifetime(editor) {} }
        var updates = 0
        for index in 0..<2 {
            let started = expectation(description: "描画開始 \(index)")
            renderer.onStart = { started.fulfill() }
            refresh.scheduleFullQualityRefresh(for: image, edits: editor.imageEdits, renderSessions: editor.managedRenderSessions) { updates += 1 }
            scheduler.runPending()
            await fulfillment(of: [started], timeout: 1)
        }
        let latestImage = UIImage()
        for index in [1, 0] {
            let returned = expectation(description: "描画復帰 \(index)")
            renderer.onReturn = { returned.fulfill() }
            renderer.finish(index, with: index == 1 ? latestImage : UIImage())
            await fulfillment(of: [returned], timeout: 1)
            XCTAssertTrue(editor.sessionStore.cachedRenderedImage(of: image) === latestImage)
            XCTAssertEqual(updates, 1)
        }
    }

    @MainActor
    func test_pendingRender_doesNotRetainOwner() async {
        let scheduler = ManualImageRenderScheduler()
        let renderer = ControlledImageRenderer()
        var refresh: ImageRenderRefreshUseCase? = ImageRenderRefreshUseCase(
            renderScheduler: scheduler, renderFullQuality: renderer.render
        )
        weak var weakRefresh = refresh
        let (image, editor) = makeContext()
        defer { withExtendedLifetime(editor) {} }
        let started = expectation(description: "描画開始")
        renderer.onStart = { started.fulfill() }
        refresh?.scheduleFullQualityRefresh(for: image, edits: editor.imageEdits, renderSessions: editor.managedRenderSessions) { XCTFail("解放後は更新しない") }
        scheduler.runPending()
        await fulfillment(of: [started], timeout: 1)
        refresh = nil
        XCTAssertNil(weakRefresh)
        let returned = expectation(description: "描画復帰")
        renderer.onReturn = { returned.fulfill() }
        renderer.finish(0, with: UIImage())
        await fulfillment(of: [returned], timeout: 1)
        XCTAssertNil(editor.sessionStore.cachedRenderedImage(of: image))
    }
}
