//
//  HDRImagePreviewService.swift
//  GLogo
//
//  概要:
//  HDR専用のプレビュー生成・フィルタ適用サービスのスタブ。
//  将来のHDR対応時に実装を追加するエントリポイント。
//

import UIKit

/// HDR専用のプレビュー・フィルタ適用スタブ
final class HDRImagePreviewService: ImagePreviewing {

    /// プレビュー用ベースを生成（HDR未実装）
    /// - Parameters:
    ///   - editingImage: 編集用プロキシ
    ///   - originalImage: オリジナル画像
    /// - Returns: プレビューで使う画像
    func generatePreviewImage(editingImage: UIImage?, originalImage: UIImage?) -> UIImage? {
        fatalError("HDR未実装")
    }

    /// 即時プレビューを生成（HDR未実装）
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
        fatalError("HDR未実装")
    }

    /// フィルタ適用・同期（HDR未実装）
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
        fatalError("HDR未実装")
    }

    /// フィルタ適用・非同期（HDR未実装）
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
        fatalError("HDR未実装")
    }

    /// プレビューキャッシュをリセット（HDR未実装）
    func resetCache() {
        fatalError("HDR未実装")
    }
}
