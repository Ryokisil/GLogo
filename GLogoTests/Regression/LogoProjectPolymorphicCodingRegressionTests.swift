//
//  LogoProjectPolymorphicCodingRegressionTests.swift
//  GLogoTests
//
//  概要:
//  LogoProject の要素配列が Swift 6 移行後も具体型（Image/Text/Shape）として
//  復元されることを検証する回帰テスト。
//

import XCTest
import UIKit
@testable import GLogo

/// LogoProject の多態 Codable 復元を検証する回帰テスト
@MainActor
final class LogoProjectPolymorphicCodingRegressionTests: XCTestCase {
    /// 新形式（type + payload）でエンコードした場合に具体型が復元されること
    /// - Parameters: なし
    /// - Returns: なし
    func testDecode_NewEnvelopeFormat_RestoresConcreteElementTypes() throws {
        let project = makeProjectWithAllElementTypes()
        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder.live().decode(LogoProject.self, from: data)

        assertConcreteElementTypes(in: decoded)
    }

    /// 旧形式（要素を直接配列エンコード）でも具体型を復元できること
    /// - Parameters: なし
    /// - Returns: なし
    func testDecode_LegacyElementArrayFormat_RestoresConcreteElementTypes() throws {
        let project = makeProjectWithAllElementTypes()
        let legacyData = try JSONEncoder().encode(LegacyProjectEncoding(project: project))
        let decoded = try JSONDecoder.live().decode(LogoProject.self, from: legacyData)

        assertConcreteElementTypes(in: decoded)
    }

    // MARK: - 固定 JSON（保存形式の互換と、復元の依存の受け渡し）

    /// 新形式の固定 JSON から要素の具体型と値を戻し、入れ子の画像要素へ渡した依存が届くこと
    func test_fixedEnvelopeJSON_restoresElementsAndDependencies() throws {
        let fixed = FixedDecodingDependencies(color: .red)
        let project = try fixed.dependencies.makeDecoder()
            .decode(LogoProject.self, from: Data(Self.envelopeProjectJSON.utf8))

        let image = try assertFixedElements(in: project)
        // 新形式で保存した、旧形式にない属性もそのまま戻る。
        XCTAssertEqual(image.blacksAdjustment, 0.25)
        XCTAssertEqual(image.frameStyle, .film)
        XCTAssertEqual(image.imageRole, .base)
        XCTAssertEqual(image.originalImportOrder, 1)
        XCTAssertTrue(image.hasAppliedUpscale)
        XCTAssertTrue(image.previewService === fixed.preview, "入れ子の画像要素へ描画サービスが届く")
        XCTAssertTrue(ImageRenderSessionStore().originalImage(of: image) === fixed.resolver.image, "入れ子の画像要素へ取得先が届く")
    }

    /// 旧形式（type なし）の固定 JSON でも同じく戻り、依存が届くこと。旧形式にない属性は既定値になる
    func test_fixedLegacyJSON_restoresElementsAndDependencies() throws {
        let fixed = FixedDecodingDependencies(color: .blue)
        let project = try fixed.dependencies.makeDecoder()
            .decode(LogoProject.self, from: Data(Self.legacyProjectJSON.utf8))

        let image = try assertFixedElements(in: project)
        XCTAssertEqual(image.blacksAdjustment, 0)
        XCTAssertEqual(image.frameStyle, .simple)
        XCTAssertEqual(image.imageRole, .overlay)
        XCTAssertEqual(image.originalImportOrder, 0)
        XCTAssertFalse(image.hasAppliedUpscale)
        XCTAssertTrue(image.previewService === fixed.preview, "旧形式でも入れ子の画像要素へ描画サービスが届く")
        XCTAssertTrue(ImageRenderSessionStore().originalImage(of: image) === fixed.resolver.image, "旧形式でも入れ子の画像要素へ取得先が届く")
    }

    /// 依存が欠けた Decoder では、新旧どちらの形式でも、画像要素の復元が欠けたキーを示すエラーで失敗すること
    func test_missingDependency_failsImageDecoding() {
        let fixed = FixedDecodingDependencies(color: .green)
        for json in [Self.envelopeProjectJSON, Self.legacyProjectJSON] {
            let withoutResolver = JSONDecoder()
            withoutResolver.userInfo[.imagePreviewService] = fixed.preview
            XCTAssertThrowsError(try withoutResolver.decode(LogoProject.self, from: Data(json.utf8))) { error in
                // 保存データの不正（DecodingError）ではなく、依存の設定不足として区別できる。
                XCTAssertEqual((error as? MissingDecodingDependencyError)?.key, CodingUserInfoKey.imageSourceResolver)
            }

            let withoutPreview = JSONDecoder()
            withoutPreview.userInfo[.imageSourceResolver] = fixed.resolver
            XCTAssertThrowsError(try withoutPreview.decode(LogoProject.self, from: Data(json.utf8))) { error in
                XCTAssertEqual((error as? MissingDecodingDependencyError)?.key, CodingUserInfoKey.imagePreviewService)
            }
        }
    }

    /// 画像を含まないプロジェクトは、実行時の依存を使わないため、素の Decoder でも戻ること
    func test_projectWithoutImage_decodesWithoutDependencies() throws {
        let project = try JSONDecoder().decode(LogoProject.self, from: Data(Self.projectWithoutImageJSON.utf8))

        XCTAssertEqual(project.elements.count, 2)
        XCTAssertEqual((project.elements[0] as? TextElement)?.text, "GLogo")
        XCTAssertEqual((project.elements[1] as? ShapeElement)?.shapeType, .circle)
    }

    // MARK: - Helpers

    /// 新旧の固定 JSON に共通する値を確かめ、形式ごとの確認のために画像要素を返す
    private func assertFixedElements(in project: LogoProject) throws -> ImageElement {
        XCTAssertEqual(project.name, "Fixture")
        XCTAssertEqual(project.id, UUID(uuidString: "6F9E1A52-3C4B-4D8E-9A07-1B2C3D4E5F60"))
        XCTAssertEqual(project.canvasSize, CGSize(width: 800, height: 600))
        XCTAssertEqual(project.createdAt, Date(timeIntervalSinceReferenceDate: 700_000_000))
        XCTAssertEqual(project.updatedAt, Date(timeIntervalSinceReferenceDate: 700_000_100))
        XCTAssertEqual(project.backgroundSettings.type, .solid)
        XCTAssertEqual(project.elements.count, 3)

        let image = try XCTUnwrap(project.elements[0] as? ImageElement)
        XCTAssertEqual(image.id, UUID(uuidString: "6F9E1A52-0000-4000-8000-000000000001"))
        XCTAssertEqual(image.name, "Photo")
        XCTAssertEqual(image.position, CGPoint(x: 12, y: 34))
        XCTAssertEqual(image.size, CGSize(width: 200, height: 150))
        XCTAssertEqual(image.rotation, 0.5)
        XCTAssertEqual(image.opacity, 0.75)
        XCTAssertEqual(image.zIndex, 2)
        XCTAssertEqual(image.imageFileName, "fixture-photo")
        XCTAssertEqual(image.saturationAdjustment, 1.25)
        XCTAssertEqual(image.brightnessAdjustment, 0.125)
        XCTAssertTrue(image.showFrame)
        XCTAssertEqual(image.frameWidth, 6)

        let text = try XCTUnwrap(project.elements[1] as? TextElement)
        XCTAssertEqual(text.text, "GLogo")
        XCTAssertEqual(text.fontName, "HelveticaNeue-Bold")
        XCTAssertEqual(text.fontSize, 48)
        XCTAssertEqual(text.alignment, .right)
        XCTAssertEqual(text.lineSpacing, 2)
        XCTAssertEqual(text.letterSpacing, 1.5)
        XCTAssertEqual(text.position, CGPoint(x: 40, y: 50))

        let shape = try XCTUnwrap(project.elements[2] as? ShapeElement)
        XCTAssertEqual(shape.shapeType, .circle)
        XCTAssertEqual(shape.fillMode, .gradient)
        XCTAssertEqual(shape.strokeMode, .none)
        XCTAssertEqual(shape.strokeWidth, 3)
        XCTAssertEqual(shape.sides, 6)
        XCTAssertEqual(shape.gradientAngle, 45)
        XCTAssertTrue(shape.isLocked)
        return image
    }

    /// Image/Text/Shape を1つずつ含むテスト用プロジェクトを作成
    /// - Parameters: なし
    /// - Returns: テスト用プロジェクト
    private func makeProjectWithAllElementTypes() -> LogoProject {
        let project = LogoProject(
            name: "PolymorphicCoding",
            canvasSize: CGSize(width: 800, height: 600)
        )

        let imageData = makeSolidImage(color: .systemPink).pngData() ?? Data()
        let image = ImageElementFactory().makeElement(imageData: imageData, importOrder: 1)
        image.name = "Image"
        image.position = CGPoint(x: 20, y: 20)
        image.zIndex = 100
        image.showFrame = true
        image.frameColor = UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
        image.frameWidth = 8.5
        image.frameStyle = .film
        image.roundedCorners = true
        image.cornerRadius = 16.0

        let text = TextElement(text: "Hello", fontName: "HelveticaNeue", fontSize: 24, textColor: .white)
        text.name = "Text"
        text.position = CGPoint(x: 120, y: 60)
        text.zIndex = 300

        let shape = ShapeElement(shapeType: .triangle, fillColor: .systemBlue)
        shape.name = "Shape"
        shape.position = CGPoint(x: 240, y: 180)
        shape.zIndex = 200

        project.addElement(image)
        project.addElement(text)
        project.addElement(shape)
        return project
    }

    /// 復元結果が具体型であることを検証
    /// - Parameters:
    ///   - project: 復元後プロジェクト
    /// - Returns: なし
    private func assertConcreteElementTypes(in project: LogoProject) {
        XCTAssertEqual(project.elements.count, 3)

        let image = project.elements[0] as? ImageElement
        let text = project.elements[1] as? TextElement
        let shape = project.elements[2] as? ShapeElement

        XCTAssertNotNil(image)
        XCTAssertNotNil(text)
        XCTAssertNotNil(shape)
        XCTAssertEqual(text?.text, "Hello")
        XCTAssertEqual(shape?.shapeType, .triangle)
        XCTAssertEqual(image?.name, "Image")
        XCTAssertEqual(image?.showFrame, true)
        XCTAssertEqual(image?.frameWidth ?? 0, 8.5, accuracy: 0.001)
        XCTAssertEqual(image?.frameStyle, .film)
        XCTAssertEqual(image?.roundedCorners, true)
        XCTAssertEqual(image?.cornerRadius ?? 0, 16.0, accuracy: 0.001)
        // frameColor は Codable 往復で NSKeyedArchiver 経由のため rgbaHex で比較
        let expectedHex = UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8).rgbaHexString
        XCTAssertEqual(image?.frameColor.rgbaHexString, expectedHex)
    }

    /// 単色画像を生成
    /// - Parameters:
    ///   - color: 塗りつぶし色
    /// - Returns: 32x32 の単色画像
    private func makeSolidImage(color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }
    }

    // MARK: - 固定 JSON の保存値

    /// 新形式の画像要素。旧形式にない属性（blacksAdjustment・frameStyle・imageRole など）も持つ
    private static let imageJSON = """
        {
          "id": "6F9E1A52-0000-4000-8000-000000000001",
          "name": "Photo", "isVisible": true, "isLocked": false, "zIndex": 2,
          "positionX": 12, "positionY": 34, "width": 200, "height": 150, "rotation": 0.5, "opacity": 0.75,
          "imageFileName": "fixture-photo",
          "saturationAdjustment": 1.25, "brightnessAdjustment": 0.125, "contrastAdjustment": 1,
          "highlightsAdjustment": 0, "shadowsAdjustment": 0, "hueAdjustment": 0, "sharpnessAdjustment": 0,
          "gaussianBlurRadius": 0, "tintIntensity": 0,
          "showFrame": true, "frameWidth": 6, "roundedCorners": false, "cornerRadius": 0,
          "blacksAdjustment": 0.25, "frameStyle": "film", "imageRole": "base", "originalImportOrder": 1,
          "hasAppliedUpscale": true
        }
        """

    /// 旧形式の画像要素。保存を始めた時点からある属性だけを持つ（色は try? で読むため省く）
    private static let legacyImageJSON = """
        {
          "id": "6F9E1A52-0000-4000-8000-000000000001",
          "name": "Photo", "isVisible": true, "isLocked": false, "zIndex": 2,
          "positionX": 12, "positionY": 34, "width": 200, "height": 150, "rotation": 0.5, "opacity": 0.75,
          "imageFileName": "fixture-photo",
          "saturationAdjustment": 1.25, "brightnessAdjustment": 0.125, "contrastAdjustment": 1,
          "highlightsAdjustment": 0, "shadowsAdjustment": 0, "hueAdjustment": 0, "sharpnessAdjustment": 0,
          "gaussianBlurRadius": 0, "tintIntensity": 0,
          "showFrame": true, "frameWidth": 6, "roundedCorners": false, "cornerRadius": 0
        }
        """

    private static let textJSON = """
        {
          "id": "6F9E1A52-0000-4000-8000-000000000002",
          "name": "Title", "isVisible": true, "isLocked": false, "zIndex": 3,
          "positionX": 40, "positionY": 50, "width": 300, "height": 80, "rotation": 0, "opacity": 1,
          "text": "GLogo", "fontName": "HelveticaNeue-Bold", "fontSize": 48,
          "alignment": 2, "lineSpacing": 2, "letterSpacing": 1.5
        }
        """

    private static let shapeJSON = """
        {
          "id": "6F9E1A52-0000-4000-8000-000000000003",
          "name": "Badge", "isVisible": true, "isLocked": true, "zIndex": 1,
          "positionX": 5, "positionY": 6, "width": 120, "height": 120, "rotation": 0.25, "opacity": 0.5,
          "shapeType": "circle", "fillMode": "gradient", "strokeMode": "none",
          "strokeWidth": 3, "cornerRadius": 0, "sides": 6, "gradientAngle": 45
        }
        """

    /// 新形式のプロジェクト。要素を type と payload で包む
    private static let envelopeProjectJSON = projectJSON(elements: [
        envelope("image", imageJSON), envelope("text", textJSON), envelope("shape", shapeJSON),
    ])

    /// 旧形式のプロジェクト。要素を包まずに並べ、種類はキーで判定する
    private static let legacyProjectJSON = projectJSON(elements: [legacyImageJSON, textJSON, shapeJSON])

    /// 画像を含まない新形式のプロジェクト
    private static let projectWithoutImageJSON = projectJSON(elements: [
        envelope("text", textJSON), envelope("shape", shapeJSON),
    ])

    /// プロジェクトの保存値。日時は既定の形式（基準日からの秒数）で持つ
    private static func projectJSON(elements: [String]) -> String {
        """
        {
          "name": "Fixture", "id": "6F9E1A52-3C4B-4D8E-9A07-1B2C3D4E5F60",
          "createdAt": 700000000, "updatedAt": 700000100,
          "canvasSize": {"width": 800, "height": 600},
          "backgroundSettings": {
            "type": "solid", "opacity": 1, "gradientType": "linear",
            "gradientDirection": "topToBottom", "gradientAngle": 0
          },
          "elements": [\(elements.joined(separator: ", "))]
        }
        """
    }

    private static func envelope(_ type: String, _ payload: String) -> String {
        "{\"type\": \"\(type)\", \"payload\": \(payload)}"
    }
}

/// 旧形式（elements を直接 `[LogoElement]` として保存）エンコード
private struct LegacyProjectEncoding: Encodable {
    let project: LogoProject

    /// LogoProject 旧形式のコーディングキー
    private enum CodingKeys: String, CodingKey {
        case name, elements, backgroundSettings, canvasSize, createdAt, updatedAt, id
    }

    /// 旧形式でエンコード
    /// - Parameters:
    ///   - encoder: エンコーダ
    /// - Returns: なし
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(project.name, forKey: .name)
        try container.encode(project.elements, forKey: .elements)
        try container.encode(project.backgroundSettings, forKey: .backgroundSettings)
        try container.encode(project.createdAt, forKey: .createdAt)
        try container.encode(project.updatedAt, forKey: .updatedAt)
        try container.encode(project.id, forKey: .id)
        try container.encode(
            ["width": project.canvasSize.width, "height": project.canvasSize.height],
            forKey: .canvasSize
        )
    }
}
