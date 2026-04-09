//
//  FilterLocalizationTests.swift
//  GLogoTests
//
//  概要:
//  フィルタープリセット名とカテゴリ名のローカライズキーが
//  Localizable.xcstrings に存在し、実行ロケールで解決されることを検証する。
//

import XCTest
@testable import GLogo

/// フィルターローカライズの回帰テスト
final class FilterLocalizationTests: XCTestCase {

    // MARK: - カテゴリ表示名

    /// 全カテゴリのローカライズキーが Localizable に存在する
    func testCategoryLocalizationKeys_ExistInLocalizable() {
        let bundle = Bundle.main
        for category in FilterCategory.allCases {
            let resolved = bundle.localizedString(
                forKey: category.localizationKey,
                value: "##MISSING##",
                table: "Localizable"
            )
            XCTAssertNotEqual(resolved, "##MISSING##", "\(category.localizationKey) がローカライズファイルに存在しない")
            XCTAssertFalse(resolved.isEmpty, "\(category.localizationKey) の値が空")
        }
    }

    /// カテゴリの localizationKey が期待する形式を返す
    func testCategoryLocalizationKey_Format() {
        for category in FilterCategory.allCases {
            XCTAssertEqual(
                category.localizationKey,
                "filters.category.\(category.rawValue)",
                "localizationKey の形式が不正"
            )
        }
    }

    // MARK: - プリセット表示名

    /// 全 SDR プリセットのローカライズキーが Localizable に存在する
    func testSDRPresetLocalizationKeys_ExistInLocalizable() {
        let bundle = Bundle.main
        for preset in FilterCatalog.allPresets {
            let resolved = bundle.localizedString(
                forKey: preset.localizationKey,
                value: "##MISSING##",
                table: "Localizable"
            )
            XCTAssertNotEqual(resolved, "##MISSING##", "\(preset.localizationKey) がローカライズファイルに存在しない")
        }
    }

    /// 全 HDR プリセットのローカライズキーが Localizable に存在する
    func testHDRPresetLocalizationKeys_ExistInLocalizable() {
        let bundle = Bundle.main
        for preset in HDRFilterCatalog.allPresets {
            let resolved = bundle.localizedString(
                forKey: preset.localizationKey,
                value: "##MISSING##",
                table: "Localizable"
            )
            XCTAssertNotEqual(resolved, "##MISSING##", "\(preset.localizationKey) がローカライズファイルに存在しない")
        }
    }

    /// プリセットの localizationKey が期待する形式を返す
    func testPresetLocalizationKey_Format() {
        for preset in FilterCatalog.allPresets {
            XCTAssertEqual(preset.localizationKey, "filters.preset.\(preset.id)")
        }
        for preset in HDRFilterCatalog.allPresets {
            XCTAssertEqual(preset.localizationKey, "filters.preset.\(preset.id)")
        }
    }
}
