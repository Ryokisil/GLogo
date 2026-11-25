//
//  ImagePreviewService.swift
//  GLogo
//
//  SDR／HDRの描画サービスを束ね、既定の共有依存と注入可能な描画入口を提供する。
//

import UIKit

/// SDR／HDRサービスを切り替えるファサード。
final class ImagePreviewService: ImagePreviewing {
    /// 要素数に応じてパイプラインとキャッシュを増やさないための既定サービス。
    /// 依存は不変なSendable参照として保持し、全要素向けの差し替え口は設けない。
    static let shared = ImagePreviewService()

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

    func releaseMemory() {
        sdrService.releaseMemory()
        hdrService.releaseMemory()
    }
}
