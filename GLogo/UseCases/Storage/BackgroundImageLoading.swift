// 背景設定のファイル名で背景画像を取得する境界を定義する。

import UIKit

/// 背景画像の取得。
///
/// キャンバスは描くたびに呼び、保存は受付のときに1回だけ呼んで固定する（どちらもメインスレッド）。
/// 取得できないときは nil を返し、呼ぶ側は背景画像なしで描く。
/// 取得する名前は `BackgroundSettings.imageNameToDraw` で決める（画像の背景のときだけ）。
protocol BackgroundImageLoading: Sendable {
    func loadBackgroundImage(named name: String) -> UIImage?
}
