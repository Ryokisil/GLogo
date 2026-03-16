//
//  UpscaleTileProcessorTests.swift
//  GLogoTests
//
//  概要:
//  タイル分割された高画質化画像の結合結果が崩れないことを確認するテストです。
//

import XCTest
import UIKit
@testable import GLogo

final class UpscaleTileProcessorTests: XCTestCase {

    func testProcess_IdentityRendererPreservesTileLayout() throws {
        let inputImage = try XCTUnwrap(makeQuadrantImage())
        let processor = UpscaleTileProcessor(
            tileSize: 128,
            modelScaleFactor: 1,
            outputScaleFactor: 1,
            renderer: { $0 }
        )

        let outputImage = try processor.process(image: inputImage)

        XCTAssertEqual(
            sampleRGBA(from: outputImage, x: 20, y: 20),
            sampleRGBA(from: inputImage, x: 20, y: 20),
            "左上タイルの配置は維持されるべき"
        )
        XCTAssertEqual(
            sampleRGBA(from: outputImage, x: 280, y: 20),
            sampleRGBA(from: inputImage, x: 280, y: 20),
            "右上タイルの配置は維持されるべき"
        )
        XCTAssertEqual(
            sampleRGBA(from: outputImage, x: 20, y: 180),
            sampleRGBA(from: inputImage, x: 20, y: 180),
            "左下タイルの配置は維持されるべき"
        )
        XCTAssertEqual(
            sampleRGBA(from: outputImage, x: 280, y: 180),
            sampleRGBA(from: inputImage, x: 280, y: 180),
            "右下タイルの配置は維持されるべき"
        )
    }

    /// 4 色の象限画像を生成する
    /// - Parameters: なし
    /// - Returns: テスト用の CGImage
    private func makeQuadrantImage() -> CGImage? {
        let width = 300
        let height = 200
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.setFillColor(UIColor.red.cgColor)
        context.fill(CGRect(x: 0, y: 100, width: 150, height: 100))
        context.setFillColor(UIColor.green.cgColor)
        context.fill(CGRect(x: 150, y: 100, width: 150, height: 100))
        context.setFillColor(UIColor.blue.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 150, height: 100))
        context.setFillColor(UIColor.yellow.cgColor)
        context.fill(CGRect(x: 150, y: 0, width: 150, height: 100))

        return context.makeImage()
    }

    /// 指定座標の RGBA 値を返す
    /// - Parameters:
    ///   - image: 参照対象の画像
    ///   - x: x 座標
    ///   - y: y 座標
    /// - Returns: 4 要素の RGBA 値
    private func sampleRGBA(
        from image: CGImage,
        x: Int,
        y: Int
    ) -> [UInt8] {
        guard let data = image.dataProvider?.data else {
            XCTFail("画像データを取得できません")
            return []
        }

        let bytes = CFDataGetBytePtr(data)
        let offset = y * image.bytesPerRow + x * 4
        return [
            bytes?[offset] ?? 0,
            bytes?[offset + 1] ?? 0,
            bytes?[offset + 2] ?? 0,
            bytes?[offset + 3] ?? 0
        ]
    }
}
