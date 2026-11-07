//
//  RevertSnapshotRegressionTests.swift
//  GLogoTests
//
//  概要:
//  ImageElementの調整値リセットとRevert可否判定が履歴依存で不安定化しないことを検証する回帰テスト。
//

import XCTest
import UIKit
@testable import GLogo

/// 調整値リセットとRevert可否判定の初期スナップショット運用を検証する回帰テスト
final class RevertSnapshotRegressionTests: XCTestCase {
    private let metadataRevertUseCase = ImageElementMetadataRevertUseCase(store: AppComposition.metadataStore)

    // MARK: - Revert Availability

    /// メタデータ履歴が空でも調整値変更があればRevert可能になることを検証
    func testCanRevertToInitialState_SaturationChangedWithoutMetadataHistory_ReturnsTrue() throws {
        let imageElement = try makeImageElement()

        XCTAssertFalse(metadataRevertUseCase.canRevertToInitialState(imageElement))
        XCTAssertFalse(metadataRevertUseCase.hasEditHistory(for: imageElement))

        imageElement.saturationAdjustment = 0.14

        XCTAssertTrue(metadataRevertUseCase.canRevertToInitialState(imageElement))
    }

    // MARK: - Revert Restoration

    /// 調整値リセットで調整系パラメータが初期スナップショットへ戻ることを検証
    func testResetAdjustmentsToInitialState_RestoresAdjustmentSnapshot() throws {
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
        imageElement.showFrame = true
        imageElement.frameColor = .cyan
        imageElement.frameWidth = 12.0
        imageElement.frameStyle = .badge
        imageElement.roundedCorners = true
        imageElement.cornerRadius = 24.0
        imageElement.appliedFilterRecipe = FilterCatalog.allPresets.first?.recipe
        imageElement.appliedFilterPresetId = FilterCatalog.allPresets.first?.id
        var nonDefaultCurve = ToneCurveData()
        nonDefaultCurve.rgbPoints[1] = CurvePoint(input: 0.5, output: 0.62)
        imageElement.toneCurveData = nonDefaultCurve

        imageElement.resetAdjustmentsToInitialState()

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
        XCTAssertFalse(imageElement.showFrame)
        XCTAssertEqual(imageElement.frameColor.rgbaHexString, UIColor.white.rgbaHexString)
        XCTAssertEqual(imageElement.frameWidth, 4.0, accuracy: 0.0001)
        XCTAssertEqual(imageElement.frameStyle, .simple)
        XCTAssertFalse(imageElement.roundedCorners)
        XCTAssertEqual(imageElement.cornerRadius, 10.0, accuracy: 0.0001)
        XCTAssertFalse(metadataRevertUseCase.canRevertToInitialState(imageElement))
    }

    /// 調整値リセット後に再編集した場合も再度Revert可能になることを検証
    func testCanRevertToInitialState_AfterAdjustmentResetAndReedit_ReturnsTrueAgain() throws {
        let imageElement = try makeImageElement()

        imageElement.saturationAdjustment = 0.14
        imageElement.resetAdjustmentsToInitialState()
        XCTAssertFalse(metadataRevertUseCase.canRevertToInitialState(imageElement))

        imageElement.warmthAdjustment = 40
        XCTAssertTrue(metadataRevertUseCase.canRevertToInitialState(imageElement))
    }

    /// 初期スナップショットがCodable往復後も保持されることを検証
    func testInitialSnapshot_CodableRoundTrip_PreservesBaseline() throws {
        let imageElement = try makeImageElement()
        imageElement.saturationAdjustment = 0.8
        imageElement.captureCurrentAdjustmentAsInitialSnapshot()
        XCTAssertFalse(metadataRevertUseCase.canRevertToInitialState(imageElement))

        let encoded = try JSONEncoder().encode(imageElement)
        let decoded = try JSONDecoder().decode(ImageElement.self, from: encoded)

        XCTAssertFalse(metadataRevertUseCase.canRevertToInitialState(decoded))
        decoded.saturationAdjustment = 0.5
        XCTAssertTrue(metadataRevertUseCase.canRevertToInitialState(decoded))
    }

    // MARK: - Persisted Format

    /// 保存済みプロジェクトの初期スナップショットに書かれているキー。
    /// 名前や値の表現を変えると、既存ファイルの Revert 基準を読めなくなる。
    private static let snapshotKeys: Set<String> = [
        "saturationAdjustment", "brightnessAdjustment", "contrastAdjustment", "highlightsAdjustment",
        "shadowsAdjustment", "blacksAdjustment", "whitesAdjustment", "warmthAdjustment", "vibranceAdjustment",
        "hueAdjustment", "sharpnessAdjustment", "gaussianBlurRadius", "vignetteAdjustment", "bloomAdjustment",
        "grainAdjustment", "fadeAdjustment", "chromaticAberrationAdjustment",
        "backgroundBlurRadius", "backgroundBlurMaskData", "toneCurveData", "tintColorRGBA", "tintIntensity",
        "appliedFilterRecipe", "appliedFilterPresetId",
        "showFrame", "frameColorRGBA", "frameWidth", "frameStyle", "roundedCorners", "cornerRadius"
    ]

    /// 色は RGBA 成分で書く。値は `ImageEditStateRecord.applyDistinctValues` の赤とシアン。
    private static let tintColorRGBA: [String: Double] = ["red": 1, "green": 0, "blue": 0, "alpha": 1]
    private static let frameColorRGBA: [String: Double] = ["red": 0, "green": 1, "blue": 1, "alpha": 1]

    func test_initialSnapshot_encodesStoredKeys() throws {
        let imageElement = try makeImageElement()
        ImageEditStateRecord.applyDistinctValues(to: imageElement)
        imageElement.captureCurrentAdjustmentAsInitialSnapshot()

        let json = try encodedObject(imageElement)
        let snapshot = try XCTUnwrap(json["initialAdjustmentSnapshot"] as? [String: Any])

        XCTAssertEqual(Set(snapshot.keys), Self.snapshotKeys)
        // 色以外は、要素本体の同名キーと同じ表現で書く。
        for key in Self.snapshotKeys.subtracting(["tintColorRGBA", "frameColorRGBA"]) {
            XCTAssertNotNil(json[key], key)
            XCTAssertEqual(snapshot[key] as? NSObject, json[key] as? NSObject, key)
        }
        XCTAssertEqual(snapshot["tintColorRGBA"] as? [String: Double], Self.tintColorRGBA)
        XCTAssertEqual(snapshot["frameColorRGBA"] as? [String: Double], Self.frameColorRGBA)
    }

    /// 既存ファイルの書式で手書きした初期スナップショット。
    /// 書き出しの実装から作った JSON では、書き出しと読み込みを同時に変えたときの互換切れに気づけないため、値をすべて固定する。
    private static let storedSnapshotJSON = """
    {
      "saturationAdjustment": 0.31,
      "brightnessAdjustment": 0.12,
      "contrastAdjustment": 1.23,
      "highlightsAdjustment": 0.14,
      "shadowsAdjustment": 0.15,
      "blacksAdjustment": 0.16,
      "whitesAdjustment": 0.17,
      "warmthAdjustment": 18,
      "vibranceAdjustment": 0.19,
      "hueAdjustment": 20,
      "sharpnessAdjustment": 0.21,
      "gaussianBlurRadius": 2.2,
      "vignetteAdjustment": 0.23,
      "bloomAdjustment": 0.24,
      "grainAdjustment": 0.25,
      "fadeAdjustment": 0.26,
      "chromaticAberrationAdjustment": 0.27,
      "backgroundBlurRadius": 29,
      "backgroundBlurMaskData": "AQID",
      "toneCurveData": {
        "rgbPoints": [{"input": 0, "output": 0}, {"input": 0.5, "output": 0.62}, {"input": 1, "output": 1}],
        "redPoints": [{"input": 0, "output": 0}, {"input": 0.5, "output": 0.5}, {"input": 1, "output": 1}],
        "greenPoints": [{"input": 0, "output": 0}, {"input": 0.5, "output": 0.5}, {"input": 1, "output": 1}],
        "bluePoints": [{"input": 0, "output": 0}, {"input": 0.5, "output": 0.5}, {"input": 1, "output": 1}]
      },
      "tintColorRGBA": {"red": 1, "green": 0, "blue": 0, "alpha": 1},
      "tintIntensity": 0.28,
      "appliedFilterRecipe": {"saturation": 1.2, "tintColorHex": "#C98A4B"},
      "appliedFilterPresetId": "stored-preset",
      "showFrame": true,
      "frameColorRGBA": {"red": 0, "green": 1, "blue": 1, "alpha": 1},
      "frameWidth": 12,
      "frameStyle": "badge",
      "roundedCorners": true,
      "cornerRadius": 24
    }
    """

    func test_initialSnapshot_decodesStoredKeys() throws {
        let stored = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(Self.storedSnapshotJSON.utf8)) as? [String: Any]
        )
        XCTAssertEqual(Set(stored.keys), Self.snapshotKeys)
        var json = try encodedObject(try makeImageElement())
        json["initialAdjustmentSnapshot"] = stored
        let decoded = try JSONDecoder().decode(
            ImageElement.self,
            from: JSONSerialization.data(withJSONObject: json)
        )

        XCTAssertTrue(decoded.hasAdjustmentChangesFromInitialState)
        decoded.resetAdjustmentsToInitialState()

        // 読み込んだ基準の30項目へ戻る。期待値は JSON と同じく、ここに直接書く。
        let numbers: [(ReferenceWritableKeyPath<ImageElement, CGFloat>, CGFloat)] = [
            (\.saturationAdjustment, 0.31), (\.brightnessAdjustment, 0.12), (\.contrastAdjustment, 1.23),
            (\.highlightsAdjustment, 0.14), (\.shadowsAdjustment, 0.15), (\.blacksAdjustment, 0.16),
            (\.whitesAdjustment, 0.17), (\.warmthAdjustment, 18), (\.vibranceAdjustment, 0.19),
            (\.hueAdjustment, 20), (\.sharpnessAdjustment, 0.21), (\.gaussianBlurRadius, 2.2),
            (\.vignetteAdjustment, 0.23), (\.bloomAdjustment, 0.24), (\.grainAdjustment, 0.25),
            (\.fadeAdjustment, 0.26), (\.chromaticAberrationAdjustment, 0.27), (\.backgroundBlurRadius, 29),
            (\.tintIntensity, 0.28), (\.frameWidth, 12), (\.cornerRadius, 24)
        ]
        for (keyPath, value) in numbers {
            XCTAssertEqual(decoded[keyPath: keyPath], value, "\(keyPath)")
        }
        XCTAssertEqual(decoded.backgroundBlurMaskData, Data([1, 2, 3]))
        var curve = ToneCurveData()
        curve.rgbPoints[1] = CurvePoint(input: 0.5, output: 0.62)
        XCTAssertEqual(decoded.toneCurveData, curve)
        XCTAssertEqual(decoded.tintColor?.rgbaHexString, "#FF0000FF")
        XCTAssertEqual(decoded.appliedFilterRecipe, FilterRecipe(saturation: 1.2, tintColorHex: "#C98A4B"))
        XCTAssertEqual(decoded.appliedFilterPresetId, "stored-preset")
        XCTAssertTrue(decoded.showFrame)
        XCTAssertEqual(decoded.frameColor.rgbaHexString, "#00FFFFFF")
        XCTAssertEqual(decoded.frameStyle, .badge)
        XCTAssertTrue(decoded.roundedCorners)
        XCTAssertFalse(decoded.hasAdjustmentChangesFromInitialState)
    }

    /// 高画質化済み状態がCodable往復後も保持されることを検証
    func testHasAppliedUpscale_CodableRoundTrip_PreservesValue() throws {
        let imageElement = try makeImageElement()
        imageElement.hasAppliedUpscale = true

        let encoded = try JSONEncoder().encode(imageElement)
        let decoded = try JSONDecoder().decode(ImageElement.self, from: encoded)

        XCTAssertTrue(decoded.hasAppliedUpscale)
    }

    /// copy生成時にも高画質化済み状態が保持されることを検証
    func testHasAppliedUpscale_Copy_PreservesValue() throws {
        let imageElement = try makeImageElement()
        imageElement.hasAppliedUpscale = true

        let copied = try XCTUnwrap(imageElement.copy() as? ImageElement)

        XCTAssertTrue(copied.hasAppliedUpscale)
    }

    // MARK: - Helpers

    /// テスト用の画像要素を生成
    /// - Parameters: なし
    /// - Returns: 生成したImageElement
    private func makeImageElement() throws -> ImageElement {
        let image = makeSolidImage(size: CGSize(width: 64, height: 64), color: .white)
        let data = try XCTUnwrap(image.pngData())
        return ImageElementFactory().makeElement(imageData: data, importOrder: 0)
    }

    /// 画像要素を JSON に書き出し、キーごとの値として読み直す
    private func encodedObject(_ imageElement: ImageElement) throws -> [String: Any] {
        let data = try JSONEncoder().encode(imageElement)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
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
