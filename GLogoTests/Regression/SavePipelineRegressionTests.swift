//
//  SavePipelineRegressionTests.swift
//  GLogoTests
//
//  概要:
//  保存時の合成処理でベース画像基準トリミング、重なり順、属性非破壊を検証する回帰テスト。
//

import XCTest
import UIKit
@testable import GLogo

/// 保存合成処理の不変条件を検証する回帰テスト
final class SavePipelineRegressionTests: XCTestCase {

    // MARK: - Composite Save

    /// 合成結果がベース画像範囲でクリップされ、オーバーレイが描画されることを担保する
    func testMakeCompositeImage_CropsToBaseImageBoundsAndDrawsOverlay() throws {
        let baseImage = makeSolidImage(size: CGSize(width: 200, height: 100), color: .white)
        let textElement = makeOverlayTextElement()
        let (project, baseElement) = try makeProject(baseImage: baseImage, overlayText: textElement)

        let service = ImageProcessingService()
        let output = service.makeCompositeImage(baseElement: baseElement, project: project)

        let composite = try XCTUnwrap(output)
        // 出力サイズ = ベース画像の実ピクセルサイズ
        XCTAssertEqual(composite.size.width, 200, accuracy: 0.001)
        XCTAssertEqual(composite.size.height, 100, accuracy: 0.001)
        XCTAssertEqual(composite.scale, 1.0, accuracy: 0.001)
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
        let (project, baseElement) = try makeProject(baseImage: baseImage, overlayText: textElement)

        let service = ImageProcessingService()
        _ = service.makeCompositeImage(baseElement: baseElement, project: project)

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
        let (project, baseElement) = try makeProject(baseImage: baseImage, overlayText: textElement)

        let service = ImageProcessingService()
        _ = service.makeCompositeImage(baseElement: baseElement, project: project)

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
        imageElement.imageRole = .base
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
        _ = service.makeCompositeImage(baseElement: imageElement, project: project)

        XCTAssertEqual(imageElement.frameWidth, originalFrameWidth, accuracy: 0.001, "保存後にframeWidthが変化してはいけない")
        XCTAssertEqual(imageElement.cornerRadius, originalCornerRadius, accuracy: 0.001, "保存後にcornerRadiusが変化してはいけない")
        XCTAssertEqual(imageElement.frameStyle, originalFrameStyle, "保存後にframeStyleが変化してはいけない")
        XCTAssertEqual(imageElement.showFrame, originalShowFrame, "保存後にshowFrameが変化してはいけない")
        XCTAssertEqual(imageElement.roundedCorners, originalRoundedCorners, "保存後にroundedCornersが変化してはいけない")
        XCTAssertEqual(imageElement.frameColor.rgbaHexString, originalFrameColorHex, "保存後にframeColorが変化してはいけない")
    }

    /// 画像zIndexの並べ替えが保存時の重なり順に反映されることを担保する
    func testMakeCompositeImage_UsesImageZIndexOrderForOverlays() throws {
        let baseImage = makeSolidImage(size: CGSize(width: 120, height: 120), color: .white)
        let project = LogoProject(name: "ImageOrderSaveRegression", canvasSize: baseImage.size)

        let baseElement = try makeBaseImageElement(baseImage: baseImage)
        project.addElement(baseElement)

        let redOverlay = try makeOverlayImageElement(
            color: .red,
            position: CGPoint(x: 20, y: 20),
            size: CGSize(width: 50, height: 50),
            zIndex: ElementPriority.image.rawValue + 10
        )
        let blueOverlay = try makeOverlayImageElement(
            color: .blue,
            position: CGPoint(x: 20, y: 20),
            size: CGSize(width: 50, height: 50),
            zIndex: ElementPriority.image.rawValue + 11
        )
        project.addElement(redOverlay)
        project.addElement(blueOverlay)

        let service = ImageProcessingService()
        let blueFrontImage = try XCTUnwrap(service.makeCompositeImage(baseElement: baseElement, project: project))
        XCTAssertEqual(
            try sampledColorHex(from: blueFrontImage, at: CGPoint(x: 30, y: 30)),
            UIColor.blue.rgbaHexString,
            "zIndex が高い青画像が最前面に描画されるべき"
        )

        redOverlay.zIndex = ElementPriority.image.rawValue + 12
        blueOverlay.zIndex = ElementPriority.image.rawValue + 11

        let redFrontImage = try XCTUnwrap(service.makeCompositeImage(baseElement: baseElement, project: project))
        XCTAssertEqual(
            try sampledColorHex(from: redFrontImage, at: CGPoint(x: 30, y: 30)),
            UIColor.red.rgbaHexString,
            "zIndex 並べ替え後は赤画像が最前面に描画されるべき"
        )
    }

    // MARK: - ベース画像基準クリップ

    /// ベース画像から少しはみ出したオーバーレイがクリップされることを担保する
    func testMakeCompositeImage_ClipsOverlaySlightlyOutsideBase() throws {
        let baseImage = makeSolidImage(size: CGSize(width: 200, height: 200), color: .white)
        let project = LogoProject(name: "ClipSlightlyOutside", canvasSize: CGSize(width: 400, height: 400))

        let base = try makeBaseImageElement(baseImage: baseImage)
        base.position = CGPoint(x: 50, y: 50)
        base.size = CGSize(width: 200, height: 200)
        project.addElement(base)

        // 赤オーバーレイ: ベース右下から 50pt はみ出す
        let overlay = try makeOverlayImageElement(
            color: .red,
            position: CGPoint(x: 200, y: 200),
            size: CGSize(width: 100, height: 100),
            zIndex: ElementPriority.image.rawValue + 1
        )
        project.addElement(overlay)

        let service = ImageProcessingService()
        let output = try XCTUnwrap(service.makeCompositeImage(baseElement: base, project: project))

        XCTAssertEqual(output.size.width, 200, accuracy: 0.001)
        XCTAssertEqual(output.size.height, 200, accuracy: 0.001)

        // ベース内のオーバーレイ部分は描画される（出力座標 160,160 = キャンバス 210,210）
        XCTAssertEqual(
            try sampledColorHex(from: output, at: CGPoint(x: 160, y: 160)),
            UIColor.red.rgbaHexString,
            "ベース内のオーバーレイ部分は描画されるべき"
        )

        // オーバーレイ外のベース部分は白（出力座標 50,50 = キャンバス 100,100）
        XCTAssertEqual(
            try sampledColorHex(from: output, at: CGPoint(x: 50, y: 50)),
            UIColor.white.rgbaHexString,
            "オーバーレイ外のベース部分は白のままであるべき"
        )
    }

    /// ベース画像から大きくはみ出したオーバーレイが完全にクリップされることを担保する
    func testMakeCompositeImage_ClipsOverlayCompletelyOutsideBase() throws {
        let baseImage = makeSolidImage(size: CGSize(width: 200, height: 200), color: .white)
        let project = LogoProject(name: "ClipCompletelyOutside", canvasSize: CGSize(width: 600, height: 600))

        let base = try makeBaseImageElement(baseImage: baseImage)
        base.position = CGPoint(x: 50, y: 50)
        base.size = CGSize(width: 200, height: 200)
        project.addElement(base)

        // 赤オーバーレイ: ベースの完全外
        let overlay = try makeOverlayImageElement(
            color: .red,
            position: CGPoint(x: 400, y: 400),
            size: CGSize(width: 100, height: 100),
            zIndex: ElementPriority.image.rawValue + 1
        )
        project.addElement(overlay)

        let service = ImageProcessingService()
        let output = try XCTUnwrap(service.makeCompositeImage(baseElement: base, project: project))

        XCTAssertEqual(output.size.width, 200, accuracy: 0.001)
        XCTAssertEqual(output.size.height, 200, accuracy: 0.001)

        // 全面白（ベースのみ、赤オーバーレイは完全にクリップ）
        XCTAssertEqual(
            try sampledColorHex(from: output, at: CGPoint(x: 100, y: 100)),
            UIColor.white.rgbaHexString,
            "ベース外のオーバーレイは完全にクリップされるべき"
        )
    }

    /// ベース画像内にある部分だけが描画されることを担保する
    func testMakeCompositeImage_DrawsOnlyPortionWithinBase() throws {
        let baseImage = makeSolidImage(size: CGSize(width: 200, height: 200), color: .white)
        let project = LogoProject(name: "PartialDraw", canvasSize: CGSize(width: 500, height: 500))

        let base = try makeBaseImageElement(baseImage: baseImage)
        base.position = CGPoint(x: 100, y: 100)
        base.size = CGSize(width: 200, height: 200)
        project.addElement(base)

        // 赤オーバーレイ: 左半分がベース外、右半分がベース内
        let overlay = try makeOverlayImageElement(
            color: .red,
            position: CGPoint(x: 50, y: 150),
            size: CGSize(width: 200, height: 100),
            zIndex: ElementPriority.image.rawValue + 1
        )
        project.addElement(overlay)

        let service = ImageProcessingService()
        let output = try XCTUnwrap(service.makeCompositeImage(baseElement: base, project: project))

        // 出力座標 (50, 80) = キャンバス (150, 180) → ベース内かつオーバーレイ内 → 赤
        XCTAssertEqual(
            try sampledColorHex(from: output, at: CGPoint(x: 50, y: 80)),
            UIColor.red.rgbaHexString,
            "ベース内のオーバーレイ部分は描画されるべき"
        )

        // 出力座標 (50, 10) = キャンバス (150, 110) → ベース内だがオーバーレイ外 → 白
        XCTAssertEqual(
            try sampledColorHex(from: output, at: CGPoint(x: 50, y: 10)),
            UIColor.white.rgbaHexString,
            "オーバーレイ外のベース部分は白のままであるべき"
        )
    }

    /// 保存画像サイズがベース画像の実ピクセルサイズになることを担保する
    func testMakeCompositeImage_OutputSizeEqualsBasePixelSize() throws {
        let baseImage = makeSolidImage(size: CGSize(width: 3000, height: 2000), color: .white)
        let project = LogoProject(name: "OutputSizeRegression", canvasSize: CGSize(width: 3840, height: 2160))

        let base = try makeBaseImageElement(baseImage: baseImage)
        base.position = CGPoint(x: 100, y: 80)
        base.size = CGSize(width: 240, height: 220)
        project.addElement(base)

        let service = ImageProcessingService()
        let output = try XCTUnwrap(service.makeCompositeImage(baseElement: base, project: project))

        XCTAssertEqual(output.size.width, 3000, accuracy: 0.001, "出力幅はベース画像の実ピクセル幅であるべき")
        XCTAssertEqual(output.size.height, 2000, accuracy: 0.001, "出力高さはベース画像の実ピクセル高さであるべき")
    }

    /// ベース画像を非等比リサイズしていても、オーバーレイ位置が editor 上の見た目どおり変換されることを担保する
    func testMakeCompositeImage_PreservesOverlayPositionWithNonUniformBaseScaling() throws {
        let baseImage = makeSolidImage(size: CGSize(width: 2000, height: 1000), color: .white)
        let project = LogoProject(name: "NonUniformBaseScalingRegression", canvasSize: CGSize(width: 1000, height: 1000))

        let base = try makeBaseImageElement(baseImage: baseImage)
        base.position = CGPoint(x: 100, y: 100)
        base.size = CGSize(width: 200, height: 125)
        project.addElement(base)

        let overlay = try makeOverlayImageElement(
            color: .red,
            position: CGPoint(x: 140, y: 125),
            size: CGSize(width: 40, height: 25),
            zIndex: ElementPriority.image.rawValue + 1
        )
        project.addElement(overlay)

        let service = ImageProcessingService()
        let output = try XCTUnwrap(service.makeCompositeImage(baseElement: base, project: project))

        XCTAssertEqual(output.size.width, 2000, accuracy: 0.001)
        XCTAssertEqual(output.size.height, 1000, accuracy: 0.001)
        XCTAssertEqual(
            try sampledColorHex(from: output, at: CGPoint(x: 600, y: 300)),
            UIColor.red.rgbaHexString,
            "非等比リサイズ後もオーバーレイが正しい位置に描画されるべき"
        )
        XCTAssertEqual(
            try sampledColorHex(from: output, at: CGPoint(x: 1200, y: 800)),
            UIColor.white.rgbaHexString,
            "オーバーレイ外のベース部分は白のままであるべき"
        )
    }

    /// 元画像が表示サイズより大きい場合でも、合成保存が表示サイズの解像度へ潰れないことを担保する
    func testMakeCompositeImage_UsesSourceResolutionWhenImageIsScaledDownInEditor() throws {
        let project = LogoProject(name: "HighResolutionCompositeRegression", canvasSize: CGSize(width: 3840, height: 2160))
        let largeImage = makeSolidImage(size: CGSize(width: 2000, height: 1000), color: .red)
        let imageData = try XCTUnwrap(largeImage.pngData())
        let imageElement = ImageElement(imageData: imageData, importOrder: 0)
        imageElement.position = CGPoint(x: 120, y: 80)
        imageElement.size = CGSize(width: 200, height: 100)
        imageElement.zIndex = ElementPriority.image.rawValue
        imageElement.imageRole = .base
        project.addElement(imageElement)

        let service = ImageProcessingService()
        let output = try XCTUnwrap(service.makeCompositeImage(baseElement: imageElement, project: project))

        XCTAssertEqual(output.size.width, 2000, accuracy: 0.001)
        XCTAssertEqual(output.size.height, 1000, accuracy: 0.001)
        XCTAssertEqual(
            try sampledColorHex(from: output, at: CGPoint(x: 1000, y: 500)),
            UIColor.red.rgbaHexString,
            "元画像の解像度を活かしたまま editor 上の見た目で保存されるべき"
        )
    }

    /// ベース回転なしで縦画像のみの構成でも、editor 上の見た目どおり保存されることを担保する
    func testMakeCompositeImage_PreservesLayoutForPortraitOnlyComposition() throws {
        let baseImage = makeSolidImage(size: CGSize(width: 1200, height: 2000), color: .white)
        let project = LogoProject(name: "PortraitOnlyCompositeRegression", canvasSize: CGSize(width: 800, height: 1200))

        let base = try makeBaseImageElement(baseImage: baseImage)
        base.position = CGPoint(x: 100, y: 80)
        base.size = CGSize(width: 240, height: 400)
        project.addElement(base)

        let redOverlay = try makeOverlayImageElement(
            color: .red,
            position: CGPoint(x: 130, y: 160),
            size: CGSize(width: 60, height: 140),
            zIndex: ElementPriority.image.rawValue + 1
        )
        let blueOverlay = try makeOverlayImageElement(
            color: .blue,
            position: CGPoint(x: 250, y: 310),
            size: CGSize(width: 50, height: 120),
            zIndex: ElementPriority.image.rawValue + 2
        )
        project.addElement(redOverlay)
        project.addElement(blueOverlay)

        let service = ImageProcessingService()
        let output = try XCTUnwrap(service.makeCompositeImage(baseElement: base, project: project))

        XCTAssertEqual(output.size.width, 1200, accuracy: 0.001)
        XCTAssertEqual(output.size.height, 2000, accuracy: 0.001)
        XCTAssertEqual(
            try sampledColorHex(from: output, at: exportPoint(fromCanvasPoint: CGPoint(x: 160, y: 220), baseElement: base, basePixelSize: baseImage.size)),
            UIColor.red.rgbaHexString,
            "縦画像のみでも赤オーバーレイは editor と同じ位置に保存されるべき"
        )
        XCTAssertEqual(
            try sampledColorHex(from: output, at: exportPoint(fromCanvasPoint: CGPoint(x: 270, y: 360), baseElement: base, basePixelSize: baseImage.size)),
            UIColor.blue.rgbaHexString,
            "縦画像のみでも青オーバーレイは editor と同じ位置に保存されるべき"
        )
        XCTAssertEqual(
            try sampledColorHex(from: output, at: exportPoint(fromCanvasPoint: CGPoint(x: 320, y: 120), baseElement: base, basePixelSize: baseImage.size)),
            UIColor.white.rgbaHexString,
            "縦画像のみでもオーバーレイ外のベース領域は白のままであるべき"
        )
    }

    /// ベース回転なしで横画像のみの構成でも、editor 上の見た目どおり保存されることを担保する
    func testMakeCompositeImage_PreservesLayoutForLandscapeOnlyComposition() throws {
        let baseImage = makeSolidImage(size: CGSize(width: 2000, height: 1200), color: .white)
        let project = LogoProject(name: "LandscapeOnlyCompositeRegression", canvasSize: CGSize(width: 900, height: 600))

        let base = try makeBaseImageElement(baseImage: baseImage)
        base.position = CGPoint(x: 120, y: 100)
        base.size = CGSize(width: 400, height: 240)
        project.addElement(base)

        let redOverlay = try makeOverlayImageElement(
            color: .red,
            position: CGPoint(x: 180, y: 160),
            size: CGSize(width: 140, height: 60),
            zIndex: ElementPriority.image.rawValue + 1
        )
        let blueOverlay = try makeOverlayImageElement(
            color: .blue,
            position: CGPoint(x: 330, y: 250),
            size: CGSize(width: 120, height: 50),
            zIndex: ElementPriority.image.rawValue + 2
        )
        project.addElement(redOverlay)
        project.addElement(blueOverlay)

        let service = ImageProcessingService()
        let output = try XCTUnwrap(service.makeCompositeImage(baseElement: base, project: project))

        XCTAssertEqual(output.size.width, 2000, accuracy: 0.001)
        XCTAssertEqual(output.size.height, 1200, accuracy: 0.001)
        XCTAssertEqual(
            try sampledColorHex(from: output, at: exportPoint(fromCanvasPoint: CGPoint(x: 220, y: 180), baseElement: base, basePixelSize: baseImage.size)),
            UIColor.red.rgbaHexString,
            "横画像のみでも赤オーバーレイは editor と同じ位置に保存されるべき"
        )
        XCTAssertEqual(
            try sampledColorHex(from: output, at: exportPoint(fromCanvasPoint: CGPoint(x: 360, y: 270), baseElement: base, basePixelSize: baseImage.size)),
            UIColor.blue.rgbaHexString,
            "横画像のみでも青オーバーレイは editor と同じ位置に保存されるべき"
        )
        XCTAssertEqual(
            try sampledColorHex(from: output, at: exportPoint(fromCanvasPoint: CGPoint(x: 460, y: 130), baseElement: base, basePixelSize: baseImage.size)),
            UIColor.white.rgbaHexString,
            "横画像のみでもオーバーレイ外のベース領域は白のままであるべき"
        )
    }

    /// ベース回転なしで縦横混在の構成でも、editor 上の見た目どおり保存されることを担保する
    func testMakeCompositeImage_PreservesLayoutForMixedPortraitAndLandscapeComposition() throws {
        let baseImage = makeSolidImage(size: CGSize(width: 1600, height: 1000), color: .white)
        let project = LogoProject(name: "MixedPortraitLandscapeCompositeRegression", canvasSize: CGSize(width: 900, height: 600))

        let base = try makeBaseImageElement(baseImage: baseImage)
        base.position = CGPoint(x: 80, y: 60)
        base.size = CGSize(width: 320, height: 200)
        project.addElement(base)

        let portraitOverlay = try makeOverlayImageElement(
            color: .red,
            position: CGPoint(x: 120, y: 90),
            size: CGSize(width: 60, height: 120),
            zIndex: ElementPriority.image.rawValue + 1
        )
        let landscapeOverlay = try makeOverlayImageElement(
            color: .blue,
            position: CGPoint(x: 240, y: 170),
            size: CGSize(width: 120, height: 50),
            zIndex: ElementPriority.image.rawValue + 2
        )
        project.addElement(portraitOverlay)
        project.addElement(landscapeOverlay)

        let service = ImageProcessingService()
        let output = try XCTUnwrap(service.makeCompositeImage(baseElement: base, project: project))

        XCTAssertEqual(output.size.width, 1600, accuracy: 0.001)
        XCTAssertEqual(output.size.height, 1000, accuracy: 0.001)
        XCTAssertEqual(
            try sampledColorHex(from: output, at: exportPoint(fromCanvasPoint: CGPoint(x: 150, y: 140), baseElement: base, basePixelSize: baseImage.size)),
            UIColor.red.rgbaHexString,
            "縦横混在でも縦オーバーレイは editor と同じ位置に保存されるべき"
        )
        XCTAssertEqual(
            try sampledColorHex(from: output, at: exportPoint(fromCanvasPoint: CGPoint(x: 300, y: 190), baseElement: base, basePixelSize: baseImage.size)),
            UIColor.blue.rgbaHexString,
            "縦横混在でも横オーバーレイは editor と同じ位置に保存されるべき"
        )
        XCTAssertEqual(
            try sampledColorHex(from: output, at: exportPoint(fromCanvasPoint: CGPoint(x: 360, y: 100), baseElement: base, basePixelSize: baseImage.size)),
            UIColor.white.rgbaHexString,
            "縦横混在でもオーバーレイ外のベース領域は白のままであるべき"
        )
    }

    // MARK: - 背景設定・位置ズレ

    /// 背景設定がベース画像範囲内に反映されることを担保する
    func testMakeCompositeImage_BackgroundSettingsReflectedWithinBaseBounds() throws {
        let project = LogoProject(name: "BackgroundSettingsRegression", canvasSize: CGSize(width: 300, height: 300))
        project.backgroundSettings.type = .solid
        project.backgroundSettings.color = .blue
        project.backgroundSettings.opacity = 1.0

        // 透明なベース画像で背景が透けて見えることを確認
        let transparentImage = makeTransparentImage(size: CGSize(width: 100, height: 100))
        let imageData = try XCTUnwrap(transparentImage.pngData())
        let base = ImageElement(imageData: imageData, importOrder: 0)
        base.position = CGPoint(x: 50, y: 50)
        base.size = CGSize(width: 100, height: 100)
        base.zIndex = ElementPriority.image.rawValue
        base.imageRole = .base
        project.addElement(base)

        let service = ImageProcessingService()
        let output = try XCTUnwrap(service.makeCompositeImage(baseElement: base, project: project))

        XCTAssertEqual(output.size.width, 100, accuracy: 0.001)
        XCTAssertEqual(output.size.height, 100, accuracy: 0.001)

        // 背景色（青）が出力に反映されている
        XCTAssertEqual(
            try sampledColorHex(from: output, at: CGPoint(x: 50, y: 50)),
            UIColor.blue.rgbaHexString,
            "背景設定がベース画像範囲内に反映されるべき"
        )
    }

    /// ベース画像がオフセット配置されていても位置ズレが発生しないことを担保する
    func testMakeCompositeImage_NoPositionShiftWithOffsetBase() throws {
        let baseImage = makeSolidImage(size: CGSize(width: 200, height: 200), color: .white)
        let project = LogoProject(name: "PositionShiftRegression", canvasSize: CGSize(width: 600, height: 600))

        let base = try makeBaseImageElement(baseImage: baseImage)
        base.position = CGPoint(x: 150, y: 100)
        base.size = CGSize(width: 200, height: 200)
        project.addElement(base)

        // ベース中央に配置された赤オーバーレイ
        let overlay = try makeOverlayImageElement(
            color: .red,
            position: CGPoint(x: 200, y: 150),
            size: CGSize(width: 100, height: 100),
            zIndex: ElementPriority.image.rawValue + 1
        )
        project.addElement(overlay)

        let service = ImageProcessingService()
        let output = try XCTUnwrap(service.makeCompositeImage(baseElement: base, project: project))

        // 出力座標 (100, 100) = キャンバス (250, 200) → ベース内、オーバーレイ内 → 赤
        XCTAssertEqual(
            try sampledColorHex(from: output, at: CGPoint(x: 100, y: 100)),
            UIColor.red.rgbaHexString,
            "ベース中央のオーバーレイが正確な位置に描画されるべき"
        )

        // 出力座標 (10, 10) = キャンバス (160, 110) → ベース内、オーバーレイ外 → 白
        XCTAssertEqual(
            try sampledColorHex(from: output, at: CGPoint(x: 10, y: 10)),
            UIColor.white.rgbaHexString,
            "オーバーレイ外のベース部分が正確に白であるべき"
        )
    }

    // MARK: - Helpers

    /// ベース画像とオーバーレイ文字を含む最小プロジェクトを作成する
    private func makeProject(baseImage: UIImage, overlayText: TextElement) throws -> (project: LogoProject, baseElement: ImageElement) {
        let project = LogoProject(name: "SaveRegression", canvasSize: baseImage.size)

        let baseElement = try makeBaseImageElement(baseImage: baseImage)
        baseElement.position = CGPoint(x: 40, y: 20)
        baseElement.size = CGSize(width: 120, height: 60)
        project.addElement(baseElement)
        project.addElement(overlayText)

        return (project, baseElement)
    }

    /// ベース画像要素を生成する
    private func makeBaseImageElement(baseImage: UIImage) throws -> ImageElement {
        let imageData = try XCTUnwrap(baseImage.pngData())
        let baseElement = ImageElement(imageData: imageData, importOrder: 0)
        baseElement.position = .zero
        baseElement.size = baseImage.size
        baseElement.zIndex = ElementPriority.image.rawValue
        baseElement.imageRole = .base
        return baseElement
    }

    /// オーバーレイ用画像要素を生成する
    private func makeOverlayImageElement(
        color: UIColor,
        position: CGPoint,
        size: CGSize,
        zIndex: Int
    ) throws -> ImageElement {
        let image = makeSolidImage(size: size, color: color)
        let imageData = try XCTUnwrap(image.pngData())
        let overlay = ImageElement(imageData: imageData, importOrder: 0)
        overlay.position = position
        overlay.size = size
        overlay.zIndex = zIndex
        return overlay
    }

    /// 合成確認用のテキスト要素を作成する
    private func makeOverlayTextElement() -> TextElement {
        let textElement = TextElement(text: "A", fontName: "HelveticaNeue", fontSize: 20, textColor: .black)
        textElement.position = CGPoint(x: 60, y: 35)
        textElement.size = CGSize(width: 48, height: 24)
        textElement.zIndex = ElementPriority.text.rawValue
        textElement.effects = [ShadowEffect(color: .black, offset: CGSize(width: 2, height: 2), blurRadius: 3)]
        return textElement
    }

    /// 指定色の単色画像を生成する
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

    /// 透明な画像を生成する
    private func makeTransparentImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            // 何も描画しない → 完全透明
        }
    }

    /// 指定座標の画素色を16進表現で返す
    private func sampledColorHex(from image: UIImage, at point: CGPoint) throws -> String {
        let cgImage = try XCTUnwrap(image.cgImage)
        let x = Int(point.x)
        let y = Int(point.y)
        let cropped = try XCTUnwrap(cgImage.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixel = [UInt8](repeating: 0, count: 4)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let context = try XCTUnwrap(
            CGContext(
                data: &pixel,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        )
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let color = UIColor(
            red: CGFloat(pixel[0]) / 255.0,
            green: CGFloat(pixel[1]) / 255.0,
            blue: CGFloat(pixel[2]) / 255.0,
            alpha: CGFloat(pixel[3]) / 255.0
        )
        return color.rgbaHexString
    }

    /// editor 上のキャンバス座標を、書き出し画像上の座標へ変換する
    private func exportPoint(fromCanvasPoint point: CGPoint, baseElement: ImageElement, basePixelSize: CGSize) -> CGPoint {
        let scaleX = basePixelSize.width / baseElement.size.width
        let scaleY = basePixelSize.height / baseElement.size.height
        return CGPoint(
            x: (point.x - baseElement.position.x) * scaleX,
            y: (point.y - baseElement.position.y) * scaleY
        )
    }
}
