// 画像要素の生成で使う、入力データからの寸法の読み取りを担当する。

import UIKit

/// `UIImage` のデコードで寸法を読み取る。デコードした画像は保持しない。
struct ImageInitializationLoader: ImageInitializationLoading {
    func imageSize(imageData: Data) -> CGSize? {
        UIImage(data: imageData)?.size
    }
}
