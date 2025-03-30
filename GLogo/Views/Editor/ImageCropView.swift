//
//  ImageCropView.swift
//  GameLogoMaker
//
//  概要:
//  このファイルは画像インポート時の調整機能を提供するSwiftUIビューです。
//  画像のクロップ、拡大縮小、位置調整などの機能を提供し、
//  ユーザーが必要な部分だけを正確に選択できるようにします。
//  画像のアスペクト比を変更したり、元のサイズのままインポートすることもできます。
//  画像選択後、ImageElementとして追加する前の中間処理として機能します。
//

import SwiftUI
import UIKit

/// 画像クロップビュー
struct ImageCropView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var cropRect: CGRect
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    @State private var lastDragOffset: CGSize = .zero
    
    let originalImage: UIImage
    let completion: (UIImage) -> Void
    
    // 初期化時に画像サイズに基づいてクロップ領域を設定
    init(image: UIImage, completion: @escaping (UIImage) -> Void) {
        self.originalImage = image
        self.completion = completion
        
        // 画面サイズを取得
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height * 0.6
        
        // 画像のアスペクト比を維持しながら表示サイズを計算
        let imageSize = image.size
        let imageAspect = imageSize.width / imageSize.height
        let screenAspect = screenWidth / screenHeight
        
        var displaySize: CGSize
        var origin: CGPoint
        
        if imageAspect > screenAspect {
            // 画像が画面より横長の場合
            let width = screenWidth - 40 // 余白を考慮
            let height = width / imageAspect
            displaySize = CGSize(width: width, height: height)
            origin = CGPoint(x: 20, y: (screenHeight - height) / 2)
        } else {
            // 画像が画面より縦長の場合
            let height = screenHeight - 80 // 余白と下部のコントロール用のスペースを確保
            let width = height * imageAspect
            displaySize = CGSize(width: width, height: height)
            origin = CGPoint(x: (screenWidth - width) / 2, y: 40)
        }
        
        // 初期クロップ領域を画像全体に設定
        self._cropRect = State(initialValue: CGRect(
            origin: origin,
            size: displaySize
        ))
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
                            // チェッカーボードパターン（透明部分の表示用）
                            CheckerboardPattern()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                            
                            // 画像表示
                            Image(uiImage: originalImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: cropRect.width / scale, height: cropRect.height / scale)
                                .scaleEffect(scale)
                                .position(x: cropRect.midX + dragOffset.width, y: cropRect.midY + dragOffset.height)
                                .gesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            self.scale = min(4.0, max(0.5, self.lastScale * value.magnitude))
                                        }
                                        .onEnded { _ in
                                            self.lastScale = self.scale
                                        }
                                )
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            self.dragOffset = CGSize(
                                                width: self.lastDragOffset.width + value.translation.width,
                                                height: self.lastDragOffset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { _ in
                                            self.lastDragOffset = self.dragOffset
                                        }
                                )
                            
                            // クロップ領域の表示
                            CropOverlay(cropRect: $cropRect)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    // 下部のコントロール
                    HStack(spacing: 20) {
                        AspectRatioButton(title: "フリー", action: { resetCropRect() })
                        AspectRatioButton(title: "1:1", action: { setCropAspectRatio(1) })
                        AspectRatioButton(title: "4:3", action: { setCropAspectRatio(4/3) })
                        AspectRatioButton(title: "16:9", action: { setCropAspectRatio(16/9) })
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
                    if let croppedImage = cropImage() {
                        completion(croppedImage)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            )
        }
    }
    
    /// 画像のクロップ処理
    private func cropImage() -> UIImage? {
        // 画像の表示サイズと位置を計算
        let displayRect = calculateImageViewSize()
        
        // 元画像と表示サイズの比率を計算
        let widthRatio = originalImage.size.width / displayRect.width
        let heightRatio = originalImage.size.height / displayRect.height
        
        // 画像の実際の位置（スケールとドラッグを考慮）
        let effectiveImageRect = CGRect(
            x: displayRect.origin.x + dragOffset.width,
            y: displayRect.origin.y + dragOffset.height,
            width: displayRect.width * scale,
            height: displayRect.height * scale
        )
        
        // クロップ枠と実際の画像の相対位置を計算
        let relativeRect = CGRect(
            x: (cropRect.origin.x - effectiveImageRect.origin.x) / scale,
            y: (cropRect.origin.y - effectiveImageRect.origin.y) / scale,
            width: cropRect.width / scale,
            height: cropRect.height / scale
        )
        
        // 左右の余白を調整するための補正値
        // この値を調整して左右のバランスを取る
        let horizontalOffset: CGFloat = 20.0  // 左側に追加する余白
        let verticalOffset: CGFloat = 10.0    // 下側に追加する余白
        
        // 元画像の座標系に変換（補正値を適用）
        let cropX = (relativeRect.origin.x - horizontalOffset) * widthRatio
        let cropY = (relativeRect.origin.y - verticalOffset) * heightRatio
        let cropWidth = relativeRect.width * widthRatio
        let cropHeight = relativeRect.height * heightRatio
        
        // 境界チェック
        let safeX = max(0, min(cropX, originalImage.size.width - 1))
        let safeY = max(0, min(cropY, originalImage.size.height - 1))
        let safeWidth = min(cropWidth, originalImage.size.width - safeX)
        let safeHeight = min(cropHeight, originalImage.size.height - safeY)
        
        // 安全なクロップ領域を確保
        let safeCropRect = CGRect(x: safeX, y: safeY, width: safeWidth, height: safeHeight)
        
        print("補正後のクロップ計算:")
        print("実効画像位置: \(effectiveImageRect)")
        print("相対位置(補正前): \(relativeRect)")
        print("補正値: 横=\(horizontalOffset), 縦=\(verticalOffset)")
        print("実際のクロップ位置: \(safeCropRect)")
        
        // UIGraphicsImageRendererを使用してクロップ
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: safeWidth, height: safeHeight))
        
        return renderer.image { context in
            // 元の画像をクロップ領域のオフセットを考慮して描画
            originalImage.draw(at: CGPoint(x: -safeX, y: -safeY))
        }
    }
    
    // 画像の表示サイズと位置を計算するヘルパーメソッド
    private func calculateImageViewSize() -> CGRect {
        let containerWidth: CGFloat = UIScreen.main.bounds.width - 40
        let containerHeight: CGFloat = UIScreen.main.bounds.height * 0.6
        
        let imageSize = originalImage.size
        var displaySize: CGSize
        var originX: CGFloat = 20  // デフォルトの左余白
        var originY: CGFloat = 40  // デフォルトの上余白
        
        // 余白の調整値
        let marginAdjustment: CGFloat = 15  // この値を調整して余白を微調整
        
        if imageSize.width / imageSize.height > containerWidth / containerHeight {
            // 画像が画面より横長の場合
            let aspectRatio = imageSize.height / imageSize.width
            displaySize = CGSize(width: containerWidth - marginAdjustment*2, height: (containerWidth - marginAdjustment*2) * aspectRatio)
            originX += marginAdjustment
            originY = (containerHeight - displaySize.height) / 2 + originY
        } else {
            // 画像が画面より縦長の場合
            let aspectRatio = imageSize.width / imageSize.height
            displaySize = CGSize(width: (containerHeight - marginAdjustment*2) * aspectRatio, height: containerHeight - marginAdjustment*2)
            originX = (containerWidth - displaySize.width) / 2 + originX
            originY += marginAdjustment
        }
        
        return CGRect(x: originX, y: originY, width: displaySize.width, height: displaySize.height)
    }
    
    /// クロップ領域をリセット（元の画像サイズに合わせる）
    private func resetCropRect() {
        // 画像の表示サイズを計算
        let maxSize: CGFloat = 300
        let imageSize = originalImage.size
        
        if imageSize.width > imageSize.height {
            let aspectRatio = imageSize.height / imageSize.width
            cropRect = CGRect(
                x: 0,
                y: 0,
                width: maxSize,
                height: maxSize * aspectRatio
            )
        } else {
            let aspectRatio = imageSize.width / imageSize.height
            cropRect = CGRect(
                x: 0,
                y: 0,
                width: maxSize * aspectRatio,
                height: maxSize
            )
        }
        
        // ドラッグやスケール操作をリセット
        scale = 1.0
        lastScale = 1.0
        dragOffset = .zero
        lastDragOffset = .zero
    }
    
    /// アスペクト比の設定
    private func setCropAspectRatio(_ ratio: CGFloat) {
        // 現在のクロップ領域の中心点を保持
        let center = CGPoint(x: cropRect.midX, y: cropRect.midY)
        
        // 新しい幅と高さを計算
        var newWidth: CGFloat
        var newHeight: CGFloat
        
        if cropRect.width > cropRect.height {
            newWidth = cropRect.width
            newHeight = newWidth / ratio
        } else {
            newHeight = cropRect.height
            newWidth = newHeight * ratio
        }
        
        // 中心点を基準に新しいクロップ領域を設定
        cropRect = CGRect(
            x: center.x - newWidth / 2,
            y: center.y - newHeight / 2,
            width: newWidth,
            height: newHeight
        )
    }
}

/// クロップオーバーレイビュー
struct CropOverlay: View {
    @Binding var cropRect: CGRect
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 半透明のオーバーレイ
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                // クロップ領域を切り抜く
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: cropRect.width, height: cropRect.height)
                    .position(x: cropRect.midX, y: cropRect.midY)
                    .blendMode(.destinationOut)
                
                // クロップ枠
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: cropRect.width, height: cropRect.height)
                    .position(x: cropRect.midX, y: cropRect.midY)
                
                // ハンドルの配置
                CropHandles(cropRect: $cropRect)
            }
            .compositingGroup()
        }
    }
}

/// アスペクト比ボタンコンポーネント
struct AspectRatioButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.6))
                .cornerRadius(8)
        }
    }
}

// MARK: - CropHandlesコンポーネント

/// CropHandlesコンポーネント
struct CropHandles: View {
    @Binding var cropRect: CGRect
    private let handleRadius: CGFloat = 10.0
    
    // ドラッグ中のハンドル
    @State private var activeHandle: CropHandleType?
    @State private var dragStart: CGPoint = .zero
    @State private var initialRect: CGRect = .zero
    
    var body: some View {
        ZStack {
            // 各ハンドルを配置
            ForEach(CropHandleType.allCases, id: \.self) { handleType in
                CropHandle(
                    position: handlePosition(for: handleType),
                    radius: handleRadius,
                    onDragStarted: { point in
                        activeHandle = handleType
                        dragStart = point
                        initialRect = cropRect
                    },
                    onDragChanged: { point in
                        guard let activeHandle = activeHandle else { return }
                        updateCropRect(for: activeHandle, at: point)
                    },
                    onDragEnded: {
                        activeHandle = nil
                    }
                )
            }
        }
    }
    
    /// ハンドル位置の計算
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
    
    /// クロップ領域の更新
    private func updateCropRect(for handleType: CropHandleType, at point: CGPoint) {
        let deltaX = point.x - dragStart.x
        let deltaY = point.y - dragStart.y
        
        var newRect = initialRect
        
        switch handleType {
        case .topLeft:
            newRect.origin.x = min(initialRect.maxX - 50, initialRect.minX + deltaX)
            newRect.origin.y = min(initialRect.maxY - 50, initialRect.minY + deltaY)
            newRect.size.width = initialRect.maxX - newRect.minX
            newRect.size.height = initialRect.maxY - newRect.minY
            
        case .topCenter:
            newRect.origin.y = min(initialRect.maxY - 50, initialRect.minY + deltaY)
            newRect.size.height = initialRect.maxY - newRect.minY
            
        case .topRight:
            newRect.size.width = max(50, initialRect.width + deltaX)
            newRect.origin.y = min(initialRect.maxY - 50, initialRect.minY + deltaY)
            newRect.size.height = initialRect.maxY - newRect.minY
            
        case .middleLeft:
            newRect.origin.x = min(initialRect.maxX - 50, initialRect.minX + deltaX)
            newRect.size.width = initialRect.maxX - newRect.minX
            
        case .middleRight:
            newRect.size.width = max(50, initialRect.width + deltaX)
            
        case .bottomLeft:
            newRect.origin.x = min(initialRect.maxX - 50, initialRect.minX + deltaX)
            newRect.size.width = initialRect.maxX - newRect.minX
            newRect.size.height = max(50, initialRect.height + deltaY)
            
        case .bottomCenter:
            newRect.size.height = max(50, initialRect.height + deltaY)
            
        case .bottomRight:
            newRect.size.width = max(50, initialRect.width + deltaX)
            newRect.size.height = max(50, initialRect.height + deltaY)
        }
        
        cropRect = newRect
    }
}

/// クロップハンドルのタイプ
enum CropHandleType: CaseIterable {
    case topLeft, topCenter, topRight
    case middleLeft, middleRight
    case bottomLeft, bottomCenter, bottomRight
}

/// 個別のクロップハンドル
struct CropHandle: View {
    let position: CGPoint
    let radius: CGFloat
    var onDragStarted: ((CGPoint) -> Void)?
    var onDragChanged: ((CGPoint) -> Void)?
    var onDragEnded: (() -> Void)?
    
    var body: some View {
        Circle()
            .fill(Color.blue)
            .frame(width: radius * 2, height: radius * 2)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 1)
            )
            .position(position)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if value.translation == .zero {
                            // ドラッグ開始
                            onDragStarted?(value.startLocation)
                        }
                        // ドラッグ中
                        onDragChanged?(value.location)
                    }
                    .onEnded { _ in
                        // ドラッグ終了
                        onDragEnded?()
                    }
            )
    }
}
