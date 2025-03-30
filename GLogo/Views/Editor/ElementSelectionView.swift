//
//  ElementSelectionView.swift
//  GameLogoMaker
//
//  概要:
//  このファイルは選択された要素の周囲に表示される選択ハンドルやコントロールを
//  管理するビューコンポーネントです。移動、リサイズ、回転などの操作のための
//  視覚的なハンドルを提供し、ユーザーがドラッグジェスチャーで要素を操作できるようにします。
//  CanvasViewと連携して動作します。
//

import SwiftUI

/// 選択ハンドルの種類
enum HandleType {
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left
    case rotation
    case center
    
    /// ハンドルの位置を要素の境界矩形から計算
    func position(for bounds: CGRect, rotationOffset: CGFloat = 30) -> CGPoint {
        switch self {
        case .topLeft:
            return CGPoint(x: bounds.minX, y: bounds.minY)
        case .top:
            return CGPoint(x: bounds.midX, y: bounds.minY)
        case .topRight:
            return CGPoint(x: bounds.maxX, y: bounds.minY)
        case .right:
            return CGPoint(x: bounds.maxX, y: bounds.midY)
        case .bottomRight:
            return CGPoint(x: bounds.maxX, y: bounds.maxY)
        case .bottom:
            return CGPoint(x: bounds.midX, y: bounds.maxY)
        case .bottomLeft:
            return CGPoint(x: bounds.minX, y: bounds.maxY)
        case .left:
            return CGPoint(x: bounds.minX, y: bounds.midY)
        case .rotation:
            return CGPoint(x: bounds.midX, y: bounds.minY - rotationOffset)
        case .center:
            return CGPoint(x: bounds.midX, y: bounds.midY)
        }
    }
    
    /// ハンドルのドラッグ操作から対応する操作タイプを取得
    var manipulationType: ElementManipulationType {
        switch self {
        case .center:
            return .move
        case .rotation:
            return .rotate
        default:
            return .resize
        }
    }
    
    /// カーソルタイプを取得（macCatalystで使用）
//    var cursorType: NSCursor? {
//#if targetEnvironment(macCatalyst)
//        switch self {
//        case .topLeft, .bottomRight:
//            return NSCursor.resizeNorthWestSouthEastCursor
//        case .topRight, .bottomLeft:
//            return NSCursor.resizeNorthEastSouthWestCursor
//        case .top, .bottom:
//            return NSCursor.resizeUpDownCursor
//        case .left, .right:
//            return NSCursor.resizeLeftRightCursor
//        case .rotation:
//            return NSCursor.rotateLeftCursor
//        case .center:
//            return NSCursor.openHandCursor
//        }
//#else
//        return nil
//#endif
//    }
}

/// 選択された要素の操作用ハンドルを表示・管理するSwiftUIビュー
struct ElementSelectionView: View {
    /// 選択された要素
    let element: LogoElement
    
    /// ハンドルの半径
    let handleRadius: CGFloat = 6.0
    
    /// 選択ボーダーの色
    let selectionBorderColor: Color = .blue
    
    /// 選択ボーダーの幅
    let selectionBorderWidth: CGFloat = 1.5
    
    /// ハンドル操作開始時のコールバック
    var onManipulationStarted: ((ElementManipulationType, CGPoint) -> Void)?
    
    /// ハンドル操作中のコールバック
    var onManipulationChanged: ((CGPoint) -> Void)?
    
    /// ハンドル操作終了時のコールバック
    var onManipulationEnded: (() -> Void)?
    
    var body: some View {
        ZStack {
            // 選択ボーダー
            SelectionBorder(frame: element.frame,
                            onDragStarted: { startPoint in
                onManipulationStarted?(.move, startPoint)
            },
                            onDragChanged: { currentPoint in
                onManipulationChanged?(currentPoint)
            },
                            onDragEnded: {
                onManipulationEnded?()
            })
            
            // 要素がロックされていなければハンドルを表示
            if !element.isLocked {
                // 各種ハンドル
                ForEach(getHandleTypes(), id: \.self) { handleType in
                    SelectionHandle(
                        type: handleType,
                        position: handleType.position(for: element.frame),
                        radius: handleRadius,
                        onDragStarted: { startPoint in
                            onManipulationStarted?(handleType.manipulationType, startPoint)
                        },
                        onDragChanged: { currentPoint in
                            onManipulationChanged?(currentPoint)
                        },
                        onDragEnded: {
                            onManipulationEnded?()
                        }
                    )
                }
                
                // 回転ハンドルと中心を結ぶ線
                Path { path in
                    let topCenter = HandleType.top.position(for: element.frame)
                    let rotationPoint = HandleType.rotation.position(for: element.frame)
                    path.move(to: topCenter)
                    path.addLine(to: rotationPoint)
                }
                .stroke(selectionBorderColor, lineWidth: 1)
            } else {
                // ロック表示
                LockIndicator(position: CGPoint(x: element.frame.maxX - 15, y: element.frame.minY + 15))
            }
        }
    }
    
    /// ハンドルタイプの配列を取得
    private func getHandleTypes() -> [HandleType] {
        return [
            .topLeft, .top, .topRight,
            .left, .center, .right,
            .bottomLeft, .bottom, .bottomRight,
            .rotation
        ]
    }
}

/// 選択ボーダーを表示するビュー
struct SelectionBorder: View {
    let frame: CGRect
    let color: Color = .blue
    let lineWidth: CGFloat = 1.5
    let dashPattern: [CGFloat] = [4, 2]
    
    // ドラッグジェスチャーのコールバック
    var onDragStarted: ((CGPoint) -> Void)?
    var onDragChanged: ((CGPoint) -> Void)?
    var onDragEnded: (() -> Void)?
    
    var body: some View {
        RoundedRectangle(cornerRadius: 0)
            .stroke(
                color,
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: dashPattern
                )
            )
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .contentShape(Rectangle())  // タッチ領域を確保
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

/// 選択ハンドルを表示するビュー
struct SelectionHandle: View {
    /// ハンドルタイプ
    let type: HandleType
    
    /// ハンドルの位置
    let position: CGPoint
    
    /// ハンドルの半径
    let radius: CGFloat
    
    /// ドラッグ開始時のコールバック
    var onDragStarted: ((CGPoint) -> Void)?
    
    /// ドラッグ中のコールバック
    var onDragChanged: ((CGPoint) -> Void)?
    
    /// ドラッグ終了時のコールバック
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
        // macCatalystでカーソルを変更
            .onHover { isHovered in
#if targetEnvironment(macCatalyst)
                if isHovered, let cursor = type.cursorType {
                    cursor.set()
                } else {
                    NSCursor.arrow.set()
                }
#endif
            }
    }
}

/// ロックインジケータを表示するビュー
struct LockIndicator: View {
    let position: CGPoint
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.7))
                .frame(width: 24, height: 24)
            
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundColor(.white)
        }
        .position(position)
    }
}
