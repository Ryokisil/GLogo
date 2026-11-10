
//  CanvasView.swift
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
@MainActor
class CanvasView: UIView {
    // MARK: - プロパティ
    
    /// プロジェクト参照。同じインスタンスを設定し直したときも再描画を要求する。
    /// 要素の変更は、updateUIView のたびの設定し直しで描画に反映されるため、同一判定で省かないこと。
    var project: LogoProject? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    /// エディタモード
    var editorMode: EditorMode = .select
    
    /// タッチ開始時のポイント
    private var touchStartPoint: CGPoint = .zero

    /// 要素を選択したときのコールバック
    var onElementSelected: (@MainActor (LogoElement?) -> Void)?

    /// 新しい要素を作成するときのコールバック
    var onCreateElement: (@MainActor (CGPoint) -> Void)?
    
    /// 要素の削除を実行するときのコールバック
    var onElementDelete: (@MainActor () -> Void)?

    /// 編集中のテキスト要素のID
    var editingTextElementId: UUID?

    /// 画像要素の描く画像の受け取り先（エディタの管理役）。CanvasViewRepresentable が設定する。
    /// 設定されるまでは要素を描かない（Model の描画へ戻すと、設定漏れに気づけないため）。
    var renderSessions: (any ImageRenderSessionReading)?
    
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

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        // 背景の描画
        drawBackground(in: context)
        
        // グリッドの描画
        if showGrid {
            drawGrid(in: context)
        }
        
        // プロジェクトと画像の受け取り先が設定されていない場合は終了
        guard let project = project, let renderSessions = renderSessions else { return }
        
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
            // 編集中の要素は描画しない（ID一致のみで判定し、要素種別への依存を避ける）
            if let editingId = editingTextElementId, element.id == editingId {
                continue
            }
            element.drawOnCanvas(in: context, renderSessions: renderSessions)
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
    
    // MARK: - タッチイベント処理
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        touchStartPoint = location
        
        // エディタモードに応じた処理（操作ジェスチャーは別レイヤーに委譲）
        switch editorMode {
        case .select:
            break
        case .shapeCreate, .imageImport:
            break
        case .delete:
            handleDeleteTouchBegan(at: location)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)

        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        let distance = hypot(touchStartPoint.x - location.x, touchStartPoint.y - location.y)


        guard distance < 5 else { return }

        // 通常のタップ処理
        switch editorMode {
        case .select:
            break
        case .shapeCreate, .imageImport:
            onCreateElement?(location)
        case .delete:
            break
        }
    }
    
    // MARK: - タッチイベントハンドラ
    
    /// 削除モードのタッチ開始処理
    private func handleDeleteTouchBegan(at location: CGPoint) {
        // 位置にある要素を選択して削除
        if let hitElement = hitTestElement(at: location) {
            onElementSelected?(hitElement)
            // 少し遅延を入れて削除（ユーザーがどの要素を削除するか視覚的に確認できるように）
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(100))
                guard let self else { return }
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

    // MARK: - ユーティリティ
    
    /// ポイントをグリッドにスナップ
    private func snapPointToGrid(_ point: CGPoint) -> CGPoint {
        let x = round(point.x / gridSize) * gridSize
        let y = round(point.y / gridSize) * gridSize
        return CGPoint(x: x, y: y)
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

    /// 削除エフェクト状態のバインディング
    @Binding var deleteEffect: DeleteEffectState
    
    /// コーディネータークラス - UIKitの委託パターンをSwiftUIに橋渡し
    @MainActor
    class Coordinator: NSObject {
        var parent: CanvasViewRepresentable
        
        init(_ parent: CanvasViewRepresentable) {
            self.parent = parent
        }
        
        // コールバック設定
        func setupCallbacks(canvasView: CanvasView) {
            // 要素選択時のコールバック
            canvasView.onElementSelected = { [viewModel = parent.viewModel] element in
                // 要素が選択された場合は明示的に設定
                if let element = element {
                    viewModel.selectElement(element)
                } else {
                    viewModel.clearSelection()
                }
            }
            
            // 要素作成時のコールバック
            canvasView.onCreateElement = { [viewModel = parent.viewModel] point in
                switch viewModel.editorMode {
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
            
            // 要素削除時のコールバック（フェードアウトエフェクト付き）
            canvasView.onElementDelete = { [weak self] in
                guard let self else { return }
                let viewModel = self.parent.viewModel
                // 削除前にスナップショットを取得してフェードアウト発火
                if let element = viewModel.selectedElement {
                    self.parent.deleteEffect.snapshot = element.renderSnapshot(renderSessions: viewModel.renderSessions)
                    self.parent.deleteEffect.frame = element.frame
                    self.parent.deleteEffect.isActive = true
                }
                viewModel.deleteSelectedElement()
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
        // 同じプロジェクトでも毎回設定し直し、再描画を要求する（要素の変更を描画に反映するため）。
        // editingTextElementId は自身では再描画を要求せず、この要求で反映される。
        // 画像の受け取り先も同じく、プロジェクトの設定し直しで求める再描画より前に設定する。
        canvasView.renderSessions = viewModel.renderSessions
        canvasView.project = viewModel.project
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
        EditorView(viewModel: AppComposition.makeEditorViewModel())
    }
}
