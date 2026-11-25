// 編集履歴に積む1操作（適用と取り消し）の境界を定義する。

import Foundation

/// 編集の適用と取り消しを1組で表す履歴の単位。
/// 履歴は Undo／Redo のためにメモリ上だけで保持し、保存しないため Codable にしない。
///
/// 画像の描画キャッシュは、apply／revert の中では消さない。イベントは失効させる範囲を返し、
/// 履歴が適用・巻き戻しの直後に、エディタの管理役で消す（第19回）。
protocol EditorEvent {
    /// イベントを適用するメソッド
    func apply(to project: LogoProject)

    /// イベントを元に戻すメソッド
    func revert(from project: LogoProject)

    /// イベントの説明
    var description: String { get }

    /// 適用（Redo を含む）の直後に失効させる描画キャッシュ。
    /// 画像の見た目を変えるイベントは必ず返す。既定の空のままだと、表示画像が古いまま残る。
    var renderInvalidationsAfterApply: [ImageRenderInvalidation] { get }

    /// 巻き戻し（Undo）の直後に失効させる描画キャッシュ。
    var renderInvalidationsAfterRevert: [ImageRenderInvalidation] { get }
}

extension EditorEvent {
    // 画像の見た目を変えないイベント（テキスト・図形・プロジェクト・要素の追加や変形・並び順）は、何も失効させない。

    var renderInvalidationsAfterApply: [ImageRenderInvalidation] { [] }

    var renderInvalidationsAfterRevert: [ImageRenderInvalidation] { [] }
}
