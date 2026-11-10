// 編集失効と所有者解放で中止を伝え、終了前の二重要求とキャンセルエラーの表示を防ぐ。

import Combine
import XCTest
import UIKit
@testable import GLogo

final class AICancellationIntegrationTests: XCTestCase {
    @MainActor
    func test_invalidEdit_cancelsAndAllowsRetry() async {
        for operation in 0..<3 {
            let started = expectation(description: "加工開始")
            let cancelled = expectation(description: "キャンセル到達")
            let processor = CancellationImageProcessor(started: started, cancelled: cancelled)
            let (editor, tools, image) = makeContext(processor)
            let finished = expectation(description: "加工の終了")
            let observation = completion(tools, operation, finished)
            start(tools, operation, image)
            await fulfillment(of: [started], timeout: 1)
            image.brightnessAdjustment = 0.4
            // 選択通知のない編集でも objectWillChange の更新後に失効を検知する。
            editor.markProjectModified()
            await fulfillment(of: [cancelled], timeout: 1)
            XCTAssertTrue(operation == 2 ? tools.isProcessingUpscale : tools.isProcessingAI)
            start(tools, operation, image)
            let callsBeforeFinish = await processor.calls
            XCTAssertEqual(callsBeforeFinish, 1, "同期処理の終了前に再実行しない")
            await processor.finish()
            await fulfillment(of: [finished], timeout: 1)
            XCTAssertNil(tools.lastBackgroundRemovalErrorMessage)
            XCTAssertNil(tools.lastBackgroundBlurErrorMessage)
            XCTAssertNil(tools.lastUpscaleErrorMessage)
            XCTAssertFalse(editor.canUndo)
            XCTAssertEqual(image.brightnessAdjustment, 0.4)
            let restarted = expectation(description: "再実行開始")
            await processor.expectStart(restarted)
            let retried = expectation(description: "再実行終了")
            let retryObservation = completion(tools, operation, retried)
            start(tools, operation, image)
            await fulfillment(of: [restarted], timeout: 1)
            await processor.finish()
            await fulfillment(of: [retried], timeout: 1)
            XCTAssertTrue(editor.canUndo)
            withExtendedLifetime((observation, retryObservation)) {}
        }
    }

    @MainActor
    func test_selection_keepsValidRequest() async {
        let started = expectation(description: "加工開始")
        let cancelled = expectation(description: "選択だけでは取消さない")
        cancelled.isInverted = true
        let processor = CancellationImageProcessor(started: started, cancelled: cancelled)
        let (editor, tools, image) = makeContext(processor)
        let finished = expectation(description: "加工終了")
        let observation = completion(tools, 0, finished)
        tools.requestAIBackgroundRemoval(for: image)
        await fulfillment(of: [started], timeout: 1)
        editor.clearSelection()
        editor.selectElement(image)
        await processor.finish()
        await fulfillment(of: [finished, cancelled], timeout: 0.1)
        XCTAssertTrue(editor.canUndo)
        withExtendedLifetime(observation) {}
    }

    @MainActor
    func test_ownerRelease_cancelsRequest() async {
        let started = expectation(description: "加工開始")
        let cancelled = expectation(description: "所有者解放で取消")
        let processor = CancellationImageProcessor(started: started, cancelled: cancelled)
        var context: (EditorViewModel, AIToolsViewModel, ImageElement)? = makeContext(processor)
        weak var owner = context?.1
        context?.1.requestAIBackgroundRemoval(for: context!.2)
        await fulfillment(of: [started], timeout: 1)
        context = nil
        XCTAssertNil(owner)
        await fulfillment(of: [cancelled], timeout: 1)
        await processor.finish()
    }

    @MainActor
    private func makeContext(_ processor: CancellationImageProcessor) -> (EditorViewModel, AIToolsViewModel, ImageElement) {
        let image = ImageElementFactory().makeElement(imageData: snapshotImage(.red).pngData()!)
        let project = LogoProject()
        project.addElement(image)
        let editor = EditorViewModel(project: project)
        editor.selectElement(image)
        let tools = AIToolsViewModel(edits: editor.imageEdits, renderSessions: editor.renderSessions,
                                     backgroundRemovalUseCase: processor,
                                     imageUpscaleUseCase: ImageUpscaleUseCase(lanczosPipeline: processor, realESRGANPipeline: processor),
                                     selection: editor.$selectedElement.eraseToAnyPublisher(),
                                     changes: editor.objectWillChange.eraseToAnyPublisher())
        return (editor, tools, image)
    }

    @MainActor
    private func start(_ tools: AIToolsViewModel, _ operation: Int, _ image: ImageElement) {
        switch operation {
        case 0: tools.requestAIBackgroundRemoval(for: image)
        case 1: tools.requestAIBackgroundBlur(for: image)
        default: tools.requestImageUpscale(for: image, method: .lanczos)
        }
    }

    @MainActor
    private func completion(_ tools: AIToolsViewModel, _ operation: Int, _ expectation: XCTestExpectation) -> AnyCancellable {
        let publisher = operation == 2 ? tools.$isProcessingUpscale : tools.$isProcessingAI
        return publisher.dropFirst().filter { !$0 }.prefix(1).sink { _ in expectation.fulfill() }
    }
}

private actor CancellationImageProcessor: BackgroundRemovalProcessing, ImageUpscalingPipeline {
    nonisolated var method: ImageUpscaleMethod { .lanczos }
    nonisolated var isAvailable: Bool { true }
    private var started: XCTestExpectation
    private let cancelled: XCTestExpectation
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var calls = 0

    init(started: XCTestExpectation, cancelled: XCTestExpectation) {
        self.started = started
        self.cancelled = cancelled
    }

    func expectStart(_ expectation: XCTestExpectation) { started = expectation }

    func finish() {
        continuation?.resume()
        continuation = nil
    }

    private func process() async throws -> UIImage {
        calls += 1
        let cancelled = cancelled
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                started.fulfill()
            }
        } onCancel: { cancelled.fulfill() }
        // 中断不能な同期処理の終了後にだけ復帰する状況を模擬する。
        try Task.checkCancellation()
        return snapshotImage(.green)
    }

    func removeBackground(from image: UIImage) async throws -> UIImage { try await process() }
    func generateMask(from image: UIImage) async throws -> UIImage { try await process() }
    func upscale(_ request: ImageUpscaleRequest) async throws -> ImageUpscaleResult {
        ImageUpscaleResult(image: try await process(), appliedMethod: .lanczos, scaleFactor: .x2, actualScaleMultiplier: 2)
    }
}
