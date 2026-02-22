//
//  ManualBackgroundRemovalView.swift
//  GLogo
//
//  概要:
//  手動背景除去（透明化）編集画面のSwiftUIビューです。
//  選択された画像要素に対してブラシベースの背景除去編集を提供し、
//  直感的なタッチ操作とリアルタイムプレビューを実現します。
//

import SwiftUI
import UIKit

/// 手動背景除去編集画面
struct ManualBackgroundRemovalView: View {
    /// 手動背景除去の状態と処理を管理するViewModel
    @StateObject private var viewModel: ManualBackgroundRemovalViewModel
    /// 画面の戻り操作に使用するプレゼンテーション環境
    @Environment(\.presentationMode) var presentationMode
    /// 現在のズーム倍率
    @State private var zoomScale: CGFloat = 1.0
    /// 現在のパンオフセット
    @State private var panOffset: CGSize = .zero
    /// ガイド表示フラグ
    @State private var isShowingGuide = false
    /// ガイドの現在ステップ
    @State private var guideStepIndex = 0

    /// 背景除去モード用イニシャライザ
    /// - Parameters:
    ///   - imageElement: 編集対象の画像要素
    ///   - onComplete: 編集完了時の処理（背景除去後の画像を返す）
    /// - Returns: なし
    init(imageElement: ImageElement, onComplete: @escaping (UIImage) -> Void = { _ in }) {
        self._viewModel = StateObject(wrappedValue: ManualBackgroundRemovalViewModel(
            imageElement: imageElement,
            completion: onComplete
        ))
    }

    /// 編集画面の本体ビュー
    /// - Parameters: なし
    /// - Returns: 手動背景除去の編集UI
    var body: some View {
        ZStack {
            // 明るい背景
            Color.white
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // 編集エリア
                GeometryReader { geometry in
                    let imageSize = viewModel.originalImage.size
                    let displayFrame = ManualRemovalTargetOverlay<ManualBackgroundRemovalViewModel>.calculateDisplayFrame(
                        imageSize: imageSize,
                        containerSize: geometry.size
                    )
                    ZStack {
                        // チェッカーボード背景（透明パターン）
                        CheckerboardPattern()
                        
                        // マスク適用済み画像を表示
                        ZStack {
                            if let previewImage = viewModel.getMaskedImage() {
                                Image(uiImage: previewImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                                    .id(viewModel.state.maskUpdateId)
                            } else {
                                Image(uiImage: viewModel.originalImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                            }
                            
                            // 除去領域の可視化オーバーレイ（赤）
                            if let maskImage = viewModel.state.maskImage {
                                Image(uiImage: maskImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                                    .colorInvert()
                                    .colorMultiply(.red)
                                    .blendMode(.screen)
                                    .opacity(0.35)  // 半透明
                                    .id(viewModel.state.maskUpdateId)
                            }
                        }
                        .scaleEffect(zoomScale, anchor: .center)
                        .offset(panOffset)
                        
                        // ターゲット操作用オーバーレイ
                        ManualRemovalTargetOverlay(
                            viewModel: viewModel,
                            zoomScale: zoomScale,
                            panOffset: panOffset
                        )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // 2本指ズーム/パン用の透明レイヤー
                        ZoomPanGestureView(
                            zoomScale: $zoomScale,
                            panOffset: $panOffset,
                            displayFrame: displayFrame,
                            maxScale: 4.0
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if viewModel.state.isProcessingAI {
                            Color.black.opacity(0.2)
                                .ignoresSafeArea()
                            ProgressView("Processing AI...")
                                .padding(12)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(8)
                        }

                        if !viewModel.state.isSourceImageAvailable {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.title2)
                                    .foregroundColor(.orange)
                                Text(viewModel.state.sourceImageErrorMessage ?? "Failed to load image.")
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.primary)
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(12)
                        }
                    }
                    .allowsHitTesting(viewModel.state.isSourceImageAvailable)
                }
                .frame(maxHeight: .infinity)
                
                // ツールバー
                VStack(spacing: 16) {
                        Divider()
                        
                        // モード切り替え
                        HStack(spacing: 12) {
                            Text("Mode:")
                                .font(.headline)
                            
                            Picker("Edit Mode", selection: $viewModel.state.mode) {
                                ForEach(RemovalMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            
                            Spacer()
                        }
                        
                        // ブラシサイズ
                        HStack {
                            Text("Brush Size:")
                                .font(.subheadline)
                            
                            Slider(value: Binding(
                                get: { viewModel.state.brushSize },
                                set: { viewModel.setBrushSize($0) }
                            ), in: 5...50, step: 1)
                        }
                        
                        // 操作ボタン
                        HStack(spacing: 20) {
                            // Undo
                            Button(action: viewModel.undo) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.title2)
                            }
                            .disabled(!viewModel.state.canUndo)
                            
                            // Redo
                            Button(action: viewModel.redo) {
                                Image(systemName: "arrow.uturn.forward")
                                    .font(.title2)
                            }
                            .disabled(!viewModel.state.canRedo)

                            // AI背景除去
                            Button("AI Remove") {
                                Task {
                                    await viewModel.applyAIMask()
                                }
                            }
                            .disabled(!viewModel.state.isSourceImageAvailable || viewModel.state.isProcessingAI)
                            
                            Spacer()
                            
                            // リセット
                            Button("Reset") {
                                viewModel.reset()
                            }
                            .foregroundColor(.red)
                            .disabled(!viewModel.state.isSourceImageAvailable)
                            
                            // 完了
                            Button("Done") {
                                viewModel.complete()
                                presentationMode.wrappedValue.dismiss()
                            }
                            .foregroundColor(.blue)
                            .fontWeight(.semibold)
                            .disabled(!viewModel.state.isSourceImageAvailable)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                }
            }
            .overlay {
                if isShowingGuide {
                    EditorIntroOverlay(
                        isPresented: $isShowingGuide,
                        stepIndex: $guideStepIndex,
                        steps: Self.removalGuideSteps
                    ) {}
                    .transition(.opacity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.cancel()
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("Background Removal Edit")
                        .font(.headline)
                        .foregroundStyle(Color(uiColor: .label))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        guideStepIndex = 0
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isShowingGuide = true
                        }
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.primary)
                    }
                }
            }
            .toolbarBackground(Color(uiColor: .systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onReceive(NotificationCenter.default.publisher(for: .manualRemovalResetZoom)) { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    zoomScale = 1.0
                    panOffset = .zero
                }
            }
    }

    // MARK: - ガイドステップ定義

    private static let removalGuideSteps: [EditorIntroStep] = [
        EditorIntroStep(
            titleEN: "Paint to Remove",
            titleJP: "塗って除去",
            messageEN: "Drag the handle to paint over the area you want to remove. The red overlay shows the removal area.",
            messageJP: "ハンドルをドラッグして除去したい部分をなぞります。赤いオーバーレイが除去範囲を示します。",
            systemImageName: "paintbrush.pointed"
        ),
        EditorIntroStep(
            titleEN: "Switch Modes",
            titleJP: "モード切り替え",
            messageEN: "Use Remove mode to erase the background, or Restore mode to bring back areas you removed by mistake.",
            messageJP: "Removeモードで背景を除去、Restoreモードで誤って除去した部分を復元できます。",
            systemImageName: "arrow.left.arrow.right"
        ),
        EditorIntroStep(
            titleEN: "Zoom & Pan",
            titleJP: "ズームとパン",
            messageEN: "Pinch with two fingers to zoom in/out. While zoomed in, drag with two fingers to pan around. Double-tap to reset the view.",
            messageJP: "2本指でピンチしてズームイン/アウト。ズーム中は2本指ドラッグで画面を移動。ダブルタップでリセット。",
            systemImageName: "hand.pinch"
        ),
        EditorIntroStep(
            titleEN: "AI Remove & Undo",
            titleJP: "AI除去とアンドゥ",
            messageEN: "Tap AI Remove for automatic background detection. Use Undo/Redo to fix mistakes, or Reset to start over.",
            messageJP: "AI Removeで自動背景検出。Undo/Redoでやり直し、Resetで全リセットできます。",
            systemImageName: "wand.and.stars"
        ),
    ]
}

/// プレビュー
struct ManualBackgroundRemovalView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleImageData = UIImage(systemName: "photo")?.pngData() ?? Data()
        let imageElement = ImageElement(imageData: sampleImageData)
        
        ManualBackgroundRemovalView(imageElement: imageElement)
    }
}
