//
//  ToneCurveView.swift
//  GLogo
//
//  概要:
//  トーンカーブ調整のためのインタラクティブなグラフUIコンポーネントです。
//  ユーザーはグラフ上の制御点をドラッグして、画像の明るさや色調を調整できます。
//  RGB、赤、緑、青の各チャンネルごとに独立したカーブ調整が可能です。
//

import SwiftUI

/// トーンカーブ調整ビュー
struct ToneCurveView: View {
    struct Layout {
        let maxWidth: CGFloat?
        let maxHeight: CGFloat?
        let aspectRatio: CGFloat

        static let compact = Layout(
            maxWidth: 360,
            maxHeight: 200,
            aspectRatio: 2.2
        )
    }

    /// トーンカーブデータ（バインディング）
    @Binding var curveData: ToneCurveData
    /// レイアウト設定
    var layout: Layout = .compact

    /// 選択中のチャンネル
    @State private var selectedChannel: ToneCurveChannel = .rgb

    /// ドラッグ中の制御点インデックス
    @State private var draggingPointIndex: Int? = nil

    var body: some View {
        VStack(spacing: 16) {
            // チャンネル選択ボタン
            channelSelector

            // グラフエリア
            graphArea

            // リセットボタン
            resetButton
        }
        .padding()
    }

    // MARK: - チャンネルセレクター

    private var channelSelector: some View {
        HStack(spacing: 8) {
            ForEach(ToneCurveChannel.allCases, id: \.self) { channel in
                Button(action: {
                    selectedChannel = channel
                }) {
                    Text(channel.displayName)
                        .font(.subheadline)
                        .fontWeight(selectedChannel == channel ? .semibold : .regular)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedChannel == channel ? channelColor(for: channel) : Color.gray.opacity(0.2))
                        .foregroundColor(selectedChannel == channel ? .white : .primary)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - グラフエリア

    private var graphArea: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                // 背景とグリッド
                graphBackground(size: size)

                // 曲線
                curvePath(size: size)

                // 制御点
                controlPoints(size: size)
            }
            .frame(width: size.width, height: size.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(layout.aspectRatio, contentMode: .fit)
        .frame(
            maxWidth: layout.maxWidth,
            maxHeight: layout.maxHeight
        )
    }

    /// グラフ背景とグリッド
    private func graphBackground(size: CGSize) -> some View {
        ZStack {
            // 背景
            Rectangle()
                .fill(Color.black.opacity(0.05))

            // グリッド線
            Canvas { context, canvasSize in
                let gridCount = 4
                let stepX = size.width / CGFloat(gridCount)
                let stepY = size.height / CGFloat(gridCount)

                for i in 0...gridCount {
                    let offsetX = stepX * CGFloat(i)
                    let offsetY = stepY * CGFloat(i)

                    // 縦線
                    var verticalPath = Path()
                    verticalPath.move(to: CGPoint(x: offsetX, y: 0))
                    verticalPath.addLine(to: CGPoint(x: offsetX, y: size.height))
                    context.stroke(verticalPath, with: .color(.gray.opacity(0.3)), lineWidth: 1)

                    // 横線
                    var horizontalPath = Path()
                    horizontalPath.move(to: CGPoint(x: 0, y: offsetY))
                    horizontalPath.addLine(to: CGPoint(x: size.width, y: offsetY))
                    context.stroke(horizontalPath, with: .color(.gray.opacity(0.3)), lineWidth: 1)
                }
            }
            .frame(width: size.width, height: size.height)

            // 枠線
            Rectangle()
                .stroke(Color.gray, lineWidth: 1)
        }
    }

    /// トーンカーブの曲線
    private func curvePath(size: CGSize) -> some View {
        let points = curveData.points(for: selectedChannel)

        return Canvas { context, canvasSize in
            var path = Path()

            // 曲線を描画（線形補間）
            let resolution = 100
            for i in 0...resolution {
                let inputValue = CGFloat(i) / CGFloat(resolution)
                let outputValue = interpolateOutput(input: inputValue, points: points)

                let x = inputValue * size.width
                let y = size.height - (outputValue * size.height) // Y軸は上下反転

                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            context.stroke(path, with: .color(channelColor(for: selectedChannel)), lineWidth: 2)
        }
        .frame(width: size.width, height: size.height)
    }

    /// 制御点
    private func controlPoints(size: CGSize) -> some View {
        let points = curveData.points(for: selectedChannel)

        return ZStack {
            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                let x = point.input * size.width
                let y = size.height - (point.output * size.height) // Y軸は上下反転

                Circle()
                    .fill(channelColor(for: selectedChannel))
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .position(x: x, y: y)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handleDrag(value: value, index: index, graphSize: size)
                            }
                            .onEnded { _ in
                                draggingPointIndex = nil
                            }
                    )
            }
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - リセットボタン

    private var resetButton: some View {
        Button(action: {
            curveData.reset(for: selectedChannel)
        }) {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                Text("リセット")
            }
            .font(.subheadline)
            .foregroundColor(.red)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - ヘルパーメソッド

    /// ドラッグ処理
    private func handleDrag(value: DragGesture.Value, index: Int, graphSize: CGSize) {
        draggingPointIndex = index

        let width = max(graphSize.width, 1)
        let height = max(graphSize.height, 1)

        // ドラッグ位置をグラフ座標に変換（非正方形でも崩れないように個別の軸で正規化）
        let x = max(0, min(value.location.x, width))
        let y = max(0, min(value.location.y, height))

        var newInput = x / width
        var newOutput = 1.0 - (y / height) // Y軸は上下反転

        // 入力値の制約
        let points = curveData.points(for: selectedChannel)

        // 隣接する制御点を超えないように制約
        if index > 0 {
            newInput = max(newInput, points[index - 1].input + 0.01)
        }
        if index < points.count - 1 {
            newInput = min(newInput, points[index + 1].input - 0.01)
        }

        // 出力値は0.0〜1.0の範囲内にクランプ
        newOutput = max(0.0, min(newOutput, 1.0))

        #if DEBUG
        print("✅ [ToneCurve] Point[\(index)] = (\(String(format: "%.3f", newInput)), \(String(format: "%.3f", newOutput))) - \(selectedChannel)")
        #endif

        // 制御点を更新
        let newPoint = CurvePoint(input: newInput, output: newOutput)
        curveData.updatePoint(at: index, to: newPoint, for: selectedChannel)
    }

    /// モノトニック3次補間で出力値を計算（Fritsch-Carlson法）
    /// - Parameters:
    ///   - input: 入力値（0.0〜1.0）
    ///   - points: 制御点の配列
    /// - Returns: 補間された出力値
    private func interpolateOutput(input: CGFloat, points: [CurvePoint]) -> CGFloat {
        // Monotonic cubic interpolatorを使用
        let interpolator = MonotonicCubicInterpolator(points: points)
        return interpolator.interpolate(at: input)
    }

    /// チャンネルごとの色
    private func channelColor(for channel: ToneCurveChannel) -> Color {
        switch channel {
        case .rgb:
            return Color.gray
        case .red:
            return Color.red
        case .green:
            return Color.green
        case .blue:
            return Color.blue
        }
    }
}

// MARK: - プレビュー

struct ToneCurveView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewWrapper()
    }
    
    struct PreviewWrapper: View {
        @State private var curveData = ToneCurveData()
        
        var body: some View {
            ToneCurveView(curveData: $curveData, layout: .compact)
                .frame(height: 260) // プレビュー用の外枠高さ
                .padding()
        }
    }
}
