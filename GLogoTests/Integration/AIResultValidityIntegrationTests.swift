// AI の遅れた成功・失敗が、削除・履歴移動・別加工後の編集状態を壊さないことを検証する。

import Combine
import UIKit
import XCTest
@testable import GLogo

final class AIResultValidityIntegrationTests: XCTestCase {
    private enum Operation: CaseIterable { case removal, blur, upscale }

    @MainActor
    func test_staleResults_preserveCurrentState() async throws {
        for operation in Operation.allCases {
            for change in 0..<7 {
                let started = expectation(description: "処理開始 \(operation) / \(change)")
                let processor = DeferredImageProcessor(started: started)
                let (editor, tools, image) = makeContext(processor)
                image.brightnessAdjustment = 0.3
                editor.updateProjectName("Edited")
                let finished = expectation(description: "古い処理の終了")
                let observation = observeCompletion(tools, operation, finished)
                start(tools, operation, image)
                await fulfillment(of: [started], timeout: 3)

                switch change {
                case 0: editor.deleteSelectedElement()
                case 1:
                    editor.deleteSelectedElement()
                    editor.undo()
                case 2:
                    // 画像値が変わらない履歴移動でも、以前の要求を復活させない。
                    editor.undo()
                    editor.redo()
                case 3:
                    tools.applyManualBackgroundRemovalResult(snapshotImage(.green), to: image)
                case 4:
                    // 履歴確定前の変更と同値への復帰も検出する。
                    image.brightnessAdjustment = 0.8
                    image.brightnessAdjustment = 0.3
                case 5: editor.revertSelectedImageToInitialState()
                default:
                    let replacement = ImageElementFactory().makeElement(imageData: snapshotImage(.green).pngData()!)
                    replacement.id = image.id
                    editor.project.elements = [replacement]
                    editor.selectElement(replacement)
                }
                let history = editor.getHistoryDescriptions()
                let selected = editor.selectedElement
                let data = image.imageData
                let brightness = image.brightnessAdjustment
                let modified = editor.isProjectModified
                await processor.finish(operation == .upscale ? "upscale" : "ai", with: .success(snapshotImage(.blue)))
                await fulfillment(of: [finished], timeout: 3)
                XCTAssertEqual(editor.getHistoryDescriptions(), history, "古い結果を履歴に積まない")
                XCTAssertTrue(editor.selectedElement === selected)
                XCTAssertEqual(editor.isProjectModified, modified)
                XCTAssertEqual(image.imageData, data)
                XCTAssertEqual(image.brightnessAdjustment, brightness)
                XCTAssertNil(image.backgroundBlurMaskData)
                XCTAssertFalse(image.hasAppliedUpscale)
                XCTAssertFalse(tools.isProcessingAI)
                XCTAssertFalse(tools.isProcessingUpscale)
                XCTAssertNil(tools.lastBackgroundRemovalErrorMessage)
                XCTAssertNil(tools.lastBackgroundBlurErrorMessage)
                XCTAssertNil(tools.lastUpscaleErrorMessage)
                withExtendedLifetime(observation) {}
            }
        }
    }

    @MainActor
    func test_competingRequests_firstValidCompletionWins() async {
        for upscaleFirst in [false, true] {
            let started = expectation(description: "両方の処理開始")
            started.expectedFulfillmentCount = 2
            let processor = DeferredImageProcessor(started: started)
            let (editor, tools, image) = makeContext(processor)
            let aiFinished = expectation(description: "背景除去終了")
            let upscaleFinished = expectation(description: "高画質化終了")
            let aiObservation = observeCompletion(tools, .removal, aiFinished)
            let upscaleObservation = observeCompletion(tools, .upscale, upscaleFinished)
            start(tools, .removal, image)
            start(tools, .upscale, image)
            await fulfillment(of: [started], timeout: 3)
            let firstImage = snapshotImage(.blue)
            await processor.finish(upscaleFirst ? "upscale" : "ai", with: .success(firstImage))
            await fulfillment(of: [upscaleFirst ? upscaleFinished : aiFinished], timeout: 3)
            let history = editor.getHistoryDescriptions()
            XCTAssertEqual(history.count, 1)
            await processor.finish(upscaleFirst ? "ai" : "upscale", with: .success(snapshotImage(.green)))
            await fulfillment(of: [upscaleFirst ? aiFinished : upscaleFinished], timeout: 3)
            XCTAssertEqual(editor.getHistoryDescriptions(), history)
            XCTAssertEqual(image.imageData, firstImage.pngData())
            XCTAssertEqual(image.hasAppliedUpscale, upscaleFirst)
            XCTAssertFalse(tools.isProcessingAI)
            XCTAssertFalse(tools.isProcessingUpscale)
            withExtendedLifetime((aiObservation, upscaleObservation)) {}
        }
    }

    @MainActor
    func test_staleFailures_doNotReappear() async {
        for operation in Operation.allCases {
            for selectionOnly in [false, true] {
                let started = expectation(description: "失敗予定の処理開始")
                let processor = DeferredImageProcessor(started: started)
                let (editor, tools, image) = makeContext(processor)
                let finished = expectation(description: "失敗終了")
                let observation = observeCompletion(tools, operation, finished)
                start(tools, operation, image)
                await fulfillment(of: [started], timeout: 3)
                if selectionOnly {
                    editor.clearSelection()
                    editor.selectElement(image)
                } else {
                    image.backgroundBlurMaskData = Data([1])
                }
                await processor.finish(operation == .upscale ? "upscale" : "ai", with: .failure(DeferredImageProcessor.Failure()))
                await fulfillment(of: [finished], timeout: 3)
                XCTAssertNil(tools.lastBackgroundRemovalErrorMessage)
                XCTAssertNil(tools.lastBackgroundBlurErrorMessage)
                XCTAssertNil(tools.lastUpscaleErrorMessage)
                XCTAssertFalse(tools.isProcessingAI)
                XCTAssertFalse(tools.isProcessingUpscale)
                XCTAssertFalse(editor.canUndo)
                withExtendedLifetime(observation) {}
            }
        }
    }

    @MainActor
    func test_displayChanges_keepValidRequest() async {
        let started = expectation(description: "処理開始")
        let processor = DeferredImageProcessor(started: started)
        let (editor, tools, image) = makeContext(processor)
        let finished = expectation(description: "有効な結果の適用")
        let observation = observeCompletion(tools, .removal, finished)
        start(tools, .removal, image)
        await fulfillment(of: [started], timeout: 3)
        editor.addElement(TextElement(text: "Other"))
        image.position = CGPoint(x: 10, y: 20)
        image.cachedImage = snapshotImage(.green)
        image.startEditing()
        image.endEditing()
        let result = snapshotImage(.blue)
        await processor.finish("ai", with: .success(result))
        await fulfillment(of: [finished], timeout: 3)
        XCTAssertEqual(image.imageData, result.pngData())
        XCTAssertEqual(image.position, CGPoint(x: 10, y: 20))
        XCTAssertEqual(editor.getHistoryDescriptions().count, 2)
        XCTAssertTrue(editor.selectedElement === image, "有効な背景除去結果の選択方針は維持する")
        withExtendedLifetime(observation) {}
    }

    @MainActor
    func test_invalidatedRequest_canRetry() async {
        let started = expectation(description: "最初の処理開始")
        let processor = DeferredImageProcessor(started: started)
        let (editor, tools, image) = makeContext(processor)
        let firstFinished = expectation(description: "失効した要求の終了")
        var observation = observeCompletion(tools, .removal, firstFinished)
        start(tools, .removal, image)
        await fulfillment(of: [started], timeout: 3)
        image.tintIntensity = 0.3
        await processor.finish("ai", with: .success(snapshotImage(.blue)))
        await fulfillment(of: [firstFinished], timeout: 3)
        observation.cancel()
        let retryStarted = expectation(description: "再試行開始")
        await processor.setStarted(retryStarted)
        let retryFinished = expectation(description: "再試行終了")
        observation = observeCompletion(tools, .removal, retryFinished)
        start(tools, .removal, image)
        await fulfillment(of: [retryStarted], timeout: 3)
        let result = snapshotImage(.green)
        await processor.finish("ai", with: .success(result))
        await fulfillment(of: [retryFinished], timeout: 3)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        XCTAssertEqual(image.imageData, result.pngData())
        withExtendedLifetime(observation) {}
    }

    @MainActor
    func test_removedTarget_doesNotStartRequest() async {
        let started = expectation(description: "推論は開始しない")
        started.isInverted = true
        let processor = DeferredImageProcessor(started: started)
        let (editor, tools, image) = makeContext(processor)
        editor.project.elements.removeAll()
        for operation in Operation.allCases { start(tools, operation, image) }
        XCTAssertFalse(tools.isProcessingAI)
        XCTAssertFalse(tools.isProcessingUpscale)
        await fulfillment(of: [started], timeout: 0.1)
    }

    @MainActor
    private func makeContext(_ processor: DeferredImageProcessor) -> (EditorViewModel, AIToolsViewModel, ImageElement) {
        let image = ImageElementFactory().makeElement(imageData: snapshotImage(.red).pngData()!)
        let project = LogoProject()
        project.addElement(image)
        let editor = EditorViewModel(project: project)
        editor.selectElement(image)
        let tools = AIToolsViewModel(edits: editor.imageEdits, backgroundRemovalUseCase: processor,
                                    imageUpscaleUseCase: ImageUpscaleUseCase(lanczosPipeline: processor, realESRGANPipeline: processor),
                                    selection: editor.$selectedElement.eraseToAnyPublisher())
        return (editor, tools, image)
    }

    @MainActor
    private func start(_ tools: AIToolsViewModel, _ operation: Operation, _ image: ImageElement) {
        switch operation {
        case .removal: tools.requestAIBackgroundRemoval(for: image)
        case .blur: tools.requestAIBackgroundBlur(for: image)
        case .upscale: tools.requestImageUpscale(for: image, method: .lanczos)
        }
    }

    @MainActor
    private func observeCompletion(_ tools: AIToolsViewModel, _ operation: Operation, _ expectation: XCTestExpectation) -> AnyCancellable {
        let publisher = operation == .upscale ? tools.$isProcessingUpscale : tools.$isProcessingAI
        return publisher.dropFirst().filter { !$0 }.sink { _ in expectation.fulfill() }
    }
}

/// 継続をテストから再開し、背景除去／マスクと高画質化の完了順を制御する。
private actor DeferredImageProcessor: BackgroundRemovalProcessing, ImageUpscalingPipeline {
    nonisolated let method: ImageUpscaleMethod = .lanczos
    nonisolated let isAvailable = true
    private var started: XCTestExpectation
    private var continuations: [String: CheckedContinuation<UIImage, Error>] = [:]
    init(started: XCTestExpectation) { self.started = started }
    func setStarted(_ expectation: XCTestExpectation) { started = expectation }
    func removeBackground(from image: UIImage) async throws -> UIImage { try await suspend("ai") }
    func generateMask(from image: UIImage) async throws -> UIImage { try await suspend("ai") }
    func upscale(_ request: ImageUpscaleRequest) async throws -> ImageUpscaleResult {
        let image = try await suspend("upscale")
        return ImageUpscaleResult(image: image, appliedMethod: .lanczos, scaleFactor: .x2, actualScaleMultiplier: 2)
    }
    private func suspend(_ kind: String) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            continuations[kind] = continuation
            started.fulfill()
        }
    }
    func finish(_ kind: String, with result: Result<UIImage, Error>) {
        guard let continuation = continuations.removeValue(forKey: kind) else {
            XCTFail("未開始の処理: \(kind)")
            return
        }
        continuation.resume(with: result)
    }
    struct Failure: LocalizedError {
        var errorDescription: String? { "失効した要求のエラー" }
    }
}
