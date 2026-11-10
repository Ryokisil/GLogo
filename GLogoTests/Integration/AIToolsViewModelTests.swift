// AI の完了を制御し、履歴・要求の重複・通知・所有者の寿命を検証する。

import Combine
import UIKit
import XCTest
@testable import GLogo

final class AIToolsViewModelTests: XCTestCase {
    @MainActor
    func test_editorInjection_reachesSharedUpscaleAndHistory() async throws {
        let output = snapshotImage(.blue)
        let pipeline = InjectedUpscalePipeline(image: output)
        let useCase = ImageUpscaleUseCase(lanczosPipeline: pipeline, realESRGANPipeline: pipeline)
        let image = try makeElement()
        let originalData = image.imageData
        let project = LogoProject()
        project.addElement(image)
        let editor = EditorViewModel(project: project, imageUpscaleUseCase: useCase)
        let panel = ElementViewModel(editorViewModel: editor)
        editor.selectElement(image)
        XCTAssertTrue(panel.aiTools === editor.aiTools)
        XCTAssertTrue(panel.isRealESRGANAvailable)
        let finished = expectation(description: "注入した高画質化の完了")
        let observation = editor.aiTools.$isProcessingUpscale.dropFirst().filter { !$0 }.prefix(1)
            .sink { _ in finished.fulfill() }

        panel.requestImageUpscale()
        XCTAssertTrue(editor.aiTools.isProcessingUpscale)
        await fulfillment(of: [finished], timeout: 3)
        XCTAssertNil(panel.lastUpscaleErrorMessage)
        XCTAssertEqual(image.imageData, output.pngData())
        XCTAssertTrue(image.hasAppliedUpscale)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        XCTAssertTrue(editor.selectedElement === image)
        editor.undo()
        XCTAssertEqual(image.imageData, originalData)
        XCTAssertFalse(image.hasAppliedUpscale)
        editor.redo()
        XCTAssertEqual(image.imageData, output.pngData())
        XCTAssertTrue(image.hasAppliedUpscale)
        withExtendedLifetime(observation) {}
    }

    @MainActor
    func test_removal_rejectsOverlapAndRestoresHistory() async throws {
        let started = expectation(description: "背景除去開始")
        let processor = SuspendedAIProcessor(started: started)
        let image = try makeElement()
        image.brightnessAdjustment = 0.3
        image.tintColor = .red
        image.tintIntensity = 0.5
        image.hasAppliedUpscale = true
        let project = LogoProject()
        project.addElement(image)
        let editor = EditorViewModel(project: project, backgroundRemovalUseCase: processor)
        let oldData = image.imageData
        let oldID = image.originalImageIdentifier
        let finished = expectation(description: "背景除去完了")
        let observation = editor.aiTools.$isProcessingAI.dropFirst().filter { !$0 }.sink { _ in finished.fulfill() }

        editor.aiTools.requestAIBackgroundRemoval(for: image)
        editor.aiTools.requestAIBackgroundRemoval(for: image)
        editor.aiTools.requestAIBackgroundBlur(for: image)
        await fulfillment(of: [started], timeout: 3)
        let calls = await processor.calls
        XCTAssertEqual(calls, ["remove"])
        XCTAssertTrue(editor.aiTools.isProcessingAI)
        await processor.finish(with: makeImage(.black))
        await fulfillment(of: [finished], timeout: 3)

        XCTAssertFalse(editor.aiTools.isProcessingAI)
        XCTAssertNil(editor.aiTools.lastBackgroundRemovalErrorMessage)
        XCTAssertTrue(editor.selectedElement === image)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        XCTAssertNotEqual(image.imageData, oldData)
        XCTAssertNotEqual(image.originalImageIdentifier, oldID)
        XCTAssertEqual(image.brightnessAdjustment, 0)
        XCTAssertTrue(image.hasAppliedUpscale)
        editor.undo()
        XCTAssertEqual(image.imageData, oldData)
        XCTAssertEqual(image.originalImageIdentifier, oldID)
        XCTAssertEqual(image.brightnessAdjustment, 0.3)
        XCTAssertEqual(image.tintIntensity, 0.5)
        XCTAssertEqual(image.tintColor?.rgbaHexString, UIColor.red.rgbaHexString)
        editor.redo()
        XCTAssertEqual(image.brightnessAdjustment, 0)
        XCTAssertTrue(image.hasAppliedUpscale)
        withExtendedLifetime(observation) {}
    }

    @MainActor
    func test_blur_preservesSelectionAndEventOrder() async throws {
        let started = expectation(description: "マスク生成開始")
        let processor = SuspendedAIProcessor(started: started)
        let image = try makeElement()
        let other = TextElement(text: "Selected")
        let project = LogoProject()
        project.addElement(image)
        project.addElement(other)
        let editor = EditorViewModel(project: project, backgroundRemovalUseCase: processor)
        editor.selectElement(other)
        var historyCountsAtModification: [Int] = []
        let modificationObservation = editor.$isProjectModified.dropFirst().sink { modified in
            if modified { historyCountsAtModification.append(editor.getHistoryDescriptions().count) }
        }
        let finished = expectation(description: "マスク適用完了")
        let observation = editor.aiTools.$isProcessingAI.dropFirst().filter { !$0 }.sink { _ in finished.fulfill() }
        editor.aiTools.requestAIBackgroundBlur(for: image)
        await fulfillment(of: [started], timeout: 3)
        await processor.finish(with: makeImage(.white))
        await fulfillment(of: [finished], timeout: 3)

        XCTAssertTrue(editor.selectedElement === other)
        XCTAssertNotNil(image.backgroundBlurMaskData)
        XCTAssertEqual(image.backgroundBlurRadius, 12)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 2)
        XCTAssertEqual(historyCountsAtModification, [2], "両イベントの適用後に変更を通知する")
        editor.undo()
        XCTAssertNotNil(image.backgroundBlurMaskData)
        XCTAssertEqual(image.backgroundBlurRadius, 0)
        editor.undo()
        XCTAssertNil(image.backgroundBlurMaskData)
        editor.redo()
        editor.redo()
        XCTAssertNotNil(image.backgroundBlurMaskData)
        XCTAssertEqual(image.backgroundBlurRadius, 12)
        withExtendedLifetime((observation, modificationObservation)) {}
    }

    @MainActor
    func test_pendingRequest_doesNotRetainOwners() async throws {
        let started = expectation(description: "解放前の処理開始")
        let processor = SuspendedAIProcessor(started: started)
        var editor: EditorViewModel? = EditorViewModel(backgroundRemovalUseCase: processor)
        let image = try makeElement()
        editor?.addElement(image)
        weak var weakEditor = editor
        weak var weakTools = editor?.aiTools
        editor?.aiTools.requestAIBackgroundRemoval(for: image)
        await fulfillment(of: [started], timeout: 3)
        editor = nil
        XCTAssertNil(weakEditor)
        XCTAssertNil(weakTools)
        // 継続を必ず解放する。処理そのもののキャンセルは別の契約として扱う。
        await processor.finish(with: makeImage(.black))
    }

    @MainActor
    func test_maskEditing_routesNavigationAndUndo() throws {
        let editor = EditorViewModel()
        let panel = ElementViewModel(editorViewModel: editor)
        let image = try makeElement()
        editor.addElement(image)
        editor.aiTools.requestBackgroundBlurMaskEdit(for: image)
        XCTAssertTrue(panel.aiTools.isNavigatingToBackgroundBlurMaskEdit)
        XCTAssertTrue(panel.aiTools.backgroundBlurMaskEditTarget === image)
        let mask = try XCTUnwrap(makeImage(.white).pngData())
        editor.aiTools.applyBackgroundBlurMaskResult(mask, to: image)
        let count = editor.getHistoryDescriptions().count
        editor.aiTools.applyBackgroundBlurMaskResult(mask, to: image)
        XCTAssertEqual(editor.getHistoryDescriptions().count, count)
        editor.aiTools.removeBackgroundBlurMask(from: image)
        XCTAssertNil(image.backgroundBlurMaskData)
        XCTAssertEqual(image.backgroundBlurRadius, 0)
        editor.undo()
        editor.undo()
        XCTAssertEqual(image.backgroundBlurMaskData, mask)
        XCTAssertEqual(image.backgroundBlurRadius, 12)
        panel.aiTools.isNavigatingToBackgroundBlurMaskEdit = false
        XCTAssertFalse(editor.aiTools.isNavigatingToBackgroundBlurMaskEdit)
    }

    @MainActor
    func test_upscaleFailure_clearsBusyState() async throws {
        let target = ElementEditTargetSpy()
        let image = try makeElement()
        target.images = [image]
        let selection = CurrentValueSubject<LogoElement?, Never>(image)
        let pipeline = FailingUpscalePipeline()
        let tools = AIToolsViewModel(
            edits: ImageEditUseCase(target: target),
            renderSessions: ImageRenderSessionStore(),
            backgroundRemovalUseCase: AppComposition.makeBackgroundRemover(),
            imageUpscaleUseCase: ImageUpscaleUseCase(lanczosPipeline: pipeline, realESRGANPipeline: pipeline),
            selection: selection.eraseToAnyPublisher()
        )
        let finished = expectation(description: "高画質化の失敗")
        let observation = tools.$isProcessingUpscale.dropFirst().filter { !$0 }.sink { _ in finished.fulfill() }
        tools.requestImageUpscale(for: image, method: .lanczos)
        XCTAssertTrue(tools.isProcessingUpscale)
        await fulfillment(of: [finished], timeout: 3)
        XCTAssertFalse(tools.isProcessingUpscale)
        XCTAssertEqual(tools.lastUpscaleErrorMessage, "高画質化のテスト失敗")
        XCTAssertTrue(target.events.isEmpty)
        tools.clearUpscaleError()
        XCTAssertNil(tools.lastUpscaleErrorMessage)
        withExtendedLifetime(observation) {}
    }

    private func makeElement() throws -> ImageElement {
        ImageElementFactory().makeElement(imageData: try XCTUnwrap(makeImage(.white).pngData()))
    }

    private func makeImage(_ color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }
    }
}

/// テストが明示的に完了させるまで推論を保留する。
private actor SuspendedAIProcessor: BackgroundRemovalProcessing {
    let started: XCTestExpectation
    private var continuation: CheckedContinuation<UIImage, Error>?
    private(set) var calls: [String] = []

    init(started: XCTestExpectation) { self.started = started }

    func removeBackground(from image: UIImage) async throws -> UIImage {
        try await suspend("remove")
    }

    func generateMask(from image: UIImage) async throws -> UIImage {
        try await suspend("mask")
    }

    private func suspend(_ kind: String) async throws -> UIImage {
        calls.append(kind)
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            started.fulfill()
        }
    }

    func finish(with image: UIImage) {
        continuation?.resume(returning: image)
        continuation = nil
    }
}

private struct FailingUpscalePipeline: ImageUpscalingPipeline {
    var method: ImageUpscaleMethod { .lanczos }
    var isAvailable: Bool { true }
    func upscale(_ request: ImageUpscaleRequest) async throws -> ImageUpscaleResult { throw Failure() }

    private struct Failure: LocalizedError {
        var errorDescription: String? { "高画質化のテスト失敗" }
    }
}

/// Editorからの注入が画面と共有するAIへ届き、標準リクエストを維持することを確認する。
private struct InjectedUpscalePipeline: ImageUpscalingPipeline {
    let image: UIImage
    var method: ImageUpscaleMethod { .realESRGAN }
    var isAvailable: Bool { true }

    func upscale(_ request: ImageUpscaleRequest) async throws -> ImageUpscaleResult {
        XCTAssertEqual(request.method, .realESRGAN)
        XCTAssertEqual(request.scaleFactor, .x2)
        XCTAssertTrue(request.appliesSharpening)
        return ImageUpscaleResult(image: image, appliedMethod: .realESRGAN,
                                  scaleFactor: request.scaleFactor, actualScaleMultiplier: 2)
    }
}
