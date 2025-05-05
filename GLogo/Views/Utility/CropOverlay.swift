//
//  CropOverlay.swift
//  GameLogoMaker
//
//  概要:
//  クロップオーバーレイを表示するビュー
//

import SwiftUI

struct CropOverlay: View {
    @Binding var cropRect: CGRect
    @Binding var imageFrame: CGRect
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: cropRect.width, height: cropRect.height)
                    .position(x: cropRect.midX, y: cropRect.midY)
                    .blendMode(.destinationOut)
                
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: cropRect.width, height: cropRect.height)
                    .position(x: cropRect.midX, y: cropRect.midY)
                
                CropHandles(cropRect: $cropRect, imageFrame: $imageFrame)
            }
            .compositingGroup()
        }
        // 【デバッグのために追加】
        .onAppear {
            print("CropOverlay - imageFrame: \(imageFrame)")
            print("CropOverlay - cropRect: \(cropRect)")
        }
    }
}
