// 画像要素の見た目の値を変える履歴イベントに共通の、描画キャッシュの失効を定義する。

import Foundation

/// 画像要素の見た目の値（調整値・ティント・背景ぼかし・フィルター・フレーム）だけを変える履歴イベント。
/// 適用・巻き戻しのどちらでも、その要素の表示画像（`.rendered`）だけを失効させる。
protocol ImageAppearanceEvent: EditorEvent {
    var elementId: UUID { get }
}

extension ImageAppearanceEvent {
    var renderInvalidationsAfterApply: [ImageRenderInvalidation] {
        [ImageRenderInvalidation(elementId: elementId, scope: .cache(.rendered))]
    }

    var renderInvalidationsAfterRevert: [ImageRenderInvalidation] {
        renderInvalidationsAfterApply
    }
}
