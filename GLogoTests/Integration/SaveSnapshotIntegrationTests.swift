// 権限待ち・加工待ち・AI 完了を制御し、保存要求時の内容が書き出されることを検証する。

import Combine
import Photos
import UIKit
import XCTest
@testable import GLogo

final class SaveSnapshotIntegrationTests: XCTestCase {
    @MainActor
    func test_authorizationWait_freezesBothSaveEntries() async throws {
        for composite in [false, true] {
            let writer = SnapshotWriter()
            let coordinator = SaveImageCoordinator(processingService: ImageProcessingService(), writer: writer)
            let (project, image) = makeProject()
            let expected = try XCTUnwrap(composite
                ? ImageProcessingService().makeCompositeImage(baseElement: image, project: project)
                : ImageProcessingService().applyFilters(to: image))
            let completed = expectation(description: "保存完了")
            let completion: @MainActor @Sendable (PhotoLibrarySaveResult) -> Void = { result in
                if case .failure(let error) = result { XCTFail("\(error)") }
                completed.fulfill()
            }
            if composite {
                coordinator.saveComposite(project: project, completion: completion)
            } else {
                coordinator.save(project: project, completion: completion)
            }
            image.replaceImageSource(with: snapshotImage(.blue).pngData()!, resetAdjustments: true)
            image.showFrame = true
            image.size = CGSize(width: 3, height: 2)
            project.backgroundSettings.color = .green
            project.canvasSize = .zero
            project.elements.removeAll()
            writer.authorize()
            await fulfillment(of: [completed], timeout: 5)
            XCTAssertEqual(writer.savedImage?.pngData(), expected.pngData())
            XCTAssertEqual(writer.writeCount, 1)
        }
    }

    @MainActor
    func test_processingWait_isolatesComposition() async throws {
        let writer = SnapshotWriter()
        let started = expectation(description: "加工開始")
        let processor = PausedSnapshotProcessing(started: started)
        defer { processor.resume() }
        let coordinator = SaveImageCoordinator(processingService: processor, writer: writer)
        let (project, base) = makeProject()
        let overlay = ImageElementFactory().makeElement(imageData: snapshotImage(.blue).pngData()!, importOrder: 2)
        overlay.imageRole = .overlay
        overlay.position = CGPoint(x: 4, y: 5)
        overlay.size = CGSize(width: 8, height: 8)
        overlay.zIndex = 180
        let text = TextElement(text: "A", fontSize: 12)
        text.size = CGSize(width: 16, height: 16)
        let glow = GlowEffect(color: .green, radius: 2)
        text.effects = [glow]
        text.zIndex = 310
        let shape = ShapeElement(shapeType: .rectangle, fillColor: .yellow)
        shape.size = CGSize(width: 4, height: 4)
        shape.zIndex = 220
        project.elements += [overlay, text, shape]
        let expected = try XCTUnwrap(ImageProcessingService().makeCompositeImage(baseElement: base, project: project))
        let completed = expectation(description: "合成保存完了")
        coordinator.save(project: project) { result in
            if case .failure(let error) = result { XCTFail("\(error)") }
            completed.fulfill()
        }
        writer.authorize()
        await fulfillment(of: [started], timeout: 5)
        base.imageRole = .overlay
        overlay.imageRole = .base
        overlay.zIndex = 500
        text.text = "B"
        glow.radius = 10
        shape.fillColor = .black
        base.brightnessAdjustment = 0.8
        project.elements.removeAll()
        processor.resume()
        await fulfillment(of: [completed], timeout: 5)
        XCTAssertEqual(writer.savedImage?.pngData(), expected.pngData())
        XCTAssertEqual(text.text, "B")
        XCTAssertEqual(glow.radius, 10, "保存側の描画は編集側の効果を触らない")
    }

    @MainActor
    func test_aiCompletionAndUndo_doNotChangePendingSave() async throws {
        let writer = SnapshotWriter()
        let started = expectation(description: "AI 開始")
        let ai = SaveBoundaryAIProcessor(started: started)
        let (project, image) = makeProject()
        image.brightnessAdjustment = 0.2
        let expected = try XCTUnwrap(ImageProcessingService().applyFilters(to: image))
        let editor = EditorViewModel(project: project, backgroundRemovalUseCase: ai,
                                     photoLibrarySaver: SaveImageCoordinator(processingService: ImageProcessingService(), writer: writer))
        let aiFinished = expectation(description: "AI 完了")
        let observation = editor.aiTools.$isProcessingAI.dropFirst().filter { !$0 }.sink { _ in aiFinished.fulfill() }
        editor.aiTools.requestAIBackgroundRemoval(for: image)
        await fulfillment(of: [started], timeout: 3)
        let saved = expectation(description: "保存完了")
        editor.saveToPhotoLibrary { result in
            if case .failure(let error) = result { XCTFail("\(error)") }
            saved.fulfill()
        }
        XCTAssertTrue(editor.isSavingImage)
        await ai.finish(snapshotImage(.blue))
        await fulfillment(of: [aiFinished], timeout: 3)
        XCTAssertEqual(image.brightnessAdjustment, 0)
        editor.undo()
        XCTAssertEqual(image.brightnessAdjustment, 0.2)
        editor.redo()
        project.removeElement(withId: image.id)
        writer.authorize()
        await fulfillment(of: [saved], timeout: 5)
        XCTAssertEqual(writer.savedImage?.pngData(), expected.pngData())
        XCTAssertFalse(editor.isSavingImage)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        withExtendedLifetime(observation) {}
    }

    @MainActor
    func test_pendingSave_doesNotRetainSourceProject() async {
        let writer = SnapshotWriter()
        var project: LogoProject? = makeProject().0
        weak var source = project
        let completed = expectation(description: "画面解放後の保存完了")
        SaveImageCoordinator(processingService: ImageProcessingService(), writer: writer).save(project: project!) { result in
            if case .failure(let error) = result { XCTFail("\(error)") }
            completed.fulfill()
        }
        project = nil
        XCTAssertNil(source)
        writer.authorize()
        await fulfillment(of: [completed], timeout: 5)
        XCTAssertEqual(writer.writeCount, 1)
    }

    // MARK: - エディタの管理役（第18回）

    /// 両方の入口で、元画像は権限待ちより前の受付で管理役から1回だけ受け取り、完了まで問い合わせない。
    /// 保存した画像は、管理役が返した画像（要素自身の赤ではなく緑）から作られる。
    @MainActor
    func test_acceptance_readsStoreOnlyWhileSaving() async throws {
        for composite in [false, true] {
            let writer = SnapshotWriter()
            let coordinator = SaveImageCoordinator(processingService: ImageProcessingService(), writer: writer)
            let (project, image) = makeProject()
            let store = RenderSessionReadingSpy(original: snapshotImage(.green))
            let completed = expectation(description: "保存完了")
            let completion: @MainActor @Sendable (PhotoLibrarySaveResult) -> Void = { result in
                if case .failure(let error) = result { XCTFail("\(error)") }
                completed.fulfill()
            }
            if composite {
                coordinator.saveComposite(project: project, renderSessions: store, completion: completion)
            } else {
                coordinator.save(project: project, renderSessions: store, completion: completion)
            }
            XCTAssertEqual(store.requests, [.init(.originalImage, image)], "合成: \(composite)")

            writer.authorize()
            await fulfillment(of: [completed], timeout: 5)
            XCTAssertEqual(store.requests.count, 1, "受付のあとは問い合わせない（合成: \(composite)）")
            try assertCenter(of: XCTUnwrap(writer.savedImage), isGreen: true, "合成: \(composite)")
        }
    }

    /// 保存の要求は管理役を持たない。権限待ちの間に管理役を解放しても、受付で固定した画像で保存できる。
    @MainActor
    func test_pendingSave_doesNotRetainStore() async throws {
        for composite in [false, true] {
            let writer = SnapshotWriter()
            let coordinator = SaveImageCoordinator(processingService: ImageProcessingService(), writer: writer)
            let (project, _) = makeProject()
            var store: RenderSessionReadingSpy? = RenderSessionReadingSpy(original: snapshotImage(.green))
            weak let weakStore = store
            let completed = expectation(description: "管理役の解放後の保存完了")
            let completion: @MainActor @Sendable (PhotoLibrarySaveResult) -> Void = { result in
                if case .failure(let error) = result { XCTFail("\(error)") }
                completed.fulfill()
            }
            if composite {
                coordinator.saveComposite(project: project, renderSessions: try XCTUnwrap(store), completion: completion)
            } else {
                coordinator.save(project: project, renderSessions: try XCTUnwrap(store), completion: completion)
            }
            store = nil
            XCTAssertNil(weakStore, "権限待ちの間、保存の要求は管理役を持たない（合成: \(composite)）")

            writer.authorize()
            await fulfillment(of: [completed], timeout: 5)
            XCTAssertEqual(writer.writeCount, 1)
            try assertCenter(of: XCTUnwrap(writer.savedImage), isGreen: true, "合成: \(composite)")
        }
    }

    /// 保存した画像の中央が、緑（管理役が返した画像）か赤（要素自身の画像）かを確かめる。
    private func assertCenter(
        of image: UIImage,
        isGreen: Bool,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let cgImage = try XCTUnwrap(image.cgImage, file: file, line: line)
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ), file: file, line: line)
        let center = CGRect(x: cgImage.width / 2, y: cgImage.height / 2, width: 1, height: 1)
        let cropped = try XCTUnwrap(cgImage.cropping(to: center), file: file, line: line)
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let (red, green) = (Int(pixel[0]), Int(pixel[1]))
        if isGreen {
            XCTAssertTrue(green > 200 && red < 60, "\(message)（RGBA: \(pixel)）", file: file, line: line)
        } else {
            XCTAssertTrue(red > 200 && green < 60, "\(message)（RGBA: \(pixel)）", file: file, line: line)
        }
    }

    private func makeProject() -> (LogoProject, ImageElement) {
        let project = LogoProject(canvasSize: CGSize(width: 32, height: 24))
        let image = ImageElementFactory().makeElement(imageData: snapshotImage(.red).pngData()!, importOrder: 1)
        image.size = project.canvasSize
        project.addElement(image)
        return (project, image)
    }
}

/// 権限応答だけを保留し、非同期書き込みの結果をロックで保護する。
private final class SnapshotWriter: PhotoLibraryWriting, @unchecked Sendable {
    private let lock = NSLock()
    private var authorization: (@Sendable (PHAuthorizationStatus) -> Void)?
    private var image: UIImage?
    private var count = 0

    var savedImage: UIImage? { lock.withLock { image } }
    var writeCount: Int { lock.withLock { count } }
    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus { .notDetermined }
    func requestAuthorization(for accessLevel: PHAccessLevel, handler: @escaping @Sendable (PHAuthorizationStatus) -> Void) {
        lock.withLock { authorization = handler }
    }
    func authorize() {
        let handler = lock.withLock {
            let handler = authorization
            authorization = nil
            return handler
        }
        XCTAssertNotNil(handler)
        handler?(.authorized)
    }
    func performSave(of image: UIImage, format: SaveImageFormat) async throws {
        lock.withLock {
            self.image = image
            count += 1
        }
    }
}

/// 待機は detached 保存タスク上だけで行い、MainActor を止めない。
private final class PausedSnapshotProcessing: ImageProcessing, @unchecked Sendable {
    private let gate = DispatchSemaphore(value: 0)
    private let started: XCTestExpectation
    init(started: XCTestExpectation) { self.started = started }
    func resume() { gate.signal() }
    func applyFilters(to imageElement: ImageElement, images: any SaveImageReading) -> UIImage? {
        XCTFail("合成モードを維持するべき")
        return nil
    }
    func makeCompositeImage(baseElement: ImageElement, project: LogoProject, images: any SaveImageReading) -> UIImage? {
        started.fulfill()
        guard gate.wait(timeout: .now() + 5) == .success else {
            XCTFail("加工再開が届かない")
            return nil
        }
        // 受け取った保存の範囲をそのまま渡し、本番と同じ画像で合成する。
        return ImageProcessingService().makeCompositeImage(baseElement: baseElement, project: project, images: images)
    }
}

private actor SaveBoundaryAIProcessor: BackgroundRemovalProcessing {
    let started: XCTestExpectation
    private var continuation: CheckedContinuation<UIImage, Never>?
    init(started: XCTestExpectation) { self.started = started }
    func removeBackground(from image: UIImage) async throws -> UIImage {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            started.fulfill()
        }
    }
    func generateMask(from image: UIImage) async throws -> UIImage { image }
    func finish(_ image: UIImage) {
        continuation?.resume(returning: image)
        continuation = nil
    }
}
