//
//  CGGeometry+Extensions.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはCoreGraphicsジオメトリタイプ（CGPoint, CGSize, CGRect）の拡張を提供します。
//  ジオメトリ操作、座標変換、数学的計算などの便利なメソッドやプロパティを追加し、
//  アプリ全体でのグラフィック処理をより簡単にします。
//

import CoreGraphics
import UIKit

// MARK: - CGPoint Extensions

extension CGPoint {
    /// 他の点との距離を計算
    func distance(to point: CGPoint) -> CGFloat {
        return sqrt(pow(x - point.x, 2) + pow(y - point.y, 2))
    }
    
    /// 指定された角度と距離だけ移動した新しい点を返す
    func point(atAngle angle: CGFloat, distance: CGFloat) -> CGPoint {
        return CGPoint(
            x: x + distance * cos(angle),
            y: y + distance * sin(angle)
        )
    }
    
    /// 指定された点を中心とした角度を計算（ラジアン）
    func angle(to center: CGPoint) -> CGFloat {
        return atan2(y - center.y, x - center.x)
    }
    
    /// 2つの点を線形補間
    static func linearInterpolation(start: CGPoint, end: CGPoint, t: CGFloat) -> CGPoint {
        return CGPoint(
            x: start.x + (end.x - start.x) * t,
            y: start.y + (end.y - start.y) * t
        )
    }
    
    /// 点を回転（指定された中心点を基準に）
    func rotated(around center: CGPoint, angle: CGFloat) -> CGPoint {
        let dx = x - center.x
        let dy = y - center.y
        
        let rotatedX = dx * cos(angle) - dy * sin(angle) + center.x
        let rotatedY = dx * sin(angle) + dy * cos(angle) + center.y
        
        return CGPoint(x: rotatedX, y: rotatedY)
    }
    
    /// 加算演算子のオーバーロード
    static func + (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x + right.x, y: left.y + right.y)
    }
    
    /// 減算演算子のオーバーロード
    static func - (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x - right.x, y: left.y - right.y)
    }
    
    /// スカラー乗算演算子のオーバーロード
    static func * (point: CGPoint, scalar: CGFloat) -> CGPoint {
        return CGPoint(x: point.x * scalar, y: point.y * scalar)
    }
    
    /// スナップ：指定されたグリッドサイズに合わせる
    func snapped(toGrid gridSize: CGFloat) -> CGPoint {
        return CGPoint(
            x: round(x / gridSize) * gridSize,
            y: round(y / gridSize) * gridSize
        )
    }
}

// MARK: - CGSize Extensions

extension CGSize {
    /// 幅と高さの最大値
    var maxDimension: CGFloat {
        return max(width, height)
    }
    
    /// 幅と高さの最小値
    var minDimension: CGFloat {
        return min(width, height)
    }
    
    /// サイズの面積
    var area: CGFloat {
        return width * height
    }
    
    /// アスペクト比（幅÷高さ）
    var aspectRatio: CGFloat {
        guard height != 0 else { return 0 }
        return width / height
    }
    
    /// 指定された最大サイズに収まるようにアスペクト比を維持したまま縮小
    func fitted(to size: CGSize) -> CGSize {
        let widthRatio = size.width / width
        let heightRatio = size.height / height
        let scale = min(widthRatio, heightRatio)
        
        return CGSize(
            width: width * scale,
            height: height * scale
        )
    }
    
    /// 指定された最小サイズを満たすようにアスペクト比を維持したまま拡大
    func filled(to size: CGSize) -> CGSize {
        let widthRatio = size.width / width
        let heightRatio = size.height / height
        let scale = max(widthRatio, heightRatio)
        
        return CGSize(
            width: width * scale,
            height: height * scale
        )
    }
    
    /// 加算演算子のオーバーロード
    static func + (left: CGSize, right: CGSize) -> CGSize {
        return CGSize(width: left.width + right.width, height: left.height + right.height)
    }
    
    /// 減算演算子のオーバーロード
    static func - (left: CGSize, right: CGSize) -> CGSize {
        return CGSize(width: left.width - right.width, height: left.height - right.height)
    }
    
    /// スカラー乗算演算子のオーバーロード
    static func * (size: CGSize, scalar: CGFloat) -> CGSize {
        return CGSize(width: size.width * scalar, height: size.height * scalar)
    }
    
    /// スナップ：指定されたグリッドサイズに合わせる
    func snapped(toGrid gridSize: CGFloat) -> CGSize {
        return CGSize(
            width: round(width / gridSize) * gridSize,
            height: round(height / gridSize) * gridSize
        )
    }
}

// MARK: - CGRect Extensions

extension CGRect {
    /// 中心点
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
    
    /// 指定された中心点と同じサイズの矩形を作成
    init(center: CGPoint, size: CGSize) {
        self.init(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
    
    /// 矩形の頂点を配列として取得
    var corners: [CGPoint] {
        return [
            CGPoint(x: minX, y: minY), // 左上
            CGPoint(x: maxX, y: minY), // 右上
            CGPoint(x: maxX, y: maxY), // 右下
            CGPoint(x: minX, y: maxY)  // 左下
        ]
    }
    
    /// 矩形を回転させた後の境界矩形を計算
    func boundingBox(rotatedBy angle: CGFloat) -> CGRect {
        let center = self.center
        
        let corners = self.corners.map { $0.rotated(around: center, angle: angle) }
        
        let minX = corners.min { $0.x < $1.x }?.x ?? 0
        let maxX = corners.max { $0.x < $1.x }?.x ?? 0
        let minY = corners.min { $0.y < $1.y }?.y ?? 0
        let maxY = corners.max { $0.y < $1.y }?.y ?? 0
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    /// 指定された点が矩形内にあるかどうかを、回転を考慮して判定
    func contains(_ point: CGPoint, withRotation angle: CGFloat) -> Bool {
        guard angle != 0 else {
            return self.contains(point)
        }
        
        let center = self.center
        // 逆回転して判定
        let rotatedPoint = point.rotated(around: center, angle: -angle)
        
        return self.contains(rotatedPoint)
    }
    
    /// 矩形を指定されたオフセットだけ拡大/縮小
    func insetBy(top: CGFloat = 0, left: CGFloat = 0, bottom: CGFloat = 0, right: CGFloat = 0) -> CGRect {
        return CGRect(
            x: minX + left,
            y: minY + top,
            width: width - left - right,
            height: height - top - bottom
        )
    }
    
    /// スナップ：指定されたグリッドサイズに合わせる
    func snapped(toGrid gridSize: CGFloat) -> CGRect {
        let origin = CGPoint(x: minX, y: minY).snapped(toGrid: gridSize)
        let size = self.size.snapped(toGrid: gridSize)
        
        return CGRect(origin: origin, size: size)
    }
    
    /// 中心を維持したままサイズを変更
    func withSize(_ size: CGSize) -> CGRect {
        return CGRect(center: center, size: size)
    }
    
    /// 交差部分の面積を計算
    func intersectionArea(with rect: CGRect) -> CGFloat {
        guard intersects(rect) else { return 0 }
        let intersection = self.intersection(rect)
        return intersection.width * intersection.height
    }
}
