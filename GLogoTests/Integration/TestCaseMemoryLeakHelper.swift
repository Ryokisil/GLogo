//
//  TestCaseMemoryLeakHelper.swift
//  GLogoTests
//
//  概要:
//  XCTestCase向けの共通ヘルパーを定義する。
//

import XCTest

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
