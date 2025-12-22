//
//  CanvasView.swift
//  GameLogoMaker
//
//  概要:
//  このファイルは画像編集用のキャンバスを実装するUIKitビューです。
//  役割: プロジェクト要素の描画と、タップによる選択/削除のみを担当。
//  移動・拡縮・回転などの操作は SwiftUI オーバーレイ (ElementSelectionView) 側で実施。
//  ズーム/パンは撤廃し、描画専用サーフェスとして動作します。
//  UIViewRepresentable を通じて SwiftUI と統合しています。

import UIKit
import SwiftUI

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
    
    /// 操作中に品質を下げるかのフラグ（4K+画像対応）
    var isReducingQualityDuringManipulation = false
    
    /// 4K超え解像度の閾値（8.3メガピクセル）
    let highResolutionThreshold: CGFloat = 8300000
    
    /// 要素を選択したときのコールバック
    var onElementSelected: ((LogoElement?) -> Void)?
    
    /// 要素の操作を開始するときのコールバック
    var onManipulationStarted: ((ElementManipulationType, CGPoint) -> Void)?
    
    /// 要素の操作中のコールバック
    var onManipulationChanged: ((CGPoint) -> Void)?
    
    /// 要素の操作を終了するときのコールバック
    var onManipulationEnded: (() -> Void)?
    
    /// 選択要素の変形変更通知（位置・サイズ・回転）
    var onElementTransformChanged: ((LogoElement, CGPoint, CGSize, CGFloat) -> Void)?
    
    /// 新しい要素を作成するときのコールバック
    var onCreateElement: ((CGPoint) -> Void)?
    
    /// 要素の削除を実行するときのコールバック
    var onElementDelete: (() -> Void)?

    /// 編集中のテキスト要素のID
    var editingTextElementId: UUID?
    
    /// 表示用の変換行列（ズーム/パン撤廃に伴い恒等）
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
    }
    
    // MARK: - 描画
    
    /// 高解像度画像が含まれているかチェック
    func shouldReduceQualityDuringManipulation() -> Bool {
        guard let project = project else { return false }
        
        // 画像要素の中に4K超えがあるかチェック
        for element in project.elements {
            if let imageElement = element as? ImageElement,
               let image = imageElement.image {
                let pixelCount = image.size.width * image.size.height * image.scale * image.scale
                if pixelCount > highResolutionThreshold {
                    return true
                }
            }
        }
        return false
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // 4K+画像の操作中品質低下の設定
        if isReducingQualityDuringManipulation {
            context.interpolationQuality = .low
        }
        
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
        
        // すべての要素を描画（編集中のテキスト要素は除く）
        // zIndexでソートしてから描画（小さい値から大きい値へ、奥から手前へ）
        let sortedElements = project.elements
            .filter { $0.isVisible }
            .sorted { $0.zIndex < $1.zIndex }
        
        for element in sortedElements {
            // 編集中のテキスト要素は描画しない
            if let editingId = editingTextElementId, 
               let textElement = element as? TextElement,
               textElement.id == editingId {
                continue
            }
            element.draw(in: context)
        }
        
        context.restoreGState()
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
        
        // エディタモードに応じた処理（操作ジェスチャーは別レイヤーに委譲）
        switch editorMode {
        case .select:
            break
        case .textCreate, .shapeCreate, .imageImport:
            break
        case .delete:
            handleDeleteTouchBegan(at: transformedLocation)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)

        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let transformedLocation = location.applying(viewTransform.inverted())

        let distance = hypot(touchStartPoint.x - location.x, touchStartPoint.y - location.y)

        print("DEBUG: touchesEnded - tapCount: \(touch.tapCount), distance: \(distance), mode: \(editorMode)")

        guard distance < 5 else { return }

        // 通常のタップ処理
        switch editorMode {
        case .select:
            break
        case .textCreate, .shapeCreate, .imageImport:
            onCreateElement?(transformedLocation)
        case .delete:
            break
        }
    }
    
    // MARK: - タッチイベントハンドラ
    
    /// 選択モードのタッチ開始処理（選択のみ）
    private func handleSelectTouchBegan(at location: CGPoint) {
        let hitElement = hitTestElement(at: location)
        onElementSelected?(hitElement)
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
    
    // MARK: - ヒットテスト　ユーザーのタッチが要素に当たったかを判定
    
    /// 指定された位置にある要素を検索
    private func hitTestElement(at point: CGPoint) -> LogoElement? {
        guard let project = project else { return nil }
        
        // グリッドスナップが有効な場合は座標を補正
        let testPoint = snapToGrid ? snapPointToGrid(point) : point
        
        // Z-Index順（大きい値から小さい値へ、前面から奥へ）でヒットテスト
        let sortedElements = project.elements
            .filter { !$0.isLocked && $0.isVisible }
            .sorted { $0.zIndex > $1.zIndex }
        
        return sortedElements.first { $0.hitTest(testPoint) }
    }

    // MARK: - 座標変換
    
    /// ビュー変換のリセット（ズーム/パン撤廃につき恒等）
    func resetViewTransform() {
        viewTransform = .identity
        setNeedsDisplay()
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
    
    /// コーディネータークラス - UIKitの委託パターンをSwiftUIに橋渡し
    class Coordinator: NSObject {
        var parent: CanvasViewRepresentable
        
        init(_ parent: CanvasViewRepresentable) {
            self.parent = parent
        }
        
        // コールバック設定
        func setupCallbacks(canvasView: CanvasView) {
            // 要素選択時のコールバック
            canvasView.onElementSelected = { [viewModel = parent.viewModel] element in
                DispatchQueue.main.async {
                    // 要素が選択された場合は明示的に設定
                    if let element = element {
                        viewModel.selectElement(element)
                    } else {
                        viewModel.clearSelection()
                    }
                }
            }
            
            // 操作開始時のコールバック
            canvasView.onManipulationStarted = { [weak canvasView, weak self] type, point in
                DispatchQueue.main.async {
                    // 4K+画像の操作中品質低下判定と設定
                    if let canvasView = canvasView {
                        canvasView.isReducingQualityDuringManipulation = canvasView.shouldReduceQualityDuringManipulation()
                        
                        // 高解像度画像要素の編集開始フラグを設定
                        if let project = canvasView.project {
                            for element in project.elements {
                                if let imageElement = element as? ImageElement,
                                   let image = imageElement.originalImage {
                                    let pixelCount = image.size.width * image.size.height * image.scale * image.scale
                                    if pixelCount > canvasView.highResolutionThreshold {
                                        imageElement.startEditing()
                                    }
                                }
                            }
                        }
                        
                        canvasView.setNeedsDisplay()
                    }
                    
                    self?.parent.viewModel.startManipulation(type, at: point)
                }
            }
            
            // 操作中のコールバック
            canvasView.onManipulationChanged = { [viewModel = parent.viewModel] point in
                DispatchQueue.main.async {
                    viewModel.continueManipulation(at: point)
                }
            }
            
            // 操作終了時のコールバック
            canvasView.onManipulationEnded = { [weak canvasView, weak self] in
                DispatchQueue.main.async {
                    // 4K+画像の操作中品質低下を解除
                    if let canvasView = canvasView {
                        canvasView.isReducingQualityDuringManipulation = false
                        
                        // 高解像度画像要素の編集終了フラグを設定
                        if let project = canvasView.project {
                            for element in project.elements {
                                if let imageElement = element as? ImageElement {
                                    imageElement.endEditing()
                                }
                            }
                        }
                        
                        canvasView.setNeedsDisplay()
                    }
                    
                    self?.parent.viewModel.endManipulation()
                }
        }
        
        // 要素作成時のコールバック
        canvasView.onCreateElement = { [viewModel = parent.viewModel] point in
            Task { @MainActor in
                print("DEBUG: onCreateElementコールバック開始 - 位置: \(point)")
                print("DEBUG: 現在のモード: \(viewModel.editorMode)")
                switch viewModel.editorMode {
                case .textCreate:
                    print("DEBUG: テキスト要素作成中...")
                    viewModel.addTextElement(text: "Double tap here to change text", position: point)
                case .shapeCreate:
                    print("DEBUG: 図形要素作成中... 図形タイプ: \(viewModel.nextShapeType)")
                    viewModel.addShapeElement(type: viewModel.nextShapeType, position: point)
                case .imageImport:
                    print("DEBUG: 画像インポート処理")
                    // 画像インポートは別処理（ファイル選択ダイアログ等）
                    break
                default:
                    print("DEBUG: 未対応のエディタモード: \(viewModel.editorMode)")
                    break
                }
                
                // 要素を作成したら選択モードに戻る
                print("DEBUG: 選択モードに戻る")
                viewModel.editorMode = .select
            }
        }
        
        // 要素削除時のコールバック
        canvasView.onElementDelete = { [viewModel = parent.viewModel] in
            Task { @MainActor in
                viewModel.deleteSelectedElement()
            }
        }

        }
    }
    
    /// UIViewの作成
    func makeUIView(context: Context) -> CanvasView {
        let canvasView = CanvasView(frame: .zero)
        canvasView.showGrid = showGrid
        canvasView.snapToGrid = snapToGrid
        
        // コールバックの設定
        context.coordinator.setupCallbacks(canvasView: canvasView)
        
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
        // 編集中のテキスト要素IDを同期
        canvasView.editingTextElementId = viewModel.editingTextElement?.id
    }
    
    /// コーディネーターの作成
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

/// プレビュー
struct CanvasView_Previews: PreviewProvider {
    static var previews: some View {
        EditorView(viewModel: EditorViewModel())
    }
}
