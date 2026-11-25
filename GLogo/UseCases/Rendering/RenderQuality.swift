// 描画の品質（軽量プレビューか、保存・最終描画か）を表す。

import Foundation

/// 描画サービスの境界で使う品質指定。
/// 実装側の `ToneCurveFilter.Quality` は互換のための別名で、同じ型を指す。
enum RenderQuality {
    /// 軽量プレビュー用
    case preview
    /// 保存・最終描画用
    case full
}
