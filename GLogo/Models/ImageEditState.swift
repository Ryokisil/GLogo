// 画像要素の編集値（手動の調整値・フィルター・フレーム）を、一組の値として表す。

import UIKit

/// 画像要素の編集値30項目をまとめた値。
/// Revert・画像差し替えの Undo と複製で、項目を並べ直さずに受け渡すために使う。
/// メモリ上の受け渡し専用で永続化しない。保存形式は `ImageElement` の CodingKeys と初期スナップショットが正となる。
/// 編集値を追加したときは、ここ（または構成する値型）と `ImageElement.editState`・`applyEditState(_:)`、
/// 初期スナップショットとの変換を更新する。
struct ImageEditState: Equatable {
    /// 手動の調整値。トーンカーブ・ティント・背景ぼかしを含む
    var adjustments: ImageAdjustmentValues
    /// 適用中のフィルタープリセットのレシピ
    var filterRecipe: FilterRecipe?
    /// 適用中のフィルタープリセットの ID
    var filterPresetId: String?
    /// フレームと角丸の設定
    var frame: ImageFrameSettings
}
