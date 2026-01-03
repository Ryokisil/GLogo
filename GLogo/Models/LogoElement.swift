//
//  LogoElement.swift
//
//  概要:
//  このファイルはロゴの基本構成要素を表す抽象基底クラスを定義しています。
//  位置、サイズ、回転、不透明度などの共通プロパティと操作を提供します。
//  TextElement、ShapeElement、ImageElementなどの具体的な要素クラスはこのクラスを継承します。
//  また、要素のシリアライズ/デシリアライズ機能も実装しています。
//

import Foundation
import UIKit

/// ロゴ要素の種類を表す列挙型
enum LogoElementType: String, Codable {
    case text
    case shape
    case image
}

/// 要素の描画優先度を表す列挙型
/// 値が大きいほど前面に描画される
enum ElementPriority: Int, CaseIterable {
    case background = 0     // 背景要素
    case image = 100        // 画像要素
    case shape = 200        // 図形要素
    case text = 300         // テキスト要素（最前面）
    
    /// 要素タイプに対応するデフォルト優先度を取得
    static func defaultPriority(for elementType: LogoElementType) -> ElementPriority {
        switch elementType {
        case .text:
            return .text
        case .shape:
            return .shape
        case .image:
            return .image
        }
    }
    
    /// 優先度の範囲内で次の利用可能なzIndexを取得
    func nextAvailableZIndex(existingElements: [LogoElement]) -> Int {
        let samePriorityElements = existingElements.filter { element in
            let elementPriority = ElementPriority.priority(for: element.zIndex)
            return elementPriority == self
        }
        
        if samePriorityElements.isEmpty {
            return self.rawValue
        }
        
        let maxZIndex = samePriorityElements.map { $0.zIndex }.max() ?? self.rawValue
        return maxZIndex + 1
    }
    
    /// zIndexから対応する優先度を取得
    static func priority(for zIndex: Int) -> ElementPriority {
        if zIndex >= ElementPriority.text.rawValue {
            return .text
        } else if zIndex >= ElementPriority.shape.rawValue {
            return .shape
        } else if zIndex >= ElementPriority.image.rawValue {
            return .image
        } else {
            return .background
        }
    }
}

/// ロゴ要素の基本クラス
class LogoElement: Codable {
    /// 要素のユニークID
    var id = UUID()
    
    /// 要素の位置（キャンバス上の座標）
    var position: CGPoint = .zero
    
    /// 要素のサイズ
    var size: CGSize = CGSize(width: 100, height: 100)
    
    /// 要素の回転角度（ラジアン）
    var rotation: CGFloat = 0
    
    /// 要素の不透明度（0.0〜1.0）
    var opacity: CGFloat = 1.0
    
    /// 要素の名前
    var name: String = "Element"
    
    /// 要素の可視性
    var isVisible: Bool = true
    
    /// 要素がロックされているか（編集不可）
    var isLocked: Bool = false
    
    /// 描画順序（大きい値ほど前面に描画）
    var zIndex: Int = 0
    
    /// 要素の種類
    var type: LogoElementType {
        fatalError("Subclasses must override this property")
    }
    
    /// 要素の境界矩形を計算
    var frame: CGRect {
        let baseFrame = CGRect(origin: position, size: size)
        if rotation != 0 {
            // 回転がある場合は、回転を考慮した境界ボックスを計算
            return baseFrame.boundingBox(rotatedBy: rotation)
        }
        return baseFrame
    }
    
    /// エンコード用のコーディングキー
    enum CodingKeys: String, CodingKey {
        case id, name, isVisible, isLocked, zIndex
        case positionX, positionY, width, height, rotation, opacity
    }
    
    /// カスタムエンコーダー（CGPointとCGSizeのエンコード対応）
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(isVisible, forKey: .isVisible)
        try container.encode(isLocked, forKey: .isLocked)
        try container.encode(zIndex, forKey: .zIndex)
        
        // CGPoint, CGSizeのエンコード
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
        try container.encode(size.width, forKey: .width)
        try container.encode(size.height, forKey: .height)
        try container.encode(rotation, forKey: .rotation)
        try container.encode(opacity, forKey: .opacity)
    }
    
    /// カスタムデコーダー（CGPointとCGSizeのデコード対応）
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isVisible = try container.decode(Bool.self, forKey: .isVisible)
        isLocked = try container.decode(Bool.self, forKey: .isLocked)
        zIndex = try container.decodeIfPresent(Int.self, forKey: .zIndex) ?? 0
        
        // CGPoint, CGSizeのデコード
        let x = try container.decode(CGFloat.self, forKey: .positionX)
        let y = try container.decode(CGFloat.self, forKey: .positionY)
        position = CGPoint(x: x, y: y)
        
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        size = CGSize(width: width, height: height)
        
        rotation = try container.decode(CGFloat.self, forKey: .rotation)
        opacity = try container.decode(CGFloat.self, forKey: .opacity)
    }
    
    /// 基本初期化メソッド
    init(name: String = "Element") {
        self.name = name
    }
    
    /// 要素を描画するメソッド（サブクラスでオーバーライド）
    func draw(in context: CGContext) {
        // 基本実装（サブクラスでオーバーライド）
        fatalError("Subclasses must override this method")
    }
    
    /// 要素のヒットテスト（タッチ判定）
    func hitTest(_ point: CGPoint) -> Bool {
        // 回転がある場合はより複雑な計算が必要
        if rotation != 0 {
            // 回転を考慮したヒットテスト
            let center = CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)
            let rotatedPoint = point.rotated(around: center, angle: -rotation)
            let rect = CGRect(origin: position, size: size)
            return rect.contains(rotatedPoint)
        }
        
        // 回転がない場合は単純な矩形領域でのヒットテスト
        return frame.contains(point)
    }
    
    /// 要素のコピーを作成
    func copy() -> LogoElement {
        // 基本的なコピーを作成
        let copy = LogoElement(name: self.name)
        copy.id = UUID() // 新しいIDを生成（または必要に応じて同じIDを維持）
        copy.position = self.position
        copy.size = self.size
        copy.rotation = self.rotation
        copy.opacity = self.opacity
        copy.isVisible = self.isVisible
        copy.isLocked = self.isLocked
        copy.zIndex = self.zIndex
        
        return copy
    }
    
    /// 要素を指定された距離だけ移動
    func move(by offset: CGPoint) {
        position.x += offset.x
        position.y += offset.y
    }
    
    /// 要素のサイズを変更
    func resize(to newSize: CGSize) {
        size = newSize
    }
    
    /// 要素を回転
    func rotate(to angle: CGFloat) {
        rotation = angle
    }
}
