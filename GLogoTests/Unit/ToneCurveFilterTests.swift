// ToneCurveFilterTests
//
// 軽量テストでトーンカーブの回帰を検知することを目的とする。
// 視点:
// - デフォルトカーブが恒等変換になっているか（保存とプレビューの色ズレ防止）
// - 補間器が単調性を保つか（オーバーシュート防止）

import XCTest
import CoreImage
import UIKit
@testable import GLogo

final class ToneCurveFilterTests: XCTestCase {

    /// デフォルトのトーンカーブが恒等変換になることを確認
    ///  恒等変換とは「入力と出力が同じになる変換」のこと。ここではデフォルトのトーンカーブ（対角線のカーブ）を
    ///  適用しても、元の色が変わらない＝入力ピクセルと出力ピクセルが同じ、という意味。
    /// （保存とプレビューで色が変わらないことの最低限の安全網）
    func testDefaultCurveIsIdentityOnFlatColor() {
        let redPixel = CIImage(color: CIColor(red: 1, green: 0, blue: 0, alpha: 1))
            .cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))

        guard let output = ToneCurveFilter.applyCurve(to: redPixel, curveData: ToneCurveData(), quality: .full) else {
            XCTFail("ToneCurveFilter returned nil")
            return
        }

        guard let rgba = sampleRGBA(from: output) else {
            XCTFail("Failed to read pixel after tone curve")
            return
        }

        XCTAssertEqual(rgba.r, 1.0, accuracy: 0.01)
        XCTAssertEqual(rgba.g, 0.0, accuracy: 0.01)
        XCTAssertEqual(rgba.b, 0.0, accuracy: 0.01)
        XCTAssertEqual(rgba.a, 1.0, accuracy: 0.01)
    }

    /// 補間器が単調性を保つかをざっくり確認（オーバーシュート防止のため）
    func testMonotonicCubicInterpolatorIsMonotonic() {
        let points = [
            CurvePoint(input: 0.0, output: 0.0),
            CurvePoint(input: 0.5, output: 0.5),
            CurvePoint(input: 1.0, output: 1.0)
        ]
        let interpolator = MonotonicCubicInterpolator(points: points)

        var last: CGFloat = -1
        for step in stride(from: 0.0, through: 1.0, by: 0.1) {
            let v = interpolator.interpolate(at: CGFloat(step))
            XCTAssertGreaterThanOrEqual(v, last - 0.0001, "Value decreased at \(step)")
            XCTAssertTrue((0.0...1.0).contains(v), "Value out of range at \(step)")
            last = v
        }
    }

    // MARK: - Helpers

    /// 1x1 CIImageからRGBAを読み出す（CIContext.renderを使用）
    private func sampleRGBA(from ciImage: CIImage) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        let context = CIContext(options: nil)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var buffer = [UInt8](repeating: 0, count: 4)
        context.render(
            ciImage,
            toBitmap: &buffer,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: colorSpace
        )
        return (
            r: CGFloat(buffer[0]) / 255.0,
            g: CGFloat(buffer[1]) / 255.0,
            b: CGFloat(buffer[2]) / 255.0,
            a: CGFloat(buffer[3]) / 255.0
        )
    }
}
