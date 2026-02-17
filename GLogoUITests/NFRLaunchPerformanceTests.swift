//
//  NFRLaunchPerformanceTests.swift
//  GLogoUITests
//
//  概要:
//  NFR向けコールドスタートレイテンシ検証テスト。
//  XCUIApplicationを使用してアプリ起動時間のP95を計測し閾値と比較する。
//
//  閾値:
//    ClassA端末: 2.5秒以内
//    ClassB端末: 3.5秒以内
//  切替方法: 環境変数 PERF_DEVICE_CLASS=A/B（未設定時はAとして扱う）
//

import XCTest

/// NFR向けコールドスタートレイテンシ検証テスト
final class NFRLaunchPerformanceTests: XCTestCase {

    // MARK: - Properties

    /// コールドスタート計測回数
    private let sampleCount = 10

    // MARK: - Setup

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - コールドスタートレイテンシ

    /// システムメトリクス（XCTApplicationLaunchMetric）で起動性能を継続計測
    ///
    /// 閾値判定は `testColdStartLatency_P95` が担い、このテストは
    /// Xcodeの標準メトリクス履歴を追跡するために使用する。
    @MainActor
    func testColdStartLatency_SystemMetric() {
        let options = XCTMeasureOptions()
        options.iterationCount = sampleCount

        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)], options: options) {
            XCUIApplication().launch()
        }
    }

    /// コールドスタートレイテンシのP95が閾値以内であることを検証
    ///
    /// app.launch() は applicationDidFinishLaunching 完了後に返るため、
    /// コールドスタートの実用的な指標として使用する。
    @MainActor
    func testColdStartLatency_P95() {
        let app = XCUIApplication()
        let threshold = launchThreshold()

        var timings: [TimeInterval] = []
        timings.reserveCapacity(sampleCount)

        // ウォームアップ（初回起動コストを除外）
        app.terminate()
        app.launch()
        app.terminate()

        for _ in 0..<sampleCount {
            // コールドスタートを保証するために事前終了
            app.terminate()

            let start = CFAbsoluteTimeGetCurrent()
            app.launch()
            let elapsed = CFAbsoluteTimeGetCurrent() - start

            timings.append(elapsed)
            app.terminate()
        }

        guard !timings.isEmpty else {
            XCTFail("起動計測サンプルが取得できませんでした")
            return
        }

        let p95 = computeP95(timings)
        let avg = timings.reduce(0, +) / Double(timings.count)
        let samplesStr = timings
            .map { String(format: "%.0fms", $0 * 1000) }
            .joined(separator: ", ")

        XCTAssertLessThanOrEqual(
            p95,
            threshold,
            """
            [コールドスタート] P95 超過
              計測: \(String(format: "%.0fms", p95 * 1000)) > 閾値: \(String(format: "%.0fms", threshold * 1000))
              平均: \(String(format: "%.0fms", avg * 1000))
              端末クラス: \(currentDeviceClass())
              サンプル(\(sampleCount)回): [\(samplesStr)]
            """
        )
    }

    // MARK: - Private Helpers

    /// P95を算出（UITestターゲット内でのインライン実装）
    /// - Parameter samples: 計測サンプル列（秒単位）
    /// - Returns: 95パーセンタイル値
    private func computeP95(_ samples: [TimeInterval]) -> TimeInterval {
        let sorted = samples.sorted()
        let idx = Int(ceil(0.95 * Double(sorted.count))) - 1
        return sorted[max(0, idx)]
    }

    /// 環境変数から端末クラスを解決し対応する起動閾値を返す
    /// - Returns: 許容起動時間上限（秒）
    private func launchThreshold() -> TimeInterval {
        switch currentDeviceClass() {
        case "B":
            return 3.500  // ClassB端末: 3.5秒
        default:
            return 2.500  // ClassA端末: 2.5秒
        }
    }

    /// 環境変数から端末クラス文字列を取得
    private func currentDeviceClass() -> String {
        let env = ProcessInfo.processInfo.environment["PERF_DEVICE_CLASS"] ?? "A"
        return env.uppercased()
    }
}
