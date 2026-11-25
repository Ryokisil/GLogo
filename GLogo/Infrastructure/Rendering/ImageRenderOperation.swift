// Task のキャンセルを描画キューへ伝え、開始前の不要な画像計算を省く。

import Foundation
import UIKit

/// キューとパイプラインの排他は呼び出し側のものを使い、同時実行数を変えない。
enum ImageRenderOperation {
    static func run(
        on queue: OperationQueue,
        lock: NSLock,
        render: @escaping @Sendable () -> UIImage?
    ) async -> UIImage? {
        let cancellation = CancellationState()
        return await withTaskCancellationHandler {
            guard !Task.isCancelled else { return nil }
            return await withCheckedContinuation { continuation in
                // Operation 自体を取消すとこのブロックが走らず、継続が未再開になり得る。
                // 必ずキューから復帰し、計算の前後だけをキャンセル状態で分岐する。
                queue.addOperation {
                    let result: UIImage? = {
                        guard !cancellation.isCancelled else { return nil }
                        lock.lock()
                        defer { lock.unlock() }
                        guard !cancellation.isCancelled else { return nil }
                        return render()
                    }()
                    continuation.resume(returning: cancellation.isCancelled ? nil : result)
                }
            }
        } onCancel: {
            cancellation.cancel()
        }
    }

    /// Task と OperationQueue をまたぐ一方向の状態。全アクセスをロックで保護する。
    private final class CancellationState: @unchecked Sendable {
        private let lock = NSLock()
        private var cancelled = false

        var isCancelled: Bool {
            lock.lock()
            defer { lock.unlock() }
            return cancelled
        }

        func cancel() {
            lock.lock()
            defer { lock.unlock() }
            cancelled = true
        }
    }
}
