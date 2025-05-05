//
//  CropHandles.swift
//  GameLogoMaker
//
//  概要:
//  クロップハンドルを管理するビュー
//

import SwiftUI

struct CropHandles: View {
    @Binding var cropRect: CGRect
    @Binding var imageFrame: CGRect
    
    @State private var activeHandle: CropHandleType?
    @State private var dragStart: CGPoint = .zero
    @State private var initialRect: CGRect = .zero
    
    private let handleRadius: CGFloat = 12.0
    var onCropRectChanged: (() -> Void)?
    
    var body: some View {
        ZStack {
            ForEach(CropHandleType.allCases, id: \.self) { handleType in
                CropHandle(
                    position: handlePosition(for: handleType),
                    onDragStarted: { point in
                        activeHandle = handleType
                        dragStart = point
                        initialRect = cropRect
                    },
                    onDragChanged: { point in
                        guard let activeHandle = activeHandle else { return }
                        updateCropRect(for: activeHandle, at: point)
                        onCropRectChanged?()
                    },
                    onDragEnded: {
                        activeHandle = nil
                    }
                )
            }
        }
    }
    
    private func handlePosition(for type: CropHandleType) -> CGPoint {
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
    
    private func updateCropRect(for handleType: CropHandleType, at point: CGPoint) {
        let deltaX = point.x - dragStart.x
        let deltaY = point.y - dragStart.y
        
        var newRect = initialRect
        let minSize: CGFloat = 50.0
        
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
        
        clipCropRectToImage(&newRect)
        cropRect = newRect
    }
    
    
    private func clipCropRectToImage(_ rect: inout CGRect) {
        // 浮動小数点の精度を考慮した厳密な境界チェック
        let epsilon: CGFloat = 0.001
        
        // x座標の制限
        if rect.minX < imageFrame.minX + epsilon {
            rect.origin.x = imageFrame.minX
        }
        if rect.maxX > imageFrame.maxX - epsilon {
            rect.size.width = imageFrame.maxX - rect.minX
        }
        
        // y座標の制限
        if rect.minY < imageFrame.minY + epsilon {
            rect.origin.y = imageFrame.minY
        }
        if rect.maxY > imageFrame.maxY - epsilon {
            rect.size.height = imageFrame.maxY - rect.minY
        }
        
        // 最小サイズの確保
        let minSize = min(imageFrame.width, imageFrame.height) * 0.05 // 5%を最小値に
        if rect.width < minSize {
            rect.size.width = minSize
        }
        if rect.height < minSize {
            rect.size.height = minSize
        }
        
        // 最終的な領域が画像フレーム内に収まるように調整
        if rect.maxX > imageFrame.maxX {
            rect.origin.x = imageFrame.maxX - rect.width
        }
        if rect.maxY > imageFrame.maxY {
            rect.origin.y = imageFrame.maxY - rect.height
        }
    }
}
