///
//  EditorView.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはアプリケーションの主要なエディタ画面を実装するSwiftUIビューです。
//  キャンバスエリア、ツールパネル、ツールバーなどのUI要素を統合し、
//  ユーザーがロゴの編集、要素の追加・編集、プロジェクト保存、エクスポートなど
//  主要な操作を行うためのインターフェースを提供します。
//  EditorViewModelと連携して、モデルの変更をUIに反映し、ユーザー操作をモデルに伝達します。
//

import SwiftUI

enum ActiveSheet: Identifiable {
    case imagePicker
    case imageCrop(UIImage, String?)

    var id: String {  // ビルド時にInt型だとクラッシュしたのでString型に変更
        switch self {
        case .imagePicker: return "imagePicker"
        case .imageCrop: return "imageCrop"
        }
    }
}

// MARK: - UI状態管理用struct

/// 純粋なUI表示状態（パネル表示、グリッド設定など）
private struct EditorUIState {
    /// ツールパネルの表示フラグ
    var isShowingToolPanel = true
    /// エクスポートシートの表示フラグ
    var isShowingExportSheet = false
    /// プロジェクト設定シートの表示フラグ
    var isShowingProjectSettings = false
    /// グリッド表示フラグ
    var showGrid = true
    /// グリッドスナップフラグ
    var snapToGrid = false
    /// 下部ツールバーの選択状態
    var selectedBottomTool: EditorBottomTool = .select
    /// 初回ガイドの表示フラグ
    var isShowingEditorIntro = false
    /// 初回ガイドの現在ステップ
    var editorIntroStepIndex = 0
    /// テキストプロパティパネルの表示フラグ
    var isTextPanelVisible = false
}

/// アラート・確認ダイアログの状態
private struct EditorAlertState {
    /// 確認ダイアログの表示フラグ
    var isShowingConfirmation = false
    /// 確認ダイアログのメッセージ
    var confirmationMessage = ""
    /// 確認ダイアログのアクション
    var confirmationAction: () -> Void = {}
    /// アラートの表示フラグ
    var isShowingAlert = false
    /// アラートのタイトル
    var alertTitle = ""
    /// アラートのメッセージ
    var alertMessage = ""
}

/// エディタビュー - アプリのメインエディタ画面
struct EditorView: View {
    // MARK: - プロパティ
    
    /// 複数ビューで参照するかもなのでこのラッパーを使用
    @ObservedObject var viewModel: EditorViewModel
    
    /// オブジェクトを維持しこのビューに所有権を渡すためこのラッパーを使用             ||   EditorView → ElementViewModel（強参照）
    /// 要素編集ビューモデル - 強参照で保持され、EditorViewModel（弱参照）と通信。 ||   ElementViewModel → EditorViewModel（弱参照）
    /// これにより循環参照を避けつつ、選択された要素の編集機能を提供。                    ||   EditorView → EditorViewModel（強参照）
    @StateObject private var elementViewModel: ElementViewModel
    
    // MARK: - UI状態（グルーピング済み）

    /// 純粋なUI表示状態
    @State private var uiState = EditorUIState()

    /// アラート・確認ダイアログの状態
    @State private var alertState = EditorAlertState()

    // MARK: - 画面遷移・シート制御

    /// 画像ピッカーやクロップビューの表示を切り替えるために使用
    @State private var activeSheet: ActiveSheet?

    /// 手動背景除去画面への遷移フラグ
    @State private var isNavigatingToManualRemoval = false

    /// 現在表示中のキャンバス領域サイズ（表示中心への要素追加に使用）
    @State private var canvasViewportSize: CGSize = .zero

    /// キーボード非表示時のキャンバスサイズ（テキスト編集中のリサイズ防止用）
    @State private var stableCanvasSize: CGSize = .zero

    // MARK: - 永続化

    /// 初回ガイド表示の判定
    @AppStorage("hasSeenEditorIntro") private var hasSeenEditorIntro = false
    
    // MARK: - イニシャライザ
    
    init(viewModel: EditorViewModel) {
        self.viewModel = viewModel
        // StateObjectの初期化はプロパティイニシャライザで行えないため、_elementViewModelを直接初期化 プロパティラッパーの初期化などを行う際 _ を付けた変数を使って初期化する必要がある
        _elementViewModel = StateObject(wrappedValue: ElementViewModel(editorViewModel: viewModel))
    }
    
    // MARK: - ボディ
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                // テキスト編集中（キーボード表示中）はサイズを固定して画像縮小を防止
                let effectiveSize = viewModel.isEditingText ? stableCanvasSize : geometry.size
                canvasArea
                    .frame(
                        width: effectiveSize.width,
                        height: effectiveSize.height
                    )
                    .onAppear {
                        stableCanvasSize = geometry.size
                        canvasViewportSize = geometry.size
                    }
                    .onChange(of: geometry.size) { oldSize, newSize in
                        if !viewModel.isEditingText {
                            stableCanvasSize = newSize
                        }
                        canvasViewportSize = newSize
                    }
            }
            .navigationTitle(viewModel.project.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // ツールバーアイテム
                toolbarItems
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                EditorBottomToolStrip(
                    selectedTool: $uiState.selectedBottomTool,
                    onSelectTool: { tool in
                        handleBottomToolSelection(tool)
                    }
                )
                .opacity(isBottomToolStripHidden ? 0 : 1)
                .allowsHitTesting(!isBottomToolStripHidden)
                .accessibilityHidden(isBottomToolStripHidden)
            }
            .overlay(alignment: .bottom) {
                if uiState.selectedBottomTool == .adjust {
                    AdjustBasicPanelView(
                        viewModel: elementViewModel,
                        onClose: {
                            uiState.selectedBottomTool = .select
                        }
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay(alignment: .bottom) {
                if uiState.selectedBottomTool == .magicStudio {
                    AIToolsPanelView(
                        viewModel: elementViewModel,
                        onClose: {
                            uiState.selectedBottomTool = .select
                        },
                        onOpenManualBackgroundRemoval: {
                            if viewModel.selectedElement is ImageElement {
                                isNavigatingToManualRemoval = true
                            }
                        }
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay(alignment: .bottom) {
                if uiState.selectedBottomTool == .filters {
                    FiltersPanelView(
                        viewModel: elementViewModel,
                        onClose: {
                            uiState.selectedBottomTool = .select
                        }
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay(alignment: .bottom) {
                if uiState.isTextPanelVisible && !viewModel.isEditingText {
                    TextPropertyPanelView(
                        viewModel: elementViewModel,
                        onClose: {
                            uiState.isTextPanelVisible = false
                            viewModel.clearSelection()
                            viewModel.editorMode = .select
                        },
                        onOpenTextEditor: {
                            if let textElement = viewModel.selectedElement as? TextElement {
                                viewModel.startTextEditing(for: textElement)
                            }
                        }
                    )
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay {
                if uiState.isShowingEditorIntro {
                    EditorIntroOverlay(
                        isPresented: $uiState.isShowingEditorIntro,
                        stepIndex: $uiState.editorIntroStepIndex,
                        steps: Self.editorIntroSteps
                    ) {
                        hasSeenEditorIntro = true
                    }
                    .transition(.opacity)
                }
            }
            .onAppear {
                if !hasSeenEditorIntro {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        uiState.isShowingEditorIntro = true
                    }
                }
            }
            .onChange(of: viewModel.selectedElement?.id) {
                // テキスト要素選択時にパネルを自動表示、それ以外で非表示
                uiState.isTextPanelVisible = viewModel.selectedElement is TextElement
            }
            // 画像ピッカー内でクロップ画面への遷移を追加
            .sheet(item: $activeSheet) { item in
                switch item {
                case .imagePicker:
                    ImagePickerView { imageInfo in
                        if let image = imageInfo.image {
                            // 画像が選択されたら、一度シートをnilにしてから再度表示
                            Task {
                                // まずシートを閉じる
                                activeSheet = nil
                                // UIの更新を待つ
                                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機
                                // クロップ画面を表示
                                activeSheet = .imageCrop(image, imageInfo.assetIdentifier)
                            }
                        }
                    }
                    
                case .imageCrop(let image, let assetIdentifier):
                    ImageCropView(image: image) { croppedImage in
                        viewModel.addCroppedImageElement(image: croppedImage, assetIdentifier: assetIdentifier)
                        viewModel.editorMode = .select
                        activeSheet = nil
                    }
                }
            }
            // 手動背景除去画面への遷移
            .navigationDestination(isPresented: $isNavigatingToManualRemoval) {
                if let imageElement = viewModel.selectedElement as? ImageElement {
                    ManualBackgroundRemovalView(imageElement: imageElement) { editedImage in
                        viewModel.applyManualBackgroundRemovalResult(editedImage, to: imageElement)
                    }
                }
            }
            // 背景ぼかしマスク編集画面への遷移
            .navigationDestination(isPresented: $viewModel.isNavigatingToBackgroundBlurMaskEdit) {
                if let imageElement = viewModel.backgroundBlurMaskEditTarget {
                    BackgroundBlurMaskEditView(
                        imageElement: imageElement,
                        initialMaskData: imageElement.backgroundBlurMaskData,
                        blurRadius: imageElement.backgroundBlurRadius
                    ) { maskData in
                        viewModel.applyBackgroundBlurMaskResult(maskData, to: imageElement)
                    }
                }
            }
            // 保存オプション（iOS16+はconfirmationDialogに統一）
            .alert(isPresented: $alertState.isShowingAlert) {
                Alert(
                    title: Text(alertState.alertTitle),
                    message: Text(alertState.alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .confirmationDialog(
                alertState.confirmationMessage,
                isPresented: $alertState.isShowingConfirmation,
                titleVisibility: .visible
            ) {
                Button("OK", role: .destructive) {
                    alertState.confirmationAction()
                }
                Button("Cancel", role: .cancel) {}
            }
            .applySystemOverlayVisibility(isHidden: isSystemOverlayHidden)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom) // キーボードによるレイアウト変化を画面全体で抑制
    }

    private var isBottomToolStripHidden: Bool {
        uiState.selectedBottomTool == .adjust ||
        uiState.selectedBottomTool == .magicStudio ||
        uiState.selectedBottomTool == .filters ||
        uiState.isTextPanelVisible ||
        viewModel.isEditingText
    }

    private var isSystemOverlayHidden: Bool {
        uiState.selectedBottomTool == .adjust ||
        uiState.selectedBottomTool == .magicStudio ||
        uiState.selectedBottomTool == .filters ||
        uiState.isTextPanelVisible
    }

    private func handleBottomToolSelection(_ tool: EditorBottomTool) {
        if tool == .select {
            // テキスト要素を現在表示中のキャンバス中心に新規作成
            let center = visibleCanvasCenter()
            viewModel.addTextElement(text: "Text", position: center)
            viewModel.editorMode = .select
            // addElementが自動選択 → onChange連動でパネル表示
        } else {
            uiState.isTextPanelVisible = false
            if tool == .adjust || tool == .magicStudio || tool == .filters {
                viewModel.editorMode = .select
            }
        }
    }

    /// 現在表示されているキャンバス領域の中心座標（キャンバス座標系）
    private func visibleCanvasCenter() -> CGPoint {
        let canvasSize = viewModel.project.canvasSize

        guard canvasViewportSize.width > 0, canvasViewportSize.height > 0 else {
            return CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        }

        return CGPoint(
            x: min(canvasViewportSize.width / 2, canvasSize.width),
            y: min(canvasViewportSize.height / 2, canvasSize.height)
        )
    }

    // MARK: - キャンバスエリア
    
    private var canvasArea: some View {
        ZStack {
            // キャンバス背景
            Color.gray.opacity(0.2)
                .edgesIgnoringSafeArea(.all)
            
            // キャンバスビュー
            CanvasViewRepresentable(
                viewModel: viewModel,
                showGrid: uiState.showGrid,
                snapToGrid: uiState.snapToGrid
            )
            
            if viewModel.editorMode == .select {
                Color.clear
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("canvas"))
                            .onEnded { value in
                                let hit = hitTestElement(at: value.startLocation, in: viewModel.project.elements)
                                if let element = hit {
                                    viewModel.selectElement(element)
                                } else {
                                    viewModel.clearSelection()
                                }
                            }
                    )
            }
            
            // オーバーレイは選択モードのみ表示（作成モードでは入力を塞がない）
            if viewModel.editorMode == .select,
               !viewModel.isEditingText,
               let selected = viewModel.selectedElement {
                ElementSelectionView(
                    element: selected,
                    onManipulationStarted: nil,
                    onManipulationChanged: nil,
                    onManipulationEnded: nil,
                    onMagnifyChanged: { scale in
                        elementViewModel.applyGestureTransform(translation: nil, scale: scale, rotation: nil, ended: false)
                    },
                    onMagnifyEnded: {
                        elementViewModel.applyGestureTransform(translation: nil, scale: nil, rotation: nil, ended: true)
                    },
                    onRotateGestureChanged: { angle in
                        elementViewModel.applyGestureTransform(translation: nil, scale: nil, rotation: angle, ended: false)
                    },
                    onRotateGestureEnded: {
                        elementViewModel.applyGestureTransform(translation: nil, scale: nil, rotation: nil, ended: true)
                    },
                    onMoveChanged: { translation in
                        elementViewModel.applyGestureTransform(translation: translation, scale: nil, rotation: nil, ended: false)
                    },
                    onMoveEnded: {
                        elementViewModel.applyGestureTransform(translation: nil, scale: nil, rotation: nil, ended: true)
                    },
                    onTapSelect: { globalPoint in
                        DispatchQueue.main.async {
                            // まず最前面をヒットテスト
                            if let primary = hitTestElement(at: globalPoint, in: viewModel.project.elements) {
                                if let selected = viewModel.selectedElement {
                                    if primary.id == selected.id {
                                        return // 同じ要素なら切り替えない
                                    }
                                }
                                viewModel.selectElement(primary)
                            } else {
                                viewModel.clearSelection()
                            }
                        }
                    }
                )
            }

            if viewModel.isEditingText,
               let editingElement = viewModel.editingTextElement {
                TextEditDialog(
                    initialText: editingElement.text,
                    onEditComplete: { newText in
                        viewModel.updateTextContent(editingElement, newText: newText)
                        viewModel.endTextEditing()
                    },
                    onCancel: {
                        viewModel.endTextEditing()
                    }
                )
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .zIndex(1000)
                .offset(y: -110)
            }

            // ツールバー
            VStack {
                toolbarOverlay
                Spacer()
            }
            .padding()
        }
        .frame(maxHeight: .infinity)
        .coordinateSpace(name: "canvas")
    }
    
    // MARK: - オーバーレイツールバー
    
    private var toolbarOverlay: some View {
        HStack {
            // モードセレクタ
            modeSelector
            
            Spacer()
            
            // ビューコントロール
            viewControls
        }
        .padding(8)
        .background(Color(UIColor.systemBackground).opacity(0.9))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
    
    // MARK: - モードセレクタ
    
    private var modeSelector: some View {
        HStack(spacing: 12) {
            // 図形作成モード
            Menu {
                // 各図形タイプのメニュー項目
                Button(action: {
                    viewModel.nextShapeType = .rectangle
                    viewModel.editorMode = .shapeCreate
                }) {
                    Label("四角形", systemImage: "square")
                }
                
                Button(action: {
                    viewModel.nextShapeType = .roundedRectangle
                    viewModel.editorMode = .shapeCreate
                }) {
                    Label("角丸四角形", systemImage: "square.rounded")
                }
                
                Button(action: {
                    viewModel.nextShapeType = .circle
                    viewModel.editorMode = .shapeCreate
                }) {
                    Label("円", systemImage: "circle")
                }
                
                Button(action: {
                    viewModel.nextShapeType = .triangle
                    viewModel.editorMode = .shapeCreate
                }) {
                    Label("三角形", systemImage: "triangle")
                }
                
                Button(action: {
                    viewModel.nextShapeType = .star
                    viewModel.editorMode = .shapeCreate
                }) {
                    Label("星", systemImage: "star")
                }
                
                Button(action: {
                    viewModel.nextShapeType = .polygon
                    viewModel.editorMode = .shapeCreate
                }) {
                    Label("多角形", systemImage: "hexagon")
                }
            } label: {
                Image(systemName: "square.on.circle")
                    .foregroundColor(viewModel.editorMode == .shapeCreate ? .blue : .primary)
            }
            .help("図形ツール")
            
            // 画像インポートモード
            Button(action: {
                viewModel.editorMode = .imageImport
                // activeSheetを使用する方法に変更
                activeSheet = .imagePicker
            }) {
                Image(systemName: "photo")
                    .foregroundColor(viewModel.editorMode == .imageImport ? .blue : .primary)
            }
            .help("画像追加")
            
            // 削除モード
            Button(action: {
                if viewModel.selectedElement != nil {
                    // 選択中の要素がある場合は削除の確認
                    showConfirmation(
                        message: "Delete the selected element?",
                        action: {
                        viewModel.deleteSelectedElement()
                        }
                    )
                } else {
                    // 選択中の要素がない場合は削除モードに切り替え
                    viewModel.editorMode = .delete
                }
            }) {
                Image(systemName: "trash")
                    .foregroundColor(viewModel.editorMode == .delete ? .red : .primary)
            }
            .help("削除ツール")
            
            // 画像役割切り替え（ベース/オーバーレイ）
            if let selectedElement = viewModel.selectedElement,
               let imageElement = selectedElement as? ImageElement {
                Button(action: {
                    // ベース画像でない場合のみ切り替え可能
                    if !imageElement.isBaseImage {
                        viewModel.toggleImageRole(imageElement)
                    }
                }) {
                    Image(systemName: imageElement.isBaseImage ? "star.fill" : "star")
                        .foregroundColor(imageElement.isBaseImage ? .yellow : .primary)
                        .opacity(imageElement.isBaseImage ? 0.7 : 1.0) // ベース画像時は少し薄く表示
                }
                .disabled(imageElement.isBaseImage) // ベース画像時は無効化
                .help(imageElement.isBaseImage ? "ベース画像（変更不可）" : "ベース画像に設定")
            }
        }
    }
    
    // MARK: - ビューコントロール
    
    private var viewControls: some View {
        HStack(spacing: 12) {
            // グリッド表示切替
            Button(action: { uiState.showGrid.toggle() }) {
                Image(systemName: uiState.showGrid ? "grid" : "grid.circle")
                    .foregroundColor(uiState.showGrid ? .blue : .primary)
            }
            .help("グリッド表示")
            
            // 操作履歴
            HStack(spacing: 4) {
                // アンドゥ
                Button(action: { viewModel.undo() }) {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!viewModel.canUndo)
                .keyboardShortcut("z", modifiers: .command)
                .help("元に戻す")
                
                // リドゥ
                Button(action: { viewModel.redo() }) {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!viewModel.canRedo)
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .help("やり直す")
            }
        }
    }
    
    // MARK: - ツールバーアイテム
    
    private var toolbarItems: some ToolbarContent {
        Group {
            // 左側に保存ボタン
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Save") {
                    saveProjectAuto()
                }
                .help("Save")
            }
            
            // 右側にリバートボタン
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Revert") {
                    // リバート機能の確認ダイアログを表示
                    if canRevert() {
                        showConfirmation(
                            message: "Do you want to revert the selected image to its original state?",
                            action: revertSelectedImageToInitial
                        )
                    } else {
                        showAlert(
                            title: "Cannot Revert",
                            message: "No editable history was found, or no image is selected."
                        )
                    }
                }
            }

            // 使い方ガイド
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    uiState.editorIntroStepIndex = 0
                    withAnimation(.easeInOut(duration: 0.3)) {
                        uiState.isShowingEditorIntro = true
                    }
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .help("使い方ガイド")
            }

        }
    }

    private static let editorIntroSteps: [EditorIntroStep] = [
        EditorIntroStep(
            title: "画像を追加",
            message: "写真アイコンをタップして画像を読み込みます。",
            systemImageName: "photo.on.rectangle"
        ),
        EditorIntroStep(
            title: "要素を選択",
            message: "キャンバス上の要素をタップして選択し、移動・拡大縮小・回転ができます。",
            systemImageName: "hand.tap"
        ),
        EditorIntroStep(
            title: "下部ツールで編集",
            message: "Textで文字追加、Adjustで色調整、AI Toolsで背景関連の編集ができます。",
            systemImageName: "slider.horizontal.3"
        ),
        EditorIntroStep(
            title: "保存",
            message: "左上の保存ボタンで書き出します。",
            systemImageName: "square.and.arrow.down"
        )
    ]
    
    // MARK: - アクション処理
    
    /// 編集内容を自動判定で保存
    private func saveProjectAuto() {
        viewModel.saveProject { success in
            if success {
                showAlert(title: "Saved", message: "The image was saved to Photos.")
            } else {
                showAlert(title: "Save Failed", message: "Unable to save the image. Check Photos permission or selected content.")
            }
        }
    }
    
    /// 画像選択後の処理
    private func handleImageSelected(_ image: UIImage?) {
        guard let image = image, let imageData = image.pngData() else {
            return
        }
        
        // カーソル位置（中央）に画像を追加
        let centerPosition = CGPoint(
            x: viewModel.project.canvasSize.width / 2,
            y: viewModel.project.canvasSize.height / 2
        )
        
        viewModel.addImageElement(imageData: imageData, position: centerPosition, phAsset: nil)
        
        // 選択モードに戻る
        viewModel.editorMode = .select
    }
    
    /// アラートを表示
    private func showAlert(title: String, message: String) {
        alertState.alertTitle = title
        alertState.alertMessage = message
        alertState.isShowingAlert = true
    }

    /// 確認ダイアログを表示
    private func showConfirmation(message: String, action: @escaping () -> Void) {
        alertState.confirmationMessage = message
        alertState.confirmationAction = action
        alertState.isShowingConfirmation = true
    }
    
    /// 選択された画像のリバートが可能かどうかを判断
    private func canRevert() -> Bool {
        if let imageElement = viewModel.selectedElement as? ImageElement,
           imageElement.hasEditHistory {
            return true
        }
        return false
    }
    
    /// 選択された画像を初期状態に戻す
    private func revertSelectedImageToInitial() {
        if let imageElement = viewModel.selectedElement as? ImageElement {
            imageElement.revertToInitialState()
            // キャンバスの再描画を促す
            viewModel.updateSelectedElement(imageElement)
        }
    }

    /// zIndex降順でヒットテスト
    private func hitTestElement(at location: CGPoint, in elements: [LogoElement], excluding excludeId: UUID? = nil) -> LogoElement? {
        elements
            .sorted { $0.zIndex > $1.zIndex }
            .first { element in
                if let excludeId = excludeId, element.id == excludeId { return false }
                return element.hitTest(location)
            }
    }
}

private extension View {
    @ViewBuilder
    func applySystemOverlayVisibility(isHidden: Bool) -> some View {
        if #available(iOS 16.0, *) {
            self.persistentSystemOverlays(isHidden ? .hidden : .visible)
        } else {
            self
        }
    }
}



/// プレビュー
struct EditorView_Previews: PreviewProvider {
    static var previews: some View {
        EditorView(viewModel: EditorViewModel())
    }
}

