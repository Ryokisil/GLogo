//
//  SaveCoordinatorMainActorCompletionRegressionTests.swift
//  GLogoTests
//
//  概要:
//  SaveImageCoordinator の completion が MainActor で呼ばれることを検証する回帰テスト。
//  Swift 6 移行での actor 境界退行を防ぐ。
//

import XCTest
import Photos
import UIKit
@testable import GLogo

// MARK: - Stubs

/// 常に先頭要素を選択する選択スタブ
private struct MainActorCompletionImageSelectingStub: ImageSelecting {
    func selectBaseImageElement(from elements: [ImageElement]) -> ImageElement? {
        elements.first
    }

    func selectHighestResolutionImageElement(from elements: [ImageElement]) -> ImageElement? {
        elements.first
    }
}

/// 常に画像生成成功させる処理スタブ
private struct MainActorCompletionImageProcessingStub: ImageProcessing {
    func applyFilters(to imageElement: ImageElement) -> UIImage? {
        _ = imageElement
        return makeMainActorCompletionSolidImage(color: .white)
    }

    func makeCompositeImage(baseImage: UIImage, project: LogoProject) -> UIImage? {
        _ = project
        return baseImage
    }
}

/// 権限と保存結果を制御できる writer スタブ
private final class MainActorCompletionWriterStub: @unchecked Sendable, PhotoLibraryWriting {
    let authorizationStatusValue: PHAuthorizationStatus
    let requestAuthorizationResult: PHAuthorizationStatus
    let shouldThrowOnSave: Bool

    init(
        authorizationStatusValue: PHAuthorizationStatus,
        requestAuthorizationResult: PHAuthorizationStatus = .authorized,
        shouldThrowOnSave: Bool = false
    ) {
        self.authorizationStatusValue = authorizationStatusValue
        self.requestAuthorizationResult = requestAuthorizationResult
        self.shouldThrowOnSave = shouldThrowOnSave
    }

    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus {
        _ = accessLevel
        return authorizationStatusValue
    }

    func requestAuthorization(for accessLevel: PHAccessLevel, handler: @escaping @Sendable (PHAuthorizationStatus) -> Void) {
        _ = accessLevel
        DispatchQueue.global(qos: .userInitiated).async {
            handler(self.requestAuthorizationResult)
        }
    }

    func performSave(of image: UIImage, format: SaveImageFormat) async throws {
        _ = image
        _ = format
        if shouldThrowOnSave {
            throw NSError(domain: "SaveCoordinatorMainActorCompletionRegressionTests", code: 1)
        }
    }
}

// MARK: - Tests

/// completion の MainActor 保証を検証する回帰テスト
final class SaveCoordinatorMainActorCompletionRegressionTests: XCTestCase {
    /// 権限拒否時も completion が MainActor で呼ばれることを確認
    /// - Parameters: なし
    /// - Returns: なし
    @MainActor
    func testSave_WhenAuthorizationDenied_CompletesOnMainActor() {
        let writer = MainActorCompletionWriterStub(authorizationStatusValue: .denied)
        let coordinator = SaveImageCoordinator(
            selectionService: MainActorCompletionImageSelectingStub(),
            processingService: MainActorCompletionImageProcessingStub(),
            writer: writer
        )
        let project = makeProjectWithSingleImageElement()
        let expectation = expectation(description: "completion called")

        var result: Bool?
        var completionOnMainThread = false

        coordinator.save(project: project) { success in
            completionOnMainThread = Thread.isMainThread
            result = success
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0)
        XCTAssertFalse(result ?? true)
        XCTAssertTrue(completionOnMainThread)
    }

    /// 未決定権限から許可された場合に completion が MainActor で成功することを確認
    /// - Parameters: なし
    /// - Returns: なし
    @MainActor
    func testSave_WhenAuthorizationRequestedAndGranted_CompletesOnMainActor() {
        let writer = MainActorCompletionWriterStub(
            authorizationStatusValue: .notDetermined,
            requestAuthorizationResult: .authorized
        )
        let coordinator = SaveImageCoordinator(
            selectionService: MainActorCompletionImageSelectingStub(),
            processingService: MainActorCompletionImageProcessingStub(),
            writer: writer
        )
        let project = makeProjectWithSingleImageElement()
        let expectation = expectation(description: "completion called")

        var result: Bool?
        var completionOnMainThread = false

        coordinator.save(project: project) { success in
            completionOnMainThread = Thread.isMainThread
            result = success
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
        XCTAssertTrue(result ?? false)
        XCTAssertTrue(completionOnMainThread)
    }

    // MARK: - Helpers

    /// 単一画像要素だけを持つプロジェクトを生成
    /// - Parameters: なし
    /// - Returns: テスト用プロジェクト
    private func makeProjectWithSingleImageElement() -> LogoProject {
        let project = LogoProject(name: "MainActorCompletion", canvasSize: CGSize(width: 256, height: 256))
        let imageData = makeMainActorCompletionSolidImage(color: .red).pngData() ?? Data()
        let element = ImageElement(imageData: imageData, importOrder: 0)
        project.addElement(element)
        return project
    }
}

/// 単色画像を生成
/// - Parameters:
///   - color: 塗りつぶし色
/// - Returns: 64x64 の単色画像
private func makeMainActorCompletionSolidImage(color: UIColor) -> UIImage {
    let size = CGSize(width: 64, height: 64)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { ctx in
        color.setFill()
        ctx.fill(CGRect(origin: .zero, size: size))
    }
}
