// 画像要素の初期化に必要な読み込みと、入力形式ごとのメタデータ抽出を担当する。

import UIKit

/// 初期化用の寸法・入力データ・メタデータを取得し、デコードしたUIImageは保持しない。
struct ImageInitializationLoader {
    /// 初期化に使った入力と属性。Dataは再圧縮せず保持する。
    struct Content {
        let imageData: Data
        let imageSize: CGSize?
        let metadata: ImageMetadata?
    }

    func imageSize(imageData: Data) -> CGSize? {
        UIImage(data: imageData)?.size
    }

    func imageSize(fileName: String) -> CGSize? {
        UIImage(named: fileName)?.size
    }

    func imageSize(path: String) -> CGSize? {
        UIImage(contentsOfFile: path)?.size
    }

    /// 指定されたメタデータを優先し、未指定なら画像デコード成功時だけ抽出する。
    func load(imageData: Data, metadata: ImageMetadata?) -> Content {
        let size = imageSize(imageData: imageData)
        var resolvedMetadata = metadata
        if resolvedMetadata == nil, size != nil {
            resolvedMetadata = ImageMetadataManager.shared.extractMetadata(from: imageData)
        }
        return Content(imageData: imageData, imageSize: size, metadata: resolvedMetadata)
    }

    /// URL初期化は同期読み込みと、デコード成否に依存しない抽出を維持する。
    /// 表示時のResolverと異なり、既存契約ではファイルURLに限定していない。
    /// - Returns: 読み込み失敗時はnil。画像デコード失敗時もDataと抽出結果は返す。
    func load(url: URL) -> Content? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return Content(
            imageData: data,
            imageSize: imageSize(imageData: data),
            metadata: ImageMetadataManager.shared.extractMetadata(from: data)
        )
    }
}
