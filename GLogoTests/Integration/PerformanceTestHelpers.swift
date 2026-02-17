//
//  PerformanceTestHelpers.swift
//  GLogoTests
//
//  概要:
//  NFRパフォーマンステスト全体で共有するヘルパー群。
//  テスト画像生成・HEIC変換・P95算出・閾値チェック・端末クラス判定を提供する。
//

import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers

// MARK: - 端末クラス定義

/// 端末クラス。環境変数 PERF_DEVICE_CLASS=A または B で切替可能。
enum PerfDeviceClass {
    /// 高性能端末（A12 Bionic以降など）
    case a
    /// 標準端末（A11世代相当など）
    case b

    /// 環境変数から現在の端末クラスを解決
    static var current: PerfDeviceClass {
        let env = ProcessInfo.processInfo.environment["PERF_DEVICE_CLASS"] ?? "A"
        return env.uppercased() == "B" ? .b : .a
    }
}

// MARK: - NFR閾値定義

/// NFR暫定閾値（端末クラス別）
struct NFRThresholds {
    // MARK: - Properties

    /// プレビューレイテンシ上限（SDR）
    let previewSDR: TimeInterval
    /// プレビューレイテンシ上限（HDR）
    let previewHDR: TimeInterval
    /// 4Kセーブレイテンシ上限（SDR）
    let save4KSDR: TimeInterval
    /// 4Kセーブレイテンシ上限（HDR）
    let save4KHDR: TimeInterval
    /// 8Kセーブレイテンシ上限（SDR）
    let save8KSDR: TimeInterval
    /// 8Kセーブレイテンシ上限（HDR）
    let save8KHDR: TimeInterval

    // MARK: - Factory

    /// 現在の端末クラスに対応する閾値セットを返す
    static func forCurrentDevice() -> NFRThresholds {
        // 現在の暫定NFRでは preview/save の閾値は ClassA/B 共通。
        // 必要になった時点で ClassB 専用値へ分岐する。
        _ = PerfDeviceClass.current
        return NFRThresholds(
            previewSDR: 0.100,
            previewHDR: 0.140,
            save4KSDR: 2.500,
            save4KHDR: 3.200,
            save8KSDR: 6.000,
            save8KHDR: 7.000
        )
    }
}

// MARK: - テスト画像生成ヘルパー

/// パフォーマンステスト用の画像変換エラー
enum PerformanceTestError: Error {
    case cgImageUnavailable
    case heicDestinationUnavailable
    case heicFinalizeFailed
}

/// テスト用画像生成・変換ユーティリティ
enum PerformanceTestHelper {
    /// 指定サイズのUIImageを生成（グラデーション）
    /// - Parameter size: 画像サイズ
    /// - Returns: 生成されたUIImage
    static func makeTestImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            let colors = [UIColor.systemRed.cgColor, UIColor.systemBlue.cgColor] as CFArray
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: nil
            ) else {
                UIColor.darkGray.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                return
            }
            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )
        }
    }

    /// UIImageをHEICデータに変換
    /// - Parameter image: 入力UIImage
    /// - Returns: HEICエンコード済みData
    static func makeHEICData(from image: UIImage) throws -> Data {
        guard let cgImage = image.cgImage else {
            throw PerformanceTestError.cgImageUnavailable
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else {
            throw PerformanceTestError.heicDestinationUnavailable
        }
        let properties = [kCGImageDestinationLossyCompressionQuality: 1.0] as CFDictionary
        CGImageDestinationAddImage(destination, cgImage, properties)
        guard CGImageDestinationFinalize(destination) else {
            throw PerformanceTestError.heicFinalizeFailed
        }
        return data as Data
    }

    /// 指定サイズのHEICデータを生成
    /// - Parameter size: 画像サイズ
    /// - Returns: HEICエンコード済みData
    static func makeHEICData(size: CGSize) throws -> Data {
        try makeHEICData(from: makeTestImage(size: size))
    }
}

// MARK: - P95算出

/// P95（95パーセンタイル）算出ユーティリティ
enum PerformanceP95 {
    /// サンプル列からP95を算出
    /// - Parameter samples: 計測サンプル列（秒単位）
    /// - Returns: 95パーセンタイル値
    static func compute(_ samples: [TimeInterval]) -> TimeInterval {
        guard !samples.isEmpty else { return 0 }
        let sorted = samples.sorted()
        let idx = Int(ceil(0.95 * Double(sorted.count))) - 1
        return sorted[max(0, idx)]
    }
}

// MARK: - XCTestCase拡張

extension XCTestCase {
    /// 指定ブロックをN回計測し、P95が閾値以内か検証する
    ///
    /// 失敗時はP95値・閾値・サンプル一覧をメッセージに出力する。
    /// - Parameters:
    ///   - label: テストラベル（エラーメッセージ用）
    ///   - iterations: 計測回数（デフォルト10回）
    ///   - threshold: P95の許容上限（秒）
    ///   - block: 計測対象ブロック
    /// - Returns: 実測P95値（秒）
    @discardableResult
    func assertP95(
        label: String,
        iterations: Int = 10,
        threshold: TimeInterval,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: () throws -> Void
    ) -> TimeInterval {
        guard iterations > 0 else {
            XCTFail("[\(label)] iterations は 1 以上を指定してください", file: file, line: line)
            return 0
        }

        var samples: [TimeInterval] = []
        samples.reserveCapacity(iterations)

        for _ in 0..<iterations {
            let start = CFAbsoluteTimeGetCurrent()
            do {
                try block()
            } catch {
                XCTFail("[\(label)] 計測中にエラー: \(error)", file: file, line: line)
                return 0
            }
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            samples.append(elapsed)
        }

        let p95 = PerformanceP95.compute(samples)
        let avg = samples.reduce(0, +) / Double(samples.count)
        let samplesStr = samples
            .map { String(format: "%.0fms", $0 * 1000) }
            .joined(separator: ", ")

        if p95 > threshold {
            XCTFail(
                """
                [\(label)] P95 超過
                  計測: \(String(format: "%.0fms", p95 * 1000)) > 閾値: \(String(format: "%.0fms", threshold * 1000))
                  平均: \(String(format: "%.0fms", avg * 1000))
                  サンプル(\(iterations)回): [\(samplesStr)]
                """,
                file: file,
                line: line
            )
        }

        return p95
    }
}
