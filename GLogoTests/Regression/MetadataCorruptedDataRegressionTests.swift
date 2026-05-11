//
//  MetadataCorruptedDataRegressionTests.swift
//  GLogoTests
//
//  概要:
//  壊れた画像データを extractMetadata に渡してもクラッシュせず nil もしくは
//  空メタデータが返ることを検証する回帰テスト。
//

import XCTest
import UIKit
@testable import GLogo

/// ImageMetadataManager の壊れたデータ耐性を検証する回帰テスト
final class MetadataCorruptedDataRegressionTests: XCTestCase {

    // MARK: - extractMetadata（公開 API）

    /// 完全にランダムなデータで extractMetadata がクラッシュしないこと
    /// - Note: CGImageSourceCreateWithData はランダムデータでもソースを生成し得るため、
    ///   戻り値は nil または空メタデータのどちらもあり得る。主検証はクラッシュ非発生。
    func testExtractMetadata_RandomData_DoesNotCrash() {
        let randomData = Data((0..<256).map { _ in UInt8.random(in: 0...255) })

        // クラッシュしなければ成功（戻り値は nil or 空メタデータ）
        _ = ImageMetadataManager.shared.extractMetadata(from: randomData)
    }

    /// 空データで extractMetadata がクラッシュしないこと
    func testExtractMetadata_EmptyData_DoesNotCrash() {
        // クラッシュしなければ成功
        _ = ImageMetadataManager.shared.extractMetadata(from: Data())
    }

    /// 有効な PNG データで extractMetadata が正常に値を返すこと（正常系対照）
    func testExtractMetadata_ValidPNG_ReturnsMetadata() {
        let validData = makeValidPNGData()

        let result = ImageMetadataManager.shared.extractMetadata(from: validData)

        XCTAssertNotNil(result, "有効な画像データからはメタデータを抽出できるべき")
    }

    // MARK: - Helpers

    /// テスト用の有効な PNG データを生成
    /// - Returns: 8x8 単色画像の PNG データ
    private func makeValidPNGData() -> Data {
        let size = CGSize(width: 8, height: 8)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return image.pngData()!
    }
}
