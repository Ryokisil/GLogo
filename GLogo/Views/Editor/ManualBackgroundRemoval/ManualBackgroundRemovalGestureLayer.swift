//
//  ManualBackgroundRemovalGestureLayer.swift
//  GLogo
//
//  概要:
//  マスク編集用のターゲットUIとズーム・パンのジェスチャーを担当します。
//

import SwiftUI
import UIKit

/// ターゲット操作用のオーバーレイ
struct ManualRemovalTargetOverlay<ViewModel: MaskEditingViewModeling>: View {
    /// マスク編集の状態を管理するViewModel
    @ObservedObject var viewModel: ViewModel
    /// 直前のブラシ適用点（ドラッグ中の線描画用）
    @State private var lastImagePoint: CGPoint?
    /// 現在のズーム倍率
    let zoomScale: CGFloat
    /// 現在のパンオフセット
    let panOffset: CGSize
    

    // 操作ポイント（ハンドル）の見た目と当たり判定
    private let handleOffset: CGFloat = 50
    private let handleSize: CGFloat = 16
    private let handleHitRadius: CGFloat = 24

    /// ターゲットUIと操作ポイントを描画する
    /// - Parameters: なし
    /// - Returns: ターゲットUIを含むビュー
    var body: some View {
        GeometryReader { geometry in
            let imageSize = viewModel.originalImage.size
            // 画像をアスペクトフィットで表示するための領域を計算
            let displayFrame = Self.calculateDisplayFrame(imageSize: imageSize, containerSize: geometry.size)
            let targetScreen = imageToScreen(
                viewModel.state.targetPoint,
                displayFrame: displayFrame,
                imageSize: imageSize
            )
            let handleScreen = CGPoint(x: targetScreen.x, y: targetScreen.y + handleOffset)
            // 画像座標のブラシサイズを、表示サイズへスケール
            let baseBrushScale = displayFrame.width / max(imageSize.width, 1)
            let brushDiameter = max(8, viewModel.state.brushSize * baseBrushScale * zoomScale)

            ZStack {
                // タップ移動用の透明レイヤー（シングル:移動 / ダブル:ズームリセット）
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        doubleTapGesture(displayFrame: displayFrame, imageSize: imageSize, handleScreen: handleScreen)
                            .exclusively(before: singleTapGesture(
                                displayFrame: displayFrame,
                                imageSize: imageSize,
                                handleScreen: handleScreen
                            ))
                    )

                // ターゲット円（ブラシサイズ）
                Circle()
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(width: brushDiameter, height: brushDiameter)
                    .position(targetScreen)
                    .allowsHitTesting(false)

                // ターゲットと操作ポイントを繋ぐライン
                Path { path in
                    path.move(to: targetScreen)
                    path.addLine(to: handleScreen)
                }
                .stroke(Color.blue.opacity(0.6), lineWidth: 1)
                .allowsHitTesting(false)

                // 操作ポイント（ハンドル）
                ZStack {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: handleHitRadius * 2, height: handleHitRadius * 2)
                        .contentShape(Circle())

                    Circle()
                        .fill(Color.blue)
                        .frame(width: handleSize, height: handleSize)
                }
                .position(handleScreen)
                // ハンドルをドラッグしてターゲット移動 + ブラシ適用
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("ManualRemovalOverlay"))
                        .onChanged { value in
                            let targetScreenPoint = CGPoint(
                                x: value.location.x,
                                y: value.location.y - handleOffset
                            )
                            let clampedScreen = clampScreenPoint(targetScreenPoint, to: displayFrame)
                            guard let imagePoint = screenToImage(
                                clampedScreen,
                                displayFrame: displayFrame,
                                imageSize: imageSize
                            ) else { return }

                            // ドラッグ中は線でブラシ適用（初回は点）
                            if let lastPoint = lastImagePoint {
                                viewModel.applyBrushLine(from: lastPoint, to: imagePoint)
                            } else {
                                viewModel.applyBrushStroke(at: imagePoint)
                            }

                            viewModel.setTargetPoint(imagePoint)
                            lastImagePoint = imagePoint
                        }
                        .onEnded { _ in
                            lastImagePoint = nil
                        }
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .coordinateSpace(name: "ManualRemovalOverlay")
        }
    }

    /// 画像をアスペクトフィットで表示するための矩形を算出する
    /// - Parameters:
    ///   - imageSize: 元画像のサイズ
    ///   - containerSize: 表示領域のサイズ
    /// - Returns: アスペクトフィット後の表示矩形
    static func calculateDisplayFrame(imageSize: CGSize, containerSize: CGSize) -> CGRect {
        let imageAspect = imageSize.width / max(imageSize.height, 1)
        let containerAspect = containerSize.width / max(containerSize.height, 1)

        let displaySize: CGSize
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

    /// 画面座標（ズーム・パン込み）を画像座標へ変換する
    /// - Parameters:
    ///   - screenPoint: 画面上の座標
    ///   - displayFrame: アスペクトフィット後の表示矩形
    ///   - imageSize: 元画像のサイズ
    /// - Returns: 画像座標（範囲外ならnil）
    private func screenToImage(_ screenPoint: CGPoint, displayFrame: CGRect, imageSize: CGSize) -> CGPoint? {
        let untransformed = reverseTransform(screenPoint, displayFrame: displayFrame)
        let normalizedX = (untransformed.x - displayFrame.minX) / max(displayFrame.width, 1)
        let normalizedY = (untransformed.y - displayFrame.minY) / max(displayFrame.height, 1)
        guard normalizedX >= 0, normalizedX <= 1, normalizedY >= 0, normalizedY <= 1 else {
            return nil
        }
        return CGPoint(x: normalizedX * imageSize.width, y: normalizedY * imageSize.height)
    }

    /// 画像座標を画面座標（ズーム・パン込み）へ変換する
    /// - Parameters:
    ///   - imagePoint: 画像上の座標
    ///   - displayFrame: アスペクトフィット後の表示矩形
    ///   - imageSize: 元画像のサイズ
    /// - Returns: 画面上の座標
    private func imageToScreen(_ imagePoint: CGPoint, displayFrame: CGRect, imageSize: CGSize) -> CGPoint {
        let normalizedX = imagePoint.x / max(imageSize.width, 1)
        let normalizedY = imagePoint.y / max(imageSize.height, 1)
        let basePoint = CGPoint(
            x: displayFrame.minX + normalizedX * displayFrame.width,
            y: displayFrame.minY + normalizedY * displayFrame.height
        )
        return applyTransform(basePoint, displayFrame: displayFrame)
    }

    /// 画面座標を表示領域内に制限する
    /// - Parameters:
    ///   - point: 画面上の座標
    ///   - frame: アスペクトフィット後の表示矩形
    /// - Returns: 表示領域内に収めた画面座標
    private func clampScreenPoint(_ point: CGPoint, to frame: CGRect) -> CGPoint {
        let untransformed = reverseTransform(point, displayFrame: frame)
        let clamped = CGPoint(
            x: min(max(untransformed.x, frame.minX), frame.maxX),
            y: min(max(untransformed.y, frame.minY), frame.maxY)
        )
        return applyTransform(clamped, displayFrame: frame)
    }

    /// ズーム・パンを適用してスクリーン座標に変換する
    /// - Parameters:
    ///   - point: ベースとなる画面座標
    ///   - displayFrame: アスペクトフィット後の表示矩形
    /// - Returns: ズーム・パン適用後の画面座標
    private func applyTransform(_ point: CGPoint, displayFrame: CGRect) -> CGPoint {
        let center = CGPoint(x: displayFrame.midX, y: displayFrame.midY)
        let scaled = CGPoint(
            x: center.x + (point.x - center.x) * zoomScale,
            y: center.y + (point.y - center.y) * zoomScale
        )
        return CGPoint(x: scaled.x + panOffset.width, y: scaled.y + panOffset.height)
    }

    /// ズーム・パンを逆変換してベース座標へ戻す
    /// - Parameters:
    ///   - point: ズーム・パン適用後の画面座標
    ///   - displayFrame: アスペクトフィット後の表示矩形
    /// - Returns: 逆変換後の画面座標
    private func reverseTransform(_ point: CGPoint, displayFrame: CGRect) -> CGPoint {
        let center = CGPoint(x: displayFrame.midX, y: displayFrame.midY)
        let translated = CGPoint(x: point.x - panOffset.width, y: point.y - panOffset.height)
        return CGPoint(
            x: center.x + (translated.x - center.x) / max(zoomScale, 0.0001),
            y: center.y + (translated.y - center.y) / max(zoomScale, 0.0001)
        )
    }

    /// シングルタップでターゲットを移動するジェスチャー
    /// - Parameters:
    ///   - displayFrame: アスペクトフィット後の表示矩形
    ///   - imageSize: 元画像のサイズ
    ///   - handleScreen: ハンドルの画面座標
    /// - Returns: タップジェスチャー
    private func singleTapGesture(
        displayFrame: CGRect,
        imageSize: CGSize,
        handleScreen: CGPoint
    ) -> some Gesture {
        SpatialTapGesture(count: 1, coordinateSpace: .named("ManualRemovalOverlay"))
            .onEnded { value in
                let tapPoint = value.location
                let distanceToHandle = hypot(tapPoint.x - handleScreen.x, tapPoint.y - handleScreen.y)
                guard distanceToHandle > handleHitRadius else { return }
                guard screenToImage(tapPoint, displayFrame: displayFrame, imageSize: imageSize) != nil else { return }
                if let imagePoint = screenToImage(tapPoint, displayFrame: displayFrame, imageSize: imageSize) {
                    viewModel.setTargetPoint(imagePoint)
                    lastImagePoint = nil
                }
            }
    }

    /// ダブルタップでズーム・パンをリセットするジェスチャー
    /// - Parameters:
    ///   - displayFrame: アスペクトフィット後の表示矩形
    ///   - imageSize: 元画像のサイズ
    ///   - handleScreen: ハンドルの画面座標
    /// - Returns: ダブルタップジェスチャー
    private func doubleTapGesture(
        displayFrame: CGRect,
        imageSize: CGSize,
        handleScreen: CGPoint
    ) -> some Gesture {
        SpatialTapGesture(count: 2, coordinateSpace: .named("ManualRemovalOverlay"))
            .onEnded { value in
                let tapPoint = value.location
                let distanceToHandle = hypot(tapPoint.x - handleScreen.x, tapPoint.y - handleScreen.y)
                guard distanceToHandle > handleHitRadius else { return }
                guard screenToImage(tapPoint, displayFrame: displayFrame, imageSize: imageSize) != nil else { return }
                NotificationCenter.default.post(name: .manualRemovalResetZoom, object: nil)
            }
    }
}

/// 2本指ズーム・パン専用の透明レイヤー
struct ZoomPanGestureView: UIViewRepresentable {
    /// 画面のズーム倍率バインディング
    @Binding var zoomScale: CGFloat
    /// 画面のパンオフセットバインディング
    @Binding var panOffset: CGSize
    /// アスペクトフィット後の表示領域
    let displayFrame: CGRect
    /// ズーム倍率の上限値
    let maxScale: CGFloat

    /// ジェスチャー中継用のホストビューを生成する
    /// - Parameters:
    ///   - context: SwiftUIが提供するコンテキスト
    /// - Returns: ジェスチャー中継用のホストビュー
    func makeUIView(context: Context) -> ZoomPanGestureHostingView {
        let view = ZoomPanGestureHostingView()
        view.isUserInteractionEnabled = false
        view.onMoveToWindow = { [weak coordinator = context.coordinator] window in
            // マルチタッチが無効なビュー階層を避け、ウィンドウに直接付与する
            coordinator?.attachGestures(to: window)
        }
        return view
    }

    /// 画面サイズや拡大率制限の更新に追従する
    /// - Parameters:
    ///   - uiView: 生成済みホストビュー
    ///   - context: SwiftUIが提供するコンテキスト
    /// - Returns: なし
    func updateUIView(_ uiView: ZoomPanGestureHostingView, context: Context) {
        context.coordinator.update(displayFrame: displayFrame, maxScale: maxScale)
        context.coordinator.attachGestures(to: uiView.window)
    }

    /// 画面が破棄されるタイミングでジェスチャーを解除する
    /// - Parameters:
    ///   - uiView: 生成済みホストビュー
    ///   - coordinator: 生成済みコーディネータ
    /// - Returns: なし
    static func dismantleUIView(_ uiView: ZoomPanGestureHostingView, coordinator: Coordinator) {
        coordinator.attachGestures(to: nil)
    }

    /// UIKitジェスチャーの状態管理用コーディネータを生成する
    /// - Parameters: なし
    /// - Returns: ジェスチャー管理用コーディネータ
    func makeCoordinator() -> Coordinator {
        Coordinator(zoomScale: $zoomScale, panOffset: $panOffset)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        /// 画面のズーム倍率バインディング
        @Binding var zoomScale: CGFloat
        /// 画面のパンオフセットバインディング
        @Binding var panOffset: CGSize
        /// ジェスチャー開始時点のズーム倍率
        private var startScale: CGFloat = 1.0
        /// ジェスチャー開始時点のパンオフセット
        private var startOffset: CGSize = .zero
        /// アスペクトフィット後の表示領域
        private var displayFrame: CGRect = .zero
        /// ズーム倍率の上限値
        private var maxScale: CGFloat = 4.0
        /// ジェスチャーを付与したビュー参照
        private weak var attachedView: UIView?
        /// ピンチ用ジェスチャー
        private var pinch: UIPinchGestureRecognizer?
        /// 2本指パン用ジェスチャー
        private var pan: UIPanGestureRecognizer?

        /// ズーム・パンの状態バインディングを受け取って初期化する
        /// - Parameters:
        ///   - zoomScale: ズーム倍率のバインディング
        ///   - panOffset: パンオフセットのバインディング
        /// - Returns: なし
        init(zoomScale: Binding<CGFloat>, panOffset: Binding<CGSize>) {
            _zoomScale = zoomScale
            _panOffset = panOffset
        }

        /// 表示領域とズーム上限を更新する
        /// - Parameters:
        ///   - displayFrame: アスペクトフィット後の表示矩形
        ///   - maxScale: ズーム倍率の上限値
        /// - Returns: なし
        func update(displayFrame: CGRect, maxScale: CGFloat) {
            self.displayFrame = displayFrame
            self.maxScale = maxScale
        }

        /// ジェスチャーの付与先を切り替える（ウィンドウが最優先）
        /// - Parameters:
        ///   - view: 付与先ビュー
        /// - Returns: なし
        func attachGestures(to view: UIView?) {
            if view == nil {
                if let attachedView {
                    if let pinch { attachedView.removeGestureRecognizer(pinch) }
                    if let pan { attachedView.removeGestureRecognizer(pan) }
                }
                pinch = nil
                pan = nil
                attachedView = nil
                return
            }

            guard let view else { return }
            if attachedView === view { return }

            if let attachedView {
                if let pinch { attachedView.removeGestureRecognizer(pinch) }
                if let pan { attachedView.removeGestureRecognizer(pan) }
            }

            // 2本指操作が確実に届くよう、付与先で多点タッチを有効化
            view.isUserInteractionEnabled = true
            view.isMultipleTouchEnabled = true
            view.isExclusiveTouch = false

            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            pinch.delegate = self
            pinch.cancelsTouchesInView = false

            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.minimumNumberOfTouches = 2
            pan.delegate = self
            pan.cancelsTouchesInView = false

            view.addGestureRecognizer(pinch)
            view.addGestureRecognizer(pan)

            self.pinch = pinch
            self.pan = pan
            self.attachedView = view
        }

        /// ピンチでズーム倍率を更新する
        /// - Parameters:
        ///   - recognizer: ピンチジェスチャー
        /// - Returns: なし
        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began:
                startScale = zoomScale
            case .changed:
                let rawScale = startScale * recognizer.scale
                zoomScale = clampScale(rawScale)
                panOffset = clampOffset(panOffset)
            default:
                break
            }
        }

        /// 2本指パンでオフセットを更新する
        /// - Parameters:
        ///   - recognizer: 2本指パンジェスチャー
        /// - Returns: なし
        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                startOffset = panOffset
            case .changed:
                let translation = recognizer.translation(in: recognizer.view)
                let rawOffset = CGSize(
                    width: startOffset.width + translation.x,
                    height: startOffset.height + translation.y
                )
                panOffset = clampOffset(rawOffset)
            default:
                break
            }
        }

        /// ズーム倍率を上限・下限で制限する
        /// - Parameters:
        ///   - scale: 変更後のズーム倍率
        /// - Returns: 制限後のズーム倍率
        private func clampScale(_ scale: CGFloat) -> CGFloat {
            min(max(scale, 1.0), maxScale)
        }

        /// ズーム後の表示範囲に収まるようオフセットを制限する
        /// - Parameters:
        ///   - offset: 変更後のパンオフセット
        /// - Returns: 制限後のパンオフセット
        private func clampOffset(_ offset: CGSize) -> CGSize {
            let maxOffsetX = max(0, (displayFrame.width * zoomScale - displayFrame.width) / 2)
            let maxOffsetY = max(0, (displayFrame.height * zoomScale - displayFrame.height) / 2)
            let clampedX = min(max(offset.width, -maxOffsetX), maxOffsetX)
            let clampedY = min(max(offset.height, -maxOffsetY), maxOffsetY)
            return CGSize(width: clampedX, height: clampedY)
        }

        /// ピンチとパンを同時に認識する
        /// - Parameters:
        ///   - gestureRecognizer: 判定対象のジェスチャー
        ///   - otherGestureRecognizer: 同時認識対象のジェスチャー
        /// - Returns: 同時認識を許可するかどうか
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

// SwiftUIのライフサイクルでwindow確定を検知するホストビュー
final class ZoomPanGestureHostingView: UIView {
    /// ウィンドウに移動したタイミングで呼び出すコールバック
    var onMoveToWindow: ((UIWindow?) -> Void)?

    /// ウィンドウが確定したタイミングでコールバックを通知する
    /// - Parameters: なし
    /// - Returns: なし
    override func didMoveToWindow() {
        super.didMoveToWindow()
        onMoveToWindow?(window)
    }
}

extension Notification.Name {
    /// 手動背景除去のズーム・パンをリセットする通知
    static let manualRemovalResetZoom = Notification.Name("manualRemovalResetZoom")
}
