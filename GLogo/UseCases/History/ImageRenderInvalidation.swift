// 履歴イベントが、適用・巻き戻しのあとで失効させる描画キャッシュの範囲を表す。

import Foundation

/// 履歴イベントが示す、画像要素の描画キャッシュの失効。
/// 履歴は適用・巻き戻しの直後に、そのときのプロジェクトで ID を要素のインスタンスへ解決し、エディタの管理役へ渡す
/// （管理役は ID ではなくインスタンスで識別するため）。要素が見つからなければ何もしない（イベント側の扱いと同じ）。
struct ImageRenderInvalidation: Equatable {
    let elementId: UUID
    let scope: ImageRenderCache.Invalidation
}
