// エディタの画像要素ごとの描画のセッションを、要素のインスタンスで引き当てる管理役。

import UIKit

/// エディタで表示・編集する画像要素の、描画のセッションの管理役。`EditorViewModel` が1つ持ち、寿命はエディタと同じ。
///
/// 中間段階として、セッションはまだ要素が持ち、ここは要素のセッションを返すだけにする（所有の移動は第21回）。
/// 受け取る側の入口は、ここから画像を受け取る。状態を変える側（編集中の切り替え・キャッシュの書き込み・失効・メモリ警告）も、
/// 第19回からここを通す。画像の差し替え・復元・初期値への戻しの失効も、第20回から履歴イベントの範囲でここを通す。
/// 保存は受付で元画像だけをここから受け取る。保存用の複製はここを通さず、保存の範囲（`SaveProjectSnapshot`）で扱う（第18回）。
/// 要素は ID ではなくインスタンスで識別する（保存用の複製は、元の要素と同じ ID を持つため）。
@MainActor
final class ImageRenderSessionStore: ImageRenderSessionReading, ImageRenderSessionControlling {
    // MARK: - 読み取り

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

    // MARK: - 状態の変更

    func startEditing(_ element: ImageElement) {
        session(of: element).startEditing()
    }

    func endEditing(_ element: ImageElement) {
        session(of: element).endEditing()
    }

    func invalidate(_ scope: ImageRenderCache.Invalidation, of element: ImageElement) {
        session(of: element).invalidate(scope)
    }

    func invalidateForSourceChange(of element: ImageElement) {
        session(of: element).invalidateForSourceChange()
    }

    func storeRenderedImage(_ image: UIImage?, of element: ImageElement) {
        session(of: element).renderedImage = image
    }

    func fullQualityImage(of element: ImageElement) async -> UIImage? {
        await session(of: element).fullQualityImageAsync(of: element)
    }

    // MARK: - 観察（テスト）

    // Protocol には含めない。テストは、注入した具体型のこのインスタンスで観察する（コードと同じ持ち主を見るため）。

    /// 表示画像のキャッシュを見るだけで、無ければ作らない。
    func cachedRenderedImage(of element: ImageElement) -> UIImage? {
        session(of: element).renderedImage
    }

    /// 即時プレビュー。プロキシとプレビュー元画像を取得・生成してキャッシュする。
    func instantPreview(of element: ImageElement) -> UIImage? {
        session(of: element).instantPreview(of: element)
    }

    /// フル品質の加工を同期で行う（表示画像のキャッシュは使わず、元画像のキャッシュは使う）。
    func filteredImage(of element: ImageElement) -> UIImage? {
        session(of: element).filteredImage(of: element)
    }

    /// 要素のインスタンスごとのセッション。今は要素が持つものを返す。
    private func session(of element: ImageElement) -> ImageRenderSession {
        element.renderSession
    }
}
