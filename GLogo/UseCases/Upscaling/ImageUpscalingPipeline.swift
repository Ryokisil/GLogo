//
//  ImageUpscalingPipeline.swift
//  GLogo
//
//  概要:
//  このファイルは高画質化パイプラインの共通インターフェースを定義します。
//  Core Image ベースの簡易実装と、将来の Core ML / Real-ESRGAN 実装を同じ窓口で扱えるようにします。
//

import Foundation

/// 高画質化パイプラインの共通インターフェース
protocol ImageUpscalingPipeline {
    /// パイプラインが担当する高画質化方式
    var method: ImageUpscaleMethod { get }

    /// 現在の実行環境で利用可能かどうか
    var isAvailable: Bool { get }

    /// 高画質化処理を実行する
    /// - Parameters:
    ///   - request: 実行対象のリクエスト
    /// - Returns: 高画質化結果
    func upscale(_ request: ImageUpscaleRequest) async throws -> ImageUpscaleResult
}
