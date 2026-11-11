// エディタの画像要素ごとの描画のセッションを、要素のインスタンスで引き当てる管理役。

import UIKit

/// エディタで表示・編集する画像要素の、描画のセッションの管理役。`EditorViewModel` が1つ持ち、寿命はエディタと同じ。
///
/// 第17回の中間段階として、セッションはまだ要素が持ち、ここは要素のセッションを返すだけにする（所有の移動は第19回）。
/// 受け取る側の入口は、ここから画像を受け取る。状態を変える側（編集中の切り替え・キャッシュの書き込み・失効）は、まだ要素を通す。
/// 保存は受付で元画像だけをここから受け取る。保存用の複製はここを通さず、保存の範囲（`SaveProjectSnapshot`）で扱う（第18回）。
/// 要素は ID ではなくインスタンスで識別する（保存用の複製は、元の要素と同じ ID を持つため）。
@MainActor
final class ImageRenderSessionStore: ImageRenderSessionReading {
    func originalImage(of element: ImageElement) -> UIImage? {
        session(of: element).originalImage(of: element)
    }

    func displayImage(of element: ImageElement) -> UIImage? {
        session(of: element).displayImage(of: element)
    }

    func drawingImage(of element: ImageElement) -> UIImage? {
        session(of: element).drawingImage(of: element)
    }

    func previewService(of element: ImageElement) -> any ImagePreviewing {
        session(of: element).previewService
    }

    /// 要素のインスタンスごとのセッション。今は要素が持つものを返す。
    private func session(of element: ImageElement) -> ImageRenderSession {
        element.renderSession
    }
}
