//
//  ToneCurveStage.swift
//  GLogo
//
//  概要:
//  トーンカーブ適用を1ステージとして扱う薄いラッパー。
//  既存のToneCurveFilterを呼び出し、RenderPolicyの品質設定を反映する。

import CoreImage
import UIKit

/// トーンカーブ適用のステージ。現行実装を使い回す薄いラッパー。
struct ToneCurveStage {
    func apply(to ciImage: CIImage, curveData: ToneCurveData, policy: RenderPolicy, context: RenderContext) -> CIImage? {
        // 既存のToneCurveFilterを利用しつつ、品質をpolicyに合わせる。
        // 既存コードとの互換を保つため、ToneCurveFilterのQualityをRenderPolicyからマッピング。
        let quality: ToneCurveFilter.Quality = (policy.quality == .preview) ? .preview : .full
        return ToneCurveFilter.applyCurve(to: ciImage, curveData: curveData, quality: quality)
    }
}
