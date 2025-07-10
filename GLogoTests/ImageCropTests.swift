//
//  ImageCropTests.swift
//  GLogoTests
//
//  概要:
//  画像クロップ機能のテストコード
//

import XCTest
import UIKit
@testable import GLogo

class ImageCropTests: XCTestCase {
    
    var testImage: UIImage!
    var cropViewModel: ImageCropViewModel!
    
    override func setUp() {
        super.setUp()
        
        // テスト用の画像を作成（100x100の白い画像）
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(size)
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        testImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        cropViewModel = ImageCropViewModel(image: testImage) { _ in }
    }
    
    override func tearDown() {
        testImage = nil
        cropViewModel = nil
        super.tearDown()
    }
    
    func testInitialCropRectMatchesImageFrame() {
        // テスト用のフレームを設定
        let testFrame = CGRect(x: 50, y: 50, width: 200, height: 200)
        
        // フレームを更新
        cropViewModel.updateImageFrame(testFrame)
        
        // 初期クロップ領域が画像フレーム全体に設定されることを確認
        XCTAssertEqual(cropViewModel.cropRect, testFrame, "初期クロップ領域は画像フレーム全体と一致すべき")
        XCTAssertFalse(cropViewModel.hasCropped, "初期状態ではクロップされていない状態")
        XCTAssertTrue(cropViewModel.imageIsLoaded, "画像がロードされた状態")
    }
    
    func testResetCropRectSetsToImageFrame() {
        // フレームを設定
        let testFrame = CGRect(x: 10, y: 10, width: 150, height: 150)
        cropViewModel.updateImageFrame(testFrame)
        
        // クロップ領域を変更
        cropViewModel.cropRect = CGRect(x: 20, y: 20, width: 100, height: 100)
        
        // リセット実行
        cropViewModel.resetCropRect()
        
        // リセット後に画像フレーム全体に戻ることを確認
        XCTAssertEqual(cropViewModel.cropRect, testFrame, "リセット後のクロップ領域は画像フレーム全体と一致すべき")
        XCTAssertFalse(cropViewModel.hasCropped, "リセット後はクロップされていない状態")
    }
    
    func testCropHandlePositionsMatchImageEdges() {
        let testFrame = CGRect(x: 0, y: 0, width: 200, height: 200)
        cropViewModel.updateImageFrame(testFrame)
        
        let cropRect = cropViewModel.cropRect
        
        // クロップハンドルの期待される位置
        let expectedPositions = [
            CGPoint(x: cropRect.minX, y: cropRect.minY), // topLeft
            CGPoint(x: cropRect.midX, y: cropRect.minY), // topCenter
            CGPoint(x: cropRect.maxX, y: cropRect.minY), // topRight
            CGPoint(x: cropRect.minX, y: cropRect.midY), // middleLeft
            CGPoint(x: cropRect.maxX, y: cropRect.midY), // middleRight
            CGPoint(x: cropRect.minX, y: cropRect.maxY), // bottomLeft
            CGPoint(x: cropRect.midX, y: cropRect.maxY), // bottomCenter
            CGPoint(x: cropRect.maxX, y: cropRect.maxY)  // bottomRight
        ]
        
        // 画像端にハンドルが配置されることを確認
        XCTAssertEqual(expectedPositions[0], CGPoint(x: 0, y: 0), "左上ハンドルが画像左上端に配置")
        XCTAssertEqual(expectedPositions[2], CGPoint(x: 200, y: 0), "右上ハンドルが画像右上端に配置")
        XCTAssertEqual(expectedPositions[5], CGPoint(x: 0, y: 200), "左下ハンドルが画像左下端に配置")
        XCTAssertEqual(expectedPositions[7], CGPoint(x: 200, y: 200), "右下ハンドルが画像右下端に配置")
    }
}