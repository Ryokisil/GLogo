//
//  PreviewCacheRegressionTests.swift
//  GLogoTests
//
//  概要:
//  プレビューキャッシュが別画像へ誤ヒットしないことを検証する回帰テスト。
//

import XCTest
import UIKit
@testable import GLogo

/// プレビューキャッシュの画像分離を検証する回帰テスト
final class PreviewCacheRegressionTests: XCTestCase {

    // MARK: - SDR / HDR

    /// SDRプレビューで同一調整値かつ別ベース画像の場合に誤キャッシュしないことを検証
    /// - Parameters: なし
    /// - Returns: なし
    func testInstantPreview_ReturnsDifferentImageForDifferentBaseImage_SDR() throws {
        let service = SDRImagePreviewService()
        let params = makeNeutralParams()
        let redImage = makeSolidImage(color: .systemRed)
        let blueImage = makeSolidImage(color: .systemBlue)

        let first = try XCTUnwrap(
            service.instantPreview(
                baseImage: redImage,
                params: params,
                quality: .preview,
                mode: .sdr
            )
        )
        let second = try XCTUnwrap(
            service.instantPreview(
                baseImage: blueImage,
                params: params,
                quality: .preview,
                mode: .sdr
            )
        )

        let firstRGBA = try rgbaSample(from: first)
        let secondRGBA = try rgbaSample(from: second)
        logPreviewComparison(
            tag: "SDR",
            firstImage: first,
            secondImage: second,
            firstRGBA: firstRGBA,
            secondRGBA: secondRGBA
        )

        XCTAssertGreaterThan(firstRGBA.r, firstRGBA.b, "1回目は赤画像由来の出力であるべき")
        XCTAssertGreaterThan(secondRGBA.b, secondRGBA.r, "2回目は青画像由来の出力であるべき")
        XCTAssertGreaterThan(colorDistance(firstRGBA, secondRGBA), 0.30, "別画像なのに同一に近い結果は誤キャッシュの可能性が高い")
    }

    /// HDRプレビューで同一調整値かつ別ベース画像の場合に誤キャッシュしないことを検証
    /// - Parameters: なし
    /// - Returns: なし
    func testInstantPreview_ReturnsDifferentImageForDifferentBaseImage_HDR() throws {
        let service = HDRImagePreviewService()
        let params = makeNeutralParams()
        let redImage = makeSolidImage(color: .systemRed)
        let blueImage = makeSolidImage(color: .systemBlue)

        let first = try XCTUnwrap(
            service.instantPreview(
                baseImage: redImage,
                params: params,
                quality: .preview,
                mode: .hdr
            )
        )
        let second = try XCTUnwrap(
            service.instantPreview(
                baseImage: blueImage,
                params: params,
                quality: .preview,
                mode: .hdr
            )
        )

        let firstRGBA = try rgbaSample(from: first)
        let secondRGBA = try rgbaSample(from: second)
        logPreviewComparison(
            tag: "HDR",
            firstImage: first,
            secondImage: second,
            firstRGBA: firstRGBA,
            secondRGBA: secondRGBA
        )

        XCTAssertGreaterThan(firstRGBA.r, firstRGBA.b, "1回目は赤画像由来の出力であるべき")
        XCTAssertGreaterThan(secondRGBA.b, secondRGBA.r, "2回目は青画像由来の出力であるべき")
        XCTAssertGreaterThan(colorDistance(firstRGBA, secondRGBA), 0.30, "別画像なのに同一に近い結果は誤キャッシュの可能性が高い")
    }

    // MARK: - Helpers

    /// 変化を入れないニュートラルなフィルターパラメータを生成
    /// - Parameters: なし
    /// - Returns: すべてデフォルト寄りの ImageFilterParams
    private func makeNeutralParams() -> ImageFilterParams {
        ImageFilterParams(
            toneCurveData: ToneCurveData(),
            saturation: 1.0,
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
    }

    /// 単色画像を生成
    /// - Parameter color: 塗りつぶし色
    /// - Returns: テスト用の 64x64 単色 UIImage
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

    /// 画像中心ピクセルをRGBAで取得（0.0...1.0）
    /// - Parameter image: サンプル対象画像
    /// - Returns: 正規化済みRGBA値
    private func rgbaSample(from image: UIImage) throws -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        guard let cgImage = image.cgImage else {
            XCTFail("CGImage の取得に失敗")
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
            XCTFail("ピクセルサンプリング用 CGContext の生成に失敗")
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

    /// 2色の距離を算出
    /// - Parameters:
    ///   - lhs: 比較元RGBA
    ///   - rhs: 比較先RGBA
    /// - Returns: RGBユークリッド距離（0.0...sqrt(3.0)）
    private func colorDistance(
        _ lhs: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat),
        _ rhs: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)
    ) -> CGFloat {
        let dr = lhs.r - rhs.r
        let dg = lhs.g - rhs.g
        let db = lhs.b - rhs.b
        return sqrt((dr * dr) + (dg * dg) + (db * db))
    }

    /// ログ判定しやすい形式で比較情報を出力
    /// - Parameters:
    ///   - tag: テスト識別タグ（SDR/HDR）
    ///   - firstImage: 1回目の結果画像
    ///   - secondImage: 2回目の結果画像
    ///   - firstRGBA: 1回目の色サンプル
    ///   - secondRGBA: 2回目の色サンプル
    /// - Returns: なし
    private func logPreviewComparison(
        tag: String,
        firstImage: UIImage,
        secondImage: UIImage,
        firstRGBA: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat),
        secondRGBA: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)
    ) {
        let firstID = Int(bitPattern: Unmanaged.passUnretained(firstImage).toOpaque())
        let secondID = Int(bitPattern: Unmanaged.passUnretained(secondImage).toOpaque())
        let distance = colorDistance(firstRGBA, secondRGBA)

        print(
            """
            [PreviewCacheRegression][\(tag)]
            - first image id: \(firstID), rgba: (\(String(format: "%.3f", firstRGBA.r)), \(String(format: "%.3f", firstRGBA.g)), \(String(format: "%.3f", firstRGBA.b)), \(String(format: "%.3f", firstRGBA.a)))
            - second image id: \(secondID), rgba: (\(String(format: "%.3f", secondRGBA.r)), \(String(format: "%.3f", secondRGBA.g)), \(String(format: "%.3f", secondRGBA.b)), \(String(format: "%.3f", secondRGBA.a)))
            - color distance: \(String(format: "%.3f", distance))
            """
        )
    }
}
