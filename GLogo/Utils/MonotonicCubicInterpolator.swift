//
//  MonotonicCubicInterpolator.swift
//  GLogo
//
//  概要:
//  Fritsch-Carlson法による単調3次補間（Monotonic Cubic Interpolation）を実装します。
//  この方法は、制御点が単調であれば補間曲線も単調であることを保証し、
//  予期しないオーバーシュート（膨らみ）を防ぎます。
//
//  参考文献:
//  Fritsch, F. N., and R. E. Carlson. "Monotone Piecewise Cubic Interpolation."
//  SIAM Journal on Numerical Analysis 17.2 (1980): 238-246.
//

import Foundation
import CoreGraphics

/// Fritsch-Carlson法による単調3次補間
class MonotonicCubicInterpolator {

    /// 制御点
    private let points: [CurvePoint]

    /// 各制御点での接線（tangent）
    private var tangents: [CGFloat] = []

    /// イニシャライザ
    /// - Parameter points: 補間する制御点（X座標の昇順でソート済みであること）
    init(points: [CurvePoint]) {
        self.points = points
        self.tangents = []

        guard points.count >= 2 else { return }

        // 接線を計算
        calculateTangents()
    }

    /// 指定された入力値に対する出力値を補間計算
    /// - Parameter input: 入力値（0.0〜1.0）
    /// - Returns: 補間された出力値
    func interpolate(at input: CGFloat) -> CGFloat {
        guard !points.isEmpty else { return input }

        // 入力値が最小制御点より小さい場合
        if input <= points.first!.input {
            return points.first!.output
        }

        // 入力値が最大制御点より大きい場合
        if input >= points.last!.input {
            return points.last!.output
        }

        // 入力値を挟む2つの制御点を探す
        for i in 0..<(points.count - 1) {
            let p0 = points[i]
            let p1 = points[i + 1]

            if input >= p0.input && input <= p1.input {
                // Hermite補間を実行
                return hermiteInterpolate(
                    input: input,
                    x0: p0.input, y0: p0.output, m0: tangents[i],
                    x1: p1.input, y1: p1.output, m1: tangents[i + 1]
                )
            }
        }

        return input
    }

    // MARK: - Private Methods

    /// Fritsch-Carlson法で単調性を保証する接線を計算
    private func calculateTangents() {
        let n = points.count

        guard n >= 2 else {
            tangents = [0.0]
            return
        }

        // 各区間のsecant slopes（割線の傾き）を計算
        var deltas = [CGFloat]()
        for i in 0..<(n - 1) {
            let dx = points[i + 1].input - points[i].input
            let dy = points[i + 1].output - points[i].output
            deltas.append(dy / dx)
        }

        // 接線配列を初期化
        tangents = [CGFloat](repeating: 0, count: n)

        // 最初の点の接線（最初の区間の傾きを使用）
        // 改善: 0ではなく適切な傾きを計算することで、対角線状態でも滑らかな曲線を実現
        if n >= 2 {
            tangents[0] = deltas[0]
        }

        // 内部の点の接線
        for i in 1..<(n - 1) {
            // 左右の傾きが同じ符号の場合、加重平均を使用
            if (deltas[i - 1] * deltas[i]) > 0 {
                // 加重調和平均（Fritsch-Carlson法）
                let w1 = 2 * (points[i + 1].input - points[i].input) + (points[i].input - points[i - 1].input)
                let w2 = (points[i + 1].input - points[i].input) + 2 * (points[i].input - points[i - 1].input)
                tangents[i] = (w1 + w2) / (w1 / deltas[i - 1] + w2 / deltas[i])
            } else {
                // 符号が異なる場合は0（極値点）
                tangents[i] = 0
            }
        }

        // 最後の点の接線（最後の区間の傾きを使用）
        // 改善: 0ではなく適切な傾きを計算
        if n >= 2 {
            tangents[n - 1] = deltas[n - 2]
        }

        // 単調性を保証するために接線を調整
        adjustTangentsForMonotonicity(deltas: deltas)
    }

    /// 単調性を保証するために接線を調整（Fritsch-Carlson条件）
    private func adjustTangentsForMonotonicity(deltas: [CGFloat]) {
        let n = points.count

        for i in 0..<(n - 1) {
            if deltas[i] == 0 {
                // 区間が水平な場合、両端の接線を0に
                tangents[i] = 0
                tangents[i + 1] = 0
                continue
            }

            // α と β を計算
            let alpha = tangents[i] / deltas[i]
            let beta = tangents[i + 1] / deltas[i]

            // Fritsch-Carlson条件: α² + β² ≤ 9
            let sum = alpha * alpha + beta * beta

            if sum > 9 {
                let tau = 3.0 / sqrt(sum)
                tangents[i] = tau * alpha * deltas[i]
                tangents[i + 1] = tau * beta * deltas[i]
            }
        }
    }

    /// Hermite補間
    /// - Parameters:
    ///   - input: 補間する入力値
    ///   - x0: 左側の制御点のX座標
    ///   - y0: 左側の制御点のY座標
    ///   - m0: 左側の制御点での接線
    ///   - x1: 右側の制御点のX座標
    ///   - y1: 右側の制御点のY座標
    ///   - m1: 右側の制御点での接線
    /// - Returns: 補間された値
    private func hermiteInterpolate(
        input: CGFloat,
        x0: CGFloat, y0: CGFloat, m0: CGFloat,
        x1: CGFloat, y1: CGFloat, m1: CGFloat
    ) -> CGFloat {
        // 正規化されたパラメータt（0.0〜1.0）
        let h = x1 - x0
        let t = (input - x0) / h

        // Hermite基底関数
        let t2 = t * t
        let t3 = t2 * t

        let h00 = 2 * t3 - 3 * t2 + 1  // (2t³ - 3t² + 1)
        let h10 = t3 - 2 * t2 + t      // (t³ - 2t² + t)
        let h01 = -2 * t3 + 3 * t2     // (-2t³ + 3t²)
        let h11 = t3 - t2               // (t³ - t²)

        // Hermite補間の式
        let result = h00 * y0 + h10 * h * m0 + h01 * y1 + h11 * h * m1

        return result
    }
}
