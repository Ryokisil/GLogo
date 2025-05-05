//
//  CropHandle.swift
//  GameLogoMaker
//
//  概要:
//  個別のクロップハンドルを表示するビュー
//

import SwiftUI

struct CropHandle: View {
    let position: CGPoint
    let radius: CGFloat = 12.0
    var onDragStarted: ((CGPoint) -> Void)?
    var onDragChanged: ((CGPoint) -> Void)?
    var onDragEnded: (() -> Void)?
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: radius * 2, height: radius * 2)
            
            Circle()
                .fill(Color.blue)
                .frame(width: radius * 1.5, height: radius * 1.5)
        }
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        .position(position)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if value.translation == .zero {
                        onDragStarted?(value.startLocation)
                    }
                    onDragChanged?(value.location)
                }
                .onEnded { _ in
                    onDragEnded?()
                }
        )
    }
}
