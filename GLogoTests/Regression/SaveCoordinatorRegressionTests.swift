//
//  SaveCoordinatorRegressionTests.swift
//  GLogoTests
//
//  概要:
//  SaveImageCoordinator の異常系回帰テスト。
//  合成保存時に makeCompositeImage が nil を返した場合に
//  completion(false) となることを検証し、以前の `?? baseImage` フォールバック復活を防止する。
//

import XCTest
import Photos
import UIKit
@testable import GLogo

// MARK: - モック実装

/// 合成結果を nil で返すモック（異常系再現用）
private struct StubImageProcessing_CompositeNil: ImageProcessing {
    /// applyFilters は有効な画像を返す（合成前段階を通過させるため）
    func applyFilters(to imageElement: ImageElement) -> UIImage? {
        makeSolidImage(color: .white)
    }

    /// 合成処理が失敗するケースを再現
    func makeCompositeImage(baseImage: UIImage, project: LogoProject) -> UIImage? {
        nil
    }
}

/// 常に最初の要素をベースとして返すモック
private struct StubImageSelecting: ImageSelecting {
    func selectBaseImageElement(from elements: [ImageElement]) -> ImageElement? {
        elements.first
    }

    func selectHighestResolutionImageElement(from elements: [ImageElement]) -> ImageElement? {
        elements.first
    }
}

/// 権限を常に authorized として返し、保存は常に成功するモック
private struct StubPhotoLibraryWriter: PhotoLibraryWriting {
    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus {
        .authorized
    }

    func requestAuthorization(for accessLevel: PHAccessLevel, handler: @escaping (PHAuthorizationStatus) -> Void) {
        handler(.authorized)
    }

    func performSave(of image: UIImage, format: SaveImageFormat) async throws {
        // 何もしない（テスト用）
    }
}

// MARK: - テスト

/// 合成保存異常系の回帰テスト
final class SaveCoordinatorRegressionTests: XCTestCase {

    /// makeCompositeImage が nil を返した場合に completion(false) になること
    /// - 以前は `?? baseImage` で無言成功していたが、修正後はエラー扱いとなる
    func testSaveComposite_CompositeFails_CompletionIsFalse() {
        let coordinator = SaveImageCoordinator(
            selectionService: StubImageSelecting(),
            processingService: StubImageProcessing_CompositeNil(),
            writer: StubPhotoLibraryWriter()
        )

        let project = makeProjectWithImageElement()
        let expectation = expectation(description: "completion が呼ばれること")
        var result: Bool?

        coordinator.saveComposite(project: project) { success in
            result = success
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
        XCTAssertEqual(result, false, "合成失敗時は completion(false) であるべき（フォールバック保存は不可）")
    }

    // MARK: - Helpers

    /// テスト用の最小プロジェクト（画像要素1つ）を作成
    /// - Returns: ImageElement を1つ含む LogoProject
    private func makeProjectWithImageElement() -> LogoProject {
        let project = LogoProject(name: "CoordinatorRegression", canvasSize: CGSize(width: 200, height: 100))
        let imageData = makeSolidImage(color: .red).pngData()!
        let imageElement = ImageElement(imageData: imageData, importOrder: 0)
        imageElement.imageRole = .base
        imageElement.position = .zero
        imageElement.size = CGSize(width: 200, height: 100)
        // テキスト要素も追加して composite モードの条件を満たす
        let textElement = TextElement(text: "T", fontName: "HelveticaNeue", fontSize: 20, textColor: .white)
        textElement.position = CGPoint(x: 10, y: 10)
        textElement.size = CGSize(width: 50, height: 20)
        project.addElement(imageElement)
        project.addElement(textElement)
        return project
    }
}

/// テスト用の単色画像を生成
/// - Parameter color: 塗りつぶし色
/// - Returns: 64x64 の単色 UIImage
private func makeSolidImage(color: UIColor) -> UIImage {
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
