//
//  ToneCurveChannel.swift
//  GLogo
//
//  概要:
//  トーンカーブ調整で使用するカラーチャンネルを定義します。
//  RGB（明度）、赤、緑、青の4つのチャンネルを提供し、
//  それぞれ独立したトーンカーブ調整を可能にします。
//

import Foundation

/// トーンカーブのカラーチャンネル
enum ToneCurveChannel: String, CaseIterable, Codable {
    /// RGB（明度）チャンネル - 全チャンネル同時調整
    case rgb = "RGB"

    /// 赤チャンネル
    case red = "赤"

    /// 緑チャンネル
    case green = "緑"

    /// 青チャンネル
    case blue = "青"

    /// 表示名
    var displayName: String {
        return self.rawValue
    }
}
