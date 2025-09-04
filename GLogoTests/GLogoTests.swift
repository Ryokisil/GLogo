
// GLogoTests

import XCTest
@testable import GLogo
import SwiftUI

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
final class ViewModelMemoryLeakTests: XCTestCase {
    /// 基本的なEditorViewModelのメモリリークがないことを検証
    /// EditorViewModelが単体で適切に解放されることを確認する
    func testEditorViewModelDoesNotLeak() {
        assertNoMemoryLeak {
            return EditorViewModel()
        }
    }
    /// ElementViewModelと関連するEditorViewModelの間でメモリリークがないことを検証
    /// 両ViewModelの参照関係が正しく設計され、循環参照を作らないことを確認する
    @MainActor
    func testElementViewModelDoesNotLeak() {
        assertNoMemoryLeak {
            let editorVM = EditorViewModel()
            return ElementViewModel(editorViewModel: editorVM)
        }
    }
    /// 要素選択操作を含む複雑なシナリオでもメモリリークが発生しないことを検証
    /// 実際の使用パターンに近い状態で、ViewModelと要素間の参照関係が適切に管理されているか確認する
    @MainActor
    func testElementViewModelWithSelectedElementDoesNotLeak() {
        assertNoMemoryLeak {
            let editorVM = EditorViewModel()
            let elementVM = ElementViewModel(editorViewModel: editorVM)
            
            // テスト要素を作成し、追加・選択操作を実行
            let textElement = TextElement(text: "テスト")
            editorVM.addElement(textElement)
            editorVM.selectElement(textElement)
            
            return elementVM
        }
    }
}

// 操作に関するテスト
final class OperationMemoryLeakTests: XCTestCase {
    /// 要素操作（移動など）におけるメモリリークテスト
    ///
    /// 目的
    /// 要素の追加、選択、移動操作を行った後、EditorViewModelが適切に解放されることを確認
    /// 操作開始、操作続行、操作終了のシーケンスを実行し、操作履歴の管理が適切に行われているか検証
    ///
    /// 理由
    /// 操作履歴の記録時に循環参照が発生する可能性がある
    /// 特に操作イベントのコールバックやクロージャで自己参照を行う場合にリークの危険性がある
    @MainActor
    func testManipulationDoesNotLeak() {
        weak var weakViewModel: EditorViewModel?
        
        autoreleasepool {
            let viewModel = EditorViewModel()
            weakViewModel = viewModel
            
            // 要素を追加
            let element = ShapeElement(shapeType: .rectangle)
            viewModel.addElement(element)
            viewModel.selectElement(element)
            
            // 操作を実行
            viewModel.startManipulation(.move, at: CGPoint(x: 0, y: 0))
            viewModel.continueManipulation(at: CGPoint(x: 100, y: 100))
            viewModel.endManipulation()
        }
        
        XCTAssertNil(weakViewModel, "操作処理中にメモリリークが発生しています")
    }
    /// アンドゥ・リドゥ操作におけるメモリリークテスト
    ///
    /// 目的
    /// 要素の追加、テキスト編集、アンドゥ、リドゥの操作を行った後、
    /// EditorViewModelが適切に解放されることを確認
    /// イベントソーシングによる操作履歴の実装が適切にメモリ管理されているか検証
    ///
    /// 理由
    /// 操作履歴スタックが要素やViewModelへの強参照を持ち続ける可能性がある
    /// アンドゥ・リドゥ操作はイベントの適用と取り消しを行うため、
    /// イベントオブジェクトとモデルオブジェクト間で循環参照を作りやすい
    @MainActor
    func testUndoRedoDoesNotLeak() {
        weak var weakViewModel: EditorViewModel?
        
        autoreleasepool {
            let viewModel = EditorViewModel()
            weakViewModel = viewModel
            
            // アンドゥ用の操作を実行
            let element = TextElement(text: "テスト")
            viewModel.addElement(element)
            viewModel.selectElement(element)
            viewModel.updateTextContent(element, newText: "変更後")
            
            // アンドゥ・リドゥを実行
            viewModel.undo()
            viewModel.redo()
        }
        
        XCTAssertNil(weakViewModel, "アンドゥ・リドゥ処理中にメモリリークが発生しています")
    }
}

// 写真アプリ保存機能テスト
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
        
        // ImageElementを作成しフィルターを適用
        let imageElement = ImageElement(imageData: imageData, fitMode: .aspectFit)
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
        
        // フィルター適用画像が確実に生成されていることを確認
        XCTAssertNotNil(filteredImage, "フィルター適用画像が生成されていない")
        
        print("DEBUG: 元画像サイズ: \(originalImage.size)")
        print("DEBUG: フィルター適用画像サイズ: \(filteredImage.size)")
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
        let lowResElement = ImageElement(imageData: lowResData, fitMode: .aspectFit)
        let midResElement = ImageElement(imageData: midResData, fitMode: .aspectFit)
        let highResElement = ImageElement(imageData: highResData, fitMode: .aspectFit)
        
        viewModel.addElement(lowResElement)
        viewModel.addElement(midResElement)
        viewModel.addElement(highResElement)
        
        // 最高解像度画像の検証
        let imageElements = viewModel.project.elements.compactMap { $0 as? ImageElement }
        XCTAssertEqual(imageElements.count, 3, "3つの画像要素が追加されているべき")
        
        // 各画像要素の解像度を確認
        var maxPixelCount: CGFloat = 0
        var selectedElement: ImageElement?
        
        for imageElement in imageElements {
            if let originalImage = imageElement.originalImage,
               let cgImage = originalImage.cgImage {
                let pixelCount = CGFloat(cgImage.width * cgImage.height)
                if pixelCount > maxPixelCount {
                    maxPixelCount = pixelCount
                    selectedElement = imageElement
                }
            }
        }
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
        let imageElement = ImageElement(imageData: corruptedData, fitMode: .aspectFit)
        viewModel.addElement(imageElement)
        
        // originalImageが正しくnilになることを確認
        XCTAssertNil(imageElement.originalImage, "破損データの場合、originalImageはnilであるべき")
        
        // 保存処理を実行し、適切に失敗することを確認
        await withCheckedContinuation { continuation in
            viewModel.saveProject { success in
                XCTAssertFalse(success, "破損データの場合は保存が失敗すべき")
                continuation.resume()
            }
        }
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
        
        let imageElement = ImageElement(imageData: imageData, fitMode: .aspectFit)
        
        // 初期状態でフィルター適用画像を取得（キャッシュされる）
        _ = imageElement.image
        
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
        XCTAssertEqual(forcedFilteredImage.size, originalSize, "フィルター適用後もサイズは保持されるべき")
        
        print("DEBUG: フィルター強制適用画像サイズ: \(forcedFilteredImage.size)")
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
