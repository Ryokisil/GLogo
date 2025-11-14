//
//  ToneCurveView.swift
//  GLogo
//
//  概要:
//  このファイルはトーンカーブ編集用のインタラクティブなグラフビューを実装しています。
//  ユーザーはシャドウとハイライトの制御点をドラッグして階調調整を行うことができます。
//  Core ImageのCIToneCurveフィルターと連携し、リアルタイムでプレビューが更新されます。
//

import SwiftUI

/// トーンカーブ編集ビュー
struct ToneCurveView: View {
    /// トーンカーブの制御点（5点）
    @Binding var curvePoints: [CGPoint]

    /// 変更時のコールバック
    var onChange: (() -> Void)?

    /// グラフのサイズ
    @State private var graphSize: CGSize = .zero

    /// ドラッグ中のポイントインデックス（nilの場合はドラッグしていない）
    @State private var draggingPointIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // タイトル
            Text("トーンカーブ")
                .font(.headline)

            // グラフエリア
            GeometryReader { geometry in
                ZStack {
                    // 背景とグリッド
                    graphBackground

                    // トーンカーブライン
                    curvePathView

                    // 制御点（シャドウとハイライトのみ表示）
                    controlPointsView
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                graphSize = geo.size
                            }
                            .onChange(of: geo.size) { newSize in
                                graphSize = newSize
                            }
                    }
                )
            }
            .aspectRatio(1.0, contentMode: .fit)
            .frame(maxWidth: .infinity)

            // 軸ラベル
            HStack {
                Text("入力 →")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            // チャンネル切り替え（将来の拡張用、現在は無効）
            HStack(spacing: 16) {
                Text("チャンネル:")
                    .font(.subheadline)

                ForEach(["RGB", "R", "G", "B"], id: \.self) { channel in
                    Button(action: {
                        // 将来の実装用
                    }) {
                        Text(channel)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                channel == "RGB" ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1)
                            )
                            .cornerRadius(4)
                    }
                    .disabled(channel != "RGB")
                }
            }

            // リセットボタン
            Button(action: resetCurve) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("リセット")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
    }

    // MARK: - グラフ背景

    private var graphBackground: some View {
        ZStack {
            // 背景色
            Color(UIColor.systemBackground)

            // グリッド線
            Canvas { context, size in
                let path = Path { path in
                    // 縦線（10%刻み）
                    for i in 0...10 {
                        let x = size.width * CGFloat(i) / 10.0
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }

                    // 横線（10%刻み）
                    for i in 0...10 {
                        let y = size.height * CGFloat(i) / 10.0
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                }

                context.stroke(
                    path,
                    with: .color(.gray.opacity(0.2)),
                    lineWidth: 0.5
                )

                // 対角線（デフォルトライン）
                let diagonalPath = Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height))
                    path.addLine(to: CGPoint(x: size.width, y: 0))
                }

                context.stroke(
                    diagonalPath,
                    with: .color(.gray.opacity(0.3)),
                    lineWidth: 1.0,
                    style: StrokeStyle(lineWidth: 1.0, dash: [5, 5])
                )
            }

            // 枠線
            Rectangle()
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        }
    }

    // MARK: - カーブパス

    private var curvePathView: some View {
        Canvas { context, size in
            guard curvePoints.count >= 5 else { return }

            let path = Path { path in
                // グラフ座標系に変換（Y軸を反転）
                let startPoint = CGPoint(
                    x: curvePoints[0].x * size.width,
                    y: size.height - curvePoints[0].y * size.height
                )
                path.move(to: startPoint)

                // 各制御点を通る線を描画
                for i in 1..<curvePoints.count {
                    let point = CGPoint(
                        x: curvePoints[i].x * size.width,
                        y: size.height - curvePoints[i].y * size.height
                    )
                    path.addLine(to: point)
                }
            }

            context.stroke(
                path,
                with: .color(.blue),
                lineWidth: 2.0
            )
        }
    }

    // MARK: - 制御点

    private var controlPointsView: some View {
        ZStack {
            // シャドウポイント（point0）
            if curvePoints.count > 0 {
                controlPoint(index: 0, point: curvePoints[0])
            }

            // ハイライトポイント（point4）
            if curvePoints.count > 4 {
                controlPoint(index: 4, point: curvePoints[4])
            }
        }
    }

    /// 個別の制御点ビュー
    private func controlPoint(index: Int, point: CGPoint) -> some View {
        let isDragging = draggingPointIndex == index

        return Circle()
            .fill(Color.white)
            .frame(width: 16, height: 16)
            .overlay(
                Circle()
                    .stroke(Color.blue, lineWidth: 2)
            )
            .shadow(radius: isDragging ? 4 : 2)
            .position(
                x: point.x * graphSize.width,
                y: graphSize.height - point.y * graphSize.height
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        draggingPointIndex = index
                        updatePoint(index: index, location: value.location)
                    }
                    .onEnded { _ in
                        draggingPointIndex = nil
                        onChange?()
                    }
            )
    }

    // MARK: - ヘルパーメソッド

    /// 制御点の位置を更新
    private func updatePoint(index: Int, location: CGPoint) {
        guard graphSize.width > 0 && graphSize.height > 0 else { return }

        // グラフ座標系に変換（Y軸反転、0-1の範囲にクランプ）
        var newX = location.x / graphSize.width
        var newY = 1.0 - (location.y / graphSize.height)

        // X軸の制約（各ポイントは固定位置）
        if index == 0 {
            newX = 0.0  // シャドウは左端固定
        } else if index == 4 {
            newX = 1.0  // ハイライトは右端固定
        }

        // Y軸を0-1の範囲にクランプ
        newY = max(0.0, min(1.0, newY))

        // 制御点を更新
        curvePoints[index] = CGPoint(x: newX, y: newY)
    }

    /// カーブをリセット
    private func resetCurve() {
        curvePoints = [
            CGPoint(x: 0.0, y: 0.0),
            CGPoint(x: 0.25, y: 0.25),
            CGPoint(x: 0.5, y: 0.5),
            CGPoint(x: 0.75, y: 0.75),
            CGPoint(x: 1.0, y: 1.0)
        ]
        onChange?()
    }
}

/// プレビュー
struct ToneCurveView_Previews: PreviewProvider {
    static var previews: some View {
        ToneCurveView(
            curvePoints: .constant([
                CGPoint(x: 0.0, y: 0.0),
                CGPoint(x: 0.25, y: 0.25),
                CGPoint(x: 0.5, y: 0.5),
                CGPoint(x: 0.75, y: 0.75),
                CGPoint(x: 1.0, y: 1.0)
            ])
        )
        .frame(height: 500)
        .padding()
    }
}
