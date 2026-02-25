//
//  TextEffectScalingTests.swift
//  GLogoTests
//
//  概要:
//  TextEffect のスケーリング・ディープコピー・Codable ラウンドトリップを検証するユニットテスト。
//

import XCTest
@testable import GLogo

final class TextEffectScalingTests: XCTestCase {

    // MARK: - scaled(by:) テスト

    /// ShadowEffect の scaled がオフセットとぼかし半径を正しくスケーリングすること
    func testShadowEffect_scaled_scalesOffsetAndBlur() {
        let shadow = ShadowEffect(color: .red, offset: CGSize(width: 4, height: 6), blurRadius: 8)
        let scaled = shadow.scaled(by: 2.0) as! ShadowEffect

        XCTAssertEqual(scaled.offset.width, 8.0, accuracy: 0.001)
        XCTAssertEqual(scaled.offset.height, 12.0, accuracy: 0.001)
        XCTAssertEqual(scaled.blurRadius, 16.0, accuracy: 0.001)
    }

    /// StrokeEffect の scaled が太さを正しくスケーリングすること
    func testStrokeEffect_scaled_scalesWidth() {
        let stroke = StrokeEffect(color: .blue, width: 3.0)
        let scaled = stroke.scaled(by: 1.5) as! StrokeEffect

        XCTAssertEqual(scaled.width, 4.5, accuracy: 0.001)
    }

    /// GlowEffect の scaled が半径を正しくスケーリングすること
    func testGlowEffect_scaled_scalesRadius() {
        let glow = GlowEffect(color: .white, radius: 5.0)
        let scaled = glow.scaled(by: 3.0) as! GlowEffect

        XCTAssertEqual(scaled.radius, 15.0, accuracy: 0.001)
    }

    // MARK: - deepCopy テスト

    /// ShadowEffect のディープコピーが独立していること
    func testDeepCopy_ShadowEffect_independentMutation() {
        let shadow = ShadowEffect(color: .black, offset: CGSize(width: 2, height: 2), blurRadius: 3)
        let copy = shadow.deepCopy() as! ShadowEffect

        copy.blurRadius = 99
        copy.offset = CGSize(width: 50, height: 50)

        XCTAssertEqual(shadow.blurRadius, 3.0, accuracy: 0.001, "元のインスタンスが汚染されていないこと")
        XCTAssertEqual(shadow.offset.width, 2.0, accuracy: 0.001)
    }

    /// StrokeEffect のディープコピーが独立していること
    func testDeepCopy_StrokeEffect_independentMutation() {
        let stroke = StrokeEffect(color: .red, width: 5)
        let copy = stroke.deepCopy() as! StrokeEffect

        copy.width = 99

        XCTAssertEqual(stroke.width, 5.0, accuracy: 0.001, "元のインスタンスが汚染されていないこと")
    }

    /// GlowEffect のディープコピーが独立していること
    func testDeepCopy_GlowEffect_independentMutation() {
        let glow = GlowEffect(color: .white, radius: 10)
        let copy = glow.deepCopy() as! GlowEffect

        copy.radius = 99

        XCTAssertEqual(glow.radius, 10.0, accuracy: 0.001, "元のインスタンスが汚染されていないこと")
    }

    /// GradientFillEffect のディープコピーが独立していること
    func testDeepCopy_GradientFillEffect_independentMutation() {
        let gradient = GradientFillEffect(startColor: .red, endColor: .blue, angle: 45, opacity: 0.6)
        let copy = gradient.deepCopy() as! GradientFillEffect

        copy.angle = 180
        copy.opacity = 0.2

        XCTAssertEqual(gradient.angle, 45.0, accuracy: 0.001, "元のインスタンスが汚染されていないこと")
        XCTAssertEqual(gradient.opacity, 0.6, accuracy: 0.001, "元のインスタンスが汚染されていないこと")
    }

    /// TextElement.copy() がエフェクトをディープコピーすること
    func testTextElement_copy_deepCopiesEffects() {
        let textElement = TextElement(text: "Test", fontName: "HelveticaNeue", fontSize: 20, textColor: .white)
        let shadow = ShadowEffect(color: .black, offset: CGSize(width: 2, height: 2), blurRadius: 3)
        textElement.effects = [shadow]

        let copied = textElement.copy() as! TextElement
        let copiedShadow = copied.effects.first as! ShadowEffect
        copiedShadow.blurRadius = 99

        XCTAssertEqual(shadow.blurRadius, 3.0, accuracy: 0.001, "コピー元のエフェクトが汚染されていないこと")
    }

    // MARK: - AnyTextEffect Codable テスト

    /// ShadowEffect の Codable ラウンドトリップ
    func testAnyTextEffect_codableRoundTrip_shadow() throws {
        let shadow = ShadowEffect(color: .red, offset: CGSize(width: 3, height: 5), blurRadius: 7)
        let wrapped = AnyTextEffect(shadow)

        let data = try JSONEncoder().encode(wrapped)
        let decoded = try JSONDecoder().decode(AnyTextEffect.self, from: data)

        let result = try XCTUnwrap(decoded.effect as? ShadowEffect)
        XCTAssertEqual(result.offset.width, 3.0, accuracy: 0.001)
        XCTAssertEqual(result.offset.height, 5.0, accuracy: 0.001)
        XCTAssertEqual(result.blurRadius, 7.0, accuracy: 0.001)
    }

    /// StrokeEffect の Codable ラウンドトリップ
    func testAnyTextEffect_codableRoundTrip_stroke() throws {
        let stroke = StrokeEffect(color: .blue, width: 4)
        let wrapped = AnyTextEffect(stroke)

        let data = try JSONEncoder().encode(wrapped)
        let decoded = try JSONDecoder().decode(AnyTextEffect.self, from: data)

        let result = try XCTUnwrap(decoded.effect as? StrokeEffect)
        XCTAssertEqual(result.width, 4.0, accuracy: 0.001)
    }

    /// GlowEffect の Codable ラウンドトリップ
    func testAnyTextEffect_codableRoundTrip_glow() throws {
        let glow = GlowEffect(color: .green, radius: 12)
        let wrapped = AnyTextEffect(glow)

        let data = try JSONEncoder().encode(wrapped)
        let decoded = try JSONDecoder().decode(AnyTextEffect.self, from: data)

        let result = try XCTUnwrap(decoded.effect as? GlowEffect)
        XCTAssertEqual(result.radius, 12.0, accuracy: 0.001)
    }

    /// GradientFillEffect の Codable ラウンドトリップ
    func testAnyTextEffect_codableRoundTrip_gradient() throws {
        let gradient = GradientFillEffect(startColor: .red, endColor: .blue, angle: 120, opacity: 0.35)
        let wrapped = AnyTextEffect(gradient)

        let data = try JSONEncoder().encode(wrapped)
        let decoded = try JSONDecoder().decode(AnyTextEffect.self, from: data)

        let result = try XCTUnwrap(decoded.effect as? GradientFillEffect)
        XCTAssertEqual(result.angle, 120.0, accuracy: 0.001)
        XCTAssertEqual(result.opacity, 0.35, accuracy: 0.001)
    }

    /// 混合エフェクト配列の Codable ラウンドトリップ
    func testTextElement_codableRoundTrip_mixedEffects() throws {
        let textElement = TextElement(text: "Hello", fontName: "HelveticaNeue", fontSize: 24, textColor: .white)
        textElement.effects = [
            ShadowEffect(color: .black, offset: CGSize(width: 1, height: 1), blurRadius: 2),
            StrokeEffect(color: .red, width: 3),
            GlowEffect(color: .yellow, radius: 8)
        ]

        let data = try JSONEncoder().encode(textElement)
        let decoded = try JSONDecoder().decode(TextElement.self, from: data)

        XCTAssertEqual(decoded.effects.count, 3)
        XCTAssertTrue(decoded.effects[0] is ShadowEffect, "1番目は ShadowEffect であること")
        XCTAssertTrue(decoded.effects[1] is StrokeEffect, "2番目は StrokeEffect であること")
        XCTAssertTrue(decoded.effects[2] is GlowEffect, "3番目は GlowEffect であること")
    }

    /// effects キーなしの JSON からデコードした場合に空配列になること（後方互換）
    func testTextElement_decode_missingEffectsKey() throws {
        // effects キーを含まない最小 JSON を作成
        let textElement = TextElement(text: "Test", fontName: "HelveticaNeue", fontSize: 20, textColor: .white)
        let data = try JSONEncoder().encode(textElement)

        // effects キーを削除して再エンコード
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "effects")
        let modifiedData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(TextElement.self, from: modifiedData)
        XCTAssertTrue(decoded.effects.isEmpty, "effects キーなしの場合に空配列であること")
    }

    /// opacity キーなしの GradientFillEffect をデコードした場合に 1.0 になること（後方互換）
    func testGradientFillEffect_decode_missingOpacity_defaultsToOne() throws {
        let gradient = GradientFillEffect(startColor: .red, endColor: .blue, angle: 30, opacity: 0.2)
        let data = try JSONEncoder().encode(AnyTextEffect(gradient))

        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "opacity")
        let modifiedData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(AnyTextEffect.self, from: modifiedData)
        let result = try XCTUnwrap(decoded.effect as? GradientFillEffect)
        XCTAssertEqual(result.opacity, 1.0, accuracy: 0.001)
    }
}
