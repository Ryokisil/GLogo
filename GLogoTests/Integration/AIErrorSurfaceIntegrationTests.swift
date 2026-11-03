// AI の失敗とクリア・選択変更が、共有状態を通じてパネルへ伝わることを検証する。

import Combine
import UIKit
import XCTest
@testable import GLogo

final class AIErrorSurfaceIntegrationTests: XCTestCase {
    @MainActor
    func test_initialErrors_areEmpty() {
        let editor = EditorViewModel()
        let panel = ElementViewModel(editorViewModel: editor)
        XCTAssertTrue(panel.aiTools === editor.aiTools)
        XCTAssertNil(panel.lastBackgroundRemovalErrorMessage)
        XCTAssertNil(panel.lastBackgroundBlurErrorMessage)
        XCTAssertNil(panel.lastUpscaleErrorMessage)
    }

    @MainActor
    func test_failures_clearThroughPanel() async throws {
        let editor = EditorViewModel(backgroundRemovalUseCase: FailingAIProcessor())
        let panel = ElementViewModel(editorViewModel: editor)
        let image = try makeImage()
        editor.addElement(image)
        await failRequest(editor.aiTools, image: image, blur: false)
        await failRequest(editor.aiTools, image: image, blur: true)
        XCTAssertEqual(panel.lastBackgroundRemovalErrorMessage, "テスト用の処理失敗")
        XCTAssertEqual(panel.lastBackgroundBlurErrorMessage, "テスト用の処理失敗")
        panel.clearBackgroundRemovalError()
        panel.clearBackgroundBlurError()
        XCTAssertNil(editor.aiTools.lastBackgroundRemovalErrorMessage)
        XCTAssertNil(editor.aiTools.lastBackgroundBlurErrorMessage)
        XCTAssertNil(panel.lastBackgroundRemovalErrorMessage)
        XCTAssertNil(panel.lastBackgroundBlurErrorMessage)
    }

    @MainActor
    func test_failure_notifiesEditorAndPanel() async throws {
        let editor = EditorViewModel(backgroundRemovalUseCase: FailingAIProcessor())
        let panel = ElementViewModel(editorViewModel: editor)
        let image = try makeImage()
        editor.addElement(image)
        var editorNotifications = 0
        var panelNotifications = 0
        let editorObservation = editor.objectWillChange.sink { editorNotifications += 1 }
        let panelObservation = panel.objectWillChange.sink { panelNotifications += 1 }
        await failRequest(editor.aiTools, image: image, blur: false)
        XCTAssertGreaterThan(editorNotifications, 0)
        XCTAssertGreaterThan(panelNotifications, 0)
        XCTAssertEqual(panel.lastBackgroundRemovalErrorMessage, editor.aiTools.lastBackgroundRemovalErrorMessage)
        XCTAssertNotNil(panel.lastBackgroundRemovalErrorMessage)
        XCTAssertFalse(panel.isProcessingAI)
        withExtendedLifetime((editorObservation, panelObservation)) {}
    }

    @MainActor
    func test_selection_clearsErrorsOnlyForDifferentID() async throws {
        let editor = EditorViewModel(backgroundRemovalUseCase: FailingAIProcessor())
        let panel = ElementViewModel(editorViewModel: editor)
        let first = try makeImage()
        let second = try makeImage()
        editor.addElement(first)
        editor.addElement(second)
        editor.selectElement(first)
        await failRequest(editor.aiTools, image: first, blur: false)
        await failRequest(editor.aiTools, image: first, blur: true)
        editor.updateImageElement(first)
        XCTAssertNotNil(panel.lastBackgroundRemovalErrorMessage)
        XCTAssertNotNil(panel.lastBackgroundBlurErrorMessage)
        editor.selectElement(second)
        // 状態を複製せず同期購読するため、RunLoop 待ちなしで同じ値が見える。
        XCTAssertNil(editor.aiTools.lastBackgroundRemovalErrorMessage)
        XCTAssertNil(editor.aiTools.lastBackgroundBlurErrorMessage)
        XCTAssertNil(panel.lastBackgroundRemovalErrorMessage)
        XCTAssertNil(panel.lastBackgroundBlurErrorMessage)
    }

    @MainActor
    private func failRequest(_ tools: AIToolsViewModel, image: ImageElement, blur: Bool) async {
        let finished = expectation(description: "失敗後の処理終了")
        let observation = tools.$isProcessingAI.dropFirst().filter { !$0 }.sink { _ in finished.fulfill() }
        if blur { tools.requestAIBackgroundBlur(for: image) }
        else { tools.requestAIBackgroundRemoval(for: image) }
        XCTAssertTrue(tools.isProcessingAI)
        await fulfillment(of: [finished], timeout: 3)
        withExtendedLifetime(observation) {}
    }

    private func makeImage() throws -> ImageElement {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }
        return ImageElement(imageData: try XCTUnwrap(image.pngData()))
    }
}

private struct AIProcessingTestError: LocalizedError {
    var errorDescription: String? { "テスト用の処理失敗" }
}

private struct FailingAIProcessor: BackgroundRemovalProcessing {
    func removeBackground(from image: UIImage) async throws -> UIImage { throw AIProcessingTestError() }
    func generateMask(from image: UIImage) async throws -> UIImage { throw AIProcessingTestError() }
}
