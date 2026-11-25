// キャンセル済みの描画を計算せず、実行中の同期描画は終了を待って一度だけ復帰することを検証する。

import XCTest
import UIKit
@testable import GLogo

final class ImageRenderOperationTests: XCTestCase {
    func test_queuedCancellation_skipsRender() async {
        let queue = OperationQueue()
        queue.isSuspended = true
        let entered = expectation(description: "Task 開始")
        let task = Task {
            entered.fulfill()
            return await ImageRenderOperation.run(on: queue, lock: NSLock()) {
                XCTFail("取消済みの計算は実行しない")
                return UIImage()
            }
        }
        await fulfillment(of: [entered], timeout: 1)
        task.cancel()
        queue.isSuspended = false
        let result = await task.value
        XCTAssertNil(result)
    }

    func test_runningCancellation_waitsForSynchronousRender() async {
        let queue = OperationQueue()
        let started = expectation(description: "同期描画開始")
        let release = DispatchSemaphore(value: 0)
        let task = Task {
            await ImageRenderOperation.run(on: queue, lock: NSLock()) {
                started.fulfill()
                guard release.wait(timeout: .now() + 3) == .success else {
                    XCTFail("テストの描画解放が届かない")
                    return nil
                }
                return UIImage()
            }
        }
        await fulfillment(of: [started], timeout: 1)
        task.cancel()
        release.signal()
        let result = await task.value
        XCTAssertNil(result)
        // 同じキュー・パイプラインの次の要求は正常に実行できる。
        let expected = UIImage()
        let next = await ImageRenderOperation.run(on: queue, lock: NSLock()) { expected }
        XCTAssertTrue(next === expected)
    }

    func test_preCancelledPipelines_doNotStart() async {
        let image = UIImage()
        let request = ImageUpscaleRequest(sourceImage: image, method: .lanczos, scaleFactor: .x2, appliesSharpening: false)
        let operations: [@Sendable () async throws -> Void] = [
            { _ = try await VisionBackgroundRemover().removeBackground(from: image) },
            { _ = try await VisionBackgroundRemover().generateMask(from: image) },
            { _ = try await LanczosUpscalePipeline().upscale(request) },
            { _ = try await RealESRGANPipeline().upscale(request) },
            { _ = try await CoreMLUpscaler(configuration: .init(compiledModelName: "missing")).upscale(request) },
            { _ = try await ImageUpscaleUseCase().upscale(request) }
        ]
        for operation in operations {
            let task = Task {
                withUnsafeCurrentTask { $0?.cancel() }
                do {
                    try await operation()
                    XCTFail("キャンセル済み要求が成功した")
                } catch is CancellationError {
                } catch {
                    XCTFail("画像・モデルの解決より前にキャンセルする: \(error)")
                }
            }
            await task.value
        }
    }

    func test_tileCancellation_skipsRemainingTiles() async throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32), format: format)
            .image { $0.fill(CGRect(x: 0, y: 0, width: 32, height: 32)) }.cgImage)
        let task = Task {
            var rendered = 0
            let processor = UpscaleTileProcessor(tileSize: 16, modelScaleFactor: 1, outputScaleFactor: 1) { tile in
                rendered += 1
                withUnsafeCurrentTask { $0?.cancel() }
                return tile
            }
            do {
                _ = try processor.process(image: image)
                XCTFail("部分結果は返さない")
            } catch is CancellationError {
            } catch {
                XCTFail("\(error)")
            }
            XCTAssertEqual(rendered, 1, "4タイル中、残り3タイルの推論を省く")
        }
        await task.value
    }
}
