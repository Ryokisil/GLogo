//
//  PerformanceKpiTests.swift
//  GLogoTests
//
//  概要:
//  パフォーマンスKPI（4Kインポート/保存処理）を計測する結合テスト。
//

import XCTest
@testable import GLogo
import UIKit
import ImageIO
import UniformTypeIdentifiers

/// パフォーマンスKPI向けの計測テスト
final class PerformanceKpiTests: XCTestCase {
    /// 4K画像のインポート + プレビュー生成の性能を計測
    func testImportPreviewPerformance_4K() {
        let size = CGSize(width: 3840, height: 2160)
        let sourceData = makeHEICData(size: size)
        let coordinator = ImageImportCoordinator()
        let project = LogoProject(canvasSize: size)

        measure(metrics: [XCTClockMetric()]) {
            guard let result = coordinator.importImage(
                source: .imageData(sourceData),
                project: project,
                viewportSize: size,
                assetIdentifier: "perf-import-4k",
                canvasSize: size
            ) else {
                XCTFail("インポート結果がnil")
                return
            }

            _ = result.element.getInstantPreview()
        }
    }

    /// 4K画像のフィルター適用 + エンコード（HEIC）の性能を計測
    func testSaveProcessingPerformance_4K_HEIC() {
        let size = CGSize(width: 3840, height: 2160)
        let sourceData = makeHEICData(size: size)
        let imageElement = ImageElement(imageData: sourceData)
        imageElement.saturationAdjustment = 1.2
        imageElement.brightnessAdjustment = 0.1
        imageElement.contrastAdjustment = 1.1
        let processingService = ImageProcessingService()

        measure(metrics: [XCTClockMetric()]) {
            guard let processedImage = processingService.applyFilters(to: imageElement) else {
                XCTFail("フィルター適用に失敗")
                return
            }

            _ = makeHEICData(from: processedImage)
        }
    }

    // MARK: - Helpers

    private func makeHEICData(size: CGSize) -> Data {
        let image = makeTestImage(size: size)
        return makeHEICData(from: image)
    }

    private func makeTestImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.darkGray.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func makeHEICData(from image: UIImage) -> Data {
        guard let cgImage = image.cgImage else {
            return Data()
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else {
            return Data()
        }

        let properties = [kCGImageDestinationLossyCompressionQuality: 1.0] as CFDictionary
        CGImageDestinationAddImage(destination, cgImage, properties)
        guard CGImageDestinationFinalize(destination) else {
            return Data()
        }
        return data as Data
    }
}
