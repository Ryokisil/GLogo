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

    // MARK: - カテゴリ整合性

    /// 全カテゴリにStandard側で少なくとも1つのプリセットが存在することを検証する
    func testAllCategoriesHaveStandardPresets() {
        for category in FilterCategory.allCases {
            let presets = FilterCatalog.presets(for: category)
            XCTAssertFalse(presets.isEmpty, "Standardカテゴリ \(category.rawValue) にプリセットがない")
        }
    }

    /// 全カテゴリにHDR側で少なくとも1つのプリセットが存在することを検証する
    func testAllCategoriesHaveHDRPresets() {
        for category in FilterCategory.allCases {
            let presets = HDRFilterCatalog.presets(for: category)
            XCTAssertFalse(presets.isEmpty, "HDRカテゴリ \(category.rawValue) にプリセットがない")
        }
    }

    /// Standard/HDR 間でプリセットIDが衝突しないことを検証する
    func testStandardAndHDRPresetIDsDoNotCollide() {
        let sdrIds = Set(FilterCatalog.allPresets.map(\.id))
        let hdrIds = Set(HDRFilterCatalog.allPresets.map(\.id))
        let collision = sdrIds.intersection(hdrIds)
        XCTAssertTrue(collision.isEmpty, "Standard/HDR間でプリセットIDが衝突している: \(collision)")
    }

    // MARK: - 新規プリセット存在確認

    /// portrait / mood カテゴリの新規SDRプリセットが存在し、IDが一意であることを検証する
    func testNewStandardPresetsExist() {
        let expectedIds: Set<String> = [
            "soft_portrait", "clean_portrait", "warm_portrait",
            "glow_portrait", "studio_portrait", "peach_portrait",
            "pastel_air", "rose_haze", "cool_calm",
            "cloud", "blush", "lilac", "mint", "mist"
        ]
        let actualIds = Set(FilterCatalog.allPresets.map(\.id))
        for id in expectedIds {
            XCTAssertTrue(actualIds.contains(id), "Standard新規プリセット \(id) が見つからない")
        }
    }

    /// portrait / mood カテゴリの新規HDRプリセットが存在し、hdr_接頭辞を持つことを検証する
    func testNewHDRPresetsExist() {
        let expectedIds: Set<String> = [
            "hdr_soft_portrait", "hdr_clean_portrait", "hdr_warm_portrait",
            "hdr_glow_portrait", "hdr_studio_portrait", "hdr_peach_portrait",
            "hdr_pastel_air", "hdr_rose_haze", "hdr_cool_calm",
            "hdr_cloud", "hdr_blush", "hdr_lilac", "hdr_mint", "hdr_mist"
        ]
        let actualIds = Set(HDRFilterCatalog.allPresets.map(\.id))
        for id in expectedIds {
            XCTAssertTrue(actualIds.contains(id), "HDR新規プリセット \(id) が見つからない")
        }
    }
}
