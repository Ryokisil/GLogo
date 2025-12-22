//
//  CIFilterInspector.swift
//  GLogo
//
//  概要:
//  CIFilterの属性を調査するためのデバッグユーティリティ
//

import Foundation
import CoreImage

class CIFilterInspector {

    /// 指定されたフィルターのすべての属性を出力
    static func inspectFilter(name: String) {
        guard let filter = CIFilter(name: name) else {
            print("❌ フィルター '\(name)' が見つかりません")
            return
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔍 CIFilter属性調査: \(name)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        let attributes = filter.attributes

        for (key, value) in attributes.sorted(by: { $0.key < $1.key }) {
            print("\n📌 \(key):")
            if let dict = value as? [String: Any] {
                for (subKey, subValue) in dict.sorted(by: { $0.key < $1.key }) {
                    print("   \(subKey): \(subValue)")
                }
            } else {
                print("   \(value)")
            }
        }

        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✅ 調査完了")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }
}
