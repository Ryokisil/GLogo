//
//  BackgroundBlurMaskEditView.swift
//  背景ぼかし用マスクの編集画面を提供するビュー。
//

import SwiftUI

struct BackgroundBlurMaskEditView: View {
    /// 背景ぼかしマスク編集の状態と処理を管理するViewModel
    @StateObject private var viewModel: BackgroundBlurMaskEditViewModel
    /// 画面の戻り操作に使用するプレゼンテーション環境
    @Environment(\.presentationMode) var presentationMode
    /// 現在のズーム倍率
    @State private var zoomScale: CGFloat = 1.0
    /// 現在のパンオフセット
    @State private var panOffset: CGSize = .zero

    /// 背景ぼかしマスク編集用イニシャライザ
    /// - Parameters:
    ///   - imageElement: 編集対象の画像要素
    ///   - initialMaskData: 初期マスクデータ（既存のマスクがある場合）
    ///   - blurRadius: 背景ぼかし半径（プレビュー用）
    ///   - onComplete: 編集完了時の処理（マスクデータを返す）
    /// - Returns: なし
    init(
        imageElement: ImageElement,
        initialMaskData: Data?,
        blurRadius: CGFloat,
        onComplete: @escaping (Data?) -> Void
    ) {
        self._viewModel = StateObject(wrappedValue: BackgroundBlurMaskEditViewModel(
            imageElement: imageElement,
            initialMaskData: initialMaskData,
            blurRadius: blurRadius,
            completion: onComplete
        ))
    }

    /// 編集画面の本体ビュー
    /// - Parameters: なし
    /// - Returns: 背景ぼかしマスク編集のUI
    var body: some View {
        ZStack {
            // 明るい背景
            Color.white
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // 編集エリア
                GeometryReader { geometry in
                    let imageSize = viewModel.originalImage.size
                    let displayFrame = ManualRemovalTargetOverlay<BackgroundBlurMaskEditViewModel>.calculateDisplayFrame(
                        imageSize: imageSize,
                        containerSize: geometry.size
                    )
                    ZStack {
                        // チェッカーボード背景（透明パターン）
                        CheckerboardPattern()

                        // 背景ぼかしプレビュー
                        ZStack {
                            if let previewImage = viewModel.getBackgroundBlurPreview() {
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

                            // マスクの可視化オーバーレイ（青）
                            if let maskImage = viewModel.state.maskImage {
                                Image(uiImage: maskImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                                    .colorInvert()
                                    .colorMultiply(.blue)
                                    .blendMode(.screen)
                                    .opacity(0.35)
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
                            ProgressView("AI処理中...")
                                .padding(12)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(8)
                        }

                        if !viewModel.state.isSourceImageAvailable {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.title2)
                                    .foregroundColor(.orange)
                                Text(viewModel.state.sourceImageErrorMessage ?? "画像の読み込みに失敗しました")
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
                        Text("モード:")
                            .font(.headline)

                        Picker("編集モード", selection: $viewModel.state.mode) {
                            ForEach(RemovalMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())

                        Spacer()
                    }

                    // ブラシサイズ
                    HStack {
                        Text("ブラシサイズ:")
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

                        // AIマスク生成
                        Button("AIマスク生成") {
                            Task {
                                await viewModel.applyAIMask()
                            }
                        }
                        .disabled(!viewModel.state.isSourceImageAvailable || viewModel.state.isProcessingAI)

                        Spacer()

                        // リセット
                        Button("リセット") {
                            viewModel.reset()
                        }
                        .foregroundColor(.red)
                        .disabled(!viewModel.state.isSourceImageAvailable)

                        // 完了
                        Button("完了") {
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
        .navigationBarTitle("背景ぼかしマスク編集", displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button("キャンセル") {
                viewModel.cancel()
                presentationMode.wrappedValue.dismiss()
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: .manualRemovalResetZoom)) { _ in
            withAnimation(.easeOut(duration: 0.2)) {
                zoomScale = 1.0
                panOffset = .zero
            }
        }
    }
}
