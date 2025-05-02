//
//  CanvasView.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはロゴ編集用のキャンバスを実装するUIKitビュークラスです。
//  プロジェクトの要素を描画し、タッチイベントを処理してユーザーが要素を
//  選択、移動、リサイズ、回転などの操作を行えるようにします。
//  また、ズーム、パン、グリッド表示などの機能も提供します。
//  UIViewRepresentableプロトコルを実装したラッパークラスを通じてSwiftUIと統合されます。
//　SwiftUIとUIKitを統合、CoreGraphicsを直接扱うことでグラフィック処理を効率化しSwiftUIでUi設計

import UIKit
import SwiftUI
//import Combine

/// キャンバスビュー - ロゴ要素を描画・編集するためのUIKitビュー
class CanvasView: UIView {
    // MARK: - プロパティ
    
    /// プロジェクト参照
    var project: LogoProject? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    /// 選択中の要素
    var selectedElement: LogoElement? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    /// エディタモード
    var editorMode: EditorMode = .select {
        didSet {
            updateCursor()
        }
    }
    
    /// タッチ開始時のポイント
    private var touchStartPoint: CGPoint = .zero
    
    /// 現在の操作タイプ
    private var currentManipulationType: ElementManipulationType = .none
    
    /// 要素を選択したときのコールバック
    var onElementSelected: ((LogoElement?) -> Void)?
    
    /// 要素の操作を開始するときのコールバック
    var onManipulationStarted: ((ElementManipulationType, CGPoint) -> Void)?
    
    /// 要素の操作中のコールバック
    var onManipulationChanged: ((CGPoint) -> Void)?
    
    /// 要素の操作を終了するときのコールバック
    var onManipulationEnded: (() -> Void)?
    
    /// 新しい要素を作成するときのコールバック
    var onCreateElement: ((CGPoint) -> Void)?
    
    /// 要素の削除を実行するときのコールバック
    var onElementDelete: (() -> Void)?
    
    /// ズーム比率
    var zoomScale: CGFloat = 1.0 {
        didSet {
            // ズーム比率の制限（最小0.1、最大5.0）
            zoomScale = min(max(zoomScale, 0.1), 5.0)
            updateTransform()
        }
    }
    
    /// パン（平行移動）のオフセット
    var panOffset: CGPoint = .zero {
        didSet {
            updateTransform()
        }
    }
    
    /// 表示用の変換行列
    private var viewTransform: CGAffineTransform = .identity
    
    /// 操作ハンドルの半径
    private let handleRadius: CGFloat = 10.0
    
    /// 選択ハンドルの色
    private let handleColor: UIColor = .systemBlue
    
    /// 選択ボーダーの色
    private let selectionBorderColor: UIColor = .systemBlue
    
    /// 選択ボーダーの幅
    private let selectionBorderWidth: CGFloat = 2.0
    
    /// 選択ボーダーの破線パターン
    private let selectionBorderPattern: [CGFloat] = [6, 3]
    
    /// グリッドのサイズ
    private let gridSize: CGFloat = 20.0
    
    /// グリッド表示フラグ
    var showGrid: Bool = true {
        didSet {
            setNeedsDisplay()
        }
    }
    
    /// グリッドにスナップするフラグ
    var snapToGrid: Bool = false
    
    /// グリッドの色
    private let gridColor: UIColor = UIColor.gray.withAlphaComponent(0.3)
    
    // MARK: - イニシャライザ
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - セットアップ
    
    private func setupView() {
        backgroundColor = .systemGray6
        isMultipleTouchEnabled = true
        
        // ピンチジェスチャーの追加（ズーム用）
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        addGestureRecognizer(pinchGesture)
        
        // パンジェスチャーの追加（キャンバス移動用）
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.minimumNumberOfTouches = 2
        addGestureRecognizer(panGesture)
        
        // ダブルタップジェスチャーの追加（ズームリセット用）
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTapGesture(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTapGesture)
    }
    
    // MARK: - 描画
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // 背景の描画
        drawBackground(in: context)
        
        // グリッドの描画
        if showGrid {
            drawGrid(in: context)
        }
        
        // プロジェクトが設定されていない場合は終了
        guard let project = project else { return }
        
        // キャンバスの境界を描画
        drawCanvasBoundary(in: context, size: project.canvasSize)
        
        // キャンバスの領域を設定
        context.saveGState()
        let canvasRect = CGRect(origin: .zero, size: project.canvasSize)
        context.clip(to: canvasRect)
        
        // 背景設定の描画
        project.backgroundSettings.draw(in: context, rect: canvasRect)
        
        // すべての要素を描画
        for element in project.elements where element.isVisible {
            element.draw(in: context)
        }
        
        context.restoreGState()
        
        // 選択中の要素があれば選択ハンドルを描画
        if let selectedElement = selectedElement {
            drawSelectionHandles(for: selectedElement, in: context)
        }
    }
    
    /// 背景の描画
    private func drawBackground(in context: CGContext) {
        // ビュー全体を背景色で塗りつぶし
        context.setFillColor(backgroundColor?.cgColor ?? UIColor.white.cgColor)
        context.fill(bounds)
    }
    
    /// グリッドの描画
    private func drawGrid(in context: CGContext) {
        guard let project = project else { return }
        
        context.saveGState()
        
        // グリッド線の色と幅を設定
        context.setStrokeColor(gridColor.cgColor)
        context.setLineWidth(0.5)
        
        // 縦線を描画
        for x in stride(from: 0, through: project.canvasSize.width, by: gridSize) {
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: project.canvasSize.height))
        }
        
        // 横線を描画
        for y in stride(from: 0, through: project.canvasSize.height, by: gridSize) {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: project.canvasSize.width, y: y))
        }
        
        context.strokePath()
        context.restoreGState()
    }
    
    /// キャンバスの境界を描画
    private func drawCanvasBoundary(in context: CGContext, size: CGSize) {
        context.saveGState()
        
        // キャンバスの境界線を描画
        context.setStrokeColor(UIColor.darkGray.cgColor)
        context.setLineWidth(1.0)
        
        let rect = CGRect(origin: .zero, size: size)
        context.stroke(rect)
        
        // キャンバスの外側に影を描画（任意）
        let shadowPath = UIBezierPath(rect: rect.insetBy(dx: -5, dy: -5))
        shadowPath.append(UIBezierPath(rect: rect))
        shadowPath.usesEvenOddFillRule = true
        
        context.setShadow(offset: CGSize(width: 0, height: 0), blur: 5, color: UIColor.black.withAlphaComponent(0.3).cgColor)
        UIColor.clear.setFill()
        shadowPath.fill()
        
        context.restoreGState()
    }
    
    /// 選択ハンドルの描画
    private func drawSelectionHandles(for element: LogoElement, in context: CGContext) {
        context.saveGState()
        
        // 選択枠の描画
        let frame = element.frame
        context.setStrokeColor(selectionBorderColor.cgColor)
        context.setLineWidth(selectionBorderWidth)
        context.setLineDash(phase: 0, lengths: selectionBorderPattern)
        context.stroke(frame)
        
        // 要素がロックされている場合は、ロックアイコンを描画して終了
        if element.isLocked {
            drawLockIcon(for: element, in: context)
            context.restoreGState()
            return
        }
        
        // 操作ハンドルの描画
        context.setLineDash(phase: 0, lengths: [])
        
        // 移動ハンドル（中央）
        drawHandle(at: CGPoint(x: frame.midX, y: frame.midY), in: context)
        
        // リサイズハンドル（四隅と辺の中点）
        drawHandle(at: CGPoint(x: frame.minX, y: frame.minY), in: context) // 左上
        drawHandle(at: CGPoint(x: frame.maxX, y: frame.minY), in: context) // 右上
        drawHandle(at: CGPoint(x: frame.minX, y: frame.maxY), in: context) // 左下
        drawHandle(at: CGPoint(x: frame.maxX, y: frame.maxY), in: context) // 右下
        
        drawHandle(at: CGPoint(x: frame.midX, y: frame.minY), in: context) // 上中央
        drawHandle(at: CGPoint(x: frame.midX, y: frame.maxY), in: context) // 下中央
        drawHandle(at: CGPoint(x: frame.minX, y: frame.midY), in: context) // 左中央
        drawHandle(at: CGPoint(x: frame.maxX, y: frame.midY), in: context) // 右中央
        
        // 回転ハンドル（上部中央から少し上）
        let rotationHandlePosition = CGPoint(x: frame.midX, y: frame.minY - 30)
        drawHandle(at: rotationHandlePosition, in: context)
        
        // 回転ハンドルへの線
        context.setStrokeColor(selectionBorderColor.cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: frame.midX, y: frame.minY))
        context.addLine(to: rotationHandlePosition)
        context.strokePath()
        
        context.restoreGState()
    }
    
    /// ハンドルの描画
    private func drawHandle(at point: CGPoint, in context: CGContext) {
        // ハンドルの塗りつぶし
        context.setFillColor(handleColor.cgColor)
        let handleRect = CGRect(
            x: point.x - handleRadius,
            y: point.y - handleRadius,
            width: handleRadius * 2,
            height: handleRadius * 2
        )
        context.fillEllipse(in: handleRect)
        
        // ハンドルの枠線
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(1.0)
        context.strokeEllipse(in: handleRect)
    }
    
    /// ロックアイコンの描画
    private func drawLockIcon(for element: LogoElement, in context: CGContext) {
        // 鍵アイコンを描画（簡易的な実装）
        let frame = element.frame
        let iconSize: CGFloat = 20
        let iconRect = CGRect(
            x: frame.maxX - iconSize - 5,
            y: frame.minY + 5,
            width: iconSize,
            height: iconSize
        )
        
        // 鍵のボディ
        context.setFillColor(UIColor.systemRed.withAlphaComponent(0.7).cgColor)
        let bodyRect = CGRect(
            x: iconRect.minX + 3,
            y: iconRect.minY + 8,
            width: iconRect.width - 6,
            height: iconRect.height - 8
        )
        context.fill(bodyRect)
        
        // 鍵の弧
        context.setStrokeColor(UIColor.systemRed.withAlphaComponent(0.7).cgColor)
        context.setLineWidth(2.0)
        let arcRadius = (iconRect.width - 6) / 2
        let arcCenter = CGPoint(x: iconRect.midX, y: iconRect.minY + 8)
        context.addArc(
            center: arcCenter,
            radius: arcRadius,
            startAngle: .pi,
            endAngle: 0,
            clockwise: false
        )
        context.strokePath()
    }
    
    // MARK: - タッチイベント処理
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        touchStartPoint = location
        
        // 座標変換
        let transformedLocation = location.applying(viewTransform.inverted())
        
        // エディタモードに応じた処理
        switch editorMode {
        case .select:
            handleSelectTouchBegan(at: transformedLocation)
        case .textCreate, .shapeCreate, .imageImport:
            // 要素作成モードでは何もしない（タッチエンド時に作成）
            break
        case .delete:
            handleDeleteTouchBegan(at: transformedLocation)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // 座標変換
        let transformedLocation = location.applying(viewTransform.inverted())
        
        // 操作中の場合
        if currentManipulationType != .none {
            onManipulationChanged?(transformedLocation)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // 座標変換
        let transformedLocation = location.applying(viewTransform.inverted())
        
        // 操作中の場合は終了
        if currentManipulationType != .none {
            onManipulationEnded?()
            currentManipulationType = .none
            return
        }
        
        // 短いタップの場合（クリック）
        let distance = hypot(touchStartPoint.x - location.x, touchStartPoint.y - location.y)
        if distance < 5 {  // 閾値を小さくして、タップとドラッグを区別
            switch editorMode {
            case .select:
                handleSelectTouchEnded(at: transformedLocation)
            case .textCreate, .shapeCreate, .imageImport:
                onCreateElement?(transformedLocation)
            case .delete:
                break
            }
        }
    }
    
    // MARK: - タッチイベントハンドラ
    
    /// 選択モードのタッチ開始処理
    private func handleSelectTouchBegan(at location: CGPoint) {
        // 位置にある要素をヒットテスト
        let hitElement = hitTestElement(at: location)
        
        if let selectedElement = selectedElement {
            // 選択中の要素がある場合
            
            // 最初に、要素自体がタッチされているかチェック
            if selectedElement.hitTest(location) {
                // 要素の中央のハンドル以外の領域がタップされた場合は移動開始
                let centerHandleHit = pointInHandle(location, handlePosition: CGPoint(x: selectedElement.frame.midX, y: selectedElement.frame.midY))
                
                if !centerHandleHit {
                    // 移動開始
                    currentManipulationType = .move
                    onManipulationStarted?(.move, location)
                    return
                }
            }
            
            // ハンドルのヒットテスト
            let manipulationType = hitTestHandle(for: selectedElement, at: location)
            if manipulationType != .none {
                currentManipulationType = manipulationType
                onManipulationStarted?(manipulationType, location)
                return
            }
        }
        
        // 選択中の要素がない、またはヒットしなかった場合
        // ここが重要: 新しい要素を選択する際に、ちゃんとonElementSelectedを呼ぶ
        if let hitElement = hitElement {
            // 要素を選択
            onElementSelected?(hitElement)
            
            // 要素が選択された場合、すぐに移動開始
            currentManipulationType = .move
            onManipulationStarted?(.move, location)
        } else {
            // 何もヒットしなかった場合、選択解除
            onElementSelected?(nil)
        }
    }
    
    /// 選択モードのタッチ終了処理
    private func handleSelectTouchEnded(at location: CGPoint) {
        // タッチ開始時に処理済みの場合は何もしない
        if currentManipulationType != .none {
            return
        }
        
        // 位置にある要素を選択
        let hitElement = hitTestElement(at: location)
        onElementSelected?(hitElement)
    }
    
    /// 削除モードのタッチ開始処理
    private func handleDeleteTouchBegan(at location: CGPoint) {
        // 位置にある要素を選択して削除
        if let hitElement = hitTestElement(at: location) {
            onElementSelected?(hitElement)
            // 少し遅延を入れて削除（ユーザーがどの要素を削除するか視覚的に確認できるように）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.onElementDelete?()
                self.onElementSelected?(nil) // 選択解除
            }
        }
    }
    
    // MARK: - ヒットテスト
    
    /// 指定された位置にある要素を検索
    private func hitTestElement(at point: CGPoint) -> LogoElement? {
        guard let project = project else { return nil }
        
        // グリッドスナップが有効な場合は座標を補正
        let testPoint = snapToGrid ? snapPointToGrid(point) : point
        
        // 逆順（前面の要素から）にチェック
        for element in project.elements.reversed() {
            if !element.isLocked && element.isVisible && element.hitTest(testPoint) {
                return element
            }
        }
        return nil
    }
    
    /// 選択中の要素のハンドルのヒットテスト
    private func hitTestHandle(for element: LogoElement, at point: CGPoint) -> ElementManipulationType {
        let frame = element.frame
        
        // 要素がロックされている場合は何もできない
        if element.isLocked {
            return .none
        }
        
        // 回転ハンドル
        let rotationHandlePosition = CGPoint(x: frame.midX, y: frame.minY - 30)
        if pointInHandle(point, handlePosition: rotationHandlePosition) {
            return .rotate
        }
        
        // リサイズハンドル（四隅）
        if pointInHandle(point, handlePosition: CGPoint(x: frame.minX, y: frame.minY)) ||  // 左上
            pointInHandle(point, handlePosition: CGPoint(x: frame.maxX, y: frame.minY)) ||  // 右上
            pointInHandle(point, handlePosition: CGPoint(x: frame.minX, y: frame.maxY)) ||  // 左下
            pointInHandle(point, handlePosition: CGPoint(x: frame.maxX, y: frame.maxY)) ||  // 右下
            pointInHandle(point, handlePosition: CGPoint(x: frame.midX, y: frame.minY)) ||  // 上中央
            pointInHandle(point, handlePosition: CGPoint(x: frame.midX, y: frame.maxY)) ||  // 下中央
            pointInHandle(point, handlePosition: CGPoint(x: frame.minX, y: frame.midY)) ||  // 左中央
            pointInHandle(point, handlePosition: CGPoint(x: frame.maxX, y: frame.midY)) {   // 右中央
            return .resize
        }
        
        // 中央（移動ハンドル）
        if pointInHandle(point, handlePosition: CGPoint(x: frame.midX, y: frame.midY)) {
            return .move
        }
        
        return .none
    }
    
    /// 点がハンドル内にあるかチェック
    private func pointInHandle(_ point: CGPoint, handlePosition: CGPoint) -> Bool {
        let handleRect = CGRect(
            x: handlePosition.x - handleRadius,
            y: handlePosition.y - handleRadius,
            width: handleRadius * 2,
            height: handleRadius * 2
        )
        return handleRect.contains(point)
    }
    
    // MARK: - ジェスチャーハンドラ
    
    /// ピンチジェスチャー処理（ズーム）
    @objc private func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            // ジェスチャー開始時の処理
            break
            
        case .changed:
            // ズーム比率を更新
            zoomScale *= gesture.scale
            gesture.scale = 1.0 // スケールをリセット（累積を防ぐ）
            
        case .ended, .cancelled:
            // ジェスチャー終了時の処理
            break
            
        default:
            break
        }
    }
    
    /// パンジェスチャー処理（キャンバス移動）
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        // 2本指でパンしたときだけキャンバスを移動
        if gesture.numberOfTouches >= 2 {
            let translation = gesture.translation(in: self)
            
            switch gesture.state {
            case .changed:
                // パンオフセットを更新
                panOffset.x += translation.x
                panOffset.y += translation.y
                gesture.setTranslation(.zero, in: self)
                
            default:
                break
            }
        }
    }
    
    /// ダブルタップジェスチャー処理（ズームリセット）
    @objc private func handleDoubleTapGesture(_ gesture: UITapGestureRecognizer) {
        // ズームとパンをリセット
        resetViewTransform()
    }
    
    // MARK: - 座標変換
    
    /// 変換行列の更新
    private func updateTransform() {
        // スケールと移動を組み合わせた変換行列を作成
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: panOffset.x, y: panOffset.y)
        transform = transform.scaledBy(x: zoomScale, y: zoomScale)
        
        // 中央を原点とする場合は以下のような変換も可能
        // let centerX = bounds.width / 2
        // let centerY = bounds.height / 2
        // transform = transform.translatedBy(x: centerX, y: centerY)
        // transform = transform.scaledBy(x: zoomScale, y: zoomScale)
        // transform = transform.translatedBy(x: -centerX + panOffset.x, y: -centerY + panOffset.y)
        
        viewTransform = transform
        setNeedsDisplay()
    }
    
    /// ビュー変換のリセット
    func resetViewTransform() {
        zoomScale = 1.0
        panOffset = .zero
        updateTransform()
    }
    
    // MARK: - ユーティリティ
    
    /// ポイントをグリッドにスナップ
    private func snapPointToGrid(_ point: CGPoint) -> CGPoint {
        let x = round(point.x / gridSize) * gridSize
        let y = round(point.y / gridSize) * gridSize
        return CGPoint(x: x, y: y)
    }
    
    /// カーソルの更新
    private func updateCursor() {
        // カーソルスタイルを設定（macOS Catalina以降でiPadで利用可能）
#if targetEnvironment(macCatalyst)
        switch editorMode {
        case .select:
            NSCursor.arrow.set()
        case .textCreate:
            NSCursor.iBeam.set()
        case .shapeCreate:
            NSCursor.crosshair.set()
        case .imageImport:
            NSCursor.dragCopy.set()
        case .delete:
            NSCursor.disappearingItem.set()
        }
#endif
    }
    
    /// 表示座標からキャンバス座標への変換
    func convertPointToCanvas(_ point: CGPoint) -> CGPoint {
        return point.applying(viewTransform.inverted())
    }
    
    /// キャンバス座標から表示座標への変換
    func convertPointFromCanvas(_ point: CGPoint) -> CGPoint {
        return point.applying(viewTransform)
    }
}

// MARK: - SwiftUI統合用のラッパー

/// CanvasViewをSwiftUIで使用するためのラッパー
struct CanvasViewRepresentable: UIViewRepresentable {
    /// エディタビューモデル
    @ObservedObject var viewModel: EditorViewModel
    
    /// グリッド表示フラグ
    var showGrid: Bool = true
    
    /// グリッドスナップフラグ
    var snapToGrid: Bool = false
    
    /// UIViewの作成
    func makeUIView(context: Context) -> CanvasView {
        let canvasView = CanvasView(frame: .zero)
        canvasView.showGrid = showGrid
        canvasView.snapToGrid = snapToGrid
        
        // コールバックの設定
        setupCallbacks(canvasView: canvasView)
        
        return canvasView
    }
    
    /// UIViewの更新
    func updateUIView(_ canvasView: CanvasView, context: Context) {
        // プロジェクトと選択要素を更新
        canvasView.project = viewModel.project
        canvasView.selectedElement = viewModel.selectedElement
        canvasView.editorMode = viewModel.editorMode
        canvasView.showGrid = showGrid
        canvasView.snapToGrid = snapToGrid
    }
    
    /// コールバックの設定
    private func setupCallbacks(canvasView: CanvasView) {
        // 要素選択時のコールバック
        canvasView.onElementSelected = { [viewModel] element in
            viewModel.selectElement(at: CGPoint(x: 0, y: 0)) // 任意の座標（実際には使用されない）
            
            // 要素が選択された場合は明示的に設定
            if let element = element {
                viewModel.selectElement(element)
            } else {
                viewModel.clearSelection()
            }
        }
        
        // 操作開始時のコールバック
        canvasView.onManipulationStarted = { [viewModel] type, point in
            viewModel.startManipulation(type, at: point)
        }
        
        // 操作中のコールバック
        canvasView.onManipulationChanged = { [viewModel] point in
            viewModel.continueManipulation(at: point)
        }
        
        // 操作終了時のコールバック
        canvasView.onManipulationEnded = { [viewModel] in
            viewModel.endManipulation()
        }
        
        // 要素作成時のコールバック
        canvasView.onCreateElement = { [viewModel] point in
            switch viewModel.editorMode {
            case .textCreate:
                viewModel.addTextElement(text: "テキストを入力", position: point)
            case .shapeCreate:
                viewModel.addShapeElement(type: viewModel.nextShapeType, position: point)
            case .imageImport:
                // 画像インポートは別処理（ファイル選択ダイアログ等）
                break
            default:
                break
            }
            
            // 要素を作成したら選択モードに戻る
            viewModel.editorMode = .select
        }
        
        // 要素削除時のコールバック
        canvasView.onElementDelete = { [viewModel] in
            viewModel.deleteSelectedElement()
        }
    }
}

/// プレビュー
struct CanvasView_Previews: PreviewProvider {
    static var previews: some View {
        EditorView(viewModel: EditorViewModel())
    }
}
