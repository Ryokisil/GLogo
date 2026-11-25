// 画像要素ごとの描画資源と、操作に応じたキャッシュの無効化範囲を管理する。

import UIKit

/// 保存・複製・復元時に引き継がない実行時の保持領域。
/// 値型で保持先の共有を避けるが、UIImageは複製せず、並行アクセスの同期も行わない。
struct ImageRenderCache {
    var renderedImage: UIImage?
    var originalImage: UIImage?
    var proxyImage: UIImage?
    var previewBaseImage: UIImage?

    /// 元画像・プロキシの再取得や共有サービスの解放を必要以上に発生させない範囲。
    enum Invalidation {
        case rendered
        case adjustments
        case revert
        case all
    }

    /// 共有プレビューサービス側のキャッシュは呼び出し元が別途扱う。
    mutating func invalidate(_ scope: Invalidation) {
        switch scope {
        case .rendered:
            renderedImage = nil
        case .adjustments:
            renderedImage = nil
            previewBaseImage = nil
        case .revert:
            renderedImage = nil
            originalImage = nil
        case .all:
            renderedImage = nil
            originalImage = nil
            proxyImage = nil
            previewBaseImage = nil
        }
    }
}
