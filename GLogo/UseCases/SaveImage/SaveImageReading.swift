// 保存1件の範囲から、選定・加工・合成が画像を受け取るための読み取りの境界を定義する。

import UIKit

/// 保存1件の範囲（`SaveProjectSnapshot`）が、自分の要素の画像を返す読み取りの境界。
///
/// 選定・加工・合成はバックグラウンドの保存処理から呼ぶため、MainActor にはしない。
/// エディタの管理役（`ImageRenderSessionReading`）とは別の境界にし、保存の処理へエディタの状態を持ち込まない。
/// 範囲に含まれない要素（エディタの要素・ほかの保存要求の要素）には nil を返す。
protocol SaveImageReading {
    /// 受付時に固定した元画像。選定が解像度の比較に使う。
    func originalImage(of element: ImageElement) -> UIImage?

    /// 元画像にフル品質で加工した画像。表示画像のキャッシュは使わず、呼ぶたびに加工する。
    func filteredImage(of element: ImageElement) -> UIImage?

    /// 描画用の画像。合成で加工済みの画像を得られなかった画像要素を描くときに使う（表示画像の加工を試し直す）。
    func drawingImage(of element: ImageElement) -> UIImage?

    /// 受付時に固定した背景画像。合成が背景を描くときに使い、読むたびに取得し直さない。
    /// 画像の背景でないとき・受付のときに取得できなかったときは nil。
    var backgroundImage: UIImage? { get }
}
