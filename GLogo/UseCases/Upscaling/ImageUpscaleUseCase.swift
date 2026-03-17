//
//  ImageUpscaleUseCase.swift
//  GLogo
//
//  概要:
//  このファイルは高画質化の内部実装方式を解決して実行するユースケースを定義します。
//  ユーザーには単一の Enhance 機能だけを見せつつ、内部では Real-ESRGAN とフォールバック処理を切り替えます。
//

import Foundation

/// 高画質化ユースケース
struct ImageUpscaleUseCase {
    private let lanczosPipeline: any ImageUpscalingPipeline
    private let realESRGANPipeline: any ImageUpscalingPipeline

    /// Real-ESRGAN パイプラインが利用可能かどうか
    var isRealESRGANAvailable: Bool {
        realESRGANPipeline.isAvailable
    }

    /// ユースケースを生成する
    /// - Parameters:
    ///   - lanczosPipeline: 既定のフォールバックパイプライン
    ///   - realESRGANPipeline: Real-ESRGAN 用パイプライン
    /// - Returns: 生成されたユースケース
    init(
        lanczosPipeline: any ImageUpscalingPipeline = LanczosUpscalePipeline(),
        realESRGANPipeline: any ImageUpscalingPipeline = RealESRGANPipeline()
    ) {
        self.lanczosPipeline = lanczosPipeline
        self.realESRGANPipeline = realESRGANPipeline
    }

    /// 適切な内部パイプラインを選択して高画質化を実行する
    /// - Parameters:
    ///   - request: 実行対象のリクエスト
    /// - Returns: 高画質化結果
    func upscale(_ request: ImageUpscaleRequest) async throws -> ImageUpscaleResult {
        let pipeline = try resolvePipeline(for: request.method)
        return try await pipeline.upscale(request)
    }

    /// 指定した内部方式に応じた実行パイプラインを解決する
    /// - Parameters:
    ///   - method: 要求された高画質化方式
    /// - Returns: 実行対象のパイプライン
    private func resolvePipeline(for method: ImageUpscaleMethod) throws -> any ImageUpscalingPipeline {
        switch method {
        case .automatic:
            if realESRGANPipeline.isAvailable {
                return realESRGANPipeline
            }
            return lanczosPipeline
        case .lanczos:
            return lanczosPipeline
        case .realESRGAN:
            guard realESRGANPipeline.isAvailable else {
                throw ImageUpscaleError.pipelineUnavailable(method: .realESRGAN)
            }
            return realESRGANPipeline
        }
    }
}
