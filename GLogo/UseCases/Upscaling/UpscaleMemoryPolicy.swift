//
//  UpscaleMemoryPolicy.swift
//  GLogo
//
//  概要:
//  このファイルは高画質化時の出力サイズを安全域へ制限するためのポリシーを定義します。
//  端末メモリを圧迫しやすい巨大出力を抑え、OS kill を避けるための共通判定を提供します。
//

import Foundation

/// 高画質化時のメモリ保護ポリシー
struct UpscaleMemoryPolicy {
    let maxOutputPixelCount: CGFloat
    let maxOutputLongSide: CGFloat

    /// 既定のメモリ保護ポリシーを生成する
    /// - Parameters:
    ///   - maxOutputPixelCount: 許容する出力総ピクセル数
    ///   - maxOutputLongSide: 許容する出力長辺
    /// - Returns: 生成されたポリシー
    init(
        maxOutputPixelCount: CGFloat = 24_000_000,
        maxOutputLongSide: CGFloat = 6_144
    ) {
        self.maxOutputPixelCount = maxOutputPixelCount
        self.maxOutputLongSide = maxOutputLongSide
    }

    /// 要求倍率を安全な範囲へ制限する
    /// - Parameters:
    ///   - requestedScale: 要求された倍率
    ///   - sourcePixelSize: 元画像のピクセルサイズ
    /// - Returns: 安全化後の倍率
    func safeScale(
        requestedScale: CGFloat,
        sourcePixelSize: CGSize
    ) -> CGFloat {
        let sourcePixelCount = max(sourcePixelSize.width * sourcePixelSize.height, 1)
        let sourceLongSide = max(sourcePixelSize.width, sourcePixelSize.height)

        let pixelLimitedScale = sqrt(maxOutputPixelCount / sourcePixelCount)
        let longSideLimitedScale = maxOutputLongSide / max(sourceLongSide, 1)

        let constrainedScale = min(requestedScale, pixelLimitedScale, longSideLimitedScale)
        return max(constrainedScale, 0)
    }
}
