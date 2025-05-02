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
    @State private var imageFrame: CGRect // 画像の実際の表示位置とサイズを保持
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
        let initialCropRect = CGRect(
            origin: origin,
            size: displaySize
        )
        
        self._cropRect = State(initialValue: initialCropRect)
        self._imageFrame = State(initialValue: initialCropRect) // 画像枠も同じ値で初期化
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
                            
                            // 画像表示 - 固定位置
                            Image(uiImage: originalImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: imageFrame.width, height: imageFrame.height)
                                .position(x: imageFrame.midX, y: imageFrame.midY)
                            
                            // クロップ領域の表示
                            CropOverlay(cropRect: $cropRect, imageFrame: $imageFrame)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        // 画像のパンとズームを無効化
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
        // デバッグ情報を出力
        print("クロップ枠: \(cropRect)")
        print("元画像サイズ: \(originalImage.size)")
        
        // 画像表示時の実際のサイズと位置を取得
        let displaySize = calculateImageViewSize()
        print("画像表示サイズ: \(displaySize)")
        
        // 画面上の表示と画像座標のマッピングを直接計算
        // スクリーン座標から原画像座標への直接マッピング
        let scaleX = originalImage.size.width / displaySize.width
        let scaleY = originalImage.size.height / displaySize.height
        
        // クロップ枠の左上座標を、画像の左上からの相対位置に変換
        let cropLeft = cropRect.minX - displaySize.minX
        let cropTop = cropRect.minY - displaySize.minY
        
        // 元画像での座標に変換
        let imgX = cropLeft * scaleX
        let imgY = cropTop * scaleY
        let imgWidth = cropRect.width * scaleX
        let imgHeight = cropRect.height * scaleY
        
        print("表示スケール: X=\(scaleX), Y=\(scaleY)")
        print("変換座標: X=\(imgX), Y=\(imgY), W=\(imgWidth), H=\(imgHeight)")
        
        // 境界チェック
        let safeX = max(0, min(imgX, originalImage.size.width))
        let safeY = max(0, min(imgY, originalImage.size.height))
        let safeWidth = min(imgWidth, originalImage.size.width - safeX)
        let safeHeight = min(imgHeight, originalImage.size.height - safeY)
        
        let finalCropRect = CGRect(x: safeX, y: safeY, width: safeWidth, height: safeHeight)
        print("最終クロップ領域: \(finalCropRect)")
        
        // CoreGraphicsを使用した正確なクロップ処理
        if let cgImage = originalImage.cgImage?.cropping(to: finalCropRect) {
            // 正確なクロップ画像を作成
            return UIImage(cgImage: cgImage, scale: originalImage.scale, orientation: originalImage.imageOrientation)
        }
        
        return nil
    }
    
    // 画像の表示サイズと位置を計算するヘルパーメソッド
    private func calculateImageViewSize() -> CGRect {
        // スクリーンサイズから計算範囲を取得
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height * 0.6
        
        // 元画像のアスペクト比
        let imageSize = originalImage.size
        let imageAspect = imageSize.width / imageSize.height
        
        // 表示サイズの計算（余白を考慮）
        let padding: CGFloat = 20
        let maxWidth = screenWidth - padding * 2
        let maxHeight = screenHeight - padding * 2
        
        var displayWidth: CGFloat
        var displayHeight: CGFloat
        
        if imageAspect > maxWidth / maxHeight {
            // 横長画像
            displayWidth = maxWidth
            displayHeight = displayWidth / imageAspect
        } else {
            // 縦長画像
            displayHeight = maxHeight
            displayWidth = displayHeight * imageAspect
        }
        
        // 中央配置の計算
        let originX = (screenWidth - displayWidth) / 2
        let originY = padding + (maxHeight - displayHeight) / 2
        
        return CGRect(x: originX, y: originY, width: displayWidth, height: displayHeight)
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

extension UIImage {
    func cropToRect(_ rect: CGRect) -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }
        
        let scaleX = self.size.width / self.scale
        let scaleY = self.size.height / self.scale
        
        let scaledRect = CGRect(
            x: rect.origin.x * self.scale,
            y: rect.origin.y * self.scale,
            width: rect.size.width * self.scale,
            height: rect.size.height * self.scale
        )
        
        guard let croppedCGImage = cgImage.cropping(to: scaledRect) else { return nil }
        return UIImage(cgImage: croppedCGImage, scale: self.scale, orientation: self.imageOrientation)
    }
}

/// クロップオーバーレイビュー
struct CropOverlay: View {
    @Binding var cropRect: CGRect
    @Binding var imageFrame: CGRect
    
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
                
                // ハンドルの配置 - 画像フレーム情報も渡す
                CropHandles(cropRect: $cropRect, imageFrame: $imageFrame)
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
    
    // 画像の位置・サイズ情報を維持するための参照
    @Binding var imageFrame: CGRect
    
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
    
    /// クロップ領域の更新 - 画像の位置とサイズを考慮
    private func updateCropRect(for handleType: CropHandleType, at point: CGPoint) {
        let deltaX = point.x - dragStart.x
        let deltaY = point.y - dragStart.y
        
        var newRect = initialRect
        
        // 画像の境界内に収まるように制限
        let minX = imageFrame.minX
        let minY = imageFrame.minY
        let maxX = imageFrame.maxX
        let maxY = imageFrame.maxY
        
        switch handleType {
        case .topLeft:
            newRect.origin.x = max(minX, min(initialRect.maxX - 50, initialRect.minX + deltaX))
            newRect.origin.y = max(minY, min(initialRect.maxY - 50, initialRect.minY + deltaY))
            newRect.size.width = initialRect.maxX - newRect.minX
            newRect.size.height = initialRect.maxY - newRect.minY
            
        case .topCenter:
            newRect.origin.y = max(minY, min(initialRect.maxY - 50, initialRect.minY + deltaY))
            newRect.size.height = initialRect.maxY - newRect.minY
            
        case .topRight:
            newRect.size.width = max(50, min(maxX - newRect.minX, initialRect.width + deltaX))
            newRect.origin.y = max(minY, min(initialRect.maxY - 50, initialRect.minY + deltaY))
            newRect.size.height = initialRect.maxY - newRect.minY
            
        case .middleLeft:
            newRect.origin.x = max(minX, min(initialRect.maxX - 50, initialRect.minX + deltaX))
            newRect.size.width = initialRect.maxX - newRect.minX
            
        case .middleRight:
            newRect.size.width = max(50, min(maxX - newRect.minX, initialRect.width + deltaX))
            
        case .bottomLeft:
            newRect.origin.x = max(minX, min(initialRect.maxX - 50, initialRect.minX + deltaX))
            newRect.size.width = initialRect.maxX - newRect.minX
            newRect.size.height = max(50, min(maxY - newRect.minY, initialRect.height + deltaY))
            
        case .bottomCenter:
            newRect.size.height = max(50, min(maxY - newRect.minY, initialRect.height + deltaY))
            
        case .bottomRight:
            newRect.size.width = max(50, min(maxX - newRect.minX, initialRect.width + deltaX))
            newRect.size.height = max(50, min(maxY - newRect.minY, initialRect.height + deltaY))
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
