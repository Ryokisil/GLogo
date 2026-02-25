//
//  ImageCropView.swift
//  GameLogoMaker
//
//  概要:
//  このファイルは画像インポート時の調整機能を提供するSwiftUIビューです。
//  画像のクロップ、拡大縮小、位置調整などの機能を提供し、
//  ユーザーが必要な部分だけを正確に選択できるようにします。
//

import SwiftUI
import UIKit

struct ImageCropView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel: ImageCropViewModel
    @State private var isImageFrameSet = false // フレーム設定の確認
    
    init(image: UIImage, completion: @escaping (UIImage) -> Void) {
        self._viewModel = StateObject(wrappedValue: ImageCropViewModel(image: image, completion: completion))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.opacity(0.8)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    // 画像プレビュー領域
                    GeometryReader { geometry in
                        ZStack {
                            CheckerboardPattern()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                            
                            // 画像表示用ビュー
                            ImagePreviewView(
                                image: viewModel.backgroundRemovedImage ?? viewModel.originalImage,
                                viewModel: viewModel,
                                geometry: geometry
                            )
                            
                            
                            if viewModel.imageIsLoaded {
                                CropOverlay(
                                    viewModel: viewModel
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    Spacer()
                        .frame(height: 16)
                }
            }
            .navigationBarTitle("Adjust Image", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Done") {
                    viewModel.onComplete()
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

// 画像プレビュービュー
struct ImagePreviewView: View {
    let image: UIImage
    @ObservedObject var viewModel: ImageCropViewModel
    let geometry: GeometryProxy
    
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear {
                DispatchQueue.main.async {
                    updateFrame()
                }
            }
            .background(
                GeometryReader { imageGeometry in
                    Color.clear
                        .onChange(of: imageGeometry.size) { 
                            updateFrame()
                        }
                }
            )
    }
    
    private func updateFrame() {
        let imageFrame = calculateImageFrame()
        viewModel.updateImageFrame(imageFrame)
    }
    
    private func calculateImageFrame() -> CGRect {
        let imageSize = image.size
        let containerSize = geometry.size
        
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height
        
        var displaySize: CGSize
        if imageAspect > containerAspect {
            displaySize = CGSize(width: containerSize.width, height: containerSize.width / imageAspect)
        } else {
            displaySize = CGSize(width: containerSize.height * imageAspect, height: containerSize.height)
        }
        
        let displayOrigin = CGPoint(
            x: (containerSize.width - displaySize.width) / 2,
            y: (containerSize.height - displaySize.height) / 2
        )
        
        return CGRect(origin: displayOrigin, size: displaySize)
    }
}
