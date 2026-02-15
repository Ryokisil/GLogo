//
//  AdjustmentStages.swift
//  GLogo
//
//  概要:
//  彩度・明度・コントラストなど既存のフィルター適用順序をステージ化し、
//  パイプラインから再利用できるようにした補助モジュール。

import CoreImage

/// フィルター調整用のパラメータをまとめる
struct AdjustmentParams {
    let saturation: CGFloat
    let brightness: CGFloat
    let contrast: CGFloat
    let highlights: CGFloat
    let shadows: CGFloat
    let blacks: CGFloat
    let whites: CGFloat
    let warmth: CGFloat
    let vibrance: CGFloat
    let hue: CGFloat
    let sharpness: CGFloat
    let gaussianBlurRadius: CGFloat
}

/// 既存のフィルター適用順序を小さなステージとして提供
enum AdjustmentStages {
    static func makeClosure(params: AdjustmentParams) -> (inout CIImage) -> Void {
        return { ciImage in
            // 彩度・明度・コントラスト
            if let adjusted = ImageFilterUtility.applyBasicColorAdjustment(
                to: ciImage,
                saturation: params.saturation,
                brightness: params.brightness,
                contrast: params.contrast
            ) {
                ciImage = adjusted
            }

            // ハイライト
            if params.highlights != 0,
               let adjusted = ImageFilterUtility.applyHighlightAdjustment(
                to: ciImage,
                amount: params.highlights
               ) {
                ciImage = adjusted
            }

            // シャドウ
            if params.shadows != 0,
               let adjusted = ImageFilterUtility.applyShadowAdjustment(
                to: ciImage,
                amount: params.shadows
               ) {
                ciImage = adjusted
            }

            // 黒レベル
            if params.blacks != 0,
               let adjusted = ImageFilterUtility.applyBlackAdjustment(
                to: ciImage,
                amount: params.blacks
               ) {
                ciImage = adjusted
            }

            // 白レベル
            if params.whites != 0,
               let adjusted = ImageFilterUtility.applyWhiteAdjustment(
                to: ciImage,
                amount: params.whites
               ) {
                ciImage = adjusted
            }

            // 色温度
            if params.warmth != 0,
               let adjusted = ImageFilterUtility.applyWarmthAdjustment(
                to: ciImage,
                warmth: params.warmth
               ) {
                ciImage = adjusted
            }

            // ヴィブランス
            if params.vibrance != 0,
               let adjusted = ImageFilterUtility.applyVibranceAdjustment(
                to: ciImage,
                amount: params.vibrance
               ) {
                ciImage = adjusted
            }

            // 色相
            if params.hue != 0,
               let adjusted = ImageFilterUtility.applyHueAdjustment(
                to: ciImage,
                angle: params.hue
               ) {
                ciImage = adjusted
            }

            // シャープネス
            if params.sharpness != 0,
               let adjusted = ImageFilterUtility.applySharpness(
                to: ciImage,
                intensity: params.sharpness
               ) {
                ciImage = adjusted
            }

            // ガウシアンブラー
            if params.gaussianBlurRadius != 0,
               let adjusted = ImageFilterUtility.applyGaussianBlur(
                to: ciImage,
                radius: params.gaussianBlurRadius
               ) {
                ciImage = adjusted
            }
        }
    }
}
