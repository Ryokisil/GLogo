//
//  CropHandleInteraction.swift
//  GLogo
//
//  概要:
//  クロップハンドル操作に伴う矩形更新とハンドル位置計算を担うユースケース。
//

import UIKit

struct CropHandleInteractionUseCase {
    private let absoluteMinSize: CGFloat = 50.0

    func handlePosition(for type: CropHandleType, cropRect: CGRect) -> CGPoint {
        switch type {
        case .topLeft:     return CGPoint(x: cropRect.minX, y: cropRect.minY)
        case .topCenter:   return CGPoint(x: cropRect.midX, y: cropRect.minY)
        case .topRight:    return CGPoint(x: cropRect.maxX, y: cropRect.minY)
        case .middleLeft:  return CGPoint(x: cropRect.minX, y: cropRect.midY)
        case .middleRight: return CGPoint(x: cropRect.maxX, y: cropRect.midY)
        case .bottomLeft:  return CGPoint(x: cropRect.minX, y: cropRect.maxY)
        case .bottomCenter:return CGPoint(x: cropRect.midX, y: cropRect.maxY)
        case .bottomRight: return CGPoint(x: cropRect.maxX, y: cropRect.maxY)
        }
    }

    func updatedCropRect(
        for handleType: CropHandleType,
        dragStart: CGPoint,
        currentPoint: CGPoint,
        initialRect: CGRect,
        imageFrame: CGRect
    ) -> CGRect {
        let deltaX = currentPoint.x - dragStart.x
        let deltaY = currentPoint.y - dragStart.y

        var newRect = initialRect
        let minSize = absoluteMinSize

        switch handleType {
        case .topLeft:
            newRect.origin.x = min(initialRect.maxX - minSize, initialRect.minX + deltaX)
            newRect.origin.y = min(initialRect.maxY - minSize, initialRect.minY + deltaY)
            newRect.size.width = initialRect.maxX - newRect.minX
            newRect.size.height = initialRect.maxY - newRect.minY
        case .topCenter:
            newRect.origin.y = min(initialRect.maxY - minSize, initialRect.minY + deltaY)
            newRect.size.height = initialRect.maxY - newRect.minY
        case .topRight:
            newRect.size.width = max(minSize, initialRect.width + deltaX)
            newRect.origin.y = min(initialRect.maxY - minSize, initialRect.minY + deltaY)
            newRect.size.height = initialRect.maxY - newRect.minY
        case .middleLeft:
            newRect.origin.x = min(initialRect.maxX - minSize, initialRect.minX + deltaX)
            newRect.size.width = initialRect.maxX - newRect.minX
        case .middleRight:
            newRect.size.width = max(minSize, initialRect.width + deltaX)
        case .bottomLeft:
            newRect.origin.x = min(initialRect.maxX - minSize, initialRect.minX + deltaX)
            newRect.size.width = initialRect.maxX - newRect.minX
            newRect.size.height = max(minSize, initialRect.height + deltaY)
        case .bottomCenter:
            newRect.size.height = max(minSize, initialRect.height + deltaY)
        case .bottomRight:
            newRect.size.width = max(minSize, initialRect.width + deltaX)
            newRect.size.height = max(minSize, initialRect.height + deltaY)
        }

        return clipCropRectToImage(newRect, imageFrame: imageFrame)
    }

    private func clipCropRectToImage(_ rect: CGRect, imageFrame: CGRect) -> CGRect {
        var rect = rect
        let epsilon: CGFloat = 0.001

        if rect.minX < imageFrame.minX + epsilon {
            rect.origin.x = imageFrame.minX
        }
        if rect.maxX > imageFrame.maxX - epsilon {
            rect.size.width = imageFrame.maxX - rect.minX
        }

        if rect.minY < imageFrame.minY + epsilon {
            rect.origin.y = imageFrame.minY
        }
        if rect.maxY > imageFrame.maxY - epsilon {
            rect.size.height = imageFrame.maxY - rect.minY
        }

        let minSize = min(imageFrame.width, imageFrame.height) * 0.05
        if rect.width < minSize {
            rect.size.width = minSize
        }
        if rect.height < minSize {
            rect.size.height = minSize
        }

        if rect.maxX > imageFrame.maxX {
            rect.origin.x = imageFrame.maxX - rect.width
        }
        if rect.maxY > imageFrame.maxY {
            rect.origin.y = imageFrame.maxY - rect.height
        }

        return rect
    }
}
