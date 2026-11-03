// 実機の Vision／Core ML に取消を要求してからの復帰時間と、取消後の再実行を測定する。

import XCTest
import UIKit
@testable import GLogo

final class DeviceCancellationPerformanceTests: XCTestCase {
    @MainActor
    func test_visionCancellation_responseAndRetry() throws {
        try requireDevice()
        let image = makeFixture()
        let processor = VisionBackgroundRemover()
        try measureCancellation(after: 5_000_000) { try await processor.removeBackground(from: image) }
    }

    @MainActor
    func test_coreMLCancellation_responseAndRetry() throws {
        try requireDevice()
        let pipeline = RealESRGANPipeline()
        XCTAssertTrue(pipeline.isAvailable, "実モデルを測定し、Lanczos へフォールバックしない")
        let request = ImageUpscaleRequest(sourceImage: makeFixture(), method: .realESRGAN,
                                          scaleFactor: .x2, appliesSharpening: false)
        try measureCancellation { try await pipeline.upscale(request).image }
    }

    @MainActor
    private func measureCancellation(
        after delay: UInt64 = 50_000_000,
        _ operation: @escaping @Sendable () async throws -> UIImage
    ) throws {
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        options.invocationOptions = [.manuallyStart, .manuallyStop]
        var didFinishBeforeCancellation = false
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()], options: options) {
            let finished = expectation(description: "実処理が取消から復帰")
            Task { @MainActor in
                let worker = Task { try await operation() }
                // 指定時間後に取消する。同期演算内部に到達したことまでは保証しない。
                try? await Task.sleep(nanoseconds: delay)
                startMeasuring()
                worker.cancel()
                let result = await worker.result
                stopMeasuring()
                switch result {
                case .failure(is CancellationError): break
                case .failure(let error): XCTFail("取消以外の失敗: \(error)")
                case .success: didFinishBeforeCancellation = true
                }
                finished.fulfill()
            }
            wait(for: [finished], timeout: 120)
        }
        // 速い端末で先に完了した結果を「取消が速かった」として採用しない。
        try XCTSkipIf(didFinishBeforeCancellation, "取消より先に完了した試行があるため、取消応答の測定値は不採用")

        // 復帰した時点で再実行し、共有モデルや画像パイプラインが使用可能なことを確かめる。
        let retried = expectation(description: "取消後に正常な画像を生成")
        Task { @MainActor in
            do {
                let image = try await operation()
                XCTAssertNotNil(image.cgImage)
                XCTAssertGreaterThan(image.size.width, 0)
                XCTAssertGreaterThan(image.size.height, 0)
            } catch {
                XCTFail("取消後の再実行失敗: \(error)")
            }
            retried.fulfill()
        }
        wait(for: [retried], timeout: 120)
    }

    private func requireDevice() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("実機の推論応答・物理メモリを測るテスト。Simulator の値は採用しない。")
        #endif
    }

    private func makeFixture() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 512, height: 512))
            UIColor.systemBlue.setFill()
            UIBezierPath(roundedRect: CGRect(x: 136, y: 230, width: 240, height: 220), cornerRadius: 35).fill()
            UIColor.systemOrange.setFill()
            UIBezierPath(ovalIn: CGRect(x: 156, y: 70, width: 200, height: 200)).fill()
            UIColor.black.setFill()
            UIBezierPath(ovalIn: CGRect(x: 205, y: 135, width: 25, height: 25)).fill()
            UIBezierPath(ovalIn: CGRect(x: 282, y: 135, width: 25, height: 25)).fill()
            UIBezierPath(roundedRect: CGRect(x: 216, y: 197, width: 80, height: 15), cornerRadius: 7).fill()
        }
    }
}
