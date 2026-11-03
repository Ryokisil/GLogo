// AI・手動加工の結果を画像編集へ渡す境界を定義する。

import UIKit

/// 推論や画面状態を所有せず、加工結果を既存の履歴へ確定する能力。
@MainActor
protocol AIImageEditApplying: AnyObject {
    /// 対象が現在のプロジェクトに存在する場合だけ、要求開始時のトークンを返す。
    func imageEditToken(for element: ImageElement) -> ImageEditToken?
    func isImageEditCurrent(_ token: ImageEditToken, for element: ImageElement) -> Bool
    func applyManualBackgroundRemovalResult(_ image: UIImage, to element: ImageElement)
    func applyUpscaledImageResult(_ image: UIImage, to element: ImageElement)
    /// マスク変換または変更計画の生成ができなかった場合は false を返す。
    func applyAIBackgroundBlurMask(_ mask: UIImage, to element: ImageElement) -> Bool
    func applyBackgroundBlurMaskResult(_ data: Data?, to element: ImageElement)
    func removeBackgroundBlurMask(from element: ImageElement)
}
