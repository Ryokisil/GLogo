// 編集履歴に積む1操作（適用と取り消し）の境界を定義する。

import Foundation

/// 編集の適用と取り消しを1組で表す履歴の単位。
/// 履歴は Undo／Redo のためにメモリ上だけで保持し、保存しないため Codable にしない。
protocol EditorEvent {
    /// イベントを適用するメソッド
    func apply(to project: LogoProject)

    /// イベントを元に戻すメソッド
    func revert(from project: LogoProject)

    /// イベントの説明
    var description: String { get }
}
