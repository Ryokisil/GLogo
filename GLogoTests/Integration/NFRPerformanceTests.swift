//
//  NFRPerformanceTests.swift
//  GLogoTests
//
//  概要:
//  NFR（非機能要件）向けパフォーマンス検証テスト。
//  4K/8Kプレビュー・セーブのレイテンシP95とメモリ使用量を計測し閾値を検証する。
//
//  実行コマンド例:
//    通常実行（4Kのみ）:
//      xcodebuild -project GLogo.xcodeproj -scheme GLogo \
//        -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
//        -only-testing:GLogoTests/NFRPerformanceTests \
//        CODE_SIGNING_ALLOWED=NO test
//
//    8K有効化:
//      PERF_RUN_8K=1 xcodebuild ... test
//
//    ClassB端末として実行:
//      PERF_DEVICE_CLASS=B xcodebuild ... test
//

import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import GLogo

/// NFR向けパフォーマンス検証テスト（4K/8K Preview・Save・メモリ）
final class NFRPerformanceTests: XCTestCase {

    // MARK: - Properties

    private var thresholds: NFRThresholds!

    /// 4K解像度
    private let size4K = CGSize(width: 3840, height: 2160)
    /// 8K解像度
    private let size8K = CGSize(width: 7680, height: 4320)

    /// P95計測のサンプル数
    private let sampleCount = 10

    /// フィルター付き計測用パラメータ（プレビュー・セーブ共通）
    private var baseParams: ImageFilterParams {
        ImageFilterParams(
            toneCurveData: ToneCurveData(),
            saturation: 1.2,
            brightness: 0.1,
            contrast: 1.1,
            highlights: 0.0,
            shadows: 0.0,
            hue: 0.0,
            sharpness: 0.0,
            gaussianBlurRadius: 0.0,
            tintColor: nil,
            tintIntensity: 0.0
        )
    }

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        thresholds = NFRThresholds.forCurrentDevice()
    }

    // MARK: - プレビューレイテンシ SDR 4K

    /// 4K SDRプレビューレイテンシのP95が閾値以内であることを検証
    func testPreviewLatencySDR_4K_P95() {
        let image = PerformanceTestHelper.makeTestImage(size: size4K)
        let service = ImagePreviewService()
        let params = baseParams

        // ウォームアップ（JITコンパイル・初回初期化コストを除外）
        _ = service.applyFilters(to: image, params: params, quality: .preview, mode: .sdr)

        assertP95(
            label: "Preview SDR 4K",
            iterations: sampleCount,
            threshold: thresholds.previewSDR
        ) {
            _ = service.applyFilters(to: image, params: params, quality: .preview, mode: .sdr)
        }
    }

    // MARK: - プレビューレイテンシ HDR 4K

    /// 4K HDRプレビューレイテンシのP95が閾値以内であることを検証
    /// HDR経路は mode: .hdr を明示的に指定して通す
    func testPreviewLatencyHDR_4K_P95() {
        let image = PerformanceTestHelper.makeTestImage(size: size4K)
        let service = ImagePreviewService()
        let params = baseParams

        // ウォームアップ
        _ = service.applyFilters(to: image, params: params, quality: .preview, mode: .hdr)

        assertP95(
            label: "Preview HDR 4K",
            iterations: sampleCount,
            threshold: thresholds.previewHDR
        ) {
            _ = service.applyFilters(to: image, params: params, quality: .preview, mode: .hdr)
        }
    }

    // MARK: - セーブレイテンシ SDR 4K

    /// 4K SDRセーブレイテンシ（フル品質フィルター + HEICエンコード）のP95が閾値以内であることを検証
    func testSaveLatencySDR_4K_P95() {
        let image = PerformanceTestHelper.makeTestImage(size: size4K)
        let service = ImagePreviewService()
        let params = baseParams

        // ウォームアップ
        _ = service.applyFilters(to: image, params: params, quality: .full, mode: .sdr)

        assertP95(
            label: "Save SDR 4K",
            iterations: sampleCount,
            threshold: thresholds.save4KSDR
        ) {
            guard let processed = service.applyFilters(
                to: image, params: params, quality: .full, mode: .sdr
            ) else {
                XCTFail("SDR 4K フィルター適用に失敗")
                return
            }
            _ = try PerformanceTestHelper.makeHEICData(from: processed)
        }
    }

    // MARK: - セーブレイテンシ HDR 4K

    /// 4K HDRセーブレイテンシ（フル品質フィルター + HEICエンコード）のP95が閾値以内であることを検証
    func testSaveLatencyHDR_4K_P95() {
        let image = PerformanceTestHelper.makeTestImage(size: size4K)
        let service = ImagePreviewService()
        let params = baseParams

        // ウォームアップ
        _ = service.applyFilters(to: image, params: params, quality: .full, mode: .hdr)

        assertP95(
            label: "Save HDR 4K",
            iterations: sampleCount,
            threshold: thresholds.save4KHDR
        ) {
            guard let processed = service.applyFilters(
                to: image, params: params, quality: .full, mode: .hdr
            ) else {
                XCTFail("HDR 4K フィルター適用に失敗")
                return
            }
            _ = try PerformanceTestHelper.makeHEICData(from: processed)
        }
    }

    // MARK: - セーブレイテンシ SDR 8K（オプトイン）

    /// 8K SDRセーブレイテンシのP95が閾値以内であることを検証
    /// 環境変数 PERF_RUN_8K=1 の場合のみ実行する
    func testSaveLatencySDR_8K_P95() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["PERF_RUN_8K"] == "1",
            "PERF_RUN_8K=1 が設定されていないためスキップ"
        )

        let image = PerformanceTestHelper.makeTestImage(size: size8K)
        let service = ImagePreviewService()
        let params = baseParams

        // ウォームアップ
        _ = service.applyFilters(to: image, params: params, quality: .full, mode: .sdr)

        assertP95(
            label: "Save SDR 8K",
            iterations: sampleCount,
            threshold: thresholds.save8KSDR
        ) {
            guard let processed = service.applyFilters(
                to: image, params: params, quality: .full, mode: .sdr
            ) else {
                XCTFail("SDR 8K フィルター適用に失敗")
                return
            }
            _ = try PerformanceTestHelper.makeHEICData(from: processed)
        }
    }

    // MARK: - セーブレイテンシ HDR 8K（オプトイン）

    /// 8K HDRセーブレイテンシのP95が閾値以内であることを検証
    /// 環境変数 PERF_RUN_8K=1 の場合のみ実行する
    func testSaveLatencyHDR_8K_P95() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["PERF_RUN_8K"] == "1",
            "PERF_RUN_8K=1 が設定されていないためスキップ"
        )

        let image = PerformanceTestHelper.makeTestImage(size: size8K)
        let service = ImagePreviewService()
        let params = baseParams

        // ウォームアップ
        _ = service.applyFilters(to: image, params: params, quality: .full, mode: .hdr)

        assertP95(
            label: "Save HDR 8K",
            iterations: sampleCount,
            threshold: thresholds.save8KHDR
        ) {
            guard let processed = service.applyFilters(
                to: image, params: params, quality: .full, mode: .hdr
            ) else {
                XCTFail("HDR 8K フィルター適用に失敗")
                return
            }
            _ = try PerformanceTestHelper.makeHEICData(from: processed)
        }
    }

    // MARK: - メモリ使用量 SDR 4K プレビュー

    /// 4K SDRプレビュー生成時のメモリ使用量を計測
    func testMemoryUsage_PreviewSDR_4K() {
        let image = PerformanceTestHelper.makeTestImage(size: size4K)
        let service = ImagePreviewService()
        let params = baseParams
        let options = XCTMeasureOptions()
        options.iterationCount = sampleCount

        measure(metrics: [XCTMemoryMetric()], options: options) {
            _ = service.applyFilters(to: image, params: params, quality: .preview, mode: .sdr)
        }
    }

    // MARK: - メモリ使用量 HDR 4K プレビュー

    /// 4K HDRプレビュー生成時のメモリ使用量を計測
    func testMemoryUsage_PreviewHDR_4K() {
        let image = PerformanceTestHelper.makeTestImage(size: size4K)
        let service = ImagePreviewService()
        let params = baseParams
        let options = XCTMeasureOptions()
        options.iterationCount = sampleCount

        measure(metrics: [XCTMemoryMetric()], options: options) {
            _ = service.applyFilters(to: image, params: params, quality: .preview, mode: .hdr)
        }
    }
}
