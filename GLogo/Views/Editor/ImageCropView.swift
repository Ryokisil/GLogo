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
                                    cropRect: $viewModel.cropRect,
                                    imageFrame: $viewModel.imageViewFrame
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    VStack(spacing: 16) {
                        // アスペクト比ボタン
                        HStack(spacing: 20) {
                            AspectRatioButton(title: "フリー", action: { viewModel.resetCropRect() })
                            AspectRatioButton(title: "1:1", action: { viewModel.setCropAspectRatio(1) })
                            AspectRatioButton(title: "4:3", action: { viewModel.setCropAspectRatio(4/3) })
                            AspectRatioButton(title: "16:9", action: { viewModel.setCropAspectRatio(16/9) })
                        }
                        
                        // AI背景除去ボタンとプログレス
                        VStack(spacing: 8) {
                            Button(action: {
                                viewModel.startBackgroundRemoval()
                            }) {
                                HStack {
                                    if viewModel.isProcessingBackgroundRemoval {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "wand.and.stars")
                                    }
                                    Text(viewModel.isProcessingBackgroundRemoval ? "処理中..." : "AI背景除去")
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(viewModel.backgroundRemovedImage != nil ? Color.green : Color.blue)
                                )
                            }
                            .disabled(viewModel.isProcessingBackgroundRemoval)
                            
                            if viewModel.isProcessingBackgroundRemoval {
                                Text("背景を除去中...")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            } else if viewModel.backgroundRemovedImage != nil {
                                Text("背景除去完了")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitle("画像を調整", displayMode: .inline)
            .navigationBarItems(
                leading: Button("キャンセル") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("完了") {
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
                        .onChange(of: imageGeometry.size) { _ in
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
