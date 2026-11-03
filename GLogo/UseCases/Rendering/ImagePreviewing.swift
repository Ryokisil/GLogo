// 描画サービスの境界と、復元時に描画依存を渡すためのキーを定義する。

import UIKit

/// 同期描画と非同期描画から共有できる、プレビュー・フィルタ適用の契約。
/// 可変状態の同期は実装側が担い、参照同一性はキャッシュ解放の重複排除に使う。
protocol ImagePreviewing: AnyObject, Sendable {
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

extension CodingUserInfoKey {
    /// 子Decoderへ渡す実行時の描画依存。永続化する画像属性ではない。
    static let imagePreviewService = CodingUserInfoKey(rawValue: "GLogo.imagePreviewService")!
}
