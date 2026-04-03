//
//  ToneCurveModel.swift
//  GLogo
//
//  概要:
//  トーンカーブ調整のデータモデルを定義します。
//  制御点（CurvePoint）と各チャンネルごとのカーブデータを管理し、
//  入力輝度値から出力輝度値へのマッピングを提供します。
//

import Foundation
import CoreGraphics

// MARK: - 制御点

/// トーンカーブの制御点
struct CurvePoint: Codable, Equatable {
    /// 入力値（0.0 〜 1.0）
    var input: CGFloat

    /// 出力値（0.0 〜 1.0）
    var output: CGFloat

    /// イニシャライザ
    init(input: CGFloat, output: CGFloat) {
        self.input = min(max(input, 0.0), 1.0)   // 0.0 〜 1.0 にクランプ
        self.output = min(max(output, 0.0), 1.0) // 0.0 〜 1.0 にクランプ
    }

    /// デフォルト（対角線上の点）
    static func diagonal(at position: CGFloat) -> CurvePoint {
        return CurvePoint(input: position, output: position)
    }
}

// MARK: - トーンカーブデータ

/// トーンカーブの調整データ
struct ToneCurveData: Codable, Equatable {
    /// RGBチャンネルの制御点
    var rgbPoints: [CurvePoint]

    /// 赤チャンネルの制御点
    var redPoints: [CurvePoint]

    /// 緑チャンネルの制御点
    var greenPoints: [CurvePoint]

    /// 青チャンネルの制御点
    var bluePoints: [CurvePoint]

    /// イニシャライザ - デフォルト値（対角線）
    init() {
        // 各チャンネルに3つの制御点を配置（シャドウ、中間、ハイライト）
        self.rgbPoints = [
            CurvePoint.diagonal(at: 0.0),   // シャドウ（左下）
            CurvePoint.diagonal(at: 0.5),   // 中間
            CurvePoint.diagonal(at: 1.0)    // ハイライト（右上）
        ]
        self.redPoints = self.rgbPoints
        self.greenPoints = self.rgbPoints
        self.bluePoints = self.rgbPoints
    }

    /// カスタムイニシャライザ
    init(rgbPoints: [CurvePoint], redPoints: [CurvePoint], greenPoints: [CurvePoint], bluePoints: [CurvePoint]) {
        self.rgbPoints = rgbPoints
        self.redPoints = redPoints
        self.greenPoints = greenPoints
        self.bluePoints = bluePoints

        // 極端な値を検証・修正
        self.validateAndClampPoints()
    }

    /// Codableデコード時のカスタムイニシャライザ
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.rgbPoints = try container.decode([CurvePoint].self, forKey: .rgbPoints)
        self.redPoints = try container.decode([CurvePoint].self, forKey: .redPoints)
        self.greenPoints = try container.decode([CurvePoint].self, forKey: .greenPoints)
        self.bluePoints = try container.decode([CurvePoint].self, forKey: .bluePoints)

        // デコード後に極端な値を検証・修正
        self.validateAndClampPoints()
    }

    /// 制御点の出力値を検証し、0.0〜1.0の範囲内にクランプする
    private mutating func validateAndClampPoints() {
        // RGB チャンネル
        let validatedRGB = clampPoints(rgbPoints)
        self.rgbPoints = validatedRGB

        // 赤チャンネル
        let validatedRed = clampPoints(redPoints)
        self.redPoints = validatedRed

        // 緑チャンネル
        let validatedGreen = clampPoints(greenPoints)
        self.greenPoints = validatedGreen

        // 青チャンネル
        let validatedBlue = clampPoints(bluePoints)
        self.bluePoints = validatedBlue
    }

    /// 制御点配列の各要素を0.0〜1.0の範囲内にクランプ
    private func clampPoints(_ points: [CurvePoint]) -> [CurvePoint] {
        return points.map { point in
            let clampedOutput = max(0.0, min(point.output, 1.0))

            if abs(clampedOutput - point.output) > 0.001 {
                return CurvePoint(input: point.input, output: clampedOutput)
            }

            return point
        }
    }

    /// CodingKeys for Codable
    private enum CodingKeys: String, CodingKey {
        case rgbPoints, redPoints, greenPoints, bluePoints
    }

    /// 指定されたチャンネルの制御点を取得
    func points(for channel: ToneCurveChannel) -> [CurvePoint] {
        switch channel {
        case .rgb:
            return rgbPoints
        case .red:
            return redPoints
        case .green:
            return greenPoints
        case .blue:
            return bluePoints
        }
    }

    /// 指定されたチャンネルの制御点を更新
    mutating func setPoints(_ points: [CurvePoint], for channel: ToneCurveChannel) {
        // 入力値でソート（昇順）
        let sortedPoints = points.sorted { $0.input < $1.input }

        switch channel {
        case .rgb:
            self.rgbPoints = sortedPoints
        case .red:
            self.redPoints = sortedPoints
        case .green:
            self.greenPoints = sortedPoints
        case .blue:
            self.bluePoints = sortedPoints
        }
    }

    /// 制御点を更新（指定インデックス）
    mutating func updatePoint(at index: Int, to newPoint: CurvePoint, for channel: ToneCurveChannel) {
        var currentPoints = points(for: channel)
        guard index >= 0 && index < currentPoints.count else { return }

        currentPoints[index] = newPoint
        setPoints(currentPoints, for: channel)
    }

    /// リセット（対角線に戻す）
    mutating func reset(for channel: ToneCurveChannel) {
        let defaultPoints = [
            CurvePoint.diagonal(at: 0.0),
            CurvePoint.diagonal(at: 0.5),
            CurvePoint.diagonal(at: 1.0)
        ]
        setPoints(defaultPoints, for: channel)
    }

    /// 全チャンネルをリセット
    mutating func resetAll() {
        reset(for: .rgb)
        reset(for: .red)
        reset(for: .green)
        reset(for: .blue)
    }
}
