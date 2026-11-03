// 保存受付時に MainActor で固定する入力の時間とメモリを、4K／8K・元画像キャッシュの有無で測定する。

import XCTest
import UIKit
@testable import GLogo

final class SaveSnapshotPerformanceTests: XCTestCase {
    @MainActor
    func test_snapshot4K_uncached() throws { try measureSnapshot(width: 3840, height: 2160, cached: false) }

    @MainActor
    func test_snapshot4K_cached() throws { try measureSnapshot(width: 3840, height: 2160, cached: true) }

    @MainActor
    func test_snapshot8K_uncached() throws { try measureSnapshot(width: 7680, height: 4320, cached: false) }

    @MainActor
    func test_snapshot8K_cached() throws { try measureSnapshot(width: 7680, height: 4320, cached: true) }

    @MainActor
    private func measureSnapshot(width: Int, height: Int, cached: Bool) throws {
        let data = try autoreleasepool {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            format.preferredRange = .standard
            let size = CGSize(width: width, height: height)
            let source = UIGraphicsImageRenderer(size: size, format: format).image { context in
                UIColor.darkGray.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                UIColor.orange.setFill()
                context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height / 2))
            }
            return try XCTUnwrap(source.jpegData(compressionQuality: 0.95))
        }
        let image = ImageElement(imageData: data)
        let project = LogoProject()
        project.addElement(image)
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        options.invocationOptions = [.manuallyStart, .manuallyStop]
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()], options: options) {
            autoreleasepool {
                // OS のファイルキャッシュを排除した測定ではなく、要素の元画像解決キャッシュの差を測る。
                image.handleMemoryWarning()
                if cached { _ = image.originalImage }
                startMeasuring()
                let snapshot = SaveProjectSnapshot(project: project)
                stopMeasuring()
                let copy = snapshot.project.elements.first as? ImageElement
                XCTAssertEqual(copy?.originalImage?.cgImage?.width, width)
                XCTAssertEqual(copy?.originalImage?.cgImage?.height, height)
            }
        }
    }
}
