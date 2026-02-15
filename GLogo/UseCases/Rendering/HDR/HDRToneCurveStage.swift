//
//  HDRToneCurveStage.swift
//  GLogo
//
//  概要:
//  HDR用トーンカーブ適用を1ステージとして扱う薄いラッパー。
//  HDRToneCurveFilterを呼び出し、RenderPolicyの品質設定を反映する。

import CoreImage
import UIKit

/// HDR用トーンカーブ適用ステージ。HDRToneCurveFilterへ委譲する。
struct HDRToneCurveStage {
    func apply(to ciImage: CIImage, curveData: ToneCurveData, policy: RenderPolicy, context: RenderContext) -> CIImage? {
        let quality: ToneCurveFilter.Quality = (policy.quality == .preview) ? .preview : .full
        return HDRToneCurveFilter.applyCurve(to: ciImage, curveData: curveData, quality: quality)
    }
}
