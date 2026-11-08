// プロジェクトの復元で画像要素へ渡す実行時の依存と、その設定が欠けたときのエラーを定義する。

import Foundation

/// プロジェクトの復元で、画像要素へ渡す実行時の依存。保存データには含まれない。
/// `ProjectStorage` の読み込みは、これを必須の引数で受け取る。具体型は Composition Root で選んで渡す。
struct ProjectDecodingDependencies: Sendable {
    /// 画像要素の元画像・編集用画像の取得先。1回の読み込みで復元した画像要素が共有する
    let sourceResolver: any ImageSourceResolving
    /// 画像要素の描画サービス。要素間でキャッシュを共有するため、通常は共有インスタンスを渡す
    let previewService: any ImagePreviewing

    /// 依存を userInfo に設定した Decoder を作る。Decoder は読み込みごとに作り、並行に使い回さない。
    func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.userInfo[.imageSourceResolver] = sourceResolver
        decoder.userInfo[.imagePreviewService] = previewService
        return decoder
    }
}

/// 画像要素の復元に必要な実行時の依存が、Decoder の userInfo にない。
/// 依存の設定不足（注入忘れ）を、保存データの不正（`DecodingError`）と区別するための型。
struct MissingDecodingDependencyError: LocalizedError {
    /// 欠けていた userInfo のキー
    let key: CodingUserInfoKey

    var errorDescription: String? {
        "復元に必要な依存が Decoder の userInfo にない: \(key.rawValue)"
    }
}
