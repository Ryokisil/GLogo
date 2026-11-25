// エディタの画像要素の、描画のセッションの状態を変える側の境界を定義する。

import UIKit

/// 編集中の切り替え・キャッシュの失効と書き込み・確定のフル品質の加工を、エディタの管理役へ求める境界。
///
/// 読み取り用の `ImageRenderSessionReading` と同じ管理役のインスタンスが実装する（所有を移したあとも状態が分かれないようにするため）。
/// View には渡さず、エディタ・編集パネル・履歴・描画の更新・メモリ警告の解放が使う。要素はインスタンスで識別する。
/// セッションは管理役が要素ごとに作って持つ（第21回）。要素が解放されたあとのセッションは、`reclaimReleasedSessions()` で捨てる。
@MainActor
protocol ImageRenderSessionControlling: AnyObject {
    /// 編集中にし、表示画像のキャッシュを消す（以後の描画は即時プレビューを使う）。
    func startEditing(_ element: ImageElement)

    /// 編集中を終える。キャッシュとセッションは消さない。
    func endEditing(_ element: ImageElement)

    /// 指定した範囲のキャッシュを消す。共有の描画サービスのキャッシュは消さない。
    func invalidate(_ scope: ImageRenderCache.Invalidation, of element: ImageElement)

    /// 画像ソースの変更（差し替え・復元）のあとで、要素の4つのキャッシュと、要素の描画サービスの共有のキャッシュを消す。
    func invalidateForSourceChange(of element: ImageElement)

    /// 確定した表示画像をキャッシュに書き込む。採用するかの判定は、呼び出し側が先に行う。
    func storeRenderedImage(_ image: UIImage?, of element: ImageElement)

    /// フル品質の加工を非同期で行い、画像を返すだけにする。
    /// 表示画像のキャッシュへの書き込みと編集の終了は、結果を採用すると判定した呼び出し側が行う
    /// （元画像が未取得なら、取得した元画像はここでキャッシュに入る）。
    func fullQualityImage(of element: ImageElement) async -> UIImage?

    /// 解放された要素のセッションを、キャッシュの画像ごと捨てる。生きている要素のセッションには触れない。
    /// 履歴の操作（適用・Undo・Redo・全消去）の最後と、メモリ警告の解放の最初に呼ぶ。非同期の処理が要素を持っていた場合は、
    /// 処理が終わって要素が解放されても、次にここが呼ばれるまでセッションが残る（時間の上限はない）。
    func reclaimReleasedSessions()

    // MARK: - メモリ警告の解放の判定（取得・生成・回収をしない）

    /// セッションを持つ、生きている要素（プロジェクトにない要素も含む）。順序は決まっていない。
    /// メモリ警告の解放が、履歴や非同期の処理だけが持つ要素の分も消すために使う（第22回）。
    var registeredElements: [ImageElement] { get }

    /// 要素の元画像がキャッシュにあるか。元画像を取得せず、セッションがなければ作らずに false を返す。
    /// 元画像がないまま取れたプロキシは、外部のファイルから読んだものかもしれないため、解放の範囲の判定に使う。
    func hasCachedOriginalImage(of element: ImageElement) -> Bool
}

/// 読み取りと状態の変更の両方を使う側（エディタ・編集パネル・メモリ警告の解放）が受け取る管理役。
/// 1つのインスタンスで両方を担う。View へは読み取り用（`ImageRenderSessionReading`）だけを渡す。
typealias ImageRenderSessionManaging = ImageRenderSessionReading & ImageRenderSessionControlling
