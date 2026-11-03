// 機能別 UseCase から編集セッションへ渡せる変更を定義する。

import Foundation

/// 履歴の所有者に対するプレビュー反映とイベント適用の境界。
@MainActor
protocol ElementEditApplying: AnyObject {
    /// 履歴を積まずに要素を反映し、選択と変更フラグを更新する。
    func updateSelectedElement(_ element: LogoElement)

    /// イベントを記録・適用し、対象が選択中の場合にだけ選択参照を更新する。
    func applyEventAndRefreshSelection(_ event: EditorEvent, elementId: UUID)

    /// イベントを記録・適用する。選択の通知は呼び出し元が必要な時点で行う。
    func applyEvent(_ event: EditorEvent)
}
