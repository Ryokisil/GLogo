
// 画像インポートに必要な周辺情報をまとめるコンテキスト。
// 既存要素数からインポート順を決め、キャンバスサイズやビューポートサイズで初期配置を決める。
// assetIdentifierはメタデータ参照や後続処理のために保持する。

import UIKit

// MARK: - Image Import Context
struct ImageImportContext {
    let existingImageCount: Int
    let viewportSize: CGSize
    let canvasSize: CGSize?
    let assetIdentifier: String?
}
