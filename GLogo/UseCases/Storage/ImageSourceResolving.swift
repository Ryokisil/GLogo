// 画像要素の参照から元画像・編集用画像を解決する境界と、復元時に取得先を渡すためのキーを定義する。

import UIKit

/// `ImageElement` が保持する画像参照から表示・編集用画像を解決するプロトコル
/// 復元では Decoder の userInfo で受け渡し、要素間やスレッド間で共有するため Sendable を求める。
protocol ImageSourceResolving: Sendable {
    /// 元画像を優先順位付きで解決する。
    /// - Parameters:
    ///   - imageData: 直接保持している画像データ
    ///   - fileName: アセット名
    ///   - url: 元画像URL
    ///   - path: 元画像ファイルパス
    /// - Returns: 解決した元画像。利用可能なソースがない場合は nil
    func resolveOriginalImage(
        imageData: Data?,
        fileName: String?,
        url: URL?,
        path: String?
    ) -> UIImage?

    /// 編集用プロキシを含めた画像を解決する。
    /// 元画像が取れるときは、そこから作る（縮小または元画像そのもの）。保存済みのプロキシのファイルを読むのは、元画像が取れないときだけ。
    /// メモリ警告の解放は、この前提で、元画像がキャッシュにあるデータの要素のプロキシを消してよいと判断する（第22回）。
    /// - Parameters:
    ///   - identifier: オリジナル画像の識別子
    ///   - fileName: アセット名
    ///   - originalPath: 元画像ファイルパス
    ///   - originalImageProvider: 元画像を必要時に提供するクロージャ
    ///   - proxyTargetLongSide: プロキシ生成時の長辺ピクセル
    ///   - highResThresholdMP: プロキシ生成を行う解像度しきい値
    /// - Returns: 編集に使用する画像。解決できない場合は nil
    func resolveEditingImage(
        identifier: String?,
        fileName: String?,
        originalPath: String?,
        originalImageProvider: () -> UIImage?,
        proxyTargetLongSide: CGFloat,
        highResThresholdMP: CGFloat
    ) -> UIImage?
}


extension CodingUserInfoKey {
    /// プロジェクト復元時の取得先。画像要素の復元に必須で、`ProjectDecodingDependencies.makeDecoder()` が設定する。
    /// 子Decoderにも渡されるが、保存データには含まれない。
    static let imageSourceResolver = CodingUserInfoKey(rawValue: "GLogo.imageSourceResolver")!
}
