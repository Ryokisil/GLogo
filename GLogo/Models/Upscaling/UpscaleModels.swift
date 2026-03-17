//
//  UpscaleModels.swift
//  GLogo
//
//  概要:
//  このファイルは高画質化機能で利用するリクエスト・レスポンス・設定値を定義します。
//  ユーザーには単一の Enhance 機能だけを見せつつ、内部で使う処理方式や倍率などを集約します。
//

import Foundation
import UIKit

/// 高画質化処理の内部方式を表す列挙型
enum ImageUpscaleMethod: String, CaseIterable, Codable {
    case automatic
    case lanczos
    case realESRGAN
}

/// 高画質化倍率を表す列挙型
enum ImageUpscaleScaleFactor: Int, CaseIterable, Codable {
    case x2 = 2
    case x4 = 4

    /// Core Image などで利用する倍率値を返す
    /// - Parameters: なし
    /// - Returns: 倍率
    var multiplier: CGFloat {
        CGFloat(rawValue)
    }
}

/// 高画質化実行時の入力値
struct ImageUpscaleRequest {
    let sourceImage: UIImage
    let method: ImageUpscaleMethod
    let scaleFactor: ImageUpscaleScaleFactor
    let appliesSharpening: Bool

    /// 高画質化リクエストを生成する
    /// - Parameters:
    ///   - sourceImage: 高画質化対象の元画像
    ///   - method: 内部で利用する高画質化方式
    ///   - scaleFactor: 出力倍率
    ///   - appliesSharpening: 拡大後にシャープ化を行うかどうか
    /// - Returns: 生成されたリクエスト
    init(
        sourceImage: UIImage,
        method: ImageUpscaleMethod = .realESRGAN,
        scaleFactor: ImageUpscaleScaleFactor = .x2,
        appliesSharpening: Bool = true
    ) {
        self.sourceImage = sourceImage
        self.method = method
        self.scaleFactor = scaleFactor
        self.appliesSharpening = appliesSharpening
    }
}

/// 高画質化完了時の出力値
struct ImageUpscaleResult {
    let image: UIImage
    let appliedMethod: ImageUpscaleMethod
    let scaleFactor: ImageUpscaleScaleFactor
    let actualScaleMultiplier: CGFloat

    /// 高画質化結果を生成する
    /// - Parameters:
    ///   - image: 生成された画像
    ///   - appliedMethod: 実際に適用された方式
    ///   - scaleFactor: 実際に適用された倍率
    ///   - actualScaleMultiplier: 実際に出力へ適用した倍率
    /// - Returns: 生成された結果
    init(
        image: UIImage,
        appliedMethod: ImageUpscaleMethod,
        scaleFactor: ImageUpscaleScaleFactor,
        actualScaleMultiplier: CGFloat
    ) {
        self.image = image
        self.appliedMethod = appliedMethod
        self.scaleFactor = scaleFactor
        self.actualScaleMultiplier = actualScaleMultiplier
    }
}

/// 高画質化処理で発生するエラー
enum ImageUpscaleError: LocalizedError {
    case missingCGImage
    case filterUnavailable(name: String)
    case imageGenerationFailed
    case pipelineUnavailable(method: ImageUpscaleMethod)
    case modelNotFound(name: String)
    case invalidModelInterface
    case predictionFailed(reason: String)
    case sourceImageTooLarge

    var errorDescription: String? {
        switch self {
        case .missingCGImage:
            return "元画像の CGImage を取得できませんでした。"
        case .filterUnavailable(let name):
            return "\(name) フィルターが利用できませんでした。"
        case .imageGenerationFailed:
            return "高画質化画像の生成に失敗しました。"
        case .pipelineUnavailable:
            return "AI高画質化を利用するためのモデルが見つかりませんでした。"
        case .modelNotFound(let name):
            return "\(name) の Core ML モデルが見つかりませんでした。"
        case .invalidModelInterface:
            return "Core ML モデルの入出力定義を解決できませんでした。"
        case .predictionFailed(let reason):
            return "Core ML 推論に失敗しました: \(reason)"
        case .sourceImageTooLarge:
            return "画像が大きすぎるため、この設定では安全に高画質化できません。"
        }
    }
}
