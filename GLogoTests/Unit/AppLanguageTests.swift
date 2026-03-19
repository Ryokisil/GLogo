//
//  AppLanguageTests.swift
//  GLogoTests
//
//  概要:
//  アプリ内言語設定モデルの基本動作を確認するテストです。
//

import XCTest
@testable import GLogo

final class AppLanguageTests: XCTestCase {

    /// `from(rawValue:)` が有効な値を正しく復元する
    func testFromRawValue_WithKnownLanguageCodes_ReturnsExpectedCases() {
        XCTAssertEqual(AppLanguage.from(rawValue: "system"), .system)
        XCTAssertEqual(AppLanguage.from(rawValue: "en"), .english)
        XCTAssertEqual(AppLanguage.from(rawValue: "ja"), .japanese)
    }

    /// `from(rawValue:)` が不正値を `.system` にフォールバックする
    func testFromRawValue_WithUnknownValue_FallsBackToSystem() {
        XCTAssertEqual(AppLanguage.from(rawValue: "invalid"), .system)
        XCTAssertEqual(AppLanguage.from(rawValue: ""), .system)
    }

    /// 明示選択した英語設定が英語 Locale を返す
    func testResolvedLocale_ForEnglish_ReturnsEnglishLocale() {
        XCTAssertEqual(AppLanguage.english.resolvedLocale.identifier, "en")
    }

    /// 明示選択した日本語設定が日本語 Locale を返す
    func testResolvedLocale_ForJapanese_ReturnsJapaneseLocale() {
        XCTAssertEqual(AppLanguage.japanese.resolvedLocale.identifier, "ja")
    }

    /// 固定表示名が期待どおりである
    func testDisplayName_ForExplicitLanguages_ReturnsNativeNames() {
        XCTAssertEqual(AppLanguage.english.displayName, "English")
        XCTAssertEqual(AppLanguage.japanese.displayName, "日本語")
    }

    /// system 表示名がローカライズキー未解決ではない
    func testSystemDisplayName_IsLocalized() {
        let displayName = AppLanguage.system.displayName
        XCTAssertFalse(displayName.isEmpty)
        XCTAssertNotEqual(displayName, "settings.language.system")

        let currentAppLanguageLabel = AppLanguage.currentAppLanguageLabel
        XCTAssertFalse(currentAppLanguageLabel.isEmpty)
    }
}
