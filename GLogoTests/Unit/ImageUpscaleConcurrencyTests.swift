// MainActor から共有した高画質化処理を複数タスクで利用できることを検証する。

import XCTest
import UIKit
@testable import GLogo

final class ImageUpscaleConcurrencyTests: XCTestCase {
    @MainActor
    func testSharedUseCaseKeepsConcurrentRequestResultsSeparate() async throws {
        let useCase = ImageUpscaleUseCase()
        let request2x = makeRequest(size: CGSize(width: 16, height: 12), scale: .x2)
        let request4x = makeRequest(size: CGSize(width: 10, height: 8), scale: .x4)

        async let first = useCase.upscale(request2x)
        async let second = useCase.upscale(request4x)
        let (result2x, result4x) = try await (first, second)

        XCTAssertEqual(result2x.image.size, CGSize(width: 32, height: 24))
        XCTAssertEqual(result4x.image.size, CGSize(width: 40, height: 32))
        XCTAssertEqual(result2x.appliedMethod, .lanczos)
        XCTAssertEqual(result4x.appliedMethod, .lanczos)
    }

    /// モデル未配置時も共有 actor を複数タスクから呼べ、各呼び出しへ失敗を返す。
    @MainActor
    func testSharedCoreMLUpscalerReportsMissingModelToConcurrentRequests() async {
        let modelName = "missing-model-\(UUID().uuidString)"
        let upscaler = CoreMLUpscaler(configuration: .init(compiledModelName: modelName))
        let request = makeRequest(size: CGSize(width: 8, height: 8), scale: .x2)
        let failureCount = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<2 {
                group.addTask {
                    do {
                        _ = try await upscaler.upscale(request)
                        return false
                    } catch ImageUpscaleError.modelNotFound(let name) {
                        return name == modelName
                    } catch {
                        return false
                    }
                }
            }
            var count = 0
            for await failedAsExpected in group where failedAsExpected {
                count += 1
            }
            return count
        }
        XCTAssertEqual(failureCount, 2)
    }

    private func makeRequest(size: CGSize, scale: ImageUpscaleScaleFactor) -> ImageUpscaleRequest {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return ImageUpscaleRequest(sourceImage: image, method: .lanczos,
                                   scaleFactor: scale, appliesSharpening: false)
    }
}
