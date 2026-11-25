// 図形の各確定操作が正しいイベントと対象を渡し、変更を取り消せることを検証する。

import UIKit
import XCTest
@testable import GLogo

final class ShapeEditUseCaseTests: XCTestCase {
    @MainActor
    func test_shapeChanges_applyAndRevert() throws {
        let changes: [(String, (ShapeEditUseCase, ShapeElement) -> Void, (ShapeElement) -> Bool)] = [
            ("type", { $0.updateShapeType($1, newType: .circle) }, { $0.shapeType == .circle }),
            ("fill", { $0.updateShapeFillColor($1, newColor: .red) }, { $0.fillColor.isEqual(UIColor.red) }),
            ("fillMode", { $0.updateShapeFillMode($1, newMode: .gradient) }, { $0.fillMode == .gradient }),
            ("stroke", { $0.updateShapeStrokeColor($1, newColor: .blue) }, { $0.strokeColor.isEqual(UIColor.blue) }),
            ("strokeWidth", { $0.updateShapeStrokeWidth($1, newWidth: 8) }, { $0.strokeWidth == 8 }),
            ("strokeMode", { $0.updateShapeStrokeMode($1, newMode: .none) }, { $0.strokeMode == .none }),
            ("radius", { $0.updateShapeCornerRadius($1, newRadius: 30) }, { $0.cornerRadius == 30 }),
            ("sides", { $0.updateShapeSides($1, newSides: 7) }, { $0.sides == 7 }),
            ("gradient", { useCase, shape in
                useCase.updateShapeGradientColors(
                    shape, oldStartColor: shape.gradientStartColor, newStartColor: .red,
                    oldEndColor: shape.gradientEndColor, newEndColor: .green
                )
            }, { $0.gradientStartColor.isEqual(UIColor.red) && $0.gradientEndColor.isEqual(UIColor.green) }),
            ("angle", { $0.updateShapeGradientAngle($1, newAngle: 135) }, { $0.gradientAngle == 135 })
        ]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        for (name, change, hasExpectedValue) in changes {
            let target = ElementEditTargetSpy()
            let useCase = ShapeEditUseCase(target: target)
            let shape = ShapeElement(shapeType: .rectangle)
            let project = LogoProject()
            project.addElement(shape)
            let original = try encoder.encode(shape)

            change(useCase, shape)

            XCTAssertEqual(try encoder.encode(shape), original, name)
            XCTAssertEqual(target.events.count, 1, name)
            XCTAssertEqual(target.refreshedIDs, [shape.id], name)
            let event = try XCTUnwrap(target.events.first)
            event.apply(to: project)
            XCTAssertTrue(hasExpectedValue(shape), name)
            event.revert(from: project)
            XCTAssertEqual(try encoder.encode(shape), original, name)
        }
    }
}
