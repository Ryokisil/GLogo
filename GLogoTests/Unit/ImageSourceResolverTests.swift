//
//  ImageSourceResolverTests.swift
//  GLogoTests
//
//  概要:
//  ImageSourceResolver の画像ソース優先順位と編集用画像解決を検証する。
//

import XCTest
import UIKit
@testable import GLogo

final class ImageSourceResolverTests: XCTestCase {

    /// path が imageData より優先されることを検証
    func test_resolveOriginalImage_pathWins() throws {
        let resolver = ImageSourceResolver()
        let dataImage = makeSolidImage(size: CGSize(width: 8, height: 8), color: .red)
        let pathImage = makeSolidImage(size: CGSize(width: 16, height: 12), color: .blue)
        let pathURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        try XCTUnwrap(pathImage.pngData()).write(to: pathURL)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: pathURL)
        }

        let resolved = try XCTUnwrap(
            resolver.resolveOriginalImage(
                imageData: dataImage.pngData(),
                fileName: nil,
                url: nil,
                path: pathURL.path
            )
        )

        XCTAssertEqual(resolved.size, pathImage.size)
    }

    /// 非ファイルURLは従来どおり後続ソースへフォールバックしないことを検証
    func test_resolveOriginalImage_remoteURLReturnsNil() {
        let resolver = ImageSourceResolver()
        let dataImage = makeSolidImage(size: CGSize(width: 8, height: 8), color: .red)

        let resolved = resolver.resolveOriginalImage(
            imageData: dataImage.pngData(),
            fileName: nil,
            url: URL(string: "https://example.com/image.png"),
            path: nil
        )

        XCTAssertNil(resolved)
    }

    /// 編集用画像解決がリポジトリへ委譲されることを検証
    func test_resolveEditingImage_usesRepository() throws {
        let proxyImage = makeSolidImage(size: CGSize(width: 12, height: 12), color: .green)
        let repository = RecordingImageAssetRepository(result: proxyImage)
        let resolver = ImageSourceResolver(assetRepository: repository)

        let resolved = try XCTUnwrap(
            resolver.resolveEditingImage(
                identifier: "asset-id",
                fileName: "asset-name",
                originalPath: "/tmp/source.png",
                originalImageProvider: { nil },
                proxyTargetLongSide: 1920,
                highResThresholdMP: 18.0
            )
        )

        XCTAssertTrue(repository.didLoadEditingImage)
        XCTAssertEqual(repository.receivedIdentifier, "asset-id")
        XCTAssertEqual(repository.receivedFileName, "asset-name")
        XCTAssertEqual(repository.receivedOriginalPath, "/tmp/source.png")
        XCTAssertEqual(resolved.size, proxyImage.size)
    }

    /// リポジトリから編集用画像が返らない場合に元画像を使うことを検証
    func test_resolveEditingImage_fallsBackToOriginal() throws {
        let originalImage = makeSolidImage(size: CGSize(width: 20, height: 10), color: .purple)
        let repository = RecordingImageAssetRepository(result: nil)
        let resolver = ImageSourceResolver(assetRepository: repository)

        let resolved = try XCTUnwrap(
            resolver.resolveEditingImage(
                identifier: nil,
                fileName: nil,
                originalPath: nil,
                originalImageProvider: { originalImage },
                proxyTargetLongSide: 1920,
                highResThresholdMP: 18.0
            )
        )

        XCTAssertTrue(repository.didLoadEditingImage)
        XCTAssertEqual(resolved.size, originalImage.size)
    }

    /// ImageElement が設定済み resolver 経由で元画像を取得し、結果をキャッシュすることを検証
    func test_originalImage_usesResolverCache() throws {
        let originalResolver = ImageElement.imageSourceResolver
        let expectedImage = makeSolidImage(size: CGSize(width: 18, height: 18), color: .orange)
        let resolver = CountingImageSourceResolver(originalImage: expectedImage)
        ImageElement.imageSourceResolver = resolver
        defer { ImageElement.imageSourceResolver = originalResolver }

        let element = ImageElement(imageData: Data(), importOrder: 0)
        let first = try XCTUnwrap(element.originalImage)
        let second = try XCTUnwrap(element.originalImage)

        XCTAssertEqual(first.size, expectedImage.size)
        XCTAssertEqual(second.size, expectedImage.size)
        XCTAssertEqual(resolver.originalResolveCallCount, 1)
    }
}

private extension ImageSourceResolverTests {
    /// 単色画像を生成する
    /// - Parameters:
    ///   - size: 画像サイズ
    ///   - color: 塗りつぶし色
    /// - Returns: 生成した画像
    private func makeSolidImage(size: CGSize, color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

/// 呼び出し内容を記録するテスト用 ImageAssetRepository
private final class RecordingImageAssetRepository: ImageAssetRepositoryProtocol {
    let result: UIImage?
    private(set) var didLoadEditingImage = false
    private(set) var receivedIdentifier: String?
    private(set) var receivedFileName: String?
    private(set) var receivedOriginalPath: String?

    init(result: UIImage?) {
        self.result = result
    }

    func loadEditingImage(
        identifier: String?,
        fileName: String?,
        originalPath: String?,
        originalImageProvider _: () -> UIImage?,
        proxyTargetLongSide _: CGFloat,
        highResThresholdMP _: CGFloat
    ) -> UIImage? {
        didLoadEditingImage = true
        receivedIdentifier = identifier
        receivedFileName = fileName
        receivedOriginalPath = originalPath
        return result
    }
}

/// 元画像解決の呼び出し回数を記録するテスト用 Resolver
private final class CountingImageSourceResolver: ImageSourceResolving {
    let originalImage: UIImage
    private(set) var originalResolveCallCount = 0

    init(originalImage: UIImage) {
        self.originalImage = originalImage
    }

    func resolveOriginalImage(
        imageData _: Data?,
        fileName _: String?,
        url _: URL?,
        path _: String?
    ) -> UIImage? {
        originalResolveCallCount += 1
        return originalImage
    }

    func resolveEditingImage(
        identifier _: String?,
        fileName _: String?,
        originalPath _: String?,
        originalImageProvider: () -> UIImage?,
        proxyTargetLongSide _: CGFloat,
        highResThresholdMP _: CGFloat
    ) -> UIImage? {
        originalImageProvider()
    }
}
