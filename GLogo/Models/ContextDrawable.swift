// 自分の値だけで描き込み先へ描ける要素（テキスト・図形）の、描画の入口。

import CoreGraphics

/// 自分の値だけで、描き込み先へ描ける要素。
///
/// 画像要素は採用しない。描く画像は、エディタの管理役や保存の範囲から受け取って `ImageElement.draw(in:image:)` に渡すため、
/// 画像を受け取らずに描く入口を持たせない（第21回で基底の `LogoElement.draw(in:)` を外した）。
/// 呼び出し側は型を確かめてから呼ぶので、採用を忘れた要素はコンパイルが通ったまま描かれなくなる。
/// キャンバスと保存の合成で、テキストと図形が描かれることは `TextShapeDrawingTests` が確かめる。
protocol ContextDrawable {
    func draw(in context: CGContext)
}
