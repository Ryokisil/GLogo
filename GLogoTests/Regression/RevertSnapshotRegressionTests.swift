//
//  RevertSnapshotRegressionTests.swift
//  GLogoTests
//
//  概要:
//  ImageElementのRevertが履歴依存で不安定化しないことを検証する回帰テスト。
//

import XCTest
import UIKit
@testable import GLogo

/// Revertの初期スナップショット運用を検証する回帰テスト
final class RevertSnapshotRegressionTests: XCTestCase {

    // MARK: - Revert Availability

    /// メタデータ履歴が空でも調整値変更があればRevert可能になることを検証
    func testCanRevertToInitialState_SaturationChangedWithoutMetadataHistory_ReturnsTrue() throws {
        let imageElement = try makeImageElement()

        XCTAssertFalse(imageElement.canRevertToInitialState)
        XCTAssertFalse(imageElement.hasEditHistory)

        imageElement.saturationAdjustment = 0.14

        XCTAssertTrue(imageElement.canRevertToInitialState)
    }

    // MARK: - Revert Restoration

    /// Revert実行で調整系パラメータが初期スナップショットへ戻ることを検証
    func testRevertToInitialState_RestoresAdjustmentSnapshot() throws {
        let imageElement = try makeImageElement()

        imageElement.saturationAdjustment = 0.14
        imageElement.warmthAdjustment = 40
        imageElement.vignetteAdjustment = 0.55
        imageElement.bloomAdjustment = 0.6
        imageElement.grainAdjustment = 0.4
        imageElement.fadeAdjustment = 0.3
        imageElement.chromaticAberrationAdjustment = 0.25
        imageElement.backgroundBlurRadius = 12
        imageElement.backgroundBlurMaskData = Data([0x1, 0x2, 0x3])
        imageElement.tintColor = .red
        imageElement.tintIntensity = 0.8
        imageElement.appliedFilterRecipe = FilterCatalog.allPresets.first?.recipe
        imageElement.appliedFilterPresetId = FilterCatalog.allPresets.first?.id
        var nonDefaultCurve = ToneCurveData()
        nonDefaultCurve.rgbPoints[1] = CurvePoint(input: 0.5, output: 0.62)
        imageElement.toneCurveData = nonDefaultCurve

        imageElement.revertToInitialState()

        XCTAssertEqual(imageElement.saturationAdjustment, 1.0, accuracy: 0.0001)
        XCTAssertEqual(imageElement.warmthAdjustment, 0.0, accuracy: 0.0001)
        XCTAssertEqual(imageElement.vignetteAdjustment, 0.0, accuracy: 0.0001)
        XCTAssertEqual(imageElement.bloomAdjustment, 0.0, accuracy: 0.0001)
        XCTAssertEqual(imageElement.grainAdjustment, 0.0, accuracy: 0.0001)
        XCTAssertEqual(imageElement.fadeAdjustment, 0.0, accuracy: 0.0001)
        XCTAssertEqual(imageElement.chromaticAberrationAdjustment, 0.0, accuracy: 0.0001)
        XCTAssertEqual(imageElement.backgroundBlurRadius, 0.0, accuracy: 0.0001)
        XCTAssertNil(imageElement.backgroundBlurMaskData)
        XCTAssertNil(imageElement.tintColor)
        XCTAssertEqual(imageElement.tintIntensity, 0.0, accuracy: 0.0001)
        XCTAssertNil(imageElement.appliedFilterRecipe)
        XCTAssertNil(imageElement.appliedFilterPresetId)
        XCTAssertEqual(imageElement.toneCurveData, ToneCurveData())
        XCTAssertFalse(imageElement.canRevertToInitialState)
    }

    /// Revert後に再編集した場合も再度Revert可能になることを検証
    func testCanRevertToInitialState_AfterRevertAndReedit_ReturnsTrueAgain() throws {
        let imageElement = try makeImageElement()

        imageElement.saturationAdjustment = 0.14
        imageElement.revertToInitialState()
        XCTAssertFalse(imageElement.canRevertToInitialState)

        imageElement.warmthAdjustment = 40
        XCTAssertTrue(imageElement.canRevertToInitialState)
    }

    /// 初期スナップショットがCodable往復後も保持されることを検証
    func testInitialSnapshot_CodableRoundTrip_PreservesBaseline() throws {
        let imageElement = try makeImageElement()
        imageElement.saturationAdjustment = 0.8
        imageElement.captureCurrentAdjustmentAsInitialSnapshot()
        XCTAssertFalse(imageElement.canRevertToInitialState)

        let encoded = try JSONEncoder().encode(imageElement)
        var decoded = try JSONDecoder().decode(ImageElement.self, from: encoded)

        XCTAssertFalse(decoded.canRevertToInitialState)
        decoded.saturationAdjustment = 0.5
        XCTAssertTrue(decoded.canRevertToInitialState)
    }

    // MARK: - Helpers

    /// テスト用の画像要素を生成
    /// - Parameters: なし
    /// - Returns: 生成したImageElement
    private func makeImageElement() throws -> ImageElement {
        let image = makeSolidImage(size: CGSize(width: 64, height: 64), color: .white)
        let data = try XCTUnwrap(image.pngData())
        return ImageElement(imageData: data, importOrder: 0)
    }

    /// 単色画像を生成
    /// - Parameters:
    ///   - size: 画像サイズ
    ///   - color: 塗りつぶし色
    /// - Returns: 指定色のUIImage
    private func makeSolidImage(size: CGSize, color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
