//
//  ImageElementRenderer.swift
//  GLogo
//
//  ImageElement の描画・レイアウト計算を担当するヘルパー。
//  （fitMode を使わず、要素の position/size/rotation に基づいて描画）
//

import UIKit

struct ImageElementRenderer {
    /// 描画矩形をそのまま返す（fitMode撤廃後の単純描画）
    /// - Parameter element: 描画対象
    /// - Returns: 要素サイズの矩形
    static func drawRect(for element: ImageElement) -> CGRect {
        CGRect(origin: .zero, size: element.size)
    }

    /// 画像要素を描画する
    /// - Parameters:
    ///   - element: 描画対象
    ///   - context: CGContext
    ///   - image: 描画する画像（事前にプレビューサービスで加工済み想定）
    static func draw(_ element: ImageElement, in context: CGContext, image: UIImage?) {
        guard element.isVisible, let image = image else { return }

        context.saveGState()

        // 透明度
        context.setAlpha(element.opacity)

        // 中心点に合わせて移動し、回転を適用
        let centerX = element.position.x + element.size.width / 2
        let centerY = element.position.y + element.size.height / 2
        context.translateBy(x: centerX, y: centerY)
        context.rotate(by: element.rotation)
        context.translateBy(x: -element.size.width / 2, y: -element.size.height / 2)

        // 描画領域
        let rect = CGRect(origin: .zero, size: element.size)

        // 角丸クリップ
        if element.roundedCorners && element.cornerRadius > 0 {
            let path = UIBezierPath(roundedRect: rect, cornerRadius: element.cornerRadius)
            context.addPath(path.cgPath)
            context.clip()
        }

        // 画像描画（単一パス）
        image.draw(in: rect)

        // フレーム描画
        if element.showFrame && element.frameWidth > 0 {
            context.setStrokeColor(element.frameColor.cgColor)
            context.setLineWidth(element.frameWidth)

            if element.roundedCorners && element.cornerRadius > 0 {
                let frameRect = rect.insetBy(dx: element.frameWidth / 2, dy: element.frameWidth / 2)
                let path = UIBezierPath(roundedRect: frameRect, cornerRadius: element.cornerRadius)
                context.addPath(path.cgPath)
            } else {
                context.stroke(rect.insetBy(dx: element.frameWidth / 2, dy: element.frameWidth / 2))
            }
        }

        context.restoreGState()
    }
}
