//
//  ImagePreviewService.swift
//  GLogo
//
//  プレビュー生成・フィルタ適用・キャッシュ管理を担当するサービス。
//  モデル(ImageElement)からは委譲し、ViewModel経由で利用する前提。
//

import UIKit

/// レンダリング経路の種別
enum ImageRenderMode: Equatable {
    /// SDR向け経路
    case sdr
    /// HDR向け経路
    case hdr

    /// プリセットIDからレンダリング経路を判定
    /// - Parameters:
    ///   - presetId: 適用中プリセットID
    /// - Returns: 判定したレンダリング経路
    static func fromPresetId(_ presetId: String?) -> ImageRenderMode {
        guard let presetId, presetId.hasPrefix("hdr_") else {
            return .sdr
        }
        return .hdr
    }
}

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
    /// ビネット強度
    let vignetteIntensity: CGFloat
    /// ブルーム強度
    let bloomIntensity: CGFloat
    /// グレイン強度
    let grainIntensity: CGFloat
    /// フェード強度
    let fadeIntensity: CGFloat
    /// 色収差強度
    let chromaticAberrationIntensity: CGFloat
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
        vignetteIntensity: CGFloat = 0.0,
        bloomIntensity: CGFloat = 0.0,
        grainIntensity: CGFloat = 0.0,
        fadeIntensity: CGFloat = 0.0,
        chromaticAberrationIntensity: CGFloat = 0.0,
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
        self.vignetteIntensity = vignetteIntensity
        self.bloomIntensity = bloomIntensity
        self.grainIntensity = grainIntensity
        self.fadeIntensity = fadeIntensity
        self.chromaticAberrationIntensity = chromaticAberrationIntensity
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
    ///   - mode: レンダリング経路
    /// - Returns: プレビューに使う元画像
    func generatePreviewImage(
        editingImage: UIImage?,
        originalImage: UIImage?,
        mode: ImageRenderMode
    ) -> UIImage?
    
    /// 即時プレビューを生成（キャッシュ込み）
    /// - Parameters:
    ///   - baseImage: プレビューのベース画像
    ///   - params: フィルタパラメータ
    ///   - quality: プレビュー品質
    ///   - mode: レンダリング経路
    /// - Returns: フィルタ適用済みプレビュー
    func instantPreview(
        baseImage: UIImage?,
        params: ImageFilterParams,
        quality: ToneCurveFilter.Quality,
        mode: ImageRenderMode
    ) -> UIImage?
    
    /// フィルタ適用（同期）
    /// - Parameters:
    ///   - image: 入力画像
    ///   - params: フィルタパラメータ
    ///   - quality: レンダリング品質
    ///   - mode: レンダリング経路
    /// - Returns: フィルタ適用済み画像
    func applyFilters(
        to image: UIImage,
        params: ImageFilterParams,
        quality: ToneCurveFilter.Quality,
        mode: ImageRenderMode
    ) -> UIImage?
    
    /// フィルタ適用（非同期）
    /// - Parameters:
    ///   - image: 入力画像
    ///   - params: フィルタパラメータ
    ///   - quality: レンダリング品質
    ///   - mode: レンダリング経路
    /// - Returns: フィルタ適用済み画像
    func applyFiltersAsync(
        to image: UIImage,
        params: ImageFilterParams,
        quality: ToneCurveFilter.Quality,
        mode: ImageRenderMode
    ) async -> UIImage?

    /// プレビューキャッシュをリセットする
    /// - Parameters: なし
    /// - Returns: なし
    func resetCache()
}

/// 既定のプレビュー・フィルタサービス（SDR実装へのファサード）
final class ImagePreviewService: ImagePreviewing {
    private let sdrService: ImagePreviewing
    private let hdrService: ImagePreviewing

    /// ファサードを初期化
    /// - Parameters:
    ///   - sdrService: SDR専用サービス
    ///   - hdrService: HDR専用サービス
    /// - Returns: なし
    init(
        sdrService: ImagePreviewing = SDRImagePreviewService(),
        hdrService: ImagePreviewing = HDRImagePreviewService()
    ) {
        self.sdrService = sdrService
        self.hdrService = hdrService
    }

    /// モードに応じて実体サービスを解決
    /// - Parameters:
    ///   - mode: レンダリング経路
    /// - Returns: 使用する実体サービス
    private func service(for mode: ImageRenderMode) -> ImagePreviewing {
        switch mode {
        case .sdr:
            return sdrService
        case .hdr:
            return hdrService
        }
    }

    /// プレビュー用のベース画像を返す
    /// - Parameters:
    ///   - editingImage: 編集用プロキシ画像
    ///   - originalImage: オリジナル画像
    ///   - mode: レンダリング経路
    /// - Returns: プレビューに使う元画像
    func generatePreviewImage(
        editingImage: UIImage?,
        originalImage: UIImage?,
        mode: ImageRenderMode
    ) -> UIImage? {
        service(for: mode).generatePreviewImage(
            editingImage: editingImage,
            originalImage: originalImage,
            mode: mode
        )
    }

    /// 即時プレビューを生成（キャッシュ込み）
    /// - Parameters:
    ///   - baseImage: プレビューのベース画像
    ///   - params: フィルタパラメータ
    ///   - quality: プレビュー品質
    ///   - mode: レンダリング経路
    /// - Returns: フィルタ適用済みプレビュー
    func instantPreview(
        baseImage: UIImage?,
        params: ImageFilterParams,
        quality: ToneCurveFilter.Quality,
        mode: ImageRenderMode
    ) -> UIImage? {
        service(for: mode).instantPreview(
            baseImage: baseImage,
            params: params,
            quality: quality,
            mode: mode
        )
    }

    /// フィルタ適用（同期）
    /// - Parameters:
    ///   - image: 入力画像
    ///   - params: フィルタパラメータ
    ///   - quality: レンダリング品質
    ///   - mode: レンダリング経路
    /// - Returns: フィルタ適用済み画像
    func applyFilters(
        to image: UIImage,
        params: ImageFilterParams,
        quality: ToneCurveFilter.Quality,
        mode: ImageRenderMode
    ) -> UIImage? {
        service(for: mode).applyFilters(
            to: image,
            params: params,
            quality: quality,
            mode: mode
        )
    }

    /// フィルタ適用（非同期）
    /// - Parameters:
    ///   - image: 入力画像
    ///   - params: フィルタパラメータ
    ///   - quality: レンダリング品質
    ///   - mode: レンダリング経路
    /// - Returns: フィルタ適用済み画像
    func applyFiltersAsync(
        to image: UIImage,
        params: ImageFilterParams,
        quality: ToneCurveFilter.Quality,
        mode: ImageRenderMode
    ) async -> UIImage? {
        await service(for: mode).applyFiltersAsync(
            to: image,
            params: params,
            quality: quality,
            mode: mode
        )
    }

    /// プレビューキャッシュをリセットする
    /// - Parameters: なし
    /// - Returns: なし
    func resetCache() {
        sdrService.resetCache()
        hdrService.resetCache()
    }
}
