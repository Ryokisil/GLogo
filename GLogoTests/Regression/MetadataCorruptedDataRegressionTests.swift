//
//  MetadataCorruptedDataRegressionTests.swift
//  GLogoTests
//
//  概要:
//  壊れた画像データや sourceType が取得できないデータを入力した際に
//  クラッシュせず nil を返すことを検証する回帰テスト。
//  sourceType! 除去（guard let 化）の修正が復活しないことを担保する。
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

    // MARK: - applyMetadataToImageData（internal, @testable import 経由）

    /// 壊れたデータで applyMetadataToImageData がクラッシュしないこと
    /// - 以前は sourceType! で強制アンラップしていたためクラッシュしていた経路
    func testApplyMetadata_CorruptedData_ReturnsNilWithoutCrash() {
        let corruptedData = Data([0xFF, 0xD8, 0xFF, 0x00]) // JPEG ヘッダ断片（不完全）
        let metadata = ImageMetadata()

        let result = ImageMetadataManager.shared.applyMetadataToImageData(corruptedData, metadata: metadata)

        XCTAssertNil(result, "壊れたデータに対して nil を返しクラッシュしないこと")
    }

    /// 完全にランダムなデータで applyMetadataToImageData がクラッシュしないこと
    func testApplyMetadata_RandomData_ReturnsNilWithoutCrash() {
        let randomData = Data((0..<512).map { _ in UInt8.random(in: 0...255) })
        let metadata = ImageMetadata()

        let result = ImageMetadataManager.shared.applyMetadataToImageData(randomData, metadata: metadata)

        XCTAssertNil(result, "ランダムデータに対して nil を返しクラッシュしないこと")
    }

    /// 空データで applyMetadataToImageData がクラッシュしないこと
    func testApplyMetadata_EmptyData_ReturnsNilWithoutCrash() {
        let result = ImageMetadataManager.shared.applyMetadataToImageData(Data(), metadata: ImageMetadata())

        XCTAssertNil(result, "空データに対して nil を返しクラッシュしないこと")
    }

    /// 有効な PNG データで applyMetadataToImageData が正常にデータを返すこと（正常系対照）
    func testApplyMetadata_ValidPNG_ReturnsData() {
        let validData = makeValidPNGData()
        let metadata = ImageMetadata(author: "TestAuthor")

        let result = ImageMetadataManager.shared.applyMetadataToImageData(validData, metadata: metadata)

        XCTAssertNotNil(result, "有効な画像データにメタデータを適用できるべき")
        XCTAssertGreaterThan(result?.count ?? 0, 0, "結果データは空でないこと")
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
