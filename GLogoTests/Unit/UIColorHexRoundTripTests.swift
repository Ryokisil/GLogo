//
//  UIColorHexRoundTripTests.swift
//  GLogoTests
//
//  概要:
//  UIColor の RGBA Hex 文字列表現と復元処理の往復整合性を検証する単体テスト。
//

import XCTest
import UIKit
@testable import GLogo

/// UIColor の RGBA Hex 往復変換を検証するテスト
final class UIColorHexRoundTripTests: XCTestCase {

    /// sRGB色で RGBA Hex 文字列の往復変換が安定することを検証
    /// - Parameters: なし
    /// - Returns: なし
    func testRGBAHexString_RoundTripPreservesEncodedValueForSRGBColors() throws {
        let testColors: [UIColor] = [
            UIColor(red: 0.10, green: 0.12, blue: 0.18, alpha: 0.08),
            UIColor(red: 0.24, green: 0.58, blue: 0.98, alpha: 0.32),
            UIColor(red: 0.96, green: 0.77, blue: 0.18, alpha: 1.0)
        ]

        for color in testColors {
            let encoded = color.rgbaHexString
            let decoded = try XCTUnwrap(UIColor(rgbaHex: encoded))
            XCTAssertEqual(decoded.rgbaHexString, encoded)
        }
    }

    /// Display P3 色でも RGBA Hex 文字列の往復変換が安定することを検証
    /// - Parameters: なし
    /// - Returns: なし
    func testRGBAHexString_RoundTripPreservesEncodedValueForDisplayP3Color() throws {
        let displayP3Color = UIColor(displayP3Red: 0.82, green: 0.31, blue: 0.55, alpha: 0.27)

        let encoded = displayP3Color.rgbaHexString
        let decoded = try XCTUnwrap(UIColor(rgbaHex: encoded))
        let originalComponents = displayP3Color.rgbComponents
        let decodedComponents = decoded.rgbComponents

        XCTAssertEqual(decoded.rgbaHexString, encoded)
        XCTAssertEqual(decodedComponents.red, originalComponents.red, accuracy: 2.0 / 255.0)
        XCTAssertEqual(decodedComponents.green, originalComponents.green, accuracy: 2.0 / 255.0)
        XCTAssertEqual(decodedComponents.blue, originalComponents.blue, accuracy: 2.0 / 255.0)
        XCTAssertEqual(decodedComponents.alpha, originalComponents.alpha, accuracy: 2.0 / 255.0)
    }
}
