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
        let decoded = try JSONDecoder().decode(LogoProject.self, from: data)

        assertConcreteElementTypes(in: decoded)
    }

    /// 旧形式（要素を直接配列エンコード）でも具体型を復元できること
    /// - Parameters: なし
    /// - Returns: なし
    func testDecode_LegacyElementArrayFormat_RestoresConcreteElementTypes() throws {
        let project = makeProjectWithAllElementTypes()
        let legacyData = try JSONEncoder().encode(LegacyProjectEncoding(project: project))
        let decoded = try JSONDecoder().decode(LogoProject.self, from: legacyData)

        assertConcreteElementTypes(in: decoded)
    }

    // MARK: - Helpers

    /// Image/Text/Shape を1つずつ含むテスト用プロジェクトを作成
    /// - Parameters: なし
    /// - Returns: テスト用プロジェクト
    private func makeProjectWithAllElementTypes() -> LogoProject {
        let project = LogoProject(
            name: "PolymorphicCoding",
            canvasSize: CGSize(width: 800, height: 600)
        )

        let imageData = makeSolidImage(color: .systemPink).pngData() ?? Data()
        let image = ImageElement(imageData: imageData, importOrder: 1)
        image.name = "Image"
        image.position = CGPoint(x: 20, y: 20)
        image.zIndex = 100

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
