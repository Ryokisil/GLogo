//
//  ElementSelectionView.swift
//
//  概要:
//  このファイルは選択された要素に対するジェスチャー入力を扱う SwiftUI オーバーレイです。
//  役割: 移動・拡大縮小・回転のジェスチャー適用と、タップによる選択切り替え。
//  ハンドルUIは廃止し、CanvasViewは描画とタップ選択のみを担当します。
//

import SwiftUI

/// 選択された要素の枠を表示し、移動・拡大縮小・回転とタップを受け付けるSwiftUIビュー
struct ElementSelectionView: View {
    /// 選択された要素
    let element: LogoElement

    /// ピンチでスケール変更
    var onMagnifyChanged: ((CGFloat) -> Void)?
    var onMagnifyEnded: (() -> Void)?

    /// 回転ジェスチャー
    var onRotateGestureChanged: ((CGFloat) -> Void)?
    var onRotateGestureEnded: (() -> Void)?

    /// ダブルタップで回転を初期化
    var onResetRotation: (() -> Void)?

    /// ドラッグで位置変更（ジェスチャーベース）
    var onMoveChanged: ((CGSize) -> Void)?
    var onMoveEnded: (() -> Void)?

    /// タップで選択を切り替えるためのコールバック（座標付き）
    var onTapSelect: ((CGPoint) -> Void)?

    var body: some View {
        let localFrame = CGRect(origin: .zero, size: element.frame.size)
        ZStack {
            // 選択ボーダー（移動・拡大縮小・回転のジェスチャーを受ける領域）
            SelectionBorder(frame: localFrame)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        onMoveChanged?(value.translation)
                    }
                    .onEnded { _ in
                        onMoveEnded?()
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { scale in
                        onMagnifyChanged?(scale)
                    }
                    .onEnded { _ in
                        onMagnifyEnded?()
                    }
            )
            .simultaneousGesture(
                RotationGesture()
                    .onChanged { angle in
                        onRotateGestureChanged?(angle.radians)
                    }
                    .onEnded { _ in
                        onRotateGestureEnded?()
                    }
            )
#if DEBUG
            // UI テストが、対象要素の位置・サイズ・回転を Undo／Redo の前後で比べるための値。
            .accessibilityElement()
            .accessibilityIdentifier("editor.canvas.selection")
            .accessibilityValue(Self.debugTransformValue(for: element))
#endif

            // ロック中はロック表示を出す（ハンドルUIは廃止し、ジェスチャー操作に統一）
            if element.isLocked {
                LockIndicator(position: CGPoint(x: localFrame.maxX - 15, y: localFrame.minY + 15))
            }
        }
        .frame(width: element.frame.width, height: element.frame.height)
        .position(x: element.frame.midX, y: element.frame.midY)
        .contentShape(Rectangle())
        // タップを処理して選択切替
        .simultaneousGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("canvas"))
                .onEnded { value in
                    let distance = hypot(value.translation.width, value.translation.height)
                    // 実質ドラッグでなければタップとして扱う
                    if distance < 5 {
                        onTapSelect?(value.startLocation)
                    }
                }
        )
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    onResetRotation?()
                }
        )
    }

#if DEBUG
    /// UI テスト用の値。キャンバス座標の位置・サイズと回転（ラジアン）を、比較しやすい固定の書式で返す。
    static func debugTransformValue(for element: LogoElement) -> String {
        String(
            format: "x=%.2f y=%.2f w=%.2f h=%.2f r=%.4f",
            element.position.x, element.position.y,
            element.size.width, element.size.height,
            element.rotation
        )
    }
#endif
}

/// 選択ボーダーを表示するビュー。ジェスチャーは呼び出し元が付ける
struct SelectionBorder: View {
    let frame: CGRect
    let color: Color = .blue
    let lineWidth: CGFloat = 1.5
    let dashPattern: [CGFloat] = [4, 2]

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
