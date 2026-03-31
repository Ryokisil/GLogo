//
//  SaveCoordinatorRegressionTests.swift
//  GLogoTests
//
//  概要:
//  SaveImageCoordinator の異常系回帰テスト。
//  合成保存時に makeCompositeImage が nil を返した場合に
//  `compositeGenerationFailed` で失敗することを検証し、以前の `?? baseImage` フォールバック復活を防止する。
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
    func makeCompositeImage(baseElement: ImageElement, project: LogoProject) -> UIImage? {
        _ = baseElement; _ = project
        return nil
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

    func requestAuthorization(for accessLevel: PHAccessLevel, handler: @escaping @Sendable (PHAuthorizationStatus) -> Void) {
        handler(.authorized)
    }

    func performSave(of image: UIImage, format: SaveImageFormat) async throws {
        // 何もしない（テスト用）
    }
}

/// 保存された画像を検証用に保持する writer スタブ
private final class CapturingPhotoLibraryWriter: @unchecked Sendable, PhotoLibraryWriting {
    private let queue = DispatchQueue(label: "SaveCoordinatorRegressionTests.CapturingPhotoLibraryWriter")
    private var latestSavedImage: UIImage?
    private var latestSavedFormat: SaveImageFormat?

    var capturedImage: UIImage? {
        queue.sync { latestSavedImage }
    }

    var capturedFormat: SaveImageFormat? {
        queue.sync { latestSavedFormat }
    }

    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus {
        _ = accessLevel
        return .authorized
    }

    func requestAuthorization(for accessLevel: PHAccessLevel, handler: @escaping @Sendable (PHAuthorizationStatus) -> Void) {
        _ = accessLevel
        handler(.authorized)
    }

    func performSave(of image: UIImage, format: SaveImageFormat) async throws {
        queue.sync {
            latestSavedImage = image
            latestSavedFormat = format
        }
    }
}

// MARK: - テスト

/// 合成保存異常系の回帰テスト
final class SaveCoordinatorRegressionTests: XCTestCase {

    /// 単画像かつ見た目追加なしなら通常保存が選ばれること
    func testResolveMode_SinglePlainImage_ReturnsIndividual() {
        let policy = SaveImagePolicy()
        let imageElement = ImageElement(imageData: makeSolidImage(color: .white).pngData()!, importOrder: 0)

        let mode = policy.resolveMode(elements: [imageElement])

        guard case .individual = mode else {
            return XCTFail("単画像かつ追加装飾なしは individual であるべき")
        }
    }

    /// 単画像でもフレーム付きなら合成保存が選ばれること
    func testResolveMode_SingleFramedImage_ReturnsComposite() {
        let policy = SaveImagePolicy()
        let imageElement = ImageElement(imageData: makeSolidImage(color: .white).pngData()!, importOrder: 0)
        imageElement.showFrame = true
        imageElement.frameWidth = 8
        imageElement.frameStyle = .simple
        imageElement.frameColor = .red

        let mode = policy.resolveMode(elements: [imageElement])

        guard case .composite = mode else {
            return XCTFail("単画像でもフレーム付きは composite であるべき")
        }
    }

    /// 画像1枚でもテキストを追加すると composite 保存へ切り替わること
    func testResolveMode_SingleImageWithText_ReturnsComposite() {
        let policy = SaveImagePolicy()
        let imageElement = ImageElement(imageData: makeSolidImage(color: .white).pngData()!, importOrder: 0)
        let textElement = TextElement(text: "T", fontName: "HelveticaNeue", fontSize: 20, textColor: .black)
        textElement.position = CGPoint(x: 10, y: 10)
        textElement.size = CGSize(width: 40, height: 20)

        let mode = policy.resolveMode(elements: [imageElement, textElement])

        guard case .composite = mode else {
            return XCTFail("画像1枚でもテキスト追加時は composite であるべき")
        }
    }

    /// makeCompositeImage が nil を返した場合に `compositeGenerationFailed` になること
    /// - 以前は `?? baseImage` で無言成功していたが、修正後は明示的エラー扱いとなる
    @MainActor
    func testSaveComposite_CompositeFails_ReturnsCompositeGenerationFailure() {
        let coordinator = SaveImageCoordinator(
            selectionService: StubImageSelecting(),
            processingService: StubImageProcessing_CompositeNil(),
            writer: StubPhotoLibraryWriter()
        )

        let project = makeProjectWithImageElement()
        let expectation = expectation(description: "completion が呼ばれること")
        var result: PhotoLibrarySaveResult?

        coordinator.saveComposite(project: project) { saveResult in
            result = saveResult
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
        guard case .failure(let failure)? = result else {
            return XCTFail("合成失敗時は failure であるべき")
        }
        XCTAssertEqual(failure, .compositeGenerationFailed, "合成失敗時は compositeGenerationFailed であるべき")
    }

    /// coordinator 経由の composite 保存でも base role の画像が保存基準として使われることを担保する
    @MainActor
    func testSaveComposite_UsesBaseRoleElementForExportBounds() throws {
        let writer = CapturingPhotoLibraryWriter()
        let coordinator = SaveImageCoordinator(
            selectionService: ImageSelectionService(),
            processingService: ImageProcessingService(),
            writer: writer
        )

        let project = makeProjectWithBaseAndHigherResolutionOverlay()
        let expectation = expectation(description: "composite save completion")
        var result: PhotoLibrarySaveResult?

        coordinator.saveComposite(project: project) { saveResult in
            result = saveResult
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
        guard case .success? = result else {
            return XCTFail("composite 保存は success であるべき")
        }

        let savedImage = try XCTUnwrap(writer.capturedImage, "writer に合成画像が渡されるべき")
        XCTAssertEqual(savedImage.size.width, 200, accuracy: 0.001, "base role 画像の実ピクセル幅が保存に使われるべき")
        XCTAssertEqual(savedImage.size.height, 100, accuracy: 0.001, "base role 画像の実ピクセル高さが保存に使われるべき")
    }

    /// 単画像でもフレーム付きなら自動判定で composite に入り、保存結果へフレームが反映されること
    @MainActor
    func testSave_AutoModeWithSingleFramedImage_PreservesFrameAppearance() throws {
        let writer = CapturingPhotoLibraryWriter()
        let coordinator = SaveImageCoordinator(
            selectionService: ImageSelectionService(),
            processingService: ImageProcessingService(),
            writer: writer
        )

        let project = makeProjectWithSingleFramedImage()
        let expectation = expectation(description: "single framed image save completion")
        var result: PhotoLibrarySaveResult?

        coordinator.save(project: project) { saveResult in
            result = saveResult
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5)
        guard case .success? = result else {
            return XCTFail("単画像フレーム付き保存は success であるべき")
        }

        let savedImage = try XCTUnwrap(writer.capturedImage, "writer に保存画像が渡されるべき")
        XCTAssertEqual(
            try sampledColorHex(from: savedImage, at: CGPoint(x: 5, y: 50)),
            UIColor.red.rgbaHexString,
            "自動保存でもフレーム色が保存画像へ反映されるべき"
        )
        XCTAssertEqual(
            try sampledColorHex(from: savedImage, at: CGPoint(x: 100, y: 50)),
            UIColor.white.rgbaHexString,
            "フレーム内側の画像本体は白のままであるべき"
        )
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

    /// base role 画像と、より高解像度だが overlay role の画像を含むプロジェクトを作成
    /// - Returns: composite 保存選択確認用の LogoProject
    private func makeProjectWithBaseAndHigherResolutionOverlay() -> LogoProject {
        let project = LogoProject(name: "CoordinatorBaseSelection", canvasSize: CGSize(width: 600, height: 400))

        let baseImageData = makeSolidImage(color: .white, size: CGSize(width: 200, height: 100)).pngData()!
        let baseElement = ImageElement(imageData: baseImageData, importOrder: 0)
        baseElement.imageRole = .base
        baseElement.position = CGPoint(x: 40, y: 40)
        baseElement.size = CGSize(width: 200, height: 100)
        baseElement.zIndex = ElementPriority.image.rawValue - 10
        project.addElement(baseElement)

        let overlayImageData = makeSolidImage(color: .blue, size: CGSize(width: 1200, height: 1200)).pngData()!
        let overlayElement = ImageElement(imageData: overlayImageData, importOrder: 0)
        overlayElement.imageRole = .overlay
        overlayElement.position = CGPoint(x: 260, y: 60)
        overlayElement.size = CGSize(width: 120, height: 120)
        overlayElement.zIndex = ElementPriority.image.rawValue + 10
        project.addElement(overlayElement)

        let textElement = TextElement(text: "T", fontName: "HelveticaNeue", fontSize: 20, textColor: .white)
        textElement.position = CGPoint(x: 60, y: 60)
        textElement.size = CGSize(width: 50, height: 20)
        project.addElement(textElement)
        return project
    }

    /// フレーム付き単画像のみのプロジェクトを作成
    /// - Returns: 自動保存経路確認用の LogoProject
    private func makeProjectWithSingleFramedImage() -> LogoProject {
        let project = LogoProject(name: "SingleFramedImageSave", canvasSize: CGSize(width: 300, height: 200))
        let imageData = makeSolidImage(color: .white, size: CGSize(width: 200, height: 100)).pngData()!
        let imageElement = ImageElement(imageData: imageData, importOrder: 0)
        imageElement.imageRole = .base
        imageElement.position = CGPoint(x: 40, y: 40)
        imageElement.size = CGSize(width: 200, height: 100)
        imageElement.zIndex = ElementPriority.image.rawValue
        imageElement.showFrame = true
        imageElement.frameStyle = .simple
        imageElement.frameWidth = 10
        imageElement.frameColor = .red
        project.addElement(imageElement)
        return project
    }
}

/// テスト用の単色画像を生成
/// - Parameter color: 塗りつぶし色
/// - Parameter size: 画像サイズ
/// - Returns: 指定サイズの単色 UIImage
private func makeSolidImage(color: UIColor, size: CGSize = CGSize(width: 64, height: 64)) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { ctx in
        color.setFill()
        ctx.fill(CGRect(origin: .zero, size: size))
    }
}

/// 指定座標の画素色を16進表現で返す
/// - Parameters:
///   - image: サンプリング対象画像
///   - point: サンプリング座標
/// - Returns: RGBA 16進文字列
private func sampledColorHex(from image: UIImage, at point: CGPoint) throws -> String {
    let cgImage = try XCTUnwrap(image.cgImage)
    let x = Int(point.x)
    let y = Int(point.y)
    let cropped = try XCTUnwrap(cgImage.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)))
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    var pixel = [UInt8](repeating: 0, count: 4)
    let context = try XCTUnwrap(
        CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    )
    context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
    let color = UIColor(
        red: CGFloat(pixel[0]) / 255.0,
        green: CGFloat(pixel[1]) / 255.0,
        blue: CGFloat(pixel[2]) / 255.0,
        alpha: CGFloat(pixel[3]) / 255.0
    )
    return color.rgbaHexString
}
