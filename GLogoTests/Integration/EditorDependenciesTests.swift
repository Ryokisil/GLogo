// Composition Root から渡す依存が、エディタの実際の操作から呼ばれることと、エディタ内での生成の単位を確かめる。
// テスト側の生成口（LiveDependencyDefaults）を通さず、本番の初期化 EditorViewModel(dependencies:) を直接使う。

import UIKit
import XCTest
@testable import GLogo

final class EditorDependenciesTests: XCTestCase {
    @MainActor
    func test_editorInit_createsOnlySharedRemover() {
        let recorder = DependencyRecorder()
        let editor = EditorViewModel(dependencies: recorder.makeDependencies())

        // AI ツールと共有する背景除去だけを初期化時に作り、画面ごとの依存は画面を開くまで作らない。
        XCTAssertEqual(recorder.createdRemovers, 1)
        XCTAssertEqual(recorder.createdResolvers, 0)
        XCTAssertEqual(recorder.createdBlurUseCases, 0)
        _ = editor.aiTools
        XCTAssertEqual(recorder.createdRemovers, 1, "AI ツールはエディタの背景除去を共有する")
    }

    @MainActor
    func test_save_reachesInjectedSaver() {
        let recorder = DependencyRecorder()
        let editor = EditorViewModel(dependencies: recorder.makeDependencies())
        let finished = expectation(description: "保存の完了")
        finished.expectedFulfillmentCount = 2

        editor.saveToPhotoLibrary { _ in finished.fulfill() }
        editor.saveCompositeToPhotoLibrary { _ in finished.fulfill() }

        wait(for: [finished], timeout: 1)
        XCTAssertEqual(recorder.saver.requests, ["save", "saveComposite"])
    }

    @MainActor
    func test_import_reachesInjectedImporter() throws {
        let recorder = DependencyRecorder()
        let editor = EditorViewModel(dependencies: recorder.makeDependencies())

        editor.addImageElement(imageData: try XCTUnwrap(snapshotImage(.red).pngData()), position: .zero)

        XCTAssertEqual(recorder.importer.callCount, 1)
    }

    @MainActor
    func test_backgroundRemoval_reachesInjectedRemover() async throws {
        let recorder = DependencyRecorder()
        let (editor, image) = try makeEditor(recorder: recorder)
        let finished = expectation(description: "背景除去の完了")
        let observation = editor.aiTools.$isProcessingAI.dropFirst().filter { !$0 }.prefix(1)
            .sink { _ in finished.fulfill() }

        editor.aiTools.requestAIBackgroundRemoval(for: image)

        await fulfillment(of: [finished], timeout: 3)
        let removals = await recorder.remover.callCount
        XCTAssertEqual(removals, 1)
        withExtendedLifetime(observation) {}
    }

    @MainActor
    func test_upscale_reusesEditorExecutor() async throws {
        let recorder = DependencyRecorder()
        let (editor, first) = try makeEditor(recorder: recorder)
        let second = ImageElementFactory().makeElement(imageData: try XCTUnwrap(snapshotImage(.green).pngData()))
        editor.addElement(second)

        // 同じエディタの2回の高画質化が、注入した1つの実行器へ届く（要求ごとに作り直さない）。
        for image in [first, second] {
            editor.selectElement(image)
            let finished = expectation(description: "高画質化の完了")
            let observation = editor.aiTools.$isProcessingUpscale.dropFirst().filter { !$0 }.prefix(1)
                .sink { _ in finished.fulfill() }
            editor.aiTools.requestImageUpscale(for: image)
            await fulfillment(of: [finished], timeout: 3)
            withExtendedLifetime(observation) {}
        }

        let upscales = await recorder.pipeline.callCount
        XCTAssertEqual(upscales, 2)
        XCTAssertTrue(first.hasAppliedUpscale)
        XCTAssertTrue(second.hasAppliedUpscale)
    }

    // MARK: - 生成

    @MainActor
    private func makeEditor(recorder: DependencyRecorder) throws -> (EditorViewModel, ImageElement) {
        let image = ImageElementFactory().makeElement(imageData: try XCTUnwrap(snapshotImage(.red).pngData()))
        let project = LogoProject()
        project.addElement(image)
        let editor = EditorViewModel(project: project, dependencies: recorder.makeDependencies())
        editor.selectElement(image)
        return (editor, image)
    }
}

// MARK: - 記録用の依存

/// 依存の生成回数と、注入した処理への到達を記録する。
@MainActor
private final class DependencyRecorder {
    let saver = SaverSpy()
    let importer = ImporterSpy()
    let remover = RemoverSpy()
    let pipeline = UpscalePipelineSpy()
    private(set) var createdRemovers = 0
    private(set) var createdResolvers = 0
    private(set) var createdBlurUseCases = 0

    func makeDependencies() -> EditorDependencies {
        EditorDependencies(
            photoLibrarySaver: saver,
            imageImporter: importer,
            imageUpscaleUseCase: ImageUpscaleUseCase(lanczosPipeline: pipeline, realESRGANPipeline: pipeline),
            makeBackgroundRemover: { [unowned self] in
                createdRemovers += 1
                return remover
            },
            makeImageSourceResolver: { [unowned self] in
                createdResolvers += 1
                return AppComposition.makeImageSourceResolver()
            },
            makeManualBackgroundBlurUseCase: { [unowned self] in
                createdBlurUseCases += 1
                return AppComposition.makeManualBackgroundBlurUseCase()
            }
        )
    }
}

@MainActor
private final class SaverSpy: PhotoLibrarySaving {
    private(set) var requests: [String] = []

    func save(project: LogoProject, completion: @escaping @MainActor @Sendable (PhotoLibrarySaveResult) -> Void) {
        requests.append("save")
        completion(.success(()))
    }

    func saveComposite(project: LogoProject, completion: @escaping @MainActor @Sendable (PhotoLibrarySaveResult) -> Void) {
        requests.append("saveComposite")
        completion(.success(()))
    }
}

private final class ImporterSpy: ImageImporting {
    private(set) var callCount = 0

    func importImage(source: ImageImportSource, project: LogoProject, viewportSize: CGSize,
                     assetIdentifier: String?, canvasSize: CGSize?) -> ImageImportResult? {
        callCount += 1
        return nil
    }
}

private actor RemoverSpy: BackgroundRemovalProcessing {
    private(set) var callCount = 0

    func removeBackground(from image: UIImage) async throws -> UIImage {
        callCount += 1
        return image
    }

    func generateMask(from image: UIImage) async throws -> UIImage {
        image
    }
}

private actor UpscalePipelineSpy: ImageUpscalingPipeline {
    private(set) var callCount = 0
    nonisolated var method: ImageUpscaleMethod { .realESRGAN }
    nonisolated var isAvailable: Bool { true }

    func upscale(_ request: ImageUpscaleRequest) async throws -> ImageUpscaleResult {
        callCount += 1
        return ImageUpscaleResult(image: snapshotImage(.blue), appliedMethod: .realESRGAN,
                                  scaleFactor: request.scaleFactor, actualScaleMultiplier: 2)
    }
}
