// キャンバスと削除エフェクトで共通の、要素の描き方。画像要素は、エディタの管理役から受け取った画像で描く。

import UIKit

extension LogoElement {
    /// キャンバスに描くときの描き方。削除エフェクトのスナップショットも、描き方が分かれないようにここを使う。
    /// 画像要素は管理役から受け取った画像で描き、テキストと図形は要素自身の描画を使う。
    /// - Parameters:
    ///   - context: 描き込み先
    ///   - renderSessions: 画像要素の描く画像の受け取り先（エディタの管理役）
    @MainActor
    func drawOnCanvas(in context: CGContext, renderSessions: any ImageRenderSessionReading) {
        guard let imageElement = self as? ImageElement else {
            draw(in: context)
            return
        }
        imageElement.draw(in: context, image: renderSessions.drawingImage(of: imageElement))
    }
}
