//
// 概要：フィルター適用・合成処理。
// ベース画像の解像度そのままで出力し、キャンバス座標をスケール変換してオーバーレイを描画。画像要素は高解像度で再描画。

import UIKit

struct ImageProcessingService {
    /// ImageElement に設定されたフィルターを適用した画像を返す
    func applyFilters(to imageElement: ImageElement) -> UIImage? {
        imageElement.getFilteredImageForce()
    }

    /// ベース画像の解像度を保ったままオーバーレイを合成する
    func makeCompositeImage(
        baseImage: UIImage,
        project: LogoProject
    ) -> UIImage? {
        print("[SaveDebug] makeCompositeImage input baseImage.size: \(baseImage.size), scale: \(baseImage.scale)")
        logImageElements(project.elements)

        // 最終出力サイズはベース画像そのまま（解像度保持）
        let imageSize = baseImage.size

        let format = UIGraphicsImageRendererFormat()
        format.scale = baseImage.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)
        return renderer.image { context in
            let cgContext = context.cgContext

            // ベース画像を全体に描画
            let baseRect = CGRect(origin: .zero, size: imageSize)
            baseImage.draw(in: baseRect)

            // 対応するベース画像要素（サイズが一致するもの）を特定
            let imageElements = project.elements.compactMap { $0 as? ImageElement }
            guard let targetImageElement = imageElements.first(where: { element in
                if let original = element.originalImage {
                    return original.size == baseImage.size || element.image?.size == baseImage.size
                }
                return false
            }) else {
                print("[SaveDebug] ❌ ベースに一致する画像要素が見つからないためベースのみで返す")
                return
            }

            // キャンバス座標系での画像要素矩形
            let imageElementRect = CGRect(
                x: targetImageElement.position.x,
                y: targetImageElement.position.y,
                width: targetImageElement.size.width,
                height: targetImageElement.size.height
            )

        // キャンバス→保存画像へのスケール比率（縦横別々に適用、アスペクト比は維持）
        let scaleX = imageSize.width / imageElementRect.width
        let scaleY = imageSize.height / imageElementRect.height
        print("[SaveDebug] scaleX: \(scaleX), scaleY: \(scaleY)")

            // ZIndex順に要素を描画（ベース自身以外を対象）
            let visibleOverlayElements = project.elements.filter { $0.id != targetImageElement.id && $0.isVisible }
            let sortedElements = visibleOverlayElements.sorted { $0.zIndex < $1.zIndex }

            for element in sortedElements {
                let elementRect = CGRect(
                    x: element.position.x,
                    y: element.position.y,
                    width: element.size.width,
                    height: element.size.height
                )
                guard imageElementRect.intersects(elementRect) else { continue }

                // 相対位置に基づきスケール変換
                let relativeX = element.position.x - imageElementRect.minX
                let relativeY = element.position.y - imageElementRect.minY
                let drawRect = CGRect(
                    x: relativeX * scaleX,
                    y: relativeY * scaleY,
                    width: element.size.width * scaleX,
                    height: element.size.height * scaleY
                )
                guard drawRect.width > 0, drawRect.height > 0 else { continue }

                let adjustedElement = element.copy()
                adjustedElement.position = CGPoint(x: drawRect.minX, y: drawRect.minY)
                adjustedElement.size = CGSize(width: drawRect.width, height: drawRect.height)

                if let imageElement = adjustedElement as? ImageElement,
                   let highResImage = imageElement.getFilteredImageForce() {
                    drawHighResolutionImageElement(
                        image: highResImage,
                        element: imageElement,
                        adjustedElement: adjustedElement,
                        in: cgContext
                    )
                    continue
                }

                if let textElement = adjustedElement as? TextElement {
                    scaleTextRenderingAttributes(textElement, by: min(scaleX, scaleY))
                }

                adjustedElement.draw(in: cgContext)
            }
        }
    }

    // MARK: - 補助

    /// 高解像度画像要素を直接描画（角丸・フレーム対応）
    private func drawHighResolutionImageElement(
        image: UIImage,
        element: ImageElement,
        adjustedElement: LogoElement,
        in context: CGContext
    ) {
        guard element.isVisible else { return }

        context.saveGState()
        context.setAlpha(element.opacity)

        let centerX = adjustedElement.position.x + adjustedElement.size.width / 2
        let centerY = adjustedElement.position.y + adjustedElement.size.height / 2
        context.translateBy(x: centerX, y: centerY)
        context.rotate(by: element.rotation)
        context.translateBy(x: -adjustedElement.size.width / 2, y: -adjustedElement.size.height / 2)

        let rect = CGRect(origin: .zero, size: adjustedElement.size)

        if element.roundedCorners && element.cornerRadius > 0 {
            let path = UIBezierPath(roundedRect: rect, cornerRadius: element.cornerRadius)
            context.addPath(path.cgPath)
            context.clip()
        }

        image.draw(in: rect)

        if element.showFrame && element.frameWidth > 0 {
            context.setStrokeColor(element.frameColor.cgColor)
            context.setLineWidth(element.frameWidth)
            let frameRect = rect.insetBy(dx: element.frameWidth / 2, dy: element.frameWidth / 2)
            if element.roundedCorners && element.cornerRadius > 0 {
                let path = UIBezierPath(roundedRect: frameRect, cornerRadius: element.cornerRadius)
                context.addPath(path.cgPath)
                context.strokePath()
            } else {
                context.stroke(frameRect)
            }
        }

        context.restoreGState()
    }

    /// 保存時の拡縮に合わせてテキスト描画属性（フォント・影・縁取り）を調整する
    /// - Parameters:
    ///   - textElement: 調整対象のテキスト要素
    ///   - scale: 拡縮倍率
    /// - Returns: なし
    private func scaleTextRenderingAttributes(_ textElement: TextElement, by scale: CGFloat) {
        guard scale > 0 else { return }

        textElement.fontSize *= scale

        textElement.effects = textElement.effects.map { effect in
            if let shadowEffect = effect as? ShadowEffect {
                let scaledShadowEffect = ShadowEffect(
                    color: shadowEffect.color,
                    offset: CGSize(
                        width: shadowEffect.offset.width * scale,
                        height: shadowEffect.offset.height * scale
                    ),
                    blurRadius: shadowEffect.blurRadius * scale
                )
                scaledShadowEffect.isEnabled = shadowEffect.isEnabled
                return scaledShadowEffect
            }

            if let strokeEffect = effect as? StrokeEffect {
                let scaledStrokeEffect = StrokeEffect(
                    color: strokeEffect.color,
                    width: strokeEffect.width * scale
                )
                scaledStrokeEffect.isEnabled = strokeEffect.isEnabled
                return scaledStrokeEffect
            }

            return effect
        }
    }

    /// 保存処理用の画像要素ログを出力
    private func logImageElements(_ elements: [LogoElement]) {
        let imageElements = elements.compactMap { $0 as? ImageElement }
        print("[SaveDebug] imageElements count: \(imageElements.count)")
        for (index, element) in imageElements.enumerated() {
            let original = element.originalImage?.size ?? .zero
            let processed = element.image?.size ?? .zero
            print("[SaveDebug]   [\(index)] id: \(element.id.uuidString.prefix(8)) pos: \(element.position) size: \(element.size)")
            print("[SaveDebug]       original: \(original) processed: \(processed) scale: \(element.originalImage?.scale ?? 0)/\(element.image?.scale ?? 0)")
            print("[SaveDebug]       visible: \(element.isVisible)")
        }
    }
}
