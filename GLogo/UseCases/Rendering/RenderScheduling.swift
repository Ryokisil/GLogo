// 再描画の予約を置換・取消する能力の境界を定義する。

import Foundation

/// 再描画予約を置換・取消できる能力。呼び出しは MainActor に限定する。
@MainActor
protocol RenderScheduling: AnyObject {
    func schedule(_ block: @escaping () -> Void)
    func cancel()
}
