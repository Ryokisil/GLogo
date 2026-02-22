//
//  SaturationBoundaryIntegrationTests.swift
//  GLogoTests
//
//  概要:
//  彩度スライダーの境界値（最小/最大）で色強度が不自然に逆転しないことを
//  SDR/HDRの両経路で検証する結合テスト。
//

import XCTest
import UIKit
@testable import GLogo

/// 彩度境界値の挙動を検証する結合テスト
final class SaturationBoundaryIntegrationTests: XCTestCase {

    // MARK: - Lifecycle

    /// 各テスト開始前にプレビューキャッシュを初期化
    /// - Parameters: なし
    /// - Returns: なし
    override func setUp() {
        super.setUp()
        ImageElement.previewService.resetCache()
    }

    // MARK: - Upper Bound

    /// SDR経路で max 彩度が max直前より色強度を落とさないことを検証
    /// - Parameters: なし
    /// - Returns: なし
    func testSaturationUpperBound_SDR_MaxDoesNotDropBelowNearMax() throws {
        let service = SDRImagePreviewService()
        try assertUpperBoundMonotonicity(service: service, mode: .sdr, tag: "SDR")
    }

    /// HDR経路で max 彩度が max直前より色強度を落とさないことを検証
    /// - Parameters: なし
    /// - Returns: なし
    func testSaturationUpperBound_HDR_MaxDoesNotDropBelowNearMax() throws {
        let service = HDRImagePreviewService()
        try assertUpperBoundMonotonicity(service: service, mode: .hdr, tag: "HDR")
    }

    // MARK: - Lower Bound

    /// SDR経路で min 彩度が min直後より色強度を上げないことを検証
    /// - Parameters: なし
    /// - Returns: なし
    func testSaturationLowerBound_SDR_MinDoesNotExceedNearMin() throws {
        let service = SDRImagePreviewService()
        try assertLowerBoundMonotonicity(service: service, mode: .sdr, tag: "SDR")
    }

    /// HDR経路で min 彩度が min直後より色強度を上げないことを検証
    /// - Parameters: なし
    /// - Returns: なし
    func testSaturationLowerBound_HDR_MinDoesNotExceedNearMin() throws {
        let service = HDRImagePreviewService()
        try assertLowerBoundMonotonicity(service: service, mode: .hdr, tag: "HDR")
    }

    // MARK: - Assertions

    /// 上限付近（nearMax / max）の単調性を検証
    /// - Parameters:
    ///   - service: 検証対象のプレビューサービス
    ///   - mode: レンダリング経路
    ///   - tag: ログ識別用タグ
    /// - Returns: なし
    private func assertUpperBoundMonotonicity(service: ImagePreviewing, mode: ImageRenderMode, tag: String) throws {
        let baseImage = makeMutedImage()
        let base = try sampleColorStrength(
            service: service,
            image: baseImage,
            saturation: 1.0,
            mode: mode
        )
        let nearMax = try sampleColorStrength(
            service: service,
            image: baseImage,
            saturation: 1.9,
            mode: mode
        )
        let max = try sampleColorStrength(
            service: service,
            image: baseImage,
            saturation: 2.0,
            mode: mode
        )

        logResult(tag: tag, label: "upper", base: base, near: nearMax, edge: max)

        XCTAssertGreaterThan(
            nearMax,
            base + 0.005,
            "[\(tag)] 彩度nearMaxで色強度が増えていない"
        )
        XCTAssertGreaterThanOrEqual(
            max,
            nearMax - 0.003,
            "[\(tag)] 彩度maxがnearMaxより不自然に弱い（上限到達時の逆転疑い）"
        )
    }

    /// 下限付近（min / nearMin）の単調性を検証
    /// - Parameters:
    ///   - service: 検証対象のプレビューサービス
    ///   - mode: レンダリング経路
    ///   - tag: ログ識別用タグ
    /// - Returns: なし
    private func assertLowerBoundMonotonicity(service: ImagePreviewing, mode: ImageRenderMode, tag: String) throws {
        let baseImage = makeMutedImage()
        let min = try sampleColorStrength(
            service: service,
            image: baseImage,
            saturation: 0.0,
            mode: mode
        )
        let nearMin = try sampleColorStrength(
            service: service,
            image: baseImage,
            saturation: 0.1,
            mode: mode
        )
        let base = try sampleColorStrength(
            service: service,
            image: baseImage,
            saturation: 1.0,
            mode: mode
        )

        logResult(tag: tag, label: "lower", base: base, near: nearMin, edge: min)

        XCTAssertLessThan(
            nearMin,
            base - 0.005,
            "[\(tag)] 彩度nearMinで色強度が十分に低下していない"
        )
        XCTAssertLessThanOrEqual(
            min,
            nearMin + 0.003,
            "[\(tag)] 彩度minがnearMinより不自然に強い（下限到達時の逆転疑い）"
        )
    }

    // MARK: - Helpers

    /// 指定彩度で出力した画像の色強度（max-min）を取得
    /// - Parameters:
    ///   - service: 適用サービス
    ///   - image: 入力画像
    ///   - saturation: 彩度値
    ///   - mode: レンダリング経路
    /// - Returns: 色強度（0.0...1.0）
    private func sampleColorStrength(
        service: ImagePreviewing,
        image: UIImage,
        saturation: CGFloat,
        mode: ImageRenderMode
    ) throws -> CGFloat {
        let params = ImageFilterParams(
            toneCurveData: ToneCurveData(),
            saturation: saturation,
            brightness: 0.0,
            contrast: 1.0,
            highlights: 0.0,
            shadows: 0.0,
            hue: 0.0,
            sharpness: 0.0,
            gaussianBlurRadius: 0.0,
            tintColor: nil,
            tintIntensity: 0.0
        )

        let output = try XCTUnwrap(
            service.instantPreview(
                baseImage: image,
                params: params,
                quality: .preview,
                mode: mode
            ),
            "プレビュー生成に失敗: saturation=\(saturation)"
        )
        let rgba = try rgbaSample(from: output)
        return colorStrength(rgba)
    }

    /// テスト用の低彩度画像を生成（クリップしづらい色域）
    /// - Parameters: なし
    /// - Returns: 生成したUIImage
    private func makeMutedImage() -> UIImage {
        let size = CGSize(width: 96, height: 96)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor(red: 0.58, green: 0.50, blue: 0.42, alpha: 1.0).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// 画像中心ピクセルのRGBA値を取得
    /// - Parameters:
    ///   - image: サンプル対象画像
    /// - Returns: 正規化済みRGBA値
    private func rgbaSample(from image: UIImage) throws -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        guard let cgImage = image.cgImage else {
            XCTFail("CGImageの取得に失敗")
            return (0, 0, 0, 0)
        }

        var pixel = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            XCTFail("ピクセル抽出用CGContextの生成に失敗")
            return (0, 0, 0, 0)
        }

        context.interpolationQuality = .none
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))

        return (
            CGFloat(pixel[0]) / 255.0,
            CGFloat(pixel[1]) / 255.0,
            CGFloat(pixel[2]) / 255.0,
            CGFloat(pixel[3]) / 255.0
        )
    }

    /// RGBの色強度（彩度近似）を算出
    /// - Parameters:
    ///   - rgba: サンプルRGBA
    /// - Returns: 強度値（max(R,G,B) - min(R,G,B)）
    private func colorStrength(_ rgba: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)) -> CGFloat {
        let maxChannel = max(rgba.r, max(rgba.g, rgba.b))
        let minChannel = min(rgba.r, min(rgba.g, rgba.b))
        return maxChannel - minChannel
    }

    /// 判定ログを出力
    /// - Parameters:
    ///   - tag: テスト識別タグ
    ///   - label: upper/lower 識別子
    ///   - base: 基準値（saturation=1.0）
    ///   - near: 境界直前値
    ///   - edge: 境界値
    /// - Returns: なし
    private func logResult(tag: String, label: String, base: CGFloat, near: CGFloat, edge: CGFloat) {
        print(
            """
            [SaturationBoundary][\(tag)][\(label)]
            - base(1.0): \(String(format: "%.6f", base))
            - near: \(String(format: "%.6f", near))
            - edge: \(String(format: "%.6f", edge))
            - delta(edge-near): \(String(format: "%.6f", edge - near))
            """
        )
    }
}

