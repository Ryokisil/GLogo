//
//  RealESRGANPipeline.swift
//  GLogo
//
//  概要:
//  このファイルは Real-ESRGAN を接続するための高画質化パイプラインを定義します。
//  `realesr-general-x4v3` を既定モデルとして扱い、アプリへ組み込まれた Core ML モデルの検出と推論委譲を担います。
//

import Foundation

/// Real-ESRGAN パイプラインの設定値
struct RealESRGANPipelineConfiguration {
    let compiledModelName: String
    let preferredTileSize: Int?
    let modelLocator: UpscaleModelLocator

    /// 設定値を生成する
    /// - Parameters:
    ///   - compiledModelName: Xcode に組み込まれたコンパイル済みモデル名
    ///   - preferredTileSize: 固定入力モデルに対して優先的に使うタイルサイズ
    ///   - modelLocator: バンドル済みモデルの探索設定
    /// - Returns: 生成された設定値
    init(
        compiledModelName: String = "realesr-general-x4v3",
        preferredTileSize: Int? = nil,
        modelLocator: UpscaleModelLocator = .init()
    ) {
        self.compiledModelName = compiledModelName
        self.preferredTileSize = preferredTileSize
        self.modelLocator = modelLocator
    }
}

/// Real-ESRGAN を接続するためのプレースホルダーパイプライン
struct RealESRGANPipeline: ImageUpscalingPipeline {
    private let configuration: RealESRGANPipelineConfiguration
    private let upscaler: CoreMLUpscaler

    /// Real-ESRGAN パイプラインを生成する
    /// - Parameters:
    ///   - configuration: モデル検出に利用する設定値
    /// - Returns: 生成されたパイプライン
    init(configuration: RealESRGANPipelineConfiguration = .init()) {
        self.configuration = configuration
        self.upscaler = CoreMLUpscaler(configuration: configuration)
    }

    var method: ImageUpscaleMethod {
        .realESRGAN
    }

    var isAvailable: Bool {
        configuration.modelLocator.compiledModelURL(named: configuration.compiledModelName) != nil
    }

    /// Real-ESRGAN の高画質化処理を実行する
    /// - Parameters:
    ///   - request: 実行対象のリクエスト
    /// - Returns: 高画質化結果
    func upscale(_ request: ImageUpscaleRequest) async throws -> ImageUpscaleResult {
        guard isAvailable else {
            throw ImageUpscaleError.modelNotFound(name: configuration.compiledModelName)
        }
        return try await upscaler.upscale(request)
    }
}
