// 画像属性の複合イベントと、調整イベントの転送境界を検証する。

import UIKit
import XCTest
@testable import GLogo

final class ImageEditUseCaseTests: XCTestCase {
    private func makeImage() throws -> ImageElement {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }
        return ImageElement(imageData: try XCTUnwrap(image.pngData()))
    }

    @MainActor
    func test_frameAppearance_usesOneReversibleEvent() throws {
        let target = ElementEditTargetSpy()
        let useCase = ImageEditUseCase(target: target)
        let image = try makeImage()
        let project = LogoProject()
        project.addElement(image)
        useCase.updateImageFrameAppearance(
            image, oldShowFrame: false, newShowFrame: true,
            oldStyle: .simple, newStyle: .double, oldColor: .red, newColor: .blue
        )
        XCTAssertEqual(target.events.count, 1)
        XCTAssertEqual(target.refreshedIDs, [image.id])
        let event = try XCTUnwrap(target.events.first)
        event.apply(to: project)
        XCTAssertTrue(image.showFrame)
        XCTAssertEqual(image.frameStyle, .double)
        XCTAssertEqual(image.frameColor.rgbaHexString, UIColor.blue.rgbaHexString)
        event.revert(from: project)
        XCTAssertFalse(image.showFrame)
        XCTAssertEqual(image.frameStyle, .simple)
        XCTAssertEqual(image.frameColor.rgbaHexString, UIColor.red.rgbaHexString)
    }

    @MainActor
    func test_tintChange_restoresAbsentColor() throws {
        let target = ElementEditTargetSpy()
        let useCase = ImageEditUseCase(target: target)
        let image = try makeImage()
        let project = LogoProject()
        project.addElement(image)
        useCase.updateImageTintColor(image, oldColor: nil, newColor: .red, oldIntensity: 0, newIntensity: 0.7)
        let event = try XCTUnwrap(target.events.first)
        event.apply(to: project)
        XCTAssertEqual(image.tintColor?.rgbaHexString, UIColor.red.rgbaHexString)
        XCTAssertEqual(image.tintIntensity, 0.7)
        event.revert(from: project)
        XCTAssertNil(image.tintColor)
        XCTAssertEqual(image.tintIntensity, 0)
    }

    @MainActor
    func test_adjustmentEvent_keepsExplicitRefreshBoundary() throws {
        let target = ElementEditTargetSpy()
        let useCase = ImageEditUseCase(target: target)
        let image = try makeImage()
        useCase.applyEvent(ImageFrameWidthChangedEvent(elementId: image.id, oldWidth: 4, newWidth: 12))
        XCTAssertEqual(target.events.count, 1)
        XCTAssertTrue(target.refreshedIDs.isEmpty)
        XCTAssertTrue(target.previews.isEmpty)
        useCase.updateImageElement(image)
        XCTAssertTrue(target.previews.first === image)
        XCTAssertEqual(target.events.count, 1)
    }
}
