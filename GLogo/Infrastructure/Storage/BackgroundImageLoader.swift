// 背景画像を、アセットの背景のディレクトリ（なければアプリのバンドル）から読み込む。

import UIKit

/// 背景画像の取得の実装。AssetManager のキャッシュ・背景のディレクトリのファイル・バンドルの順に探す。
///
/// 第26回で Model（`BackgroundSettings`）から移した。式は移す前と同じにしている。
/// 最後の `UIImage(named:)` は、`AssetManager.loadImage` がすでにバンドルを探すため重複しているが、
/// 移すだけの回で式を変えないために残す（docs/architecture/README.md の「計画外の対応と残件」）。
struct BackgroundImageLoader: BackgroundImageLoading {
    func loadBackgroundImage(named name: String) -> UIImage? {
        AssetManager.shared.loadImage(named: name, type: .background) ?? UIImage(named: name)
    }
}
