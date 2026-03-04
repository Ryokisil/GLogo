//
//  HDRToneCurveFilter.swift
//  GLogo
//
//  概要:
//  Display P3色空間でCIColorCubeWithColorSpaceを用いてトーンカーブを適用するヘルパー。
//  SDR版ToneCurveFilterと同構造だが、LUTのinputColorSpaceにP3を使用する。
//  MonotonicCubicInterpolatorで補間したカーブをLUT化して適用する。

import Foundation
import UIKit
import CoreImage

/// HDR用トーンカーブフィルター適用ユーティリティ（Display P3色空間）
class HDRToneCurveFilter {

    /// LUTキャッシュの排他制御つきストア
    private final class LUTCache: @unchecked Sendable {
        private let lock = NSLock()
        private let maxEntries: Int
        private var storage: [String: Data] = [:]

        init(maxEntries: Int) {
            self.maxEntries = maxEntries
        }

        func value(for key: String) -> Data? {
            lock.lock()
            defer { lock.unlock() }
            return storage[key]
        }

        /// 値を保存し、上限超過で削除が発生したら `true` を返す
        func insert(_ data: Data, for key: String) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            storage[key] = data
            guard storage.count > maxEntries, let firstKey = storage.keys.first else {
                return false
            }
            storage.removeValue(forKey: firstKey)
            return true
        }

        func clear() {
            lock.lock()
            storage.removeAll()
            lock.unlock()
        }
    }

    // MARK: - 定数

    /// 3D LUTのキューブ次元
    private static let fullCubeDimension = 64
    private static let previewCubeDimension = 16

    // MARK: - 共有リソース

    /// P3用共有CIContext
    private static let sharedContext: CIContext = RenderContext.hdr.ciContext

    /// P3色空間
    private static let p3ColorSpace: CGColorSpace = RenderContext.hdr.colorSpace

    /// LUTキャッシュ（SDRキャッシュとは独立）
    private static let lutCache = LUTCache(maxEntries: 10)

    // MARK: - 公開メソッド

    /// トーンカーブを画像に適用
    /// - Parameters:
    ///   - image: 元画像
    ///   - curveData: トーンカーブデータ
    ///   - quality: レンダリング品質
    /// - Returns: フィルター適用済み画像（失敗時はnil）
    static func apply(to image: UIImage, curveData: ToneCurveData, quality: ToneCurveFilter.Quality = .full) -> UIImage? {
        let startTime = CFAbsoluteTimeGetCurrent()

        guard let cgImage = image.cgImage else {
            print("⚠️ [HDRToneCurve] CGImageの取得に失敗")
            return nil
        }

        let ciImage = CIImage(
            cgImage: cgImage,
            options: [.colorSpace: p3ColorSpace]
        )

        guard let processedCIImage = applyCubeFilter(to: ciImage, curveData: curveData, quality: quality) else {
            print("⚠️ [HDRToneCurve] フィルター適用に失敗")
            return nil
        }

        guard let outputCGImage = sharedContext.createCGImage(processedCIImage, from: processedCIImage.extent) else {
            print("⚠️ [HDRToneCurve] CGImage生成に失敗")
            return nil
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        #if DEBUG
        print("✅ [HDRToneCurve] 処理完了 (\(String(format: "%.0fms", elapsed * 1000)))")
        #endif

        return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - CIImage用メソッド

    /// CIImageにトーンカーブを適用（P3色空間）
    /// - Parameters:
    ///   - ciImage: 元CIImage
    ///   - curveData: トーンカーブデータ
    ///   - quality: レンダリング品質
    /// - Returns: フィルター適用済みCIImage（失敗時はnil）
    static func applyCurve(to ciImage: CIImage, curveData: ToneCurveData, quality: ToneCurveFilter.Quality = .full) -> CIImage? {
        return applyCubeFilter(to: ciImage, curveData: curveData, quality: quality)
    }

    // MARK: - プライベートメソッド

    /// CIColorCubeWithColorSpaceフィルターを適用（P3色空間）
    private static func applyCubeFilter(to ciImage: CIImage, curveData: ToneCurveData, quality: ToneCurveFilter.Quality) -> CIImage? {
        let cubeStartTime = CFAbsoluteTimeGetCurrent()

        // すべてのカーブがデフォルト状態かチェック
        if isDefaultCurve(curveData.rgbPoints) &&
           isDefaultCurve(curveData.redPoints) &&
           isDefaultCurve(curveData.greenPoints) &&
           isDefaultCurve(curveData.bluePoints) {
            return ciImage
        }

        // 3D LUTを生成
        guard let cubeData = createColorCube(from: curveData, quality: quality) else {
            print("⚠️ [HDRToneCurve] 3D LUT生成に失敗")
            return nil
        }

        let cubeElapsed = CFAbsoluteTimeGetCurrent() - cubeStartTime

        #if DEBUG
        print("📊 [HDRToneCurve] 3D LUT生成完了 (\(String(format: "%.0fms", cubeElapsed * 1000)))")
        #endif

        // CIColorCubeWithColorSpaceフィルターを適用（P3色空間を指定）
        let filter = CIFilter(
            name: "CIColorCubeWithColorSpace",
            parameters: [
                "inputImage": ciImage,
                "inputCubeDimension": cubeDimension(for: quality),
                "inputCubeData": cubeData,
                "inputColorSpace": p3ColorSpace
            ]
        )

        guard let outputImage = filter?.outputImage else {
            print("⚠️ [HDRToneCurve] フィルター出力の取得に失敗")
            return nil
        }

        return outputImage
    }

    /// トーンカーブデータから3D LUTを生成（キャッシュ対応）
    private static func createColorCube(from curveData: ToneCurveData, quality: ToneCurveFilter.Quality) -> Data? {
        let cacheKey = generateCacheKey(from: curveData, quality: quality)

        // キャッシュをチェック
        if let cachedLUT = lutCache.value(for: cacheKey) {
            #if DEBUG
            print("🎯 [HDRToneCurve] LUTキャッシュヒット")
            #endif
            return cachedLUT
        }

        #if DEBUG
        print("🔨 [HDRToneCurve] LUT新規生成（キャッシュミス）")
        #endif

        let dimension = cubeDimension(for: quality)
        let cubeSize = dimension * dimension * dimension * 4

        var cubeDataArray = [Float](repeating: 0, count: cubeSize)

        // MonotonicCubicInterpolatorを各チャンネル用に準備
        let rgbInterpolator = MonotonicCubicInterpolator(points: curveData.rgbPoints)
        let redInterpolator = MonotonicCubicInterpolator(points: curveData.redPoints)
        let greenInterpolator = MonotonicCubicInterpolator(points: curveData.greenPoints)
        let blueInterpolator = MonotonicCubicInterpolator(points: curveData.bluePoints)

        let rgbIsDefault = isDefaultCurve(curveData.rgbPoints)
        let redIsDefault = isDefaultCurve(curveData.redPoints)
        let greenIsDefault = isDefaultCurve(curveData.greenPoints)
        let blueIsDefault = isDefaultCurve(curveData.bluePoints)

        #if DEBUG
        print("📐 [HDRToneCurve] LUT生成開始: \(dimension)³ = \(dimension * dimension * dimension)エントリ")
        #endif

        // 3D LUTを構築（Blue → Green → Red の順）
        for blueIndex in 0..<dimension {
            for greenIndex in 0..<dimension {
                for redIndex in 0..<dimension {
                    let r = Float(redIndex) / Float(dimension - 1)
                    let g = Float(greenIndex) / Float(dimension - 1)
                    let b = Float(blueIndex) / Float(dimension - 1)

                    // 1. RGB全体のカーブを適用
                    var r1 = r
                    var g1 = g
                    var b1 = b

                    if !rgbIsDefault {
                        r1 = Float(rgbInterpolator.interpolate(at: CGFloat(r)))
                        g1 = Float(rgbInterpolator.interpolate(at: CGFloat(g)))
                        b1 = Float(rgbInterpolator.interpolate(at: CGFloat(b)))
                    }

                    // 2. 個別チャンネルのカーブを適用
                    var r2 = r1
                    var g2 = g1
                    var b2 = b1

                    if !redIsDefault {
                        r2 = Float(redInterpolator.interpolate(at: CGFloat(r1)))
                    }
                    if !greenIsDefault {
                        g2 = Float(greenInterpolator.interpolate(at: CGFloat(g1)))
                    }
                    if !blueIsDefault {
                        b2 = Float(blueInterpolator.interpolate(at: CGFloat(b1)))
                    }

                    // 3. 値をクランプ（0.0〜1.0）
                    r2 = max(0.0, min(1.0, r2))
                    g2 = max(0.0, min(1.0, g2))
                    b2 = max(0.0, min(1.0, b2))

                    // 4. LUT配列に格納
                    let offset = (blueIndex * dimension * dimension + greenIndex * dimension + redIndex) * 4
                    cubeDataArray[offset] = r2
                    cubeDataArray[offset + 1] = g2
                    cubeDataArray[offset + 2] = b2
                    cubeDataArray[offset + 3] = 1.0
                }
            }
        }

        let data = Data(bytes: &cubeDataArray, count: cubeSize * MemoryLayout<Float>.size)

        #if DEBUG
        print("✅ [HDRToneCurve] LUT生成完了: \(data.count / 1024)KB")
        #endif

        // キャッシュに保存
        let didEvict = lutCache.insert(data, for: cacheKey)
        if didEvict {
            #if DEBUG
            print("🗑️ [HDRToneCurve] LUTキャッシュ削除（上限到達）")
            #endif
        }

        return data
    }

    /// キャッシュキーを生成
    private static func generateCacheKey(from curveData: ToneCurveData, quality: ToneCurveFilter.Quality) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        if let jsonData = try? encoder.encode(curveData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return "hdr_\(jsonString.hashValue)_\(cubeDimension(for: quality))"
        }

        return "hdr_\(curveData.rgbPoints.count)_\(curveData.redPoints.count)_\(curveData.greenPoints.count)_\(curveData.bluePoints.count)_\(cubeDimension(for: quality))"
    }

    /// LUTキャッシュをクリア
    static func clearCache() {
        lutCache.clear()
        #if DEBUG
        print("🗑️ [HDRToneCurve] LUTキャッシュをクリア")
        #endif
    }

    /// 制御点がデフォルト状態（対角線）かチェック
    private static func isDefaultCurve(_ points: [CurvePoint]) -> Bool {
        let tolerance: CGFloat = 0.01
        for point in points {
            if abs(point.input - point.output) > tolerance {
                return false
            }
        }
        return true
    }

    /// 品質に応じたキューブ次元
    private static func cubeDimension(for quality: ToneCurveFilter.Quality) -> Int {
        switch quality {
        case .preview:
            return previewCubeDimension
        case .full:
            return fullCubeDimension
        }
    }
}
