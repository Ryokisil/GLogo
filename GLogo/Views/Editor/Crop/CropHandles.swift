//
//  CropHandles.swift
//  GameLogoMaker
//
//  概要:
//  クロップハンドルを管理するビュー
//

import SwiftUI

struct CropHandles: View {
    @ObservedObject var viewModel: ImageCropViewModel
    
    var body: some View {
        ZStack {
            ForEach(CropHandleType.allCases, id: \.self) { handleType in
                CropHandle(
                    position: viewModel.cropHandlePosition(for: handleType),
                    onDragStarted: { point in
                        viewModel.startCropHandleDrag(handleType, at: point)
                    },
                    onDragChanged: { point in
                        viewModel.updateCropHandleDrag(at: point)
                    },
                    onDragEnded: {
                        viewModel.endCropHandleDrag()
                    }
                )
            }
        }
    }
}
