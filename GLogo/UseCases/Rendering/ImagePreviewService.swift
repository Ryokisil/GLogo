//
//  ImagePreviewService.swift
//  GLogo
//
//  プレビュー生成・フィルタ適用・キャッシュ管理を担当するサービス。
//  モデル(ImageElement)からは委譲し、ViewModel経由で利用する前提。
//

import UIKit

/// フィルタ適用に必要なパラメータをまとめた構造体
struct ImageFilterParams {
    /// トーンカーブデータ
    let toneCurveData: ToneCurveData
    /// 彩度
    let saturation: CGFloat
    /// 明度
    let brightness: CGFloat
    /// コントラスト
    let contrast: CGFloat
    /// ハイライト補正
    let highlights: CGFloat
    /// シャドウ補正
    let shadows: CGFloat
    /// 黒レベル補正
    let blacks: CGFloat
    /// 白レベル補正
    let whites: CGFloat
    /// 色温度補正
    let warmth: CGFloat
    /// ヴィブランス補正
    let vibrance: CGFloat
    /// 色相（度数）
    let hue: CGFloat
    /// シャープネス
    let sharpness: CGFloat
    /// ガウシアンブラー半径
    let gaussianBlurRadius: CGFloat
    /// ティントカラー
    let tintColor: UIColor?
    /// ティント強度
    let tintIntensity: CGFloat
    /// 背景ぼかし半径
    let backgroundBlurRadius: CGFloat
    /// 背景ぼかしマスクデータ（PNG形式）
    let backgroundBlurMaskData: Data?

    /// 便利イニシャライザ（背景ぼかしパラメータなしの場合）
    init(
        toneCurveData: ToneCurveData,
        saturation: CGFloat,
        brightness: CGFloat,
        contrast: CGFloat,
        highlights: CGFloat,
        shadows: CGFloat,
        blacks: CGFloat = 0.0,
        whites: CGFloat = 0.0,
        warmth: CGFloat = 0.0,
        vibrance: CGFloat = 0.0,
        hue: CGFloat,
        sharpness: CGFloat,
        gaussianBlurRadius: CGFloat,
        tintColor: UIColor?,
        tintIntensity: CGFloat,
        backgroundBlurRadius: CGFloat = 0.0,
        backgroundBlurMaskData: Data? = nil
    ) {
        self.toneCurveData = toneCurveData
        self.saturation = saturation
        self.brightness = brightness
        self.contrast = contrast
        self.highlights = highlights
        self.shadows = shadows
        self.blacks = blacks
        self.whites = whites
        self.warmth = warmth
        self.vibrance = vibrance
        self.hue = hue
        self.sharpness = sharpness
        self.gaussianBlurRadius = gaussianBlurRadius
        self.tintColor = tintColor
        self.tintIntensity = tintIntensity
        self.backgroundBlurRadius = backgroundBlurRadius
        self.backgroundBlurMaskData = backgroundBlurMaskData
    }
}

/// プレビュー・フィルタ適用を提供するプロトコル
protocol ImagePreviewing {
    /// プレビュー用のベース画像を返す（編集用プロキシがあれば優先）
    /// - Parameters:
    ///   - editingImage: 編集用プロキシ画像
    ///   - originalImage: オリジナル画像
    /// - Returns: プレビューに使う元画像
    func generatePreviewImage(editingImage: UIImage?, originalImage: UIImage?) -> UIImage?
    
    /// 即時プレビューを生成（キャッシュ込み）
    /// - Parameters:
    ///   - baseImage: プレビューのベース画像
    ///   - params: フィルタパラメータ
    ///   - quality: プレビュー品質
    /// - Returns: フィルタ適用済みプレビュー
    func instantPreview(
        baseImage: UIImage?,
        params: ImageFilterParams,
        quality: ToneCurveFilter.Quality
    ) -> UIImage?
    
    /// フィルタ適用（同期）
    /// - Parameters:
    ///   - image: 入力画像
    ///   - params: フィルタパラメータ
    ///   - quality: レンダリング品質
    /// - Returns: フィルタ適用済み画像
    func applyFilters(
        to image: UIImage,
        params: ImageFilterParams,
        quality: ToneCurveFilter.Quality
    ) -> UIImage?
    
    /// フィルタ適用（非同期）
    /// - Parameters:
    ///   - image: 入力画像
    ///   - params: フィルタパラメータ
    ///   - quality: レンダリング品質
    /// - Returns: フィルタ適用済み画像
    func applyFiltersAsync(
        to image: UIImage,
        params: ImageFilterParams,
        quality: ToneCurveFilter.Quality
    ) async -> UIImage?

    /// プレビューキャッシュをリセットする
    /// - Parameters: なし
    /// - Returns: なし
    func resetCache()
}

/// 既定のプレビュー・フィルタサービス（SDR実装へのファサード）
final class ImagePreviewService: ImagePreviewing {
    private let sdrService: ImagePreviewing

    /// ファサードを初期化
    /// - Parameters:
    ///   - sdrService: SDR専用サービス
    /// - Returns: なし
    init(sdrService: ImagePreviewing = SDRImagePreviewService()) {
        self.sdrService = sdrService
    }

    /// プレビュー用のベース画像を返す
    /// - Parameters:
    ///   - editingImage: 編集用プロキシ画像
    ///   - originalImage: オリジナル画像
    /// - Returns: プレビューに使う元画像
    func generatePreviewImage(editingImage: UIImage?, originalImage: UIImage?) -> UIImage? {
        sdrService.generatePreviewImage(editingImage: editingImage, originalImage: originalImage)
    }

    /// 即時プレビューを生成（キャッシュ込み）
    /// - Parameters:
    ///   - baseImage: プレビューのベース画像
    ///   - params: フィルタパラメータ
    ///   - quality: プレビュー品質
    /// - Returns: フィルタ適用済みプレビュー
    func instantPreview(
        baseImage: UIImage?,
        params: ImageFilterParams,
        quality: ToneCurveFilter.Quality
    ) -> UIImage? {
        sdrService.instantPreview(baseImage: baseImage, params: params, quality: quality)
    }

    /// フィルタ適用（同期）
    /// - Parameters:
    ///   - image: 入力画像
    ///   - params: フィルタパラメータ
    ///   - quality: レンダリング品質
    /// - Returns: フィルタ適用済み画像
    func applyFilters(
        to image: UIImage,
        params: ImageFilterParams,
        quality: ToneCurveFilter.Quality
    ) -> UIImage? {
        sdrService.applyFilters(to: image, params: params, quality: quality)
    }

    /// フィルタ適用（非同期）
    /// - Parameters:
    ///   - image: 入力画像
    ///   - params: フィルタパラメータ
    ///   - quality: レンダリング品質
    /// - Returns: フィルタ適用済み画像
    func applyFiltersAsync(
        to image: UIImage,
        params: ImageFilterParams,
        quality: ToneCurveFilter.Quality
    ) async -> UIImage? {
        await sdrService.applyFiltersAsync(to: image, params: params, quality: quality)
    }

    /// プレビューキャッシュをリセットする
    /// - Parameters: なし
    /// - Returns: なし
    func resetCache() {
        sdrService.resetCache()
    }
}
