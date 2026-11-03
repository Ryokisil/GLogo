// 再描画の予約と完了順を、時間待ちに依存せず制御するテスト用部品。

import UIKit
import XCTest
@testable import GLogo

@MainActor
final class ManualImageRenderScheduler: RenderScheduling {
    var pending: (() -> Void)?

    func schedule(_ block: @escaping () -> Void) { pending = block }
    func cancel() { pending = nil }

    func runPending() {
        let block = pending
        pending = nil
        block?()
    }
}

/// 実描画の代わりに継続を保持し、新旧要求の完了順を任意に入れ替える。
@MainActor
final class ControlledImageRenderer {
    private var continuations: [Int: CheckedContinuation<UIImage?, Never>] = [:]
    var onStart: (() -> Void)?
    var onReturn: (() -> Void)?
    private var nextID = 0

    func render(_ image: ImageElement) async -> UIImage? {
        let id = nextID
        nextID += 1
        let result = await withCheckedContinuation { continuation in
            continuations[id] = continuation
            onStart?()
        }
        onReturn?()
        return result
    }

    func finish(_ id: Int, with image: UIImage?) {
        guard let continuation = continuations.removeValue(forKey: id) else {
            XCTFail("未開始または完了済みの描画要求: \(id)")
            return
        }
        continuation.resume(returning: image)
    }
}
