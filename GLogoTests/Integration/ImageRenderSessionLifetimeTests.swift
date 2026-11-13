// エディタでの画像要素と描画のキャッシュの寿命（削除・Undo・履歴の上限・Redo の履歴の破棄・メモリ警告）の、今の振る舞いを固定する。
// 第20回で所有を管理役へ移すときと、第21回で解放の時点を変えるときに、変わった点と変わらない点をここで見分ける。
// キャッシュは、今は要素の API（cachedImage）で観察する。所有を移すときは、観察の場所も管理役へ移す。

import UIKit
import XCTest
@testable import GLogo

@MainActor
final class ImageRenderSessionLifetimeTests: XCTestCase {
    /// 削除した要素は削除のイベントが持ち、キャッシュも残る。Undo では同じインスタンスが、そのキャッシュごと戻る。
    func test_delete_keepsElementAndCacheForUndo() throws {
        let editor = EditorViewModel(project: LogoProject())
        weak var weakImage: ImageElement?
        do {
            let image = try makeImage(in: editor)
            weakImage = image
            editor.addElement(image)
            XCTAssertNotNil(editor.renderSessions.displayImage(of: image))
            editor.selectElement(image)
            editor.deleteSelectedElement()
        }
        XCTAssertNotNil(weakImage, "削除のイベントが要素を持つ")
        XCTAssertNotNil(weakImage?.cachedImage, "削除してもキャッシュは残る")

        editor.undo()

        let restored = try XCTUnwrap(weakImage)
        XCTAssertTrue(editor.project.elements.contains { $0 === restored }, "削除の Undo は同じインスタンスを戻す")
        XCTAssertNotNil(restored.cachedImage, "戻した要素は、残っていたキャッシュを使う")
    }

    /// メモリ警告では、プロジェクトにある要素のキャッシュだけを消し、削除した要素（履歴が持つ）のキャッシュは残る。
    /// 第21回で、削除した要素も解放の対象にする予定（そのときに期待値を変える）。
    func test_memoryWarning_keepsDeletedElementCache() async throws {
        let released = expectation(description: "メモリ警告の処理の終了")
        let defaultService = ReleaseSignalingPreviewService { released.fulfill() }
        let editor = EditorViewModel(project: LogoProject(), dependencies: .live(previewService: defaultService))
        let kept = try makeImage(in: editor)
        let deleted = try makeImage(in: editor)
        editor.addElement(kept)
        editor.addElement(deleted)
        XCTAssertNotNil(editor.renderSessions.displayImage(of: kept))
        XCTAssertNotNil(editor.renderSessions.displayImage(of: deleted))
        editor.selectElement(deleted)
        editor.deleteSelectedElement()

        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        // 既定の描画サービスは、要素のキャッシュをすべて消したあとで解放される。
        await fulfillment(of: [released], timeout: 2)

        XCTAssertNil(kept.cachedImage, "プロジェクトにある要素のキャッシュは消える")
        XCTAssertNotNil(deleted.cachedImage, "削除した要素のキャッシュは残る（第21回で変える予定）")
    }

    /// 削除のイベントが履歴の上限（100件）で押し出されると、削除した要素はキャッシュごと解放される。
    func test_historyOverflow_releasesDeletedElement() throws {
        let editor = EditorViewModel(project: LogoProject())
        weak var weakImage: ImageElement?
        do {
            let image = try makeImage(in: editor)
            weakImage = image
            editor.addElement(image)
            XCTAssertNotNil(editor.renderSessions.displayImage(of: image))
            editor.selectElement(image)
            editor.deleteSelectedElement()
        }

        for index in 0..<99 {
            editor.updateProjectName("name\(index)")
        }
        XCTAssertNotNil(weakImage, "上限に達するまでは、削除のイベントが持つ")

        editor.updateProjectName("name99")
        XCTAssertNil(weakImage, "削除のイベントが押し出されると解放される")
    }

    /// 追加を Undo した要素は Redo の履歴が持ち、新しい操作で Redo の履歴が消えると解放される。
    func test_newEventAfterUndoAdd_releasesElement() throws {
        let editor = EditorViewModel(project: LogoProject())
        weak var weakImage: ImageElement?
        do {
            let image = try makeImage(in: editor)
            weakImage = image
            editor.addElement(image)
            XCTAssertNotNil(editor.renderSessions.displayImage(of: image))
        }

        editor.undo()
        XCTAssertNotNil(weakImage, "追加の Undo のあとは、Redo の履歴が持つ")
        XCTAssertNotNil(weakImage?.cachedImage, "キャッシュも残る")

        editor.updateProjectName("other")
        XCTAssertNil(weakImage, "新しい操作で Redo の履歴が消えると解放される")
    }

    /// 削除そのものは編集中の状態を終えない（画面では、選択の解除を受けた編集パネルが終える）。
    func test_delete_keepsEditingState() throws {
        let editor = EditorViewModel(project: LogoProject())
        let image = try makeImage(in: editor)
        editor.addElement(image)
        image.startEditing()
        editor.selectElement(image)
        editor.deleteSelectedElement()
        editor.undo()

        XCTAssertNotNil(editor.renderSessions.displayImage(of: image))
        XCTAssertNil(image.cachedImage, "戻した要素は編集中のままで、表示画像をキャッシュしない（即時プレビューを返す）")
    }

    private func makeImage(in editor: EditorViewModel) throws -> ImageElement {
        ImageElementFactory().makeElement(
            imageData: try XCTUnwrap(snapshotImage(.red).pngData()),
            canvasSize: editor.project.canvasSize
        )
    }
}

/// メモリ警告で解放されたことを知らせる描画サービス。エディタの既定の描画サービスとしてだけ使い、画像は作らない。
private final class ReleaseSignalingPreviewService: ImagePreviewing {
    private let onRelease: @Sendable () -> Void

    init(onRelease: @escaping @Sendable () -> Void) {
        self.onRelease = onRelease
    }

    func generatePreviewImage(editingImage: UIImage?, originalImage: UIImage?, mode: ImageRenderMode) -> UIImage? {
        nil
    }

    func instantPreview(
        baseImage: UIImage?,
        params: ImageFilterParams,
        quality: RenderQuality,
        mode: ImageRenderMode
    ) -> UIImage? {
        nil
    }

    func applyFilters(to image: UIImage, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) -> UIImage? {
        nil
    }

    func applyFiltersAsync(
        to image: UIImage,
        params: ImageFilterParams,
        quality: RenderQuality,
        mode: ImageRenderMode
    ) async -> UIImage? {
        nil
    }

    func resetCache() {
        onRelease()
    }
}
