//
//  ManualBackgroundRemovalView.swift
//  GLogo
//
//  概要:
//  手動背景除去編集画面のSwiftUIビューです。
//  選択された画像要素に対してブラシベースの背景除去編集を提供し、
//  直感的なタッチ操作とリアルタイムプレビューを実現します。
//

import SwiftUI

/// 手動背景除去編集画面
struct ManualBackgroundRemovalView: View {
    @StateObject private var viewModel: ManualBackgroundRemovalViewModel
    @Environment(\.presentationMode) var presentationMode
    
    /// イニシャライザ
    init(imageElement: ImageElement, editorViewModel: EditorViewModel?) {
        self._viewModel = StateObject(wrappedValue: ManualBackgroundRemovalViewModel(
            imageElement: imageElement,
            editorViewModel: editorViewModel
        ) { editedImage in
            // 編集完了時の処理はナビゲーション戻り時に実行
        })
    }
    
    var body: some View {
        ZStack {
            // 明るい背景
            Color.white
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // 編集エリア
                GeometryReader { geometry in
                    ZStack {
                        // チェッカーボード背景（透明パターン）
                        CheckerboardPattern()
                        
                        // マスク適用済み画像を表示
                        if let maskedImage = viewModel.getMaskedImage() {
                            Image(uiImage: maskedImage)
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
                        
                        // ブラシストローク表示用オーバーレイ（赤色で可視化）
                        if let maskImage = viewModel.state.maskImage {
                            Image(uiImage: maskImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                                .colorMultiply(.white)
                                .opacity(0.2)  // 半透明
                                .id(viewModel.state.maskUpdateId)
                        }
                        
                        // タッチ操作用のオーバーレイ
                        ManualRemovalCanvas(viewModel: viewModel)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
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
                            
                            Spacer()
                            
                            // リセット
                            Button("リセット") {
                                viewModel.reset()
                            }
                            .foregroundColor(.red)
                            
                            // 完了
                            Button("完了") {
                                viewModel.complete()
                                presentationMode.wrappedValue.dismiss()
                            }
                            .foregroundColor(.blue)
                            .fontWeight(.semibold)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                }
            }
            .navigationBarTitle("背景除去編集", displayMode: .inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(
                leading: Button("キャンセル") {
                    viewModel.cancel()
                    presentationMode.wrappedValue.dismiss()
                }
            )
    }
}


/// タッチ操作用のキャンバス
struct ManualRemovalCanvas: UIViewRepresentable {
    @ObservedObject var viewModel: ManualBackgroundRemovalViewModel
    
    func makeUIView(context: Context) -> ManualRemovalCanvasUIView {
        let view = ManualRemovalCanvasUIView()
        view.viewModel = viewModel
        return view
    }
    
    func updateUIView(_ uiView: ManualRemovalCanvasUIView, context: Context) {
        uiView.viewModel = viewModel
    }
}

/// UIKitベースのタッチ操作キャンバス
class ManualRemovalCanvasUIView: UIView {
    weak var viewModel: ManualBackgroundRemovalViewModel?
    private var lastTouchPoint: CGPoint?
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let touchPoint = touch.location(in: self)
        lastTouchPoint = touchPoint
        handleTouch(touches)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouchWithLine(touches)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastTouchPoint = nil
    }
    
    private func handleTouch(_ touches: Set<UITouch>) {
        guard let viewModel = viewModel,
              let touch = touches.first else { 
            print("DEBUG: viewModel or touch is nil")
            return 
        }
        
        let touchPoint = touch.location(in: self)
        print("DEBUG: Touch at screen point: \(touchPoint)")
        
        // 画面座標を画像座標に変換
        let imagePoint = convertToImageCoordinates(touchPoint)
        print("DEBUG: Converted to image point: \(imagePoint)")
        
        // ブラシストロークを適用
        Task { @MainActor in
            print("DEBUG: Applying brush stroke")
            viewModel.applyBrushStroke(at: imagePoint)
        }
    }
    
    private func handleTouchWithLine(_ touches: Set<UITouch>) {
        guard let viewModel = viewModel,
              let touch = touches.first,
              let lastPoint = lastTouchPoint else { return }
        
        let currentPoint = touch.location(in: self)
        
        // 前回の点から現在の点まで線を描画
        let lastImagePoint = convertToImageCoordinates(lastPoint)
        let currentImagePoint = convertToImageCoordinates(currentPoint)
        
        // ラインストローク用のメソッドを呼び出し
        Task { @MainActor in
            viewModel.applyBrushLine(from: lastImagePoint, to: currentImagePoint)
        }
        
        lastTouchPoint = currentPoint
    }
    
    /// 画面座標を画像座標に変換
    private func convertToImageCoordinates(_ screenPoint: CGPoint) -> CGPoint {
        guard let viewModel = viewModel else { return screenPoint }
        
        let imageSize = viewModel.originalImage.size
        let viewSize = bounds.size
        
        // アスペクトフィット計算
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height
        
        var displaySize: CGSize
        var displayOrigin: CGPoint
        
        if imageAspect > viewAspect {
            // 横長画像
            displaySize = CGSize(width: viewSize.width, height: viewSize.width / imageAspect)
            displayOrigin = CGPoint(x: 0, y: (viewSize.height - displaySize.height) / 2)
        } else {
            // 縦長画像
            displaySize = CGSize(width: viewSize.height * imageAspect, height: viewSize.height)
            displayOrigin = CGPoint(x: (viewSize.width - displaySize.width) / 2, y: 0)
        }
        
        // 正規化座標に変換
        let normalizedX = (screenPoint.x - displayOrigin.x) / displaySize.width
        let normalizedY = (screenPoint.y - displayOrigin.y) / displaySize.height
        
        // 画像座標に変換（範囲チェック付き）
        let imageX = max(0, min(normalizedX * imageSize.width, imageSize.width - 1))
        let imageY = max(0, min(normalizedY * imageSize.height, imageSize.height - 1))
        
        print("DEBUG: Image size: \(imageSize), Converted point: (\(imageX), \(imageY))")
        return CGPoint(x: imageX, y: imageY)
    }
}

/// プレビュー
struct ManualBackgroundRemovalView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleImageData = UIImage(systemName: "photo")?.pngData() ?? Data()
        let imageElement = ImageElement(imageData: sampleImageData, fitMode: .aspectFit)
        
        ManualBackgroundRemovalView(
            imageElement: imageElement,
            editorViewModel: EditorViewModel()
        )
    }
}
