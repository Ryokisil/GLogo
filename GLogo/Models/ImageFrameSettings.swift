// 画像要素のフレーム表示と角丸の設定を、一組の値として表す。

import UIKit

/// フレームの表示・色・太さ・スタイルと、角丸の設定。
/// `ImageEditState` の一部として受け渡し、永続化しない。
struct ImageFrameSettings: Equatable {
    var isShown: Bool
    var color: UIColor
    var width: CGFloat
    var style: ImageFrameStyle
    var hasRoundedCorners: Bool
    var cornerRadius: CGFloat
}
