// ジェスチャーで動かした種類の属性だけを、変形の履歴へ含める規則を検証する。

import XCTest
@testable import GLogo

final class ElementTransformUseCaseTests: XCTestCase {
    @MainActor
    func test_commitEvent_limitsToGestureKinds() throws {
        let element = makeElement()
        let start = ElementTransformState(element)
        element.position = CGPoint(x: 40, y: 20)
        element.size = CGSize(width: 150, height: 80)
        element.rotation = 0.5

        let event = try XCTUnwrap(
            ElementTransformUseCase().commitEvent(from: start, to: element, limitedTo: [.move, .rotate])
        )

        XCTAssertEqual(event.oldPosition, CGPoint(x: 10, y: 20))
        XCTAssertEqual(event.newPosition, CGPoint(x: 40, y: 20))
        XCTAssertNil(event.oldSize, "拡大縮小で動かしていないサイズは含めない")
        XCTAssertNil(event.newSize)
        XCTAssertEqual(try XCTUnwrap(event.oldRotation), 0.2, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(event.newRotation), 0.5, accuracy: 0.0001)
    }

    @MainActor
    func test_commitEvent_ignoresChangesOutsideKinds() {
        let element = makeElement()
        let start = ElementTransformState(element)
        element.size = CGSize(width: 150, height: 80)

        XCTAssertNil(
            ElementTransformUseCase().commitEvent(from: start, to: element, limitedTo: [.move]),
            "動かした種類の属性に変化がなければ履歴を作らない"
        )
    }

    /// 位置 (10, 20)・サイズ 100×80・回転 0.2 の図形
    @MainActor
    private func makeElement() -> ShapeElement {
        let element = ShapeElement(shapeType: .rectangle)
        element.position = CGPoint(x: 10, y: 20)
        element.size = CGSize(width: 100, height: 80)
        element.rotation = 0.2
        return element
    }
}
