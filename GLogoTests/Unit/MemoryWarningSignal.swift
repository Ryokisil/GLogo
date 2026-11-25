// メモリ警告の処理の終わりを、エディタの既定の描画サービスの解放で知らせる偽物。
// 回収・寿命のテストで共有する（第21回は回収のテストの中にあった）。

import UIKit
import XCTest
@testable import GLogo

/// メモリ警告の処理の最後に解放される、エディタの既定の描画サービス。解放されたことを、待っている期待に知らせる。
/// 既定の描画サービスは、回収と要素のキャッシュの解放のあとで解放されるため、ここを待てば警告の処理は終わっている。
/// 解放は MainActor のタスクから呼ばれ、期待の設定はテストから行うため、期待だけを鍵で守る。
/// 期待は1回の警告ごとに設定し、満たしたら外す（ほかのエディタや後の警告で、同じ期待を二度満たさないため）。
final class MemoryWarningSignal: ImagePreviewing, @unchecked Sendable {
    private let lock = NSLock()
    private var released: XCTestExpectation?

    /// 次の解放で、この期待を満たす。
    func expectRelease(_ expectation: XCTestExpectation) {
        lock.withLock { released = expectation }
    }

    /// メモリ警告を送り、このサービスを既定に持つエディタの処理が終わるまで待つ。
    @MainActor
    func postWarningAndWait(in testCase: XCTestCase, timeout: TimeInterval = 2) async {
        let released = testCase.expectation(description: "メモリ警告の処理の終了")
        expectRelease(released)
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        await testCase.fulfillment(of: [released], timeout: timeout)
    }

    func releaseMemory() {
        let expectation = lock.withLock {
            defer { released = nil }
            return released
        }
        expectation?.fulfill()
    }

    func generatePreviewImage(editingImage: UIImage?, originalImage: UIImage?, mode: ImageRenderMode) -> UIImage? { nil }

    func instantPreview(baseImage: UIImage?, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) -> UIImage? {
        nil
    }

    func applyFilters(to image: UIImage, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) -> UIImage? {
        nil
    }

    func applyFiltersAsync(to image: UIImage, params: ImageFilterParams, quality: RenderQuality, mode: ImageRenderMode) async -> UIImage? {
        nil
    }

    func resetCache() {}
}
