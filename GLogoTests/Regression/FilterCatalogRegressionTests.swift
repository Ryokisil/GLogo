//
//  FilterCatalogRegressionTests.swift
//  GLogoTests
//
//  概要:
//  Standard/HDR のフィルターカタログ構成が将来変更で崩れないことを検証する回帰テスト。
//

import XCTest
@testable import GLogo

/// フィルターカタログの不変条件を検証する回帰テスト
final class FilterCatalogRegressionTests: XCTestCase {

    // MARK: - Standard

    /// StandardプリセットIDの重複を検出し、ID衝突による選択不整合を防ぐ
    /// - Parameters: なし
    /// - Returns: なし
    func testStandardCatalogPresetIDsAreUnique() {
        let ids = FilterCatalog.allPresets.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "StandardプリセットIDは重複してはいけない")
    }

    /// Standardのカテゴリ取得結果がallPresets定義順・所属と一致することを担保する
    /// - Parameters: なし
    /// - Returns: なし
    func testStandardCatalogPresetsForCategoryAreConsistent() {
        for category in FilterCategory.allCases {
            let expected = FilterCatalog.allPresets.filter { $0.category == category }.map(\.id)
            let actual = FilterCatalog.presets(for: category).map(\.id)
            XCTAssertEqual(actual, expected, "カテゴリ \(category.rawValue) の取得結果がallPresets定義と一致しない")
        }
    }

    // MARK: - HDR

    /// HDRプリセットのID重複とhdr_接頭辞規約を同時に検証し、SDR/HDR経路判定の破綻を防ぐ
    /// - Parameters: なし
    /// - Returns: なし
    func testHDRCatalogPresetIDsAreUniqueAndPrefixed() {
        let ids = HDRFilterCatalog.allPresets.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "HDRプリセットIDは重複してはいけない")
        XCTAssertTrue(ids.allSatisfy { $0.hasPrefix("hdr_") }, "HDRプリセットIDはhdr_接頭辞を持つ必要がある")
    }

    /// HDRのカテゴリ取得結果がallPresets定義順・所属と一致することを担保する
    /// - Parameters: なし
    /// - Returns: なし
    func testHDRCatalogPresetsForCategoryAreConsistent() {
        for category in HDRFilterCatalog.categories {
            let expected = HDRFilterCatalog.allPresets.filter { $0.category == category }.map(\.id)
            let actual = HDRFilterCatalog.presets(for: category).map(\.id)
            XCTAssertEqual(actual, expected, "HDRカテゴリ \(category.rawValue) の取得結果がallPresets定義と一致しない")
        }
    }
}
