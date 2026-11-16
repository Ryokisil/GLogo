// エディタの画像要素ごとの描画のセッションを、要素のインスタンスで引き当てる管理役。

import UIKit

/// エディタで表示・編集する画像要素の、描画のセッションの管理役。`EditorViewModel` が1つ持ち、寿命はエディタと同じ。
///
/// セッションは、要素ごとに最初に求められたときに要素の依存（取得先・描画サービス）で作り、表で持つ（第21回）。
/// 要素は弱く持ち、要素が解放されたあとのセッションは、回収の契機（`reclaimReleasedSessions()`）で捨てる。
/// 管理役が解放されると、持っていたセッションもキャッシュの画像ごと解放される。別の管理役とは状態を共有しない。
/// 受け取る側の入口・状態を変える側・履歴イベントが示す失効は、すべてここを通す（第17回〜第20回）。
/// 保存は受付で元画像だけをここから受け取る。保存用の複製はここに登録せず、保存の範囲（`SaveProjectSnapshot`）が扱う。
/// 要素は ID ではなくインスタンスで識別する（保存用の複製や Undo で戻る要素は、別のインスタンスでも同じ ID を持つことがあるため）。
@MainActor
final class ImageRenderSessionStore: ImageRenderSessionReading, ImageRenderSessionControlling {
    /// 要素1つ分のセッション。要素は弱く持ち、要素の寿命を延ばさない。
    private struct Entry {
        weak var element: ImageElement?
        let session: ImageRenderSession
    }

    /// 要素のインスタンスで引き当てる表。解放された要素の分は、回収の契機まで残る。
    private var entries: [ObjectIdentifier: Entry] = [:]

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

    /// 要素が持つ描画サービス。セッションは作らない。
    func previewService(of element: ImageElement) -> any ImagePreviewing {
        element.previewService
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

    func reclaimReleasedSessions() {
        entries = entries.filter { $0.value.element != nil }
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

    /// 表に残っているセッションの数（解放された要素の分も含む）。回収もセッションの生成もしない。
    var registeredSessionCount: Int {
        entries.count
    }

    /// 要素のセッションが表にあるか。回収もセッションの生成もしない。
    func hasSession(for element: ImageElement) -> Bool {
        entries[ObjectIdentifier(element)]?.element === element
    }

    // MARK: - 表

    /// 要素のインスタンスごとのセッション。無ければ要素の依存で作って表に入れる。
    private func session(of element: ImageElement) -> ImageRenderSession {
        let key = ObjectIdentifier(element)
        // 解放された要素の識別子が別のインスタンスに使い回されても、古いセッションを返さないよう、同じ要素かを確かめる。
        if let entry = entries[key], entry.element === element {
            return entry.session
        }
        let session = ImageRenderSession(sourceResolver: element.sourceResolver, previewService: element.previewService)
        entries[key] = Entry(element: element, session: session)
        return session
    }
}
