// テキストのイベント生成、無変更判定とプレビュー反映の境界を検証する。

import XCTest
@testable import GLogo

final class TextEditUseCaseTests: XCTestCase {
    @MainActor
    func test_contentChange_defersMutationUntilApply() throws {
        let target = ElementEditTargetSpy()
        let useCase = TextEditUseCase(target: target)
        let text = TextElement(text: "Before")
        let project = LogoProject()
        project.addElement(text)

        useCase.updateTextContent(text, newText: "After")

        XCTAssertEqual(text.text, "Before")
        XCTAssertEqual(target.events.count, 1)
        XCTAssertEqual(target.refreshedIDs, [text.id])
        let event = try XCTUnwrap(target.events.first)
        event.apply(to: project)
        XCTAssertEqual(text.text, "After")
        event.revert(from: project)
        XCTAssertEqual(text.text, "Before")
    }

    @MainActor
    func test_fontChange_previewApplied_preservesOldValue() throws {
        let target = ElementEditTargetSpy()
        let useCase = TextEditUseCase(target: target)
        let text = TextElement(text: "Sample")
        let originalFont = text.fontName
        let originalSize = text.fontSize
        let project = LogoProject()
        project.addElement(text)
        text.fontName = "HelveticaNeue-Bold"
        text.fontSize = 72

        useCase.updateFont(
            text, oldFontName: originalFont, newFontName: text.fontName,
            oldFontSize: originalSize, newFontSize: text.fontSize
        )

        XCTAssertEqual(target.events.count, 1)
        let event = try XCTUnwrap(target.events.first)
        event.revert(from: project)
        XCTAssertEqual(text.fontName, originalFont)
        XCTAssertEqual(text.fontSize, originalSize)
        event.apply(to: project)
        XCTAssertEqual(text.fontName, "HelveticaNeue-Bold")
        XCTAssertEqual(text.fontSize, 72)
    }

    @MainActor
    func test_unchangedValues_doNotEmitEvents() {
        let target = ElementEditTargetSpy()
        let useCase = TextEditUseCase(target: target)
        let text = TextElement(text: "Sample")
        useCase.updateFont(text, fontName: text.fontName, fontSize: text.fontSize)
        useCase.updateTextColor(text, newColor: text.textColor)
        useCase.updateTextLineSpacing(text, oldSpacing: 1, newSpacing: 1)
        useCase.updateTextLetterSpacing(text, oldSpacing: 2, newSpacing: 2)
        useCase.updateTextGradientFillEffect(text, effectIndex: 0, oldAngle: 45, newAngle: 45)
        useCase.updateTextGradientFillOpacity(text, effectIndex: 0, oldOpacity: 0.5, newOpacity: 0.5)
        XCTAssertTrue(target.events.isEmpty)
        XCTAssertTrue(target.refreshedIDs.isEmpty)
    }

    @MainActor
    func test_preview_doesNotEmitHistory() {
        let target = ElementEditTargetSpy()
        let useCase = TextEditUseCase(target: target)
        let text = TextElement(text: "Preview")
        useCase.updateTextElement(text)
        XCTAssertTrue(target.previews.first === text)
        XCTAssertTrue(target.events.isEmpty)
    }
}
