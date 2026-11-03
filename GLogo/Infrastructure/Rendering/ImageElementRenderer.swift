//
//  ImageElementRenderer.swift
//  GLogo
//
//  概要:
//  ImageElement の描画・フレームレイアウト計算を担当するヘルパーです。
//  画像本体の描画とフレームプリセットの見た目をキャンバス表示・保存処理で共通化します。
//

import UIKit

struct ImageElementRenderer {
    private struct FrameLayout {
        let imageRect: CGRect
        let imageCornerRadius: CGFloat
        let outerCornerRadius: CGFloat
    }

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
    /// - Returns: なし
    static func draw(_ element: ImageElement, in context: CGContext, image: UIImage?) {
        guard element.isVisible, let image = image else { return }

        context.saveGState()
        context.setAlpha(element.opacity)

        let centerX = element.position.x + element.size.width / 2
        let centerY = element.position.y + element.size.height / 2
        context.translateBy(x: centerX, y: centerY)
        context.rotate(by: element.rotation)
        context.translateBy(x: -element.size.width / 2, y: -element.size.height / 2)

        let rect = CGRect(origin: .zero, size: element.size)
        let frameWidth = resolvedFrameWidth(for: element)
        let layout = frameLayout(for: element, in: rect, frameWidth: frameWidth)

        if element.showFrame {
            drawFrameBackdrop(for: element, in: context, rect: rect, layout: layout, frameWidth: frameWidth)
        }

        drawImage(image, in: layout.imageRect, cornerRadius: layout.imageCornerRadius, context: context)

        if element.showFrame {
            drawFrameDecoration(for: element, in: context, rect: rect, layout: layout, frameWidth: frameWidth)
        }

        context.restoreGState()
    }

    /// フレーム有効時の画像レイアウトを求める
    /// - Parameters:
    ///   - element: 対象画像要素
    ///   - rect: 要素全体矩形
    ///   - frameWidth: 有効フレーム幅
    /// - Returns: 画像表示用レイアウト
    private static func frameLayout(for element: ImageElement, in rect: CGRect, frameWidth: CGFloat) -> FrameLayout {
        guard element.showFrame else {
            return FrameLayout(
                imageRect: rect,
                imageCornerRadius: element.roundedCorners ? element.cornerRadius : 0,
                outerCornerRadius: element.roundedCorners ? element.cornerRadius : 0
            )
        }

        let minSide = min(rect.width, rect.height)
        let baseCornerRadius = element.roundedCorners ? element.cornerRadius : 0

        switch element.frameStyle {
        case .simple, .double, .cornerAccent, .neon, .softWhite, .glassWhite, .editorialWhite:
            return FrameLayout(
                imageRect: rect,
                imageCornerRadius: baseCornerRadius,
                outerCornerRadius: baseCornerRadius
            )

        case .polaroid:
            let horizontalInset = min(rect.width * 0.18, frameWidth * 1.8)
            let topInset = min(rect.height * 0.18, frameWidth * 1.8)
            let bottomInset = min(rect.height * 0.32, frameWidth * 4.8)
            let imageRect = inset(rect, top: topInset, left: horizontalInset, bottom: bottomInset, right: horizontalInset)
            return FrameLayout(
                imageRect: imageRect,
                imageCornerRadius: max(baseCornerRadius - frameWidth, 0),
                outerCornerRadius: max(baseCornerRadius, frameWidth * 1.6)
            )

        case .film:
            let horizontalInset = min(rect.width * 0.20, frameWidth * 2.4)
            let verticalInset = min(rect.height * 0.20, frameWidth * 2.4)
            let imageRect = inset(rect, top: verticalInset, left: horizontalInset, bottom: verticalInset, right: horizontalInset)
            return FrameLayout(
                imageRect: imageRect,
                imageCornerRadius: max(baseCornerRadius - frameWidth * 0.5, 0),
                outerCornerRadius: max(baseCornerRadius, frameWidth * 1.2)
            )

        case .badge:
            let insetAmount = min(minSide * 0.12, frameWidth * 2.2)
            let imageRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
            let outerCornerRadius = max(baseCornerRadius, minSide * 0.12)
            return FrameLayout(
                imageRect: imageRect,
                imageCornerRadius: max(outerCornerRadius * 0.72, max(baseCornerRadius - insetAmount * 0.35, 0)),
                outerCornerRadius: outerCornerRadius
            )

        case .stamp:
            let insetAmount = min(minSide * 0.12, frameWidth * 2.0)
            let imageRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
            return FrameLayout(
                imageRect: imageRect,
                imageCornerRadius: max(baseCornerRadius - insetAmount * 0.35, 0),
                outerCornerRadius: 6
            )
        }
    }

    /// フレーム背面装飾を描画する
    /// - Parameters:
    ///   - element: 対象画像要素
    ///   - context: 描画先
    ///   - rect: 要素全体矩形
    ///   - layout: 画像レイアウト
    ///   - frameWidth: 有効フレーム幅
    /// - Returns: なし
    private static func drawFrameBackdrop(
        for element: ImageElement,
        in context: CGContext,
        rect: CGRect,
        layout: FrameLayout,
        frameWidth: CGFloat
    ) {
        switch element.frameStyle {
        case .simple, .double, .cornerAccent, .neon, .softWhite, .glassWhite, .editorialWhite:
            return

        case .polaroid:
            let fillColor = mix(element.frameColor, with: .white, amount: 0.92)
            fill(rect, cornerRadius: layout.outerCornerRadius, color: fillColor, in: context)
            stroke(rect.insetBy(dx: 0.75, dy: 0.75), cornerRadius: max(layout.outerCornerRadius - 0.75, 0), color: UIColor.black.withAlphaComponent(0.10), width: 1.5, in: context)

        case .film:
            fill(rect, cornerRadius: layout.outerCornerRadius, color: UIColor(white: 0.08, alpha: 1), in: context)

        case .badge:
            let fillColor = mix(element.frameColor, with: .white, amount: 0.80).withAlphaComponent(0.92)
            fill(rect, cornerRadius: layout.outerCornerRadius, color: fillColor, in: context)
            let highlightRect = rect.insetBy(dx: frameWidth * 0.55, dy: frameWidth * 0.55)
            stroke(highlightRect, cornerRadius: max(layout.outerCornerRadius - frameWidth * 0.55, 0), color: UIColor.white.withAlphaComponent(0.55), width: max(1, frameWidth * 0.4), in: context)

        case .stamp:
            let paperColor = mix(element.frameColor, with: UIColor(red: 0.97, green: 0.95, blue: 0.88, alpha: 1), amount: 0.90)
            fill(rect, cornerRadius: 0, color: paperColor, in: context)
        }
    }

    /// フレーム前面装飾を描画する
    /// - Parameters:
    ///   - element: 対象画像要素
    ///   - context: 描画先
    ///   - rect: 要素全体矩形
    ///   - layout: 画像レイアウト
    ///   - frameWidth: 有効フレーム幅
    /// - Returns: なし
    private static func drawFrameDecoration(
        for element: ImageElement,
        in context: CGContext,
        rect: CGRect,
        layout: FrameLayout,
        frameWidth: CGFloat
    ) {
        switch element.frameStyle {
        case .simple:
            let strokeRect = rect.insetBy(dx: frameWidth / 2, dy: frameWidth / 2)
            stroke(strokeRect, cornerRadius: adjustedCornerRadius(layout.outerCornerRadius, inset: frameWidth / 2), color: element.frameColor, width: frameWidth, in: context)

        case .double:
            let outerRect = rect.insetBy(dx: frameWidth / 2, dy: frameWidth / 2)
            let innerInset = min(min(rect.width, rect.height) * 0.08, frameWidth * 1.9)
            let innerRect = rect.insetBy(dx: innerInset, dy: innerInset)
            stroke(outerRect, cornerRadius: adjustedCornerRadius(layout.outerCornerRadius, inset: frameWidth / 2), color: element.frameColor, width: frameWidth, in: context)
            stroke(innerRect, cornerRadius: adjustedCornerRadius(layout.outerCornerRadius, inset: innerInset), color: mix(element.frameColor, with: .white, amount: 0.55), width: max(1, frameWidth * 0.45), in: context)

        case .cornerAccent:
            let baseRect = rect.insetBy(dx: frameWidth / 2, dy: frameWidth / 2)
            drawCornerAccents(in: baseRect, color: element.frameColor, width: max(2, frameWidth * 0.95), context: context)

        case .polaroid:
            let separatorY = layout.imageRect.maxY + max(8, frameWidth * 0.85)
            context.saveGState()
            context.setStrokeColor(UIColor.black.withAlphaComponent(0.12).cgColor)
            context.setLineWidth(1)
            context.move(to: CGPoint(x: layout.imageRect.minX, y: separatorY))
            context.addLine(to: CGPoint(x: layout.imageRect.maxX, y: separatorY))
            context.strokePath()
            context.restoreGState()
            stroke(layout.imageRect.insetBy(dx: 0.75, dy: 0.75), cornerRadius: adjustedCornerRadius(layout.imageCornerRadius, inset: 0.75), color: UIColor.black.withAlphaComponent(0.14), width: 1.5, in: context)

        case .film:
            stroke(layout.imageRect.insetBy(dx: 0.75, dy: 0.75), cornerRadius: adjustedCornerRadius(layout.imageCornerRadius, inset: 0.75), color: UIColor.white.withAlphaComponent(0.15), width: 1.5, in: context)
            drawFilmPerforations(in: rect, imageRect: layout.imageRect, context: context)

        case .neon:
            let neonRect = rect.insetBy(dx: frameWidth * 0.55, dy: frameWidth * 0.55)
            context.saveGState()
            context.setShadow(offset: .zero, blur: frameWidth * 3.4, color: element.frameColor.withAlphaComponent(0.95).cgColor)
            stroke(neonRect, cornerRadius: adjustedCornerRadius(layout.outerCornerRadius, inset: frameWidth * 0.55), color: element.frameColor, width: frameWidth * 1.15, in: context)
            context.restoreGState()
            stroke(neonRect, cornerRadius: adjustedCornerRadius(layout.outerCornerRadius, inset: frameWidth * 0.55), color: UIColor.white.withAlphaComponent(0.58), width: max(1, frameWidth * 0.26), in: context)

        case .badge:
            let outerRect = rect.insetBy(dx: frameWidth * 0.45, dy: frameWidth * 0.45)
            stroke(outerRect, cornerRadius: adjustedCornerRadius(layout.outerCornerRadius, inset: frameWidth * 0.45), color: element.frameColor, width: max(2, frameWidth * 0.95), in: context)
            stroke(layout.imageRect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: adjustedCornerRadius(layout.imageCornerRadius, inset: 0.5), color: UIColor.white.withAlphaComponent(0.42), width: 1, in: context)

        case .stamp:
            let roughRect = rect.insetBy(dx: frameWidth * 0.35, dy: frameWidth * 0.35)
            let roughPath = roughBorderPath(in: roughRect, amplitude: max(1.4, frameWidth * 0.26))
            context.saveGState()
            context.addPath(roughPath.cgPath)
            context.setStrokeColor(mix(element.frameColor, with: .black, amount: 0.16).cgColor)
            context.setLineWidth(max(1.6, frameWidth * 0.72))
            context.setLineJoin(.round)
            context.setLineCap(.round)
            context.strokePath()
            context.restoreGState()

            context.saveGState()
            context.addPath(roughPath.cgPath)
            context.setStrokeColor(UIColor.black.withAlphaComponent(0.10).cgColor)
            context.setLineWidth(max(1, frameWidth * 0.24))
            context.setLineDash(phase: 0, lengths: [3, 4, 5, 3])
            context.strokePath()
            context.restoreGState()

        case .softWhite, .glassWhite, .editorialWhite:
            let overlayInset = max(frameWidth * 1.15, min(rect.width, rect.height) * 0.045)
            let innerRect = rect.insetBy(dx: overlayInset, dy: overlayInset)
            let overlayAlpha = min(max(element.frameColor.cgColor.alpha, 0.08), 0.92)
            let baseColor = mix(element.frameColor.withAlphaComponent(1), with: .white, amount: 0.72)
                .withAlphaComponent(overlayAlpha)
            let highlightColor = UIColor.white.withAlphaComponent(min(overlayAlpha + 0.14, 0.55))
            let shadowColor = UIColor.black.withAlphaComponent(min(overlayAlpha * 0.45, 0.18))

            fillRing(
                outerRect: rect,
                innerRect: innerRect,
                outerCornerRadius: layout.outerCornerRadius,
                innerCornerRadius: adjustedCornerRadius(layout.imageCornerRadius, inset: overlayInset),
                color: baseColor,
                in: context
            )

            stroke(
                innerRect.insetBy(dx: 0.5, dy: 0.5),
                cornerRadius: adjustedCornerRadius(layout.imageCornerRadius, inset: overlayInset + 0.5),
                color: highlightColor,
                width: 1,
                in: context
            )
            stroke(
                rect.insetBy(dx: 0.6, dy: 0.6),
                cornerRadius: adjustedCornerRadius(layout.outerCornerRadius, inset: 0.6),
                color: shadowColor,
                width: 1.2,
                in: context
            )
        }
    }

    /// 画像本体をクリップ付きで描画する
    /// - Parameters:
    ///   - image: 描画画像
    ///   - rect: 画像表示矩形
    ///   - cornerRadius: 角丸半径
    ///   - context: 描画先
    /// - Returns: なし
    private static func drawImage(_ image: UIImage, in rect: CGRect, cornerRadius: CGFloat, context: CGContext) {
        context.saveGState()
        if cornerRadius > 0 {
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            context.addPath(path.cgPath)
            context.clip()
        }
        image.draw(in: rect)
        context.restoreGState()
    }

    /// フレーム幅の下限を補正する
    /// - Parameter element: 対象画像要素
    /// - Returns: 描画に使うフレーム幅
    private static func resolvedFrameWidth(for element: ImageElement) -> CGFloat {
        max(element.frameWidth, 1)
    }

    /// 矩形を部分インセットする
    /// - Parameters:
    ///   - rect: 元矩形
    ///   - top: 上インセット
    ///   - left: 左インセット
    ///   - bottom: 下インセット
    ///   - right: 右インセット
    /// - Returns: インセット後矩形
    private static func inset(_ rect: CGRect, top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX + left,
            y: rect.minY + top,
            width: max(1, rect.width - left - right),
            height: max(1, rect.height - top - bottom)
        )
    }

    /// 指定矩形を塗りつぶす
    /// - Parameters:
    ///   - rect: 対象矩形
    ///   - cornerRadius: 角丸半径
    ///   - color: 塗り色
    ///   - context: 描画先
    /// - Returns: なし
    private static func fill(_ rect: CGRect, cornerRadius: CGFloat, color: UIColor, in context: CGContext) {
        context.saveGState()
        if cornerRadius > 0 {
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            context.addPath(path.cgPath)
            context.setFillColor(color.cgColor)
            context.fillPath()
        } else {
            context.setFillColor(color.cgColor)
            context.fill(rect)
        }
        context.restoreGState()
    }

    /// 外周と内周の間だけを塗りつぶす
    /// - Parameters:
    ///   - outerRect: 外側矩形
    ///   - innerRect: 内側矩形
    ///   - outerCornerRadius: 外側角丸
    ///   - innerCornerRadius: 内側角丸
    ///   - color: 塗り色
    ///   - context: 描画先
    /// - Returns: なし
    private static func fillRing(
        outerRect: CGRect,
        innerRect: CGRect,
        outerCornerRadius: CGFloat,
        innerCornerRadius: CGFloat,
        color: UIColor,
        in context: CGContext
    ) {
        context.saveGState()
        let ringPath = UIBezierPath(roundedRect: outerRect, cornerRadius: outerCornerRadius)
        ringPath.append(UIBezierPath(roundedRect: innerRect, cornerRadius: innerCornerRadius))
        ringPath.usesEvenOddFillRule = true
        color.setFill()
        ringPath.fill()
        context.restoreGState()
    }

    /// 指定矩形をストローク描画する
    /// - Parameters:
    ///   - rect: 対象矩形
    ///   - cornerRadius: 角丸半径
    ///   - color: 線色
    ///   - width: 線幅
    ///   - context: 描画先
    /// - Returns: なし
    private static func stroke(_ rect: CGRect, cornerRadius: CGFloat, color: UIColor, width: CGFloat, in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        if cornerRadius > 0 {
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            context.addPath(path.cgPath)
            context.strokePath()
        } else {
            context.stroke(rect)
        }
        context.restoreGState()
    }

    /// 角装飾フレームのコーナー線を描画する
    /// - Parameters:
    ///   - rect: ベース矩形
    ///   - color: 線色
    ///   - width: 線幅
    ///   - context: 描画先
    /// - Returns: なし
    private static func drawCornerAccents(in rect: CGRect, color: UIColor, width: CGFloat, context: CGContext) {
        let length = min(rect.width, rect.height) * 0.22

        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.setLineCap(.round)

        let corners: [(CGPoint, CGPoint, CGPoint)] = [
            (CGPoint(x: rect.minX, y: rect.minY + length), CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.minX + length, y: rect.minY)),
            (CGPoint(x: rect.maxX - length, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY + length)),
            (CGPoint(x: rect.minX, y: rect.maxY - length), CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.minX + length, y: rect.maxY)),
            (CGPoint(x: rect.maxX - length, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY - length))
        ]

        for segment in corners {
            context.move(to: segment.0)
            context.addLine(to: segment.1)
            context.addLine(to: segment.2)
            context.strokePath()
        }

        context.restoreGState()
    }

    /// フィルム風フレームのパーフォレーションを描画する
    /// - Parameters:
    ///   - rect: 外枠矩形
    ///   - imageRect: 画像矩形
    ///   - context: 描画先
    /// - Returns: なし
    private static func drawFilmPerforations(in rect: CGRect, imageRect: CGRect, context: CGContext) {
        let availableHorizontal = rect.width - imageRect.width
        let availableVertical = rect.height - imageRect.height
        let holeColor = UIColor(white: 0.96, alpha: 0.82)

        context.saveGState()
        context.setFillColor(holeColor.cgColor)

        if availableHorizontal > availableVertical {
            let laneWidth = max(8, availableHorizontal * 0.42)
            let holeWidth = max(4, laneWidth * 0.28)
            let holeHeight = max(6, rect.height * 0.055)
            let count = max(4, Int((imageRect.height / (holeHeight * 1.9)).rounded()))
            let leftX = rect.minX + (laneWidth - holeWidth) / 2
            let rightX = rect.maxX - laneWidth + (laneWidth - holeWidth) / 2

            for index in 0..<count {
                let progress = CGFloat(index) / CGFloat(max(count - 1, 1))
                let y = imageRect.minY + progress * max(imageRect.height - holeHeight, 0)
                let leftHole = UIBezierPath(roundedRect: CGRect(x: leftX, y: y, width: holeWidth, height: holeHeight), cornerRadius: holeWidth / 2)
                let rightHole = UIBezierPath(roundedRect: CGRect(x: rightX, y: y, width: holeWidth, height: holeHeight), cornerRadius: holeWidth / 2)
                context.addPath(leftHole.cgPath)
                context.fillPath()
                context.addPath(rightHole.cgPath)
                context.fillPath()
            }
        } else {
            let laneHeight = max(8, availableVertical * 0.42)
            let holeWidth = max(6, rect.width * 0.055)
            let holeHeight = max(4, laneHeight * 0.28)
            let count = max(4, Int((imageRect.width / (holeWidth * 1.9)).rounded()))
            let topY = rect.minY + (laneHeight - holeHeight) / 2
            let bottomY = rect.maxY - laneHeight + (laneHeight - holeHeight) / 2

            for index in 0..<count {
                let progress = CGFloat(index) / CGFloat(max(count - 1, 1))
                let x = imageRect.minX + progress * max(imageRect.width - holeWidth, 0)
                let topHole = UIBezierPath(roundedRect: CGRect(x: x, y: topY, width: holeWidth, height: holeHeight), cornerRadius: holeHeight / 2)
                let bottomHole = UIBezierPath(roundedRect: CGRect(x: x, y: bottomY, width: holeWidth, height: holeHeight), cornerRadius: holeHeight / 2)
                context.addPath(topHole.cgPath)
                context.fillPath()
                context.addPath(bottomHole.cgPath)
                context.fillPath()
            }
        }

        context.restoreGState()
    }

    /// スタンプ風のラフな外周パスを生成する
    /// - Parameters:
    ///   - rect: ベース矩形
    ///   - amplitude: ゆらぎ幅
    /// - Returns: ラフパス
    private static func roughBorderPath(in rect: CGRect, amplitude: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        let horizontalSteps = max(8, Int((rect.width / 14).rounded()))
        let verticalSteps = max(8, Int((rect.height / 14).rounded()))

        func offset(_ progress: CGFloat, seed: CGFloat) -> CGFloat {
            amplitude * (
                sin(progress * 7.1 + seed) * 0.62 +
                sin(progress * 13.7 + seed * 1.9) * 0.38
            )
        }

        let startPoint = CGPoint(x: rect.minX, y: rect.minY + offset(0, seed: 0.4))
        path.move(to: startPoint)

        for index in 1...horizontalSteps {
            let progress = CGFloat(index) / CGFloat(horizontalSteps)
            path.addLine(to: CGPoint(
                x: rect.minX + rect.width * progress,
                y: rect.minY + offset(progress, seed: 0.4)
            ))
        }
        for index in 1...verticalSteps {
            let progress = CGFloat(index) / CGFloat(verticalSteps)
            path.addLine(to: CGPoint(
                x: rect.maxX + offset(progress, seed: 1.2),
                y: rect.minY + rect.height * progress
            ))
        }
        for index in 1...horizontalSteps {
            let progress = CGFloat(index) / CGFloat(horizontalSteps)
            path.addLine(to: CGPoint(
                x: rect.maxX - rect.width * progress,
                y: rect.maxY + offset(progress, seed: 2.0)
            ))
        }
        for index in 1...verticalSteps {
            let progress = CGFloat(index) / CGFloat(verticalSteps)
            path.addLine(to: CGPoint(
                x: rect.minX + offset(progress, seed: 2.8),
                y: rect.maxY - rect.height * progress
            ))
        }

        path.close()
        return path
    }

    /// 角丸半径からインセット分を差し引く
    /// - Parameters:
    ///   - radius: 元半径
    ///   - inset: 差し引き量
    /// - Returns: 補正済み半径
    private static func adjustedCornerRadius(_ radius: CGFloat, inset: CGFloat) -> CGFloat {
        max(radius - inset, 0)
    }

    /// 2色を線形補間する
    /// - Parameters:
    ///   - base: 基準色
    ///   - other: 混色先
    ///   - amount: 混合率
    /// - Returns: 補間後の色
    private static func mix(_ base: UIColor, with other: UIColor, amount: CGFloat) -> UIColor {
        let clamped = max(0, min(amount, 1))

        var baseRed: CGFloat = 0
        var baseGreen: CGFloat = 0
        var baseBlue: CGFloat = 0
        var baseAlpha: CGFloat = 0
        base.getRed(&baseRed, green: &baseGreen, blue: &baseBlue, alpha: &baseAlpha)

        var otherRed: CGFloat = 0
        var otherGreen: CGFloat = 0
        var otherBlue: CGFloat = 0
        var otherAlpha: CGFloat = 0
        other.getRed(&otherRed, green: &otherGreen, blue: &otherBlue, alpha: &otherAlpha)

        return UIColor(
            red: baseRed + (otherRed - baseRed) * clamped,
            green: baseGreen + (otherGreen - baseGreen) * clamped,
            blue: baseBlue + (otherBlue - baseBlue) * clamped,
            alpha: baseAlpha + (otherAlpha - baseAlpha) * clamped
        )
    }
}
