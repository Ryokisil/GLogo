//
//  RenderPolicy.swift
//  GLogo
//
//  概要:
//  レンダリング時の品質やダウンサンプル設定、LUTサイズをまとめるポリシー定義。
//  プレビュー/本番の切り替えを一元管理し、パイプラインに渡すためのデータ構造を提供する。

import CoreGraphics
import CoreImage

/// レンダリング品質やターゲットサイズをまとめる設定。
struct RenderPolicy {
    enum Quality {
        case preview
        case full
    }

    let quality: Quality
    /// プレビュー用のダウンサンプル後サイズ（例: 384px相当）。nilなら原寸。
    let targetMaxDimension: CGFloat?
    /// トーンカーブLUTのキューブ次元
    let toneCurveCubeDimension: Int

    /// プレビュー向けの既定ポリシー
    static let preview = RenderPolicy(
        quality: .preview,
        targetMaxDimension: nil, // 解像度を維持したまま適用
        toneCurveCubeDimension: 16
    )

    /// フル品質の既定ポリシー
    static let full = RenderPolicy(
        quality: .full,
        targetMaxDimension: nil,
        toneCurveCubeDimension: 64
    )
}
