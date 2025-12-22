
// GLogoTests
// 概要: 写真保存フロー全体（フィルター適用・最高解像度選択・破損データ・キャッシュ無視）を結合レベルで検証する

import XCTest
@testable import GLogo
import SwiftUI
import UIKit
import ImageIO
import UniformTypeIdentifiers

// ヘルパー関数を含む拡張
extension XCTestCase {
    // メモリリーク検出の汎用ヘルパー
    func assertNoMemoryLeak<T: AnyObject>(_ instance: () -> T, file: StaticString = #file, line: UInt = #line) {
        weak var weakInstance: T?
        
        autoreleasepool {
            let strongInstance = instance()
            weakInstance = strongInstance
            XCTAssertNotNil(weakInstance)
        }
        
        XCTAssertNil(weakInstance, "インスタンスがメモリリークしています", file: file, line: line)
    }
}

/// ViewModelのメモリリーク検証テストクラス 継承させるためにfinal
final class PhotoLibrarySaveTests: XCTestCase {
    
    /// 画像要素が存在しない場合の保存失敗テスト
    ///
    /// 目的
    /// プロジェクトに画像要素が一つもない場合、保存処理が適切に失敗することを確認
    ///
    /// これがダメなケース
    /// - 画像要素がないのに保存が成功してしまう
    /// - クラッシュや例外が発生する
    @MainActor
    func testSaveFailsWhenNoImageElements() async {
        let viewModel = EditorViewModel()
        
        // テキスト要素のみ追加（画像要素は追加しない）
        let textElement = TextElement(text: "テスト")
        viewModel.addElement(textElement)
        
        // 保存処理を実行
        await withCheckedContinuation { continuation in
            viewModel.saveProject { success in
                XCTAssertFalse(success, "画像要素がない場合は保存が失敗すべき")
                continuation.resume()
            }
        }
    }
    
    /// フィルター適用済み画像の保存確認テスト
    ///
    /// 目的
    /// フィルターが適用された画像が、元の未加工画像ではなく
    /// 加工済みの画像として保存されることを確認
    ///
    /// これがダメなケース
    /// - フィルターが適用されずに元画像が保存される
    /// - キャッシュされた古い画像が保存される
    func testSaveAppliesFiltersCorrectly() {
        // テスト用画像データを作成
        let originalSize = CGSize(width: 100, height: 100)
        let testImage = createTestImage(size: originalSize)
        guard let imageData = testImage.pngData() else {
            XCTFail("テスト画像データの作成に失敗")
            return
        }
        
        // ImageElementを作成しフィルターを適用（現行は fitMode 廃止）
        let imageElement = ImageElement(imageData: imageData)
        imageElement.saturationAdjustment = 2.0  // 彩度を大幅に上げる
        imageElement.brightnessAdjustment = 0.5  // 明度も上げる
        
        // フィルター適用前後で画像が違うことを確認
        guard let originalImage = imageElement.originalImage,
              let filteredImage = imageElement.getFilteredImageForce() else {
            XCTFail("画像の取得に失敗")
            return
        }
        
        // 元画像とフィルター適用後の画像は同じサイズであるべき
        XCTAssertEqual(filteredImage.size, originalImage.size, "フィルター適用後もサイズは保持されるべき")

        // フィルター適用で画素値が変化していることを確認
        guard let originalData = originalImage.pngData(),
              let filteredData = filteredImage.pngData() else {
            XCTFail("画像データの変換に失敗")
            return
        }
        XCTAssertNotEqual(originalData, filteredData, "フィルター適用後の画素が変化していない")
    }
    
    /// 複数画像要素の最高解像度選択テスト
    ///
    /// 目的
    /// 複数の画像要素がある場合、最も高解像度の画像が保存対象として
    /// 正しく選択されることを確認
    ///
    /// これがダメなケース
    /// - 低解像度の画像が選択されてしまう
    /// - 最初に見つかった画像が無条件で選択される
    /// - 画像要素の比較処理でクラッシュする
    @MainActor
    func testSelectsHighestResolutionImageElement() {
        let viewModel = EditorViewModel()
        
        // 異なる解像度の画像要素を作成
        let lowResImage = createTestImage(size: CGSize(width: 200, height: 200))
        let midResImage = createTestImage(size: CGSize(width: 800, height: 600))
        let highResImage = createTestImage(size: CGSize(width: 1920, height: 1080))
        
        guard let lowResData = lowResImage.pngData(),
              let midResData = midResImage.pngData(),
              let highResData = highResImage.pngData() else {
            XCTFail("テスト画像データの作成に失敗")
            return
        }
        
        // 意図的に順序をランダムにして追加（最高解像度が最初ではない）
        let lowResElement = ImageElement(imageData: lowResData)
        let midResElement = ImageElement(imageData: midResData)
        let highResElement = ImageElement(imageData: highResData)
        
        viewModel.addElement(lowResElement)
        viewModel.addElement(midResElement)
        viewModel.addElement(highResElement)
        
        // 最高解像度画像の検証
        let imageElements = viewModel.project.elements.compactMap { $0 as? ImageElement }
        XCTAssertEqual(imageElements.count, 3, "3つの画像要素が追加されているべき")
        
        // 最高解像度選択ロジックが期待通りであること
        let selectionService = ImageSelectionService()
        let selectedElement = selectionService.selectHighestResolutionImageElement(from: imageElements)
        XCTAssertEqual(selectedElement?.id, highResElement.id, "最高解像度の画像が選択されるべき")
    }
    
    /// 画像データ破損時の処理テスト
    ///
    /// 目的
    /// 画像データが破損している場合や、originalImageが取得できない場合に
    /// 適切にエラーハンドリングされることを確認
    ///
    /// これがダメなケース
    /// - 破損データでアプリがクラッシュする
    /// - 保存処理が無限ループに陥る
    /// - 適切なエラーが返されない
    @MainActor
    func testHandlesCorruptedImageData() async {
        let viewModel = EditorViewModel()
        
        // 破損した画像データを作成（無効なPNGデータ）
        let corruptedData = Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0x00, 0x00, 0x00]) // 不完全なPNGヘッダ
        
        // 破損データでImageElementを作成
        let imageElement = ImageElement(imageData: corruptedData)
        viewModel.addElement(imageElement)
        
        // originalImageが正しくnilになることを確認
        XCTAssertNil(imageElement.originalImage, "破損データの場合、originalImageはnilであるべき")
        
        // 強制フィルター適用が失敗することを確認
        XCTAssertNil(imageElement.getFilteredImageForce(), "破損データはフィルター適用に失敗すべき")
    }
    
    /// getFilteredImageForceメソッドの動作確認テスト
    ///
    /// 目的
    /// キャッシュを無視してフィルターが確実に適用されることを確認
    /// これは今回実装した重要なメソッドの動作検証
    ///
    /// これがダメなケース
    /// - キャッシュが効いてしまい古い画像が返される
    /// - フィルター設定が無視される
    /// - メソッドが例外を投げる
    func testGetFilteredImageForceIgnoresCache() {
        let originalSize = CGSize(width: 300, height: 300)
        let testImage = createTestImage(size: originalSize)
        guard let imageData = testImage.pngData() else {
            XCTFail("テスト画像データの作成に失敗")
            return
        }
        
        let imageElement = ImageElement(imageData: imageData)
        
        // 初期状態でフィルター適用画像を取得（キャッシュされる）
        let initialFiltered = imageElement.image
        
        // フィルターを追加
        imageElement.saturationAdjustment = 1.8
        imageElement.brightnessAdjustment = 0.3
        
        // getFilteredImageForceで新しいフィルター設定の画像を取得
        guard let forcedFilteredImage = imageElement.getFilteredImageForce() else {
            XCTFail("getFilteredImageForceが画像を返さない")
            return
        }
        
        // 画像が正常に生成されることを確認
        XCTAssertNotNil(forcedFilteredImage, "フィルター強制適用画像が生成されるべき")

        // ピクセル次元（cgImageベース）でサイズが保持されていることを確認
        if let originalCG = imageElement.originalImage?.cgImage, let forcedCG = forcedFilteredImage.cgImage {
            XCTAssertEqual(forcedCG.width, originalCG.width, "フィルター適用後も幅のピクセル数は保持されるべき")
            XCTAssertEqual(forcedCG.height, originalCG.height, "フィルター適用後も高さのピクセル数は保持されるべき")
        }

        // キャッシュを無視して最新パラメータで再生成されていることを確認
        if let cached = initialFiltered?.pngData(), let forced = forcedFilteredImage.pngData() {
            XCTAssertNotEqual(cached, forced, "キャッシュではなく最新フィルターで再生成されるべき")
        }
    }
    
    // MARK: - ヘルパーメソッド
    
    /// テスト用の画像を指定サイズで作成
    /// - Parameter size: 作成する画像のサイズ
    /// - Returns: 指定サイズのテスト画像
    private func createTestImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // グラデーション背景を作成（解像度テストに適した視覚的パターン）
            let colors = [UIColor.red.cgColor, UIColor.blue.cgColor]
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                          colors: colors as CFArray,
                                          locations: [0.0, 1.0]) else { return }
            
            cgContext.drawLinearGradient(gradient,
                                       start: CGPoint.zero,
                                       end: CGPoint(x: size.width, y: size.height),
                                       options: [])
            
            // 解像度確認用のグリッドパターンを追加
            cgContext.setStrokeColor(UIColor.white.cgColor)
            cgContext.setLineWidth(2.0)
            
            let gridSpacing: CGFloat = 100
            for x in stride(from: 0, through: size.width, by: gridSpacing) {
                cgContext.move(to: CGPoint(x: x, y: 0))
                cgContext.addLine(to: CGPoint(x: x, y: size.height))
                cgContext.strokePath()
            }
            
            for y in stride(from: 0, through: size.height, by: gridSpacing) {
                cgContext.move(to: CGPoint(x: 0, y: y))
                cgContext.addLine(to: CGPoint(x: size.width, y: y))
                cgContext.strokePath()
            }
        }
    }
}

/// パフォーマンスKPI向けの計測テスト
final class PerformanceKpiTests: XCTestCase {
    /// 4K画像のインポート + プレビュー生成の性能を計測
    func testImportPreviewPerformance_4K() {
        let size = CGSize(width: 3840, height: 2160)
        let sourceData = makeHEICData(size: size)
        let coordinator = ImageImportCoordinator()
        let project = LogoProject(canvasSize: size)

        measure(metrics: [XCTClockMetric()]) {
            guard let result = coordinator.importImage(
                source: .imageData(sourceData),
                project: project,
                viewportSize: size,
                assetIdentifier: "perf-import-4k",
                canvasSize: size
            ) else {
                XCTFail("インポート結果がnil")
                return
            }

            _ = result.element.getInstantPreview()
        }
    }

    /// 4K画像のフィルター適用 + エンコード（HEIC）の性能を計測
    func testSaveProcessingPerformance_4K_HEIC() {
        let size = CGSize(width: 3840, height: 2160)
        let sourceData = makeHEICData(size: size)
        let imageElement = ImageElement(imageData: sourceData)
        imageElement.saturationAdjustment = 1.2
        imageElement.brightnessAdjustment = 0.1
        imageElement.contrastAdjustment = 1.1
        let processingService = ImageProcessingService()

        measure(metrics: [XCTClockMetric()]) {
            guard let processedImage = processingService.applyFilters(to: imageElement) else {
                XCTFail("フィルター適用に失敗")
                return
            }

            _ = makeHEICData(from: processedImage)
        }
    }

    // MARK: - Helpers

    private func makeHEICData(size: CGSize) -> Data {
        let image = makeTestImage(size: size)
        return makeHEICData(from: image)
    }

    private func makeTestImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.darkGray.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func makeHEICData(from image: UIImage) -> Data {
        guard let cgImage = image.cgImage else {
            return Data()
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.heic.identifier as CFString,
            1,
            nil
        ) else {
            return Data()
        }

        let properties = [kCGImageDestinationLossyCompressionQuality: 1.0] as CFDictionary
        CGImageDestinationAddImage(destination, cgImage, properties)
        guard CGImageDestinationFinalize(destination) else {
            return Data()
        }
        return data as Data
    }
}
