//
//  ToneCurveFilter.swift
//  GLogo
//
//  概要:
//  CIColorCubeWithColorSpaceを用いてトーンカーブを適用するヘルパー。
//  RGB／各チャンネルのカーブを統合した3D LUTを生成し、プレビュー（軽量LUT）とフル品質（64³）を切り替え可能。
//  MonotonicCubicInterpolatorで補間したカーブをLUT化して適用する。
//

import Foundation
import UIKit
import CoreImage

/// トーンカーブフィルター適用ユーティリティ
class ToneCurveFilter {

    enum Quality {
        case preview   // 軽量プレビュー用
        case full      // 保存・最終描画用
    }

    // MARK: - 定数

    /// 3D LUTのキューブ次元
    private static let fullCubeDimension = 64
    private static let previewCubeDimension = 16

    // MARK: - 共有リソース

    /// 共有CIContext（Core Image Programming Guide推奨: コンテキストの再利用）
    /// Contexts store a lot of state information; it's more efficient to reuse them.
    private static let sharedContext: CIContext = {
        let options: [CIContextOption: Any] = [
            .workingColorSpace: ImageFilterUtility.workingColorSpace, // sRGBで統一
            .outputColorSpace: ImageFilterUtility.workingColorSpace,
            .useSoftwareRenderer: false     // GPU使用
        ]
        return CIContext(options: options)
    }()

    /// LUTキャッシュ（ToneCurveDataをキーに生成済みLUTを保持）
    private static var lutCache: [String: Data] = [:]
    private static let lutCacheQueue = DispatchQueue(label: "com.gllogo.tonecurve.lutcache")
    private static let maxCacheSize = 10  // 最大キャッシュ数

    // MARK: - 公開メソッド

    /// トーンカーブを画像に適用
    /// - Parameters:
    ///   - image: 元画像
    ///   - curveData: トーンカーブデータ
    /// - Returns: フィルター適用済み画像（失敗時はnil）
    static func apply(to image: UIImage, curveData: ToneCurveData, quality: Quality = .full) -> UIImage? {
        let startTime = CFAbsoluteTimeGetCurrent()

        guard let cgImage = image.cgImage else {
            print("⚠️ [ToneCurve] CGImageの取得に失敗")
            return nil
        }

        let ciImage = CIImage(
            cgImage: cgImage,
            options: [.colorSpace: ImageFilterUtility.workingColorSpace]
        )

        // CIColorCubeWithColorSpaceフィルターを適用
        guard let processedCIImage = applyCubeFilter(to: ciImage, curveData: curveData, quality: quality) else {
            print("⚠️ [ToneCurve] フィルター適用に失敗")
            return nil
        }

        // CIImage → UIImage（共有コンテキストを使用）
        guard let outputCGImage = sharedContext.createCGImage(processedCIImage, from: processedCIImage.extent) else {
            print("⚠️ [ToneCurve] CGImage生成に失敗")
            return nil
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        #if DEBUG
        print("✅ [ToneCurve] 処理完了 (\(String(format: "%.0fms", elapsed * 1000)))")
        #endif

        return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - CIImage用メソッド

    /// CIImageにトーンカーブを適用
    /// - Parameters:
    ///   - ciImage: 元CIImage
    ///   - curveData: トーンカーブデータ
    /// - Returns: フィルター適用済みCIImage（失敗時はnil）
    static func applyCurve(to ciImage: CIImage, curveData: ToneCurveData, quality: Quality = .full) -> CIImage? {
        return applyCubeFilter(to: ciImage, curveData: curveData, quality: quality)
    }

    // MARK: - プライベートメソッド

    /// CIColorCubeWithColorSpaceフィルターを適用
    /// - Parameters:
    ///   - ciImage: 元CIImage
    ///   - curveData: トーンカーブデータ
    /// - Returns: フィルター適用済みCIImage（失敗時はnil）
    private static func applyCubeFilter(to ciImage: CIImage, curveData: ToneCurveData, quality: Quality) -> CIImage? {
        let cubeStartTime = CFAbsoluteTimeGetCurrent()

        // 入力を作業色空間に揃える（ciImage生成時に色空間指定済み）
        let inputImage = ciImage

        // すべてのカーブがデフォルト状態かチェック
        if isDefaultCurve(curveData.rgbPoints) &&
           isDefaultCurve(curveData.redPoints) &&
           isDefaultCurve(curveData.greenPoints) &&
           isDefaultCurve(curveData.bluePoints) {
            #if DEBUG
            print("⏭️ [ToneCurve] すべてデフォルト状態のためスキップ")
            #endif
            return ciImage
        }

        // 3D LUTを生成
        guard let cubeData = createColorCube(from: curveData, quality: quality) else {
            print("⚠️ [ToneCurve] 3D LUT生成に失敗")
            return nil
        }

        let cubeElapsed = CFAbsoluteTimeGetCurrent() - cubeStartTime

        #if DEBUG
        print("📊 [ToneCurve] 3D LUT生成完了 (\(String(format: "%.0fms", cubeElapsed * 1000)))")
        #endif

        // CIColorCubeWithColorSpaceフィルターを適用
        let filter = CIFilter(
            name: "CIColorCubeWithColorSpace",
            parameters: [
                "inputImage": inputImage,
                "inputCubeDimension": cubeDimension(for: quality),
                "inputCubeData": cubeData,
                "inputColorSpace": ImageFilterUtility.workingColorSpace
            ]
        )

        guard let outputImage = filter?.outputImage else {
            print("⚠️ [ToneCurve] フィルター出力の取得に失敗")
            return nil
        }

        return outputImage
    }

    /// トーンカーブデータから3D LUTを生成（キャッシュ対応）
    /// - Parameter curveData: トーンカーブデータ
    /// - Returns: 3D LUTデータ（失敗時はnil）
    private static func createColorCube(from curveData: ToneCurveData, quality: Quality) -> Data? {
        // キャッシュキーを生成（JSONエンコードを使用）
        let cacheKey = generateCacheKey(from: curveData, quality: quality)

        // キャッシュをチェック
        if let cachedLUT = lutCacheQueue.sync(execute: { lutCache[cacheKey] }) {
            #if DEBUG
            print("🎯 [ToneCurve] LUTキャッシュヒット")
            #endif
            return cachedLUT
        }

        #if DEBUG
        print("🔨 [ToneCurve] LUT新規生成（キャッシュミス）")
        #endif

        let dimension = cubeDimension(for: quality)
        let cubeSize = dimension * dimension * dimension * 4 // RGBA

        // Float配列を確保
        var cubeDataArray = [Float](repeating: 0, count: cubeSize)

        // MonotonicCubicInterpolatorを各チャンネル用に準備
        let rgbInterpolator = MonotonicCubicInterpolator(points: curveData.rgbPoints)
        let redInterpolator = MonotonicCubicInterpolator(points: curveData.redPoints)
        let greenInterpolator = MonotonicCubicInterpolator(points: curveData.greenPoints)
        let blueInterpolator = MonotonicCubicInterpolator(points: curveData.bluePoints)

        // デフォルト状態のチェック
        let rgbIsDefault = isDefaultCurve(curveData.rgbPoints)
        let redIsDefault = isDefaultCurve(curveData.redPoints)
        let greenIsDefault = isDefaultCurve(curveData.greenPoints)
        let blueIsDefault = isDefaultCurve(curveData.bluePoints)

        #if DEBUG
        print("📐 [ToneCurve] LUT生成開始: \(dimension)³ = \(dimension * dimension * dimension)エントリ")
        print("  RGB: \(rgbIsDefault ? "デフォルト" : "カスタム")")
        print("  Red: \(redIsDefault ? "デフォルト" : "カスタム")")
        print("  Green: \(greenIsDefault ? "デフォルト" : "カスタム")")
        print("  Blue: \(blueIsDefault ? "デフォルト" : "カスタム")")
        #endif

        // 3D LUTを構築（Blue → Green → Red の順）
        for blueIndex in 0..<dimension {
            for greenIndex in 0..<dimension {
                for redIndex in 0..<dimension {
                    // 0.0〜1.0の範囲に正規化
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
                    cubeDataArray[offset + 3] = 1.0 // Alpha
                }
            }
        }

        // Float配列をDataに変換
        let data = Data(bytes: &cubeDataArray, count: cubeSize * MemoryLayout<Float>.size)

        #if DEBUG
        print("✅ [ToneCurve] LUT生成完了: \(data.count / 1024)KB")
        #endif

        // キャッシュに保存（同期的に書き込み、次回すぐヒットできるようにする）
        lutCacheQueue.sync {
            lutCache[cacheKey] = data

            // キャッシュサイズ制限（LRU的な削除）
            if lutCache.count > maxCacheSize {
                // 最初のキーを削除（簡易的な実装）
                if let firstKey = lutCache.keys.first {
                    lutCache.removeValue(forKey: firstKey)
                    #if DEBUG
                    print("🗑️ [ToneCurve] LUTキャッシュ削除（上限到達）")
                    #endif
                }
            }
        }

        return data
    }

    /// キャッシュキーを生成
    /// - Parameter curveData: トーンカーブデータ
    /// - Returns: キャッシュキー文字列
    private static func generateCacheKey(from curveData: ToneCurveData, quality: Quality) -> String {
        // JSONエンコードでハッシュ化
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys  // 一貫性のため

        if let jsonData = try? encoder.encode(curveData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return "\(jsonString.hashValue)_\(cubeDimension(for: quality))"
        }

        // フォールバック: 簡易的なキー生成
        return "\(curveData.rgbPoints.count)_\(curveData.redPoints.count)_\(curveData.greenPoints.count)_\(curveData.bluePoints.count)_\(cubeDimension(for: quality))"
    }

    /// LUTキャッシュをクリア（メモリ解放用）
    static func clearCache() {
        lutCacheQueue.async {
            lutCache.removeAll()
            #if DEBUG
            print("🗑️ [ToneCurve] LUTキャッシュをクリア")
            #endif
        }
    }

    /// 制御点がデフォルト状態（対角線）かチェック
    /// - Parameter points: 制御点の配列
    /// - Returns: デフォルト状態ならtrue
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
    private static func cubeDimension(for quality: Quality) -> Int {
        switch quality {
        case .preview:
            return previewCubeDimension
        case .full:
            return fullCubeDimension
        }
    }
}
