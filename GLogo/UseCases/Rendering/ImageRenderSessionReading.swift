// エディタの入口（キャンバス・削除エフェクト・画像一覧・AI・編集画面・フィルターのサムネイル）が、画像要素の画像を受け取る口。

import UIKit

/// 画像要素の元画像・表示画像・キャンバスに描く画像と、描画サービスを返す。エディタの管理役（`ImageRenderSessionStore`）が実装する。
///
/// 受け取る側は、Model の取得・描画の API を使わず、ここから画像を受け取る。
/// 状態を変える操作（編集中の切り替え・キャッシュの書き込み・失効）は含めない。
/// 返す画像と、取得・加工・キャッシュの時点は、要素のセッション（`ImageRenderSession`）の同じ名前の処理と同じにする。
@MainActor
protocol ImageRenderSessionReading: AnyObject {
    /// 元画像。初めて求めたときに取得してキャッシュする。
    func originalImage(of element: ImageElement) -> UIImage?

    /// 表示画像。編集中は即時プレビュー（なければプロキシ、元画像の順）、それ以外はフル品質で加工してキャッシュする。
    func displayImage(of element: ImageElement) -> UIImage?

    /// キャンバスと削除エフェクトに描く画像。
    func drawingImage(of element: ImageElement) -> UIImage?

    /// 要素の描画サービス。フィルターのサムネイルの生成に使う。
    func previewService(of element: ImageElement) -> any ImagePreviewing
}
