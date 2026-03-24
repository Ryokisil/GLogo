//
//  SavePipelineRegressionTests.swift
//  GLogoTests
//
//  概要:
//  保存時の合成処理で解像度維持とテキスト描画属性の非破壊性を検証する回帰テスト。
//

import XCTest
import UIKit
@testable import GLogo

/// 保存合成処理の不変条件を検証する回帰テスト
final class SavePipelineRegressionTests: XCTestCase {

    // MARK: - Composite Save

    /// 合成結果がベース解像度を維持しつつ、オーバーレイ描画で出力画素が変化することを担保する
    func testMakeCompositeImage_PreservesBaseResolutionAndDrawsOverlay() throws {
        let baseImage = makeSolidImage(size: CGSize(width: 200, height: 100), color: .white)
        let textElement = makeOverlayTextElement()
        let project = try makeProject(baseImage: baseImage, overlayText: textElement)

        let service = ImageProcessingService()
        let output = service.makeCompositeImage(baseImage: baseImage, project: project)

        let composite = try XCTUnwrap(output)
        XCTAssertEqual(composite.size.width, baseImage.size.width, accuracy: 0.001)
        XCTAssertEqual(composite.size.height, baseImage.size.height, accuracy: 0.001)
        XCTAssertEqual(composite.scale, baseImage.scale, accuracy: 0.001)
        XCTAssertNotEqual(composite.pngData(), baseImage.pngData(), "オーバーレイ描画で画素内容が変化するべき")
    }

    /// 保存合成時に元のTextElementのフォントサイズ/影/縁取りが破壊されないことを担保する
    func testMakeCompositeImage_DoesNotMutateOriginalTextRenderingAttributes() throws {
        let baseImage = makeSolidImage(size: CGSize(width: 240, height: 120), color: .lightGray)
        let textElement = makeOverlayTextElement()
        let shadow = ShadowEffect(color: .black, offset: CGSize(width: 3, height: 5), blurRadius: 4)
        let stroke = StrokeEffect(color: .red, width: 2)
        textElement.effects = [shadow, stroke]
        textElement.fontSize = 24

        let originalFontSize = textElement.fontSize
        let originalShadowOffset = shadow.offset
        let originalShadowBlur = shadow.blurRadius
        let originalStrokeWidth = stroke.width
        let project = try makeProject(baseImage: baseImage, overlayText: textElement)

        let service = ImageProcessingService()
        _ = service.makeCompositeImage(baseImage: baseImage, project: project)

        XCTAssertEqual(textElement.fontSize, originalFontSize, accuracy: 0.001)
        let resultingShadow = try XCTUnwrap(textElement.effects.compactMap { $0 as? ShadowEffect }.first)
        let resultingStroke = try XCTUnwrap(textElement.effects.compactMap { $0 as? StrokeEffect }.first)
        XCTAssertEqual(resultingShadow.offset.width, originalShadowOffset.width, accuracy: 0.001)
        XCTAssertEqual(resultingShadow.offset.height, originalShadowOffset.height, accuracy: 0.001)
        XCTAssertEqual(resultingShadow.blurRadius, originalShadowBlur, accuracy: 0.001)
        XCTAssertEqual(resultingStroke.width, originalStrokeWidth, accuracy: 0.001)
    }

    /// 保存合成時に元のGlowEffectの半径が破壊されないことを担保する
    func testMakeCompositeImage_DoesNotMutateOriginalGlowEffect() throws {
        let baseImage = makeSolidImage(size: CGSize(width: 240, height: 120), color: .lightGray)
        let textElement = makeOverlayTextElement()
        let glow = GlowEffect(color: .white, radius: 8)
        let stroke = StrokeEffect(color: .red, width: 3)
        textElement.effects = [glow, stroke]
        textElement.fontSize = 24

        let originalFontSize = textElement.fontSize
        let originalGlowRadius = glow.radius
        let originalStrokeWidth = stroke.width
        let project = try makeProject(baseImage: baseImage, overlayText: textElement)

        let service = ImageProcessingService()
        _ = service.makeCompositeImage(baseImage: baseImage, project: project)

        XCTAssertEqual(textElement.fontSize, originalFontSize, accuracy: 0.001)
        let resultingGlow = try XCTUnwrap(textElement.effects.compactMap { $0 as? GlowEffect }.first)
        let resultingStroke = try XCTUnwrap(textElement.effects.compactMap { $0 as? StrokeEffect }.first)
        XCTAssertEqual(resultingGlow.radius, originalGlowRadius, accuracy: 0.001)
        XCTAssertEqual(resultingStroke.width, originalStrokeWidth, accuracy: 0.001)
    }

    /// 保存合成時に元のImageElementのframeWidth/cornerRadiusが破壊されないことを担保する
    func testMakeCompositeImage_DoesNotMutateOriginalFrameAttributes() throws {
        let baseImage = makeSolidImage(size: CGSize(width: 240, height: 120), color: .lightGray)
        let baseData = try XCTUnwrap(baseImage.pngData())
        let project = LogoProject(name: "FrameRegression", canvasSize: baseImage.size)

        let imageElement = ImageElement(imageData: baseData, importOrder: 0)
        imageElement.position = CGPoint(x: 40, y: 20)
        imageElement.size = CGSize(width: 120, height: 60)
        imageElement.zIndex = ElementPriority.image.rawValue
        imageElement.showFrame = true
        imageElement.frameWidth = 6.5
        imageElement.cornerRadius = 18.0
        imageElement.roundedCorners = true
        imageElement.frameStyle = .polaroid
        imageElement.frameColor = .cyan
        project.addElement(imageElement)

        let textElement = makeOverlayTextElement()
        project.addElement(textElement)

        let originalFrameWidth = imageElement.frameWidth
        let originalCornerRadius = imageElement.cornerRadius
        let originalFrameStyle = imageElement.frameStyle
        let originalShowFrame = imageElement.showFrame
        let originalRoundedCorners = imageElement.roundedCorners
        let originalFrameColorHex = imageElement.frameColor.rgbaHexString

        let service = ImageProcessingService()
        _ = service.makeCompositeImage(baseImage: baseImage, project: project)

        XCTAssertEqual(imageElement.frameWidth, originalFrameWidth, accuracy: 0.001, "保存後にframeWidthが変化してはいけない")
        XCTAssertEqual(imageElement.cornerRadius, originalCornerRadius, accuracy: 0.001, "保存後にcornerRadiusが変化してはいけない")
        XCTAssertEqual(imageElement.frameStyle, originalFrameStyle, "保存後にframeStyleが変化してはいけない")
        XCTAssertEqual(imageElement.showFrame, originalShowFrame, "保存後にshowFrameが変化してはいけない")
        XCTAssertEqual(imageElement.roundedCorners, originalRoundedCorners, "保存後にroundedCornersが変化してはいけない")
        XCTAssertEqual(imageElement.frameColor.rgbaHexString, originalFrameColorHex, "保存後にframeColorが変化してはいけない")
    }

    // MARK: - Helpers

    /// ベース画像とオーバーレイ文字を含む最小プロジェクトを作成する
    /// - Parameters:
    ///   - baseImage: ベース画像
    ///   - overlayText: オーバーレイに使うテキスト要素
    /// - Returns: 合成テスト用のLogoProject
    private func makeProject(baseImage: UIImage, overlayText: TextElement) throws -> LogoProject {
        let project = LogoProject(name: "SaveRegression", canvasSize: baseImage.size)

        let imageData = try XCTUnwrap(baseImage.pngData())
        let baseElement = ImageElement(imageData: imageData, importOrder: 0)
        baseElement.position = CGPoint(x: 40, y: 20)
        baseElement.size = CGSize(width: 120, height: 60)
        baseElement.zIndex = ElementPriority.image.rawValue
        project.addElement(baseElement)
        project.addElement(overlayText)

        return project
    }

    /// 合成確認用のテキスト要素を作成する
    /// - Parameters: なし
    /// - Returns: 既定の位置/サイズ/効果を持つTextElement
    private func makeOverlayTextElement() -> TextElement {
        let textElement = TextElement(text: "A", fontName: "HelveticaNeue", fontSize: 20, textColor: .black)
        textElement.position = CGPoint(x: 60, y: 35)
        textElement.size = CGSize(width: 48, height: 24)
        textElement.zIndex = ElementPriority.text.rawValue
        textElement.effects = [ShadowEffect(color: .black, offset: CGSize(width: 2, height: 2), blurRadius: 3)]
        return textElement
    }

    /// 指定色の単色画像を生成する
    /// - Parameters:
    ///   - size: 画像サイズ
    ///   - color: 塗りつぶし色
    /// - Returns: 指定サイズ/色のUIImage
    private func makeSolidImage(size: CGSize, color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
