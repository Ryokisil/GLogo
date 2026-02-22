//
//  ImageAssetRepositoryRoutingTests.swift
//  GLogoTests
//
//  概要:
//  ImageAssetRepository の編集用画像解決ルーティングを検証する単体テスト。
//  色空間と解像度条件に応じた original / proxy の選択が変わらないことを担保する。
//

import XCTest
import UIKit
@testable import GLogo

final class ImageAssetRepositoryRoutingTests: XCTestCase {

    /// 非sRGB高解像度画像は original 優先で返却されることを検証
    func testLoadEditingImage_HighResolutionNonSRGB_ReturnsOriginal() throws {
        let repository = ImageAssetRepository.shared
        let original = try makeSolidImage(
            size: CGSize(width: 4284, height: 5712),
            colorSpace: try XCTUnwrap(CGColorSpace(name: CGColorSpace.displayP3))
        )

        let resolved = try XCTUnwrap(
            repository.loadEditingImage(
                identifier: "test/non-srgb/high",
                fileName: nil,
                originalPath: nil,
                originalImageProvider: { original },
                proxyTargetLongSide: 1920,
                highResThresholdMP: 18.0
            )
        )

        let originalPixels = pixelSize(of: original)
        let resolvedPixels = pixelSize(of: resolved)

        XCTAssertEqual(resolvedPixels.width, originalPixels.width)
        XCTAssertEqual(resolvedPixels.height, originalPixels.height)
        XCTAssertGreaterThan(max(resolvedPixels.width, resolvedPixels.height), 1920)
    }

    /// sRGB高解像度画像は縮小proxyが返却されることを検証
    func testLoadEditingImage_HighResolutionSRGB_ReturnsResizedProxy() throws {
        let repository = ImageAssetRepository.shared
        let original = try makeSolidImage(
            size: CGSize(width: 4284, height: 5712),
            colorSpace: try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        )

        let resolved = try XCTUnwrap(
            repository.loadEditingImage(
                identifier: "test/srgb/high",
                fileName: nil,
                originalPath: nil,
                originalImageProvider: { original },
                proxyTargetLongSide: 1920,
                highResThresholdMP: 18.0
            )
        )

        let originalPixels = pixelSize(of: original)
        let resolvedPixels = pixelSize(of: resolved)
        let resolvedLongSide = max(resolvedPixels.width, resolvedPixels.height)
        let originalAspect = originalPixels.width / originalPixels.height
        let resolvedAspect = resolvedPixels.width / resolvedPixels.height

        // UIGraphicsImageRenderer の端数処理で 1px 前後の差が出ることがあるため、±1px を許容する
        XCTAssertGreaterThanOrEqual(resolvedLongSide, 1919)
        XCTAssertLessThanOrEqual(resolvedLongSide, 1921)
        XCTAssertEqual(resolvedAspect, originalAspect, accuracy: 0.001)
        XCTAssertLessThan(max(resolvedPixels.width, resolvedPixels.height), max(originalPixels.width, originalPixels.height))
    }

    /// sRGB低解像度画像は original がそのまま返却されることを検証
    func testLoadEditingImage_LowResolutionSRGB_ReturnsOriginal() throws {
        let repository = ImageAssetRepository.shared
        let original = try makeSolidImage(
            size: CGSize(width: 1920, height: 1080),
            colorSpace: try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        )

        let resolved = try XCTUnwrap(
            repository.loadEditingImage(
                identifier: "test/srgb/low",
                fileName: nil,
                originalPath: nil,
                originalImageProvider: { original },
                proxyTargetLongSide: 1920,
                highResThresholdMP: 18.0
            )
        )

        let originalPixels = pixelSize(of: original)
        let resolvedPixels = pixelSize(of: resolved)

        XCTAssertEqual(resolvedPixels.width, originalPixels.width)
        XCTAssertEqual(resolvedPixels.height, originalPixels.height)
        XCTAssertEqual(max(resolvedPixels.width, resolvedPixels.height), 1920)
    }

    // MARK: - Helpers

    /// 指定色空間/サイズで単色画像を生成する
    /// - Parameters:
    ///   - size: 画像サイズ（pt, scale=1）
    ///   - colorSpace: 描画色空間
    /// - Returns: 生成した画像
    private func makeSolidImage(size: CGSize, colorSpace: CGColorSpace) throws -> UIImage {
        let width = Int(size.width)
        let height = Int(size.height)
        let bytesPerRow = width * 4
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            XCTFail("CGContext の生成に失敗")
            throw NSError(domain: "ImageAssetRepositoryRoutingTests", code: 1)
        }

        context.setFillColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0)
        context.fill(CGRect(origin: .zero, size: size))

        guard let cgImage = context.makeImage() else {
            XCTFail("CGImage の生成に失敗")
            throw NSError(domain: "ImageAssetRepositoryRoutingTests", code: 2)
        }
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
    }

    /// UIImageの実ピクセルサイズを返す
    /// - Parameter image: 対象画像
    /// - Returns: ピクセルサイズ
    private func pixelSize(of image: UIImage) -> CGSize {
        if let cgImage = image.cgImage {
            return CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        }
        return CGSize(
            width: (image.size.width * image.scale).rounded(),
            height: (image.size.height * image.scale).rounded()
        )
    }
}
