// 画像加工の履歴適用後に、共通の選択と画面通知を同期する境界を定義する。

import Foundation

/// 画像差し替えとマスク変更で異なる選択方針を維持する編集適用先。
@MainActor
protocol ImageEditCommitting: ElementEditApplying {
    /// 同じ ID の別インスタンスや、削除済みの対象にはトークンを発行しない。
    func imageEditToken(for element: ImageElement) -> ImageEditToken?
    /// 全イベントの適用後に変更フラグと表示を更新する。
    /// selectsResult が false の場合、対象が選択中のときだけ選択参照を更新する。
    func applyImageEvents(_ events: [EditorEvent], elementId: UUID, selectsResult: Bool)
}
