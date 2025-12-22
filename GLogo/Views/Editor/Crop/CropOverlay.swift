//
//  CropOverlay.swift
//  GameLogoMaker
//
//  概要:
//  クロップオーバーレイを表示するビュー
//

import SwiftUI

struct CropOverlay: View {
    @ObservedObject var viewModel: ImageCropViewModel
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: viewModel.cropRect.width, height: viewModel.cropRect.height)
                    .position(x: viewModel.cropRect.midX, y: viewModel.cropRect.midY)
                    .blendMode(.destinationOut)
                
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: viewModel.cropRect.width, height: viewModel.cropRect.height)
                    .position(x: viewModel.cropRect.midX, y: viewModel.cropRect.midY)
                
                CropHandles(viewModel: viewModel)
            }
            .compositingGroup()
        }
        // 【デバッグのために追加】
        .onAppear {
            print("CropOverlay - imageFrame: \(viewModel.imageViewFrame)")
            print("CropOverlay - cropRect: \(viewModel.cropRect)")
        }
    }
}
