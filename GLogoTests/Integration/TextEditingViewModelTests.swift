// テキスト編集の選択境界、変更通知と共通履歴への接続を検証する。

import Combine
import UIKit
import XCTest
@testable import GLogo

final class TextEditingViewModelTests: XCTestCase {
    @MainActor
    private func makeContext() -> (EditorViewModel, TextEditingViewModel, TextElement) {
        let text = TextElement(text: "Sample")
        let project = LogoProject()
        project.addElement(text)
        let editor = EditorViewModel(project: project)
        editor.selectElement(text)
        let viewModel = TextEditingViewModel(
            editor: editor.textEdits,
            selection: editor.$selectedElement.eraseToAnyPublisher()
        )
        return (editor, viewModel, text)
    }

    @MainActor
    func test_selection_nonText_clearsImmediately() {
        let (editor, viewModel, text) = makeContext()
        XCTAssertTrue(viewModel.textElement === text)

        let shape = ShapeElement(shapeType: .rectangle)
        editor.addElement(shape)
        XCTAssertNil(viewModel.textElement)
        let historyCount = editor.getHistoryDescriptions().count
        viewModel.updateText("Ignored")
        viewModel.beginTextFontSizeEditing()
        viewModel.previewTextFontSize(72)
        viewModel.commitTextFontSizeEditing()
        XCTAssertEqual(editor.getHistoryDescriptions().count, historyCount)
        XCTAssertEqual(text.text, "Sample")
        XCTAssertEqual(text.fontSize, 36)

        editor.selectElement(text)
        XCTAssertTrue(viewModel.textElement === text)
        editor.clearSelection()
        XCTAssertNil(viewModel.textElement)
    }

    @MainActor
    func test_selection_changed_discardsAllStartValues() {
        let (editor, viewModel, first) = makeContext()
        let second = TextElement(text: "Second")
        second.fontSize = 80
        second.lineSpacing = 4
        second.letterSpacing = 6
        for text in [first, second] {
            text.effects = [ShadowEffect(), StrokeEffect(), GlowEffect(), GradientFillEffect()]
        }
        (second.effects[0] as? ShadowEffect)?.blurRadius = 30
        (second.effects[1] as? StrokeEffect)?.width = 20
        (second.effects[2] as? GlowEffect)?.radius = 40
        (second.effects[3] as? GradientFillEffect)?.angle = 120
        (second.effects[3] as? GradientFillEffect)?.opacity = 0.3
        editor.addElement(second)

        let edits: [(String, () -> Void, () -> Void)] = [
            ("font", viewModel.beginTextFontSizeEditing, viewModel.commitTextFontSizeEditing),
            ("line", viewModel.beginTextLineSpacingEditing, viewModel.commitTextLineSpacingEditing),
            ("letter", viewModel.beginTextLetterSpacingEditing, viewModel.commitTextLetterSpacingEditing),
            ("shadow", { viewModel.beginShadowEffectEditing(atIndex: 0) }, { viewModel.commitShadowEffectEditing(atIndex: 0) }),
            ("stroke", { viewModel.beginStrokeEffectEditing(atIndex: 1) }, { viewModel.commitStrokeEffectEditing(atIndex: 1) }),
            ("glow", { viewModel.beginGlowEffectEditing(atIndex: 2) }, { viewModel.commitGlowEffectEditing(atIndex: 2) }),
            ("angle", { viewModel.beginGradientFillEffectEditing(atIndex: 3) }, { viewModel.commitGradientFillEffectEditing(atIndex: 3) }),
            ("opacity", { viewModel.beginGradientFillOpacityEditing(atIndex: 3) }, { viewModel.commitGradientFillOpacityEditing(atIndex: 3) })
        ]

        for (name, begin, commit) in edits {
            editor.selectElement(first)
            begin()
            let count = editor.getHistoryDescriptions().count
            // RunLoop を進めず確定し、選択直後に旧要素の開始値を使わないことを確認する。
            editor.selectElement(second)
            commit()
            XCTAssertEqual(editor.getHistoryDescriptions().count, count, name)
        }
        XCTAssertEqual(second.fontSize, 80)
    }

    @MainActor
    func test_selection_cleared_discardsPreviousGesture() {
        let (editor, viewModel, text) = makeContext()
        viewModel.beginTextFontSizeEditing()
        viewModel.previewTextFontSize(72)
        editor.clearSelection()
        editor.selectElement(text)
        viewModel.commitTextFontSizeEditing()

        XCTAssertFalse(editor.canUndo)
        XCTAssertEqual(text.fontSize, 72)
    }

    @MainActor
    func test_previewAndHistory_notifyTextPanel() {
        let (editor, viewModel, text) = makeContext()
        var notifications = 0
        let observation = viewModel.objectWillChange.sink { notifications += 1 }

        viewModel.beginTextFontSizeEditing()
        viewModel.previewTextFontSize(60)
        XCTAssertGreaterThan(notifications, 0)
        XCTAssertTrue(editor.isProjectModified)
        XCTAssertTrue(viewModel.textElement === text)
        XCTAssertFalse(editor.canUndo)
        viewModel.commitTextFontSizeEditing()
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)

        notifications = 0
        editor.undo()
        XCTAssertGreaterThan(notifications, 0)
        XCTAssertEqual(viewModel.textElement?.fontSize, 36)

        notifications = 0
        editor.redo()
        XCTAssertGreaterThan(notifications, 0)
        XCTAssertEqual(viewModel.textElement?.fontSize, 60)
        withExtendedLifetime(observation) {}
    }

    @MainActor
    func test_commit_noChanges_doesNotRecordHistory() {
        let (editor, viewModel, text) = makeContext()
        viewModel.beginTextFontSizeEditing()
        viewModel.previewTextFontSize(text.fontSize)
        viewModel.commitTextFontSizeEditing()
        viewModel.commitTextFontSizeEditing()
        viewModel.updateText(text.text)
        viewModel.updateTextColor(text.textColor)
        viewModel.updateFont(name: text.fontName, size: text.fontSize)

        XCTAssertFalse(editor.canUndo)
        XCTAssertFalse(editor.isProjectModified)
    }

    @MainActor
    func test_gradientEditing_preservesUndoRedo() throws {
        let (editor, viewModel, text) = makeContext()
        let gradient = GradientFillEffect()
        text.effects = [gradient]
        let originalAngle = gradient.angle
        let originalOpacity = gradient.opacity

        viewModel.beginGradientFillEffectEditing(atIndex: 0)
        viewModel.updateGradientFillAngle(atIndex: 0, angle: 90)
        viewModel.updateGradientFillAngle(atIndex: 0, angle: 135)
        XCTAssertFalse(editor.canUndo)
        viewModel.commitGradientFillEffectEditing(atIndex: 0)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)

        viewModel.beginGradientFillOpacityEditing(atIndex: 0)
        viewModel.updateGradientFillOpacity(atIndex: 0, opacity: 0.7)
        viewModel.updateGradientFillOpacity(atIndex: 0, opacity: 0.3)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        viewModel.commitGradientFillOpacityEditing(atIndex: 0)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 2)

        editor.undo()
        XCTAssertEqual(gradient.opacity, originalOpacity)
        editor.undo()
        XCTAssertEqual(gradient.angle, originalAngle)
        editor.redo()
        editor.redo()
        XCTAssertEqual(gradient.angle, 135)
        XCTAssertEqual(gradient.opacity, 0.3)
        XCTAssertTrue(try XCTUnwrap(viewModel.textElement?.effects.first) === gradient)
    }

    @MainActor
    func test_immediateEdits_useSharedHistory() {
        let (editor, viewModel, text) = makeContext()
        let originalColor = text.textColor
        viewModel.updateText("Changed")
        viewModel.updateTextColor(.red)
        viewModel.updateFont(name: "HelveticaNeue-Bold", size: 50)
        XCTAssertEqual(editor.getHistoryDescriptions().count, 3)

        editor.undo()
        XCTAssertEqual(text.fontSize, 36)
        editor.undo()
        XCTAssertTrue(text.textColor.isEqual(originalColor))
        editor.undo()
        XCTAssertEqual(text.text, "Sample")
        editor.redo()
        XCTAssertEqual(viewModel.textElement?.text, "Changed")
    }

    @MainActor
    func test_gradientColor_preservesHistoryAndOtherEffect() {
        let (editor, viewModel, text) = makeContext()
        let untouched = GradientFillEffect(startColor: .black, endColor: .white)
        let gradient = GradientFillEffect(startColor: .red, endColor: .blue)
        text.effects = [untouched, gradient]

        viewModel.updateGradientFillColor(atIndex: 1, startColor: .green, endColor: .yellow)
        XCTAssertTrue(gradient.startColor.isEqual(UIColor.green))
        XCTAssertTrue(gradient.endColor.isEqual(UIColor.yellow))
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
        XCTAssertTrue(editor.isProjectModified)
        editor.undo()
        XCTAssertTrue(gradient.startColor.isEqual(UIColor.red))
        XCTAssertTrue(gradient.endColor.isEqual(UIColor.blue))
        editor.redo()
        XCTAssertTrue(gradient.startColor.isEqual(UIColor.green))
        XCTAssertTrue(gradient.endColor.isEqual(UIColor.yellow))
        XCTAssertTrue(untouched.startColor.isEqual(UIColor.black))
        XCTAssertTrue(untouched.endColor.isEqual(UIColor.white))
        XCTAssertTrue(viewModel.textElement === text)
    }

    @MainActor
    func test_gradientImmediateCommit_preservesUndoRedo() {
        for editsAngle in [true, false] {
            let (editor, viewModel, text) = makeContext()
            let gradient = GradientFillEffect(angle: 60, opacity: 0.7)
            text.effects = [gradient]

            // スライダーの begin を通らないリセット操作にも独立した履歴が必要。
            if editsAngle {
                viewModel.commitGradientFillAngle(atIndex: 0, angle: 0)
            } else {
                viewModel.commitGradientFillOpacity(atIndex: 0, opacity: 1)
            }
            XCTAssertEqual(gradient.angle, editsAngle ? 0 : 60)
            XCTAssertEqual(gradient.opacity, editsAngle ? 0.7 : 1)
            XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
            editor.undo()
            XCTAssertEqual(gradient.angle, 60)
            XCTAssertEqual(gradient.opacity, 0.7)
            XCTAssertFalse(editor.canUndo)
            editor.redo()
            XCTAssertEqual(gradient.angle, editsAngle ? 0 : 60)
            XCTAssertEqual(gradient.opacity, editsAngle ? 0.7 : 1)
            XCTAssertFalse(editor.canRedo)
        }
    }

    @MainActor
    func test_spacingImmediateEdit_preservesUndoRedo() {
        for editsLine in [true, false] {
            let (editor, viewModel, text) = makeContext()
            text.lineSpacing = 2
            text.letterSpacing = 3
            if editsLine {
                viewModel.updateLineSpacing(5)
            } else {
                viewModel.updateLetterSpacing(7)
            }
            XCTAssertEqual(text.lineSpacing, editsLine ? 5 : 2)
            XCTAssertEqual(text.letterSpacing, editsLine ? 3 : 7)
            XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
            editor.undo()
            XCTAssertEqual(text.lineSpacing, 2)
            XCTAssertEqual(text.letterSpacing, 3)
            editor.redo()
            XCTAssertEqual(text.lineSpacing, editsLine ? 5 : 2)
            XCTAssertEqual(text.letterSpacing, editsLine ? 3 : 7)
            XCTAssertTrue(viewModel.textElement === text)
        }
    }

    @MainActor
    func test_immediateEffects_unchangedValuesKeepRedo() {
        let (editor, viewModel, text) = makeContext()
        let gradient = GradientFillEffect()
        text.effects = [gradient]
        viewModel.updateGradientFillColor(atIndex: 0, startColor: .green, endColor: .yellow)
        editor.undo()

        // 同値操作で空のイベントを追加し、Redo の枝を消さない。
        viewModel.updateGradientFillColor(atIndex: 0, startColor: gradient.startColor, endColor: gradient.endColor)
        viewModel.commitGradientFillAngle(atIndex: 0, angle: gradient.angle)
        viewModel.commitGradientFillOpacity(atIndex: 0, opacity: gradient.opacity)
        viewModel.updateLineSpacing(text.lineSpacing)
        viewModel.updateLetterSpacing(text.letterSpacing)
        XCTAssertFalse(editor.canUndo)
        XCTAssertTrue(editor.canRedo)
        editor.redo()
        XCTAssertTrue(gradient.startColor.isEqual(UIColor.green))
        XCTAssertTrue(gradient.endColor.isEqual(UIColor.yellow))
        XCTAssertEqual(editor.getHistoryDescriptions().count, 1)
    }

    @MainActor
    func test_immediateEffects_invalidTargetDoesNotChangeHistory() {
        let (editor, viewModel, text) = makeContext()
        let gradient = GradientFillEffect(angle: 45, opacity: 0.6)
        text.effects = [ShadowEffect(), gradient]
        for index in [0, text.effects.count] {
            viewModel.updateGradientFillColor(atIndex: index, startColor: .green, endColor: .yellow)
            viewModel.commitGradientFillAngle(atIndex: index, angle: 0)
            viewModel.commitGradientFillOpacity(atIndex: index, opacity: 1)
        }
        editor.clearSelection()
        viewModel.updateGradientFillColor(atIndex: 1, startColor: .green, endColor: .yellow)
        viewModel.commitGradientFillAngle(atIndex: 1, angle: 0)
        viewModel.commitGradientFillOpacity(atIndex: 1, opacity: 1)
        viewModel.updateLineSpacing(10)
        viewModel.updateLetterSpacing(10)
        XCTAssertEqual(gradient.angle, 45)
        XCTAssertEqual(gradient.opacity, 0.6)
        XCTAssertEqual(text.lineSpacing, 1)
        XCTAssertEqual(text.letterSpacing, 0)
        XCTAssertFalse(editor.canUndo)
        XCTAssertFalse(editor.isProjectModified)
    }

    @MainActor
    func test_childLifetime_doesNotRetainOwners() {
        var editor: EditorViewModel? = EditorViewModel()
        var parent: ElementViewModel? = ElementViewModel(editorViewModel: editor!)
        let child = parent!.textEditing
        weak var weakEditor = editor
        weak var weakParent = parent

        parent = nil
        editor = nil

        XCTAssertNil(weakParent)
        XCTAssertNil(weakEditor)
        withExtendedLifetime(child) {}
    }

    @MainActor
    func test_parentReleased_releasesTextEditing() {
        let editor = EditorViewModel()
        var parent: ElementViewModel? = ElementViewModel(editorViewModel: editor)
        weak var child = parent?.textEditing
        parent = nil

        XCTAssertNil(child)
        editor.addTextElement(position: .zero)
        XCTAssertNil(child)
    }
}
