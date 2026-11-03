// 画像要素の生成・複製に必要な読み込みと、URL入力のメタデータ抽出を担当する。

import UIKit

/// 生成用の寸法と、URLから読んだ入力データ・メタデータを取得する。デコードしたUIImageは保持しない。
struct ImageInitializationLoader: ImageInitializationLoading {
    /// URLから読み込んだ入力と属性。Dataは再圧縮せず保持する。
    struct Content {
        let imageData: Data
        let metadata: ImageMetadata?
    }

    func imageSize(imageData: Data) -> CGSize? {
        UIImage(data: imageData)?.size
    }

    /// URLソースの複製は同期読み込みと、デコード成否に依存しない抽出を維持する。
    /// 表示時のResolverと異なり、既存契約ではファイルURLに限定していない。
    /// - Returns: 読み込み失敗時はnil。画像デコード失敗時もDataと抽出結果は返す。
    func load(url: URL) -> Content? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return Content(
            imageData: data,
            metadata: ImageMetadataManager.shared.extractMetadata(from: data)
        )
    }
}
