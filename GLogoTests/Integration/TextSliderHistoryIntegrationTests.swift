//
//  TextSliderHistoryIntegrationTests.swift
//  GLogoTests
//
//  概要:
//  テキスト系スライダー（サイズ・行間・文字間隔）がドラッグ中はプレビューのみ、
//  指を離した時に履歴へ1件だけ確定されることを検証する結合テスト。
//

import XCTest
import UIKit
@testable import GLogo

/// テキストスライダー履歴の結合テスト
final class TextSliderHistoryIntegrationTests: XCTestCase {

    /// メインループを短時間回して Combine 通知を反映する
    /// - Parameters: なし
    /// - Returns: なし
    private func flushMainRunLoop() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }

    /// テスト用のVM一式を生成する
    /// - Parameters: なし
    /// - Returns: LogoProject, TextElement, EditorViewModel, ElementViewModel のタプル
    @MainActor
    private func makeTextEditingContext() -> (LogoProject, TextElement, EditorViewModel, ElementViewModel) {
        let project = LogoProject(name: "TextSliderHistory", canvasSize: CGSize(width: 1080, height: 1080))
        let textElement = TextElement(text: "Sample")
        project.addElement(textElement)

        let editorViewModel = EditorViewModel(project: project)
        let elementViewModel = ElementViewModel(editorViewModel: editorViewModel)

        editorViewModel.selectElement(textElement)
        flushMainRunLoop()

        return (project, textElement, editorViewModel, elementViewModel)
    }

    /// フォントサイズ編集はドラッグ中に履歴を積まず、確定時に1件だけ履歴を積む
    /// - Parameters: なし
    /// - Returns: なし
    @MainActor
    func testFontSizeSlider_RecordsSingleHistoryOnCommit() {
        let (_, textElement, editorViewModel, elementViewModel) = makeTextEditingContext()
        let initialHistoryCount = editorViewModel.getHistoryDescriptions().count

        elementViewModel.beginTextFontSizeEditing()
        elementViewModel.previewTextFontSize(44)
        elementViewModel.previewTextFontSize(60)

        XCTAssertEqual(editorViewModel.getHistoryDescriptions().count, initialHistoryCount)
        XCTAssertEqual(textElement.fontSize, 60, accuracy: 0.0001)

        elementViewModel.commitTextFontSizeEditing()

        XCTAssertEqual(editorViewModel.getHistoryDescriptions().count, initialHistoryCount + 1)
        XCTAssertEqual(textElement.fontSize, 60, accuracy: 0.0001)

        editorViewModel.undo()
        XCTAssertEqual(textElement.fontSize, 36, accuracy: 0.0001)
    }

    /// 行間編集はドラッグ中に履歴を積まず、確定時に1件だけ履歴を積む
    /// - Parameters: なし
    /// - Returns: なし
    @MainActor
    func testLineSpacingSlider_RecordsSingleHistoryOnCommit() {
        let (_, textElement, editorViewModel, elementViewModel) = makeTextEditingContext()
        let initialHistoryCount = editorViewModel.getHistoryDescriptions().count

        elementViewModel.beginTextLineSpacingEditing()
        elementViewModel.previewTextLineSpacing(2.0)
        elementViewModel.previewTextLineSpacing(3.5)

        XCTAssertEqual(editorViewModel.getHistoryDescriptions().count, initialHistoryCount)
        XCTAssertEqual(textElement.lineSpacing, 3.5, accuracy: 0.0001)

        elementViewModel.commitTextLineSpacingEditing()

        XCTAssertEqual(editorViewModel.getHistoryDescriptions().count, initialHistoryCount + 1)
        XCTAssertEqual(textElement.lineSpacing, 3.5, accuracy: 0.0001)

        editorViewModel.undo()
        XCTAssertEqual(textElement.lineSpacing, 1.0, accuracy: 0.0001)
    }

    /// 文字間隔編集はドラッグ中に履歴を積まず、確定時に1件だけ履歴を積む
    /// - Parameters: なし
    /// - Returns: なし
    @MainActor
    func testLetterSpacingSlider_RecordsSingleHistoryOnCommit() {
        let (_, textElement, editorViewModel, elementViewModel) = makeTextEditingContext()
        let initialHistoryCount = editorViewModel.getHistoryDescriptions().count

        elementViewModel.beginTextLetterSpacingEditing()
        elementViewModel.previewTextLetterSpacing(1.5)
        elementViewModel.previewTextLetterSpacing(2.5)

        XCTAssertEqual(editorViewModel.getHistoryDescriptions().count, initialHistoryCount)
        XCTAssertEqual(textElement.letterSpacing, 2.5, accuracy: 0.0001)

        elementViewModel.commitTextLetterSpacingEditing()

        XCTAssertEqual(editorViewModel.getHistoryDescriptions().count, initialHistoryCount + 1)
        XCTAssertEqual(textElement.letterSpacing, 2.5, accuracy: 0.0001)

        editorViewModel.undo()
        XCTAssertEqual(textElement.letterSpacing, 0.0, accuracy: 0.0001)
    }

    /// シャドウぼかし編集はドラッグ中に履歴を積まず、確定時に1件だけ履歴を積む
    /// - Parameters: なし
    /// - Returns: なし
    @MainActor
    func testShadowSlider_RecordsSingleHistoryOnCommit() throws {
        let (_, textElement, editorViewModel, elementViewModel) = makeTextEditingContext()
        let shadowIndex = try XCTUnwrap(textElement.effects.firstIndex(where: { $0 is ShadowEffect }))
        let shadowEffect = try XCTUnwrap(textElement.effects[shadowIndex] as? ShadowEffect)
        let initialHistoryCount = editorViewModel.getHistoryDescriptions().count
        let oldBlur = shadowEffect.blurRadius

        elementViewModel.beginShadowEffectEditing(atIndex: shadowIndex)
        elementViewModel.updateShadowEffect(
            atIndex: shadowIndex,
            color: shadowEffect.color,
            offset: shadowEffect.offset,
            blurRadius: oldBlur + 4.0
        )

        XCTAssertEqual(editorViewModel.getHistoryDescriptions().count, initialHistoryCount)
        XCTAssertEqual(shadowEffect.blurRadius, oldBlur + 4.0, accuracy: 0.0001)

        elementViewModel.commitShadowEffectEditing(atIndex: shadowIndex)
        XCTAssertEqual(editorViewModel.getHistoryDescriptions().count, initialHistoryCount + 1)

        editorViewModel.undo()
        XCTAssertEqual(shadowEffect.blurRadius, oldBlur, accuracy: 0.0001)
    }

    /// ストローク太さ編集はドラッグ中に履歴を積まず、確定時に1件だけ履歴を積む
    /// - Parameters: なし
    /// - Returns: なし
    @MainActor
    func testStrokeSlider_RecordsSingleHistoryOnCommit() throws {
        let (_, textElement, editorViewModel, elementViewModel) = makeTextEditingContext()
        if textElement.effects.firstIndex(where: { $0 is StrokeEffect }) == nil {
            elementViewModel.addTextEffect(StrokeEffect())
        }

        let strokeIndex = try XCTUnwrap(textElement.effects.firstIndex(where: { $0 is StrokeEffect }))
        let strokeEffect = try XCTUnwrap(textElement.effects[strokeIndex] as? StrokeEffect)
        let initialHistoryCount = editorViewModel.getHistoryDescriptions().count
        let oldWidth = strokeEffect.width

        elementViewModel.beginStrokeEffectEditing(atIndex: strokeIndex)
        elementViewModel.updateStrokeEffect(
            atIndex: strokeIndex,
            color: strokeEffect.color,
            width: oldWidth + 3.0
        )

        XCTAssertEqual(editorViewModel.getHistoryDescriptions().count, initialHistoryCount)
        XCTAssertEqual(strokeEffect.width, oldWidth + 3.0, accuracy: 0.0001)

        elementViewModel.commitStrokeEffectEditing(atIndex: strokeIndex)
        XCTAssertEqual(editorViewModel.getHistoryDescriptions().count, initialHistoryCount + 1)

        editorViewModel.undo()
        XCTAssertEqual(strokeEffect.width, oldWidth, accuracy: 0.0001)
    }

    /// グロー半径編集はドラッグ中に履歴を積まず、確定時に1件だけ履歴を積む
    /// - Parameters: なし
    /// - Returns: なし
    @MainActor
    func testGlowSlider_RecordsSingleHistoryOnCommit() throws {
        let (_, textElement, editorViewModel, elementViewModel) = makeTextEditingContext()
        if textElement.effects.firstIndex(where: { $0 is GlowEffect }) == nil {
            elementViewModel.addTextEffect(GlowEffect())
        }

        let glowIndex = try XCTUnwrap(textElement.effects.firstIndex(where: { $0 is GlowEffect }))
        let glowEffect = try XCTUnwrap(textElement.effects[glowIndex] as? GlowEffect)
        let initialHistoryCount = editorViewModel.getHistoryDescriptions().count
        let oldRadius = glowEffect.radius

        elementViewModel.beginGlowEffectEditing(atIndex: glowIndex)
        elementViewModel.updateGlowEffect(
            atIndex: glowIndex,
            color: glowEffect.color,
            radius: oldRadius + 6.0
        )

        XCTAssertEqual(editorViewModel.getHistoryDescriptions().count, initialHistoryCount)
        XCTAssertEqual(glowEffect.radius, oldRadius + 6.0, accuracy: 0.0001)

        elementViewModel.commitGlowEffectEditing(atIndex: glowIndex)
        XCTAssertEqual(editorViewModel.getHistoryDescriptions().count, initialHistoryCount + 1)

        editorViewModel.undo()
        XCTAssertEqual(glowEffect.radius, oldRadius, accuracy: 0.0001)
    }
}
