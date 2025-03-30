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
    case imageCrop(UIImage)
    
    var id: Int {
        switch self {
        case .imagePicker: return 0
        case .imageCrop: return 1
        }
    }
}

/// エディタビュー - アプリのメインエディタ画面
struct EditorView: View {
    // MARK: - プロパティ
    
    /// エディタビューモデル
    @ObservedObject var viewModel: EditorViewModel
    
    /// 要素編集ビューモデル
    @StateObject private var elementViewModel: ElementViewModel
    
    /// ツールパネルの表示フラグ
    @State private var isShowingToolPanel = true
    
    /// エクスポートシートの表示フラグ
    @State private var isShowingExportSheet = false
    
    /// プロジェクト設定シートの表示フラグ
    @State private var isShowingProjectSettings = false
    
    /// 画像ピッカーの表示フラグ
    @State private var selectedImage: UIImage? = nil
    
    /// 画像ピッカーやクロップビューの表示を切り替えるために使用
    @State private var activeSheet: ActiveSheet?
    
    /// グリッド表示フラグ
    @State private var showGrid = true
    
    /// グリッドスナップフラグ
    @State private var snapToGrid = false
    
    /// 確認ダイアログの表示フラグ
    @State private var isShowingConfirmation = false
    
    /// 確認ダイアログのメッセージ
    @State private var confirmationMessage = ""
    
    /// 確認ダイアログのアクション
    @State private var confirmationAction: () -> Void = {}
    
    /// アラートの表示フラグ
    @State private var isShowingAlert = false
    
    /// アラートのタイトル
    @State private var alertTitle = ""
    
    /// アラートのメッセージ
    @State private var alertMessage = ""
    
    // MARK: - イニシャライザ
    
    init(viewModel: EditorViewModel) {
        self.viewModel = viewModel
        // StateObjectの初期化はプロパティイニシャライザで行えないため、_elementViewModelを直接初期化
        _elementViewModel = StateObject(wrappedValue: ElementViewModel(editorViewModel: viewModel))
    }
    
    // MARK: - ボディ
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // キャンバスエリア（伸縮可能）
                canvasArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                bottomPropertyPanel
                    .frame(height: 300)
            }
            .navigationTitle(viewModel.project.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // ツールバーアイテム
                toolbarItems
            }
            .sheet(isPresented: $isShowingExportSheet) {
                ExportView(viewModel: viewModel)
            }
            .sheet(isPresented: $isShowingProjectSettings) {
                ProjectSettingsView(viewModel: viewModel)
            }
            .sheet(item: $activeSheet) { item in
                switch item {
                case .imagePicker:
                    ImagePickerView { image in
                        if let image = image {
                            print("画像が選択されました") // デバッグログ
                            DispatchQueue.main.async {
                                // 非同期で状態を更新
                                self.activeSheet = .imageCrop(image)
                            }
                        } else {
                            print("画像選択がキャンセルされました") // デバッグログ
                            activeSheet = nil
                        }
                    }
                    .onDisappear {
                        print("ImagePickerViewが閉じられました") // デバッグログ
                    }
                    
                case .imageCrop(let image):
                    ImageCropView(image: image) { croppedImage in
                        print("画像がクロップされました") // デバッグログ
                        // クロップ完了後、編集モードに戻る
                        viewModel.addCroppedImageElement(image: croppedImage)
                        viewModel.editorMode = .select
                        activeSheet = nil
                    }
                    .onDisappear {
                        print("ImageCropViewが閉じられました") // デバッグログ
                    }
                }
            }
            .alert(isPresented: $isShowingAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    primaryButton: .destructive(Text("はい")) {
                        confirmationAction()
                    },
                    secondaryButton: .cancel(Text("いいえ"))
                )
            }
            .confirmationDialog(
                confirmationMessage,
                isPresented: $isShowingConfirmation,
                titleVisibility: .visible
            ) {
                Button("OK", role: .destructive) {
                    confirmationAction()
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }
    
    private var bottomPropertyPanel: some View {
        VStack(spacing: 0) {
            // 上部の境界線
            Divider()
            
            // タブ選択部分
            tabSelector
            
            // パネルコンテンツ
            if let elementType = elementViewModel.elementType {
                // 要素が選択されている場合
                Group {
                    switch elementType {
                    case .text:
                        TextEditorPanel(viewModel: elementViewModel)
                    case .shape:
                        ShapeEditorPanel(viewModel: elementViewModel)
                    case .image:
                        ImageEditorPanel(viewModel: elementViewModel)
                    }
                }
            } else {
                // 要素が選択されていない場合は背景設定
                BackgroundEditorPanel(viewModel: viewModel)
            }
        }
        .background(Color(UIColor.systemBackground))
    }
    
    private var tabSelector: some View {
        HStack {
            Text("プロパティ")
                .font(.headline)
                .padding(.leading)
            
            Spacer()
            
            Button(action: {
                // タブの切り替え処理（必要に応じて実装）
            }) {
                Text("エフェクト")
                    .foregroundColor(.secondary)
            }
            .padding(.trailing)
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
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
                showGrid: showGrid,
                snapToGrid: snapToGrid
            )
            
            // ツールバー
            VStack {
                toolbarOverlay
                Spacer()
            }
            .padding()
        }
        .frame(maxHeight: .infinity)
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
            // 選択モード
            Button(action: { viewModel.editorMode = .select }) {
                Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                    .foregroundColor(viewModel.editorMode == .select ? .blue : .primary)
            }
            .help("選択ツール")
            
            // テキスト作成モード
            Button(action: { viewModel.editorMode = .textCreate }) {
                Image(systemName: "textformat")
                    .foregroundColor(viewModel.editorMode == .textCreate ? .blue : .primary)
            }
            .help("テキストツール")
            
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
                // activeSheetを使用する統一された方法に変更
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
                    alertTitle = "削除の確認"
                    alertMessage = "選択した要素を削除しますか？"
                    isShowingAlert = true
                    // 削除アクションの設定（アラートの「はい」ボタンで実行される）
                    confirmationAction = {
                        viewModel.deleteSelectedElement()
                    }
                } else {
                    // 選択中の要素がない場合は削除モードに切り替え
                    viewModel.editorMode = .delete
                }
            }) {
                Image(systemName: "trash")
                    .foregroundColor(viewModel.editorMode == .delete ? .red : .primary)
            }
            .help("削除ツール")
        }
    }
    
    // MARK: - ビューコントロール
    
    private var viewControls: some View {
        HStack(spacing: 12) {
            // グリッド表示切替
            Button(action: { showGrid.toggle() }) {
                Image(systemName: showGrid ? "grid" : "grid.circle")
                    .foregroundColor(showGrid ? .blue : .primary)
            }
            .help("グリッド表示")
            
            // グリッドスナップ切替
            Button(action: { snapToGrid.toggle() }) {
                Image(systemName: snapToGrid ? "arrow.down.forward.and.arrow.up.backward.circle.fill" : "arrow.down.forward.and.arrow.up.backward.circle")
                    .foregroundColor(snapToGrid ? .blue : .primary)
            }
            .help("グリッドにスナップ")
            
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
    
    // MARK: - ツールパネル
    
    private var toolPanel: some View {
        VStack(spacing: 0) {
            // ツールパネルのヘッダー
            HStack {
                Text("プロパティ")
                    .font(.headline)
                Spacer()
                Button(action: { isShowingToolPanel = false }) {
                    Image(systemName: "chevron.down")
                        .font(.body)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            
            // 要素が選択されている場合は要素編集パネル、そうでなければ背景設定パネル
            if viewModel.selectedElement != nil {
                ElementEditorPanel(viewModel: elementViewModel)
            } else {
                BackgroundEditorPanel(viewModel: viewModel)
            }
        }
        .frame(width: 300)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - ツールバーアイテム
    
    private var toolbarItems: some ToolbarContent {
        Group {
            // 左側アイテム
            ToolbarItem(placement: .navigationBarLeading) {
                HStack {
                    // プロジェクト設定
                    Button(action: { isShowingProjectSettings = true }) {
                        Image(systemName: "gear")
                    }
                    .help("プロジェクト設定")
                    
                    // プロジェクト保存
                    Button(action: saveProject) {
                        Image(systemName: "arrow.down.doc")
                    }
                    .help("保存")
                }
            }
            
            // 右側アイテム
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    // ツールパネル切替
                    Button(action: { isShowingToolPanel.toggle() }) {
                        Image(systemName: isShowingToolPanel ? "chevron.down" : "chevron.up")
                    }
                    .help("プロパティパネル")
                    
                    // エクスポート
                    Button(action: { isShowingExportSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .help("エクスポート")
                }
            }
        }
    }
    
    // MARK: - アクション処理
    
    /// プロジェクトを保存
    private func saveProject() {
        viewModel.saveProject { success in
            if success {
                showAlert(title: "保存完了", message: "プロジェクトが保存されました。")
            } else {
                showAlert(title: "エラー", message: "プロジェクトの保存に失敗しました。")
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
        
        viewModel.addImageElement(imageData: imageData, position: centerPosition)
        
        // 選択モードに戻る
        viewModel.editorMode = .select
    }
    
    /// アラートを表示
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        isShowingAlert = true
    }
    
    /// 確認ダイアログを表示
    private func showConfirmation(message: String, action: @escaping () -> Void) {
        confirmationMessage = message
        confirmationAction = action
        isShowingConfirmation = true
    }
    
    
}

/// プレビュー
struct EditorView_Previews: PreviewProvider {
    static var previews: some View {
        EditorView(viewModel: EditorViewModel())
    }
}
