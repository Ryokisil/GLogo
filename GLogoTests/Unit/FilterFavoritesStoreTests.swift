//
//  FilterFavoritesStoreTests.swift
//  GLogoTests
//
//  概要:
//  FilterFavoritesStore の保存・読み出し・toggle の単体テスト。
//  SDR/HDR の独立管理も検証する。
//

import XCTest
@testable import GLogo

final class FilterFavoritesStoreTests: XCTestCase {

    /// テスト用に分離した UserDefaults
    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "FilterFavoritesStoreTests")!
        testDefaults.removePersistentDomain(forName: "FilterFavoritesStoreTests")
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: "FilterFavoritesStoreTests")
        testDefaults = nil
        super.tearDown()
    }

    // MARK: - 初期状態

    /// 初回起動時はお気に入りが空
    func testInitialState_isEmpty() {
        let store = FilterFavoritesStore(defaults: testDefaults)
        XCTAssertTrue(store.loadFavoriteIds().isEmpty)
    }

    // MARK: - toggle

    /// toggle で追加できる
    func testToggle_addsPresetId() {
        var store = FilterFavoritesStore(defaults: testDefaults)
        let result = store.toggle("vintage_warm")
        XCTAssertTrue(result.contains("vintage_warm"))
    }

    /// toggle を2回呼ぶと解除される
    func testToggle_twice_removesPresetId() {
        var store = FilterFavoritesStore(defaults: testDefaults)
        store.toggle("vintage_warm")
        let result = store.toggle("vintage_warm")
        XCTAssertFalse(result.contains("vintage_warm"))
    }

    /// toggle 結果が UserDefaults に永続化される
    func testToggle_persistsToUserDefaults() {
        var store = FilterFavoritesStore(defaults: testDefaults)
        store.toggle("vivid")

        // 別インスタンスで読み直し
        let store2 = FilterFavoritesStore(defaults: testDefaults)
        XCTAssertTrue(store2.isFavorite("vivid"))
    }

    // MARK: - isFavorite

    /// 未登録プリセットは isFavorite = false
    func testIsFavorite_returnsFalse_forUnregistered() {
        let store = FilterFavoritesStore(defaults: testDefaults)
        XCTAssertFalse(store.isFavorite("nonexistent"))
    }

    // MARK: - SDR / HDR 独立管理

    /// SDR の vintage_warm と HDR の hdr_vintage_warm が独立管理される
    func testSDRAndHDR_independentFavorites() {
        var store = FilterFavoritesStore(defaults: testDefaults)
        store.toggle("vintage_warm")

        XCTAssertTrue(store.isFavorite("vintage_warm"), "SDR 側がお気に入り")
        XCTAssertFalse(store.isFavorite("hdr_vintage_warm"), "HDR 側は影響なし")
    }

    /// HDR 側だけお気に入りにしても SDR には影響しない
    func testHDROnly_doesNotAffectSDR() {
        var store = FilterFavoritesStore(defaults: testDefaults)
        store.toggle("hdr_vintage_warm")

        XCTAssertTrue(store.isFavorite("hdr_vintage_warm"), "HDR 側がお気に入り")
        XCTAssertFalse(store.isFavorite("vintage_warm"), "SDR 側は影響なし")
    }

    // MARK: - favorites(from:)

    /// favorites(from:) がお気に入り登録済みのプリセットのみ返す
    func testFavoritesFrom_filtersCorrectly() {
        var store = FilterFavoritesStore(defaults: testDefaults)
        store.toggle("vivid")
        store.toggle("noir")

        let result = store.favorites(from: FilterCatalog.allPresets)
        let ids = result.map(\.id)
        XCTAssertTrue(ids.contains("vivid"))
        XCTAssertTrue(ids.contains("noir"))
        XCTAssertFalse(ids.contains("natural"))
    }
}
