//
//  SDRImagePreviewService.swift
//  GLogo
//
//  概要:
//  SDR専用のプレビュー生成・フィルタ適用・キャッシュ管理を担当するサービス。
//  ImagePreviewingプロトコル準拠の実処理を保持し、上位ファサードから委譲される。
//

import UIKit

/// SDR専用のプレビュー・フィルタ適用実装
final class SDRImagePreviewService: ImagePreviewing {
    private let filterPipeline = FilterPipeline()
    private let previewCache = PreviewCache()

    /// プレビュー用ベースを生成（プロキシ優先）
    /// - Parameters:
    ///   - editingImage: 編集用プロキシ
    ///   - originalImage: オリジナル画像
    ///   - mode: レンダリング経路（SDRでは未使用）
    /// - Returns: プレビューで使う画像
    func generatePreviewImage(
        editingImage: UIImage?,
        originalImage: UIImage?,
        mode _: ImageRenderMode
    ) -> UIImage? {
        if let proxy = editingImage { return proxy }
        return originalImage
    }

    /// 即時プレビューを生成し、パラメータでキャッシュ管理
    /// - Parameters:
    ///   - baseImage: プレビューのベース画像
    ///   - params: フィルタパラメータ
    ///   - quality: プレビュー品質
    ///   - mode: レンダリング経路（SDRでは未使用）
    /// - Returns: フィルタ適用済みプレビュー
    func instantPreview(
        baseImage: UIImage?,
        params: ImageFilterParams,
        quality: ToneCurveFilter.Quality,
        mode: ImageRenderMode
    ) -> UIImage? {
        guard let preview = baseImage else { return nil }

        let previewKey = makeCacheKey(params: params)
        if let cached = previewCache.image(for: previewKey) {
            return cached
        }

        previewCache.markInProgress()
        let filtered = applyFilters(
            to: preview,
            params: params,
            quality: quality,
            mode: mode
        ) ?? preview
        previewCache.set(image: filtered, for: previewKey)
        return filtered
    }

    /// フィルタ適用（同期）
    /// - Parameters:
    ///   - image: 入力画像
    ///   - params: フィルタパラメータ
    ///   - quality: レンダリング品質
    ///   - mode: レンダリング経路（SDRでは未使用）
    /// - Returns: フィルタ適用済み画像
    func applyFilters(
        to image: UIImage,
        params: ImageFilterParams,
        quality: ToneCurveFilter.Quality,
        mode _: ImageRenderMode
    ) -> UIImage? {
        let policy: RenderPolicy = (quality == .preview) ? .preview : .full

        let adjustments = AdjustmentStages.makeClosure(params: Self.makeAdjustmentParams(from: params))
        guard var base = filterPipeline.applyAllFilters(
            to: image,
            toneCurveData: params.toneCurveData,
            policy: policy,
            adjustments: adjustments
        ) else {
            return image
        }

        // 背景ぼかし合成を適用（マスクがある場合のみ）
        if params.backgroundBlurRadius > 0,
           let maskData = params.backgroundBlurMaskData,
           let blurred = ImageFilterUtility.applyBackgroundBlur(
            to: base,
            maskData: maskData,
            radius: params.backgroundBlurRadius
           ) {
            base = blurred
        }

        // ティントカラーを適用
        if let tintColor = params.tintColor, params.tintIntensity > 0,
           let tinted = ImageFilterUtility.applyTintOverlay(
            to: base,
            color: tintColor,
            intensity: params.tintIntensity
           ) {
            return tinted
        }

        return base
    }

    /// フィルタ適用（非同期）
    /// - Parameters:
    ///   - image: 入力画像
    ///   - params: フィルタパラメータ
    ///   - quality: レンダリング品質
    ///   - mode: レンダリング経路（SDRでは未使用）
    /// - Returns: フィルタ適用済み画像
    func applyFiltersAsync(
        to image: UIImage,
        params: ImageFilterParams,
        quality: ToneCurveFilter.Quality,
        mode _: ImageRenderMode
    ) async -> UIImage? {
        await Task.detached(priority: .userInitiated) { [filterPipeline, params] in
            let policy: RenderPolicy = (quality == .preview) ? .preview : .full
            let adjustments = AdjustmentStages.makeClosure(params: Self.makeAdjustmentParams(from: params))
            var result = filterPipeline.applyAllFilters(
                to: image,
                toneCurveData: params.toneCurveData,
                policy: policy,
                adjustments: adjustments
            ) ?? image

            // 背景ぼかし合成を適用（マスクがある場合のみ）
            if params.backgroundBlurRadius > 0,
               let maskData = params.backgroundBlurMaskData,
               let blurred = ImageFilterUtility.applyBackgroundBlur(
                to: result,
                maskData: maskData,
                radius: params.backgroundBlurRadius
               ) {
                result = blurred
            }

            // ティントカラーを適用
            if let tintColor = params.tintColor, params.tintIntensity > 0,
               let tinted = ImageFilterUtility.applyTintOverlay(
                to: result,
                color: tintColor,
                intensity: params.tintIntensity
               ) {
                return tinted
            }
            return result
        }.value
    }

    /// プレビューキャッシュをリセットする
    /// - Parameters: なし
    /// - Returns: なし
    func resetCache() {
        previewCache.reset()
    }

    // MARK: - Helpers

    /// キャッシュキー（トーンカーブ＋調整パラメータ）を生成
    /// - Parameter params: フィルタパラメータ
    /// - Returns: キャッシュ用ハッシュ値
    private func makeCacheKey(params: ImageFilterParams) -> Int {
        toneCurveHash(params.toneCurveData) ^ adjustmentsHash(params)
    }

    /// トーンカーブ用ハッシュ
    /// - Parameter data: トーンカーブデータ
    /// - Returns: ハッシュ値
    private func toneCurveHash(_ data: ToneCurveData) -> Int {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        if let jsonData = try? encoder.encode(data),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString.hashValue
        }
        return "\(data.rgbPoints.count)_\(data.redPoints.count)_\(data.greenPoints.count)_\(data.bluePoints.count)".hashValue
    }

    /// 調整パラメータ用ハッシュ
    /// - Parameter params: フィルタパラメータ
    /// - Returns: ハッシュ値
    private func adjustmentsHash(_ params: ImageFilterParams) -> Int {
        var hasher = Hasher()
        hasher.combine(params.saturation)
        hasher.combine(params.brightness)
        hasher.combine(params.contrast)
        hasher.combine(params.highlights)
        hasher.combine(params.shadows)
        hasher.combine(params.blacks)
        hasher.combine(params.whites)
        hasher.combine(params.warmth)
        hasher.combine(params.vibrance)
        hasher.combine(params.hue)
        hasher.combine(params.sharpness)
        hasher.combine(params.gaussianBlurRadius)
        hasher.combine(params.vignetteIntensity)
        hasher.combine(params.bloomIntensity)
        hasher.combine(params.grainIntensity)
        hasher.combine(params.fadeIntensity)
        hasher.combine(params.chromaticAberrationIntensity)
        hasher.combine(params.tintIntensity)
        hasher.combine(params.backgroundBlurRadius)
        hasher.combine(params.backgroundBlurMaskData)
        return hasher.finalize()
    }

    /// 既存のレンダリング調整パラメータへ変換
    /// - Parameter params: フィルタパラメータ
    /// - Returns: AdjustmentParams への変換結果
    private static func makeAdjustmentParams(from params: ImageFilterParams) -> AdjustmentParams {
        AdjustmentParams(
            saturation: params.saturation,
            brightness: params.brightness,
            contrast: params.contrast,
            highlights: params.highlights,
            shadows: params.shadows,
            blacks: params.blacks,
            whites: params.whites,
            warmth: params.warmth,
            vibrance: params.vibrance,
            hue: params.hue,
            sharpness: params.sharpness,
            gaussianBlurRadius: params.gaussianBlurRadius,
            vignetteIntensity: params.vignetteIntensity,
            bloomIntensity: params.bloomIntensity,
            grainIntensity: params.grainIntensity,
            fadeIntensity: params.fadeIntensity,
            chromaticAberrationIntensity: params.chromaticAberrationIntensity
        )
    }
}
