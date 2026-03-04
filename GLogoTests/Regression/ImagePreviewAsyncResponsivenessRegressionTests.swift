//
//  ImagePreviewAsyncResponsivenessRegressionTests.swift
//  GLogoTests
//
//  概要:
//  ImagePreviewService の async 経路が MainActor をブロックしないことを検証する回帰テスト。
//  Swift 6 移行時の同期化退行を検知する。
//

import XCTest
import UIKit
@testable import GLogo

/// 画像プレビュー async 経路の応答性回帰テスト
final class ImagePreviewAsyncResponsivenessRegressionTests: XCTestCase {
    /// SDR の async フィルタ適用中に main queue が処理できることを確認
    /// - Parameters: なし
    /// - Returns: なし
    @MainActor
    func testSDRApplyFiltersAsync_DoesNotBlockMainQueue() {
        let service = SDRImagePreviewService()
        let image = makeLargeImage(color: .systemPink)
        let params = makeHeavyParams()

        assertMainQueueResponsive {
            _ = await service.applyFiltersAsync(
                to: image,
                params: params,
                quality: .full,
                mode: .sdr
            )
        }
    }

    /// HDR の async フィルタ適用中に main queue が処理できることを確認
    /// - Parameters: なし
    /// - Returns: なし
    @MainActor
    func testHDRApplyFiltersAsync_DoesNotBlockMainQueue() {
        let service = HDRImagePreviewService()
        let image = makeLargeImage(color: .systemTeal)
        let params = makeHeavyParams()

        assertMainQueueResponsive {
            _ = await service.applyFiltersAsync(
                to: image,
                params: params,
                quality: .full,
                mode: .hdr
            )
        }
    }

    // MARK: - Helpers

    /// MainActor 実行中に main queue が詰まらないことを検証
    /// - Parameters:
    ///   - operation: 検証対象の async 処理
    /// - Returns: なし
    @MainActor
    private func assertMainQueueResponsive(operation: @escaping @MainActor () async -> Void) {
        let started = expectation(description: "operation started")
        let finished = expectation(description: "operation finished")

        Task { @MainActor in
            started.fulfill()
            await operation()
            finished.fulfill()
        }

        wait(for: [started], timeout: 1.0)

        let mainQueueResponsive = expectation(description: "main queue remained responsive")
        DispatchQueue.main.async {
            mainQueueResponsive.fulfill()
        }

        wait(for: [mainQueueResponsive], timeout: 0.25)
        wait(for: [finished], timeout: 10.0)
    }

    /// 処理負荷が比較的高いテスト画像を生成
    /// - Parameters:
    ///   - color: 塗りつぶし色
    /// - Returns: 大きめの単色画像
    private func makeLargeImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 4032, height: 3024)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// 負荷確認用フィルターパラメータを生成
    /// - Parameters: なし
    /// - Returns: 高品質経路で利用するフィルターパラメータ
    private func makeHeavyParams() -> ImageFilterParams {
        ImageFilterParams(
            toneCurveData: ToneCurveData(),
            saturation: 1.15,
            brightness: 0.08,
            contrast: 1.20,
            highlights: 0.12,
            shadows: 0.10,
            hue: 12.0,
            sharpness: 0.30,
            gaussianBlurRadius: 6.0,
            vignetteIntensity: 0.25,
            bloomIntensity: 0.18,
            grainIntensity: 0.12,
            fadeIntensity: 0.08,
            chromaticAberrationIntensity: 0.10,
            tintColor: UIColor.orange,
            tintIntensity: 0.15
        )
    }
}

