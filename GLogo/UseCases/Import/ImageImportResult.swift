import UIKit

// 画像インポートの結果を表すデータ。
// UseCaseが生成したImageElementと、呼び出し側で使う補助情報をまとめる。
// ViewModelはこの結果を用いて追加・選択・センタリングを行う。
struct ImageImportResult {
    let element: ImageElement
    let assetIdentifier: String?
}
