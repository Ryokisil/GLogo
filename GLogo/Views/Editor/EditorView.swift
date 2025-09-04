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
    
    var id: String {  // ビルド時にInt型だとクラッシュしたのでString型に変更
        switch self {
        case .imagePicker: return "imagePicker"
        case .imageCrop: return "imageCrop"
        }
    }
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
    
    /// 以下State群をenumで列挙型としてまとめとくと整理になるかもなので検討
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
    
    /// 手動背景除去画面への遷移フラグ
    @State private var isNavigatingToManualRemoval = false
    
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
    
    /// キャンバスのズーム比率
    @State private var canvasZoomScale: CGFloat = 1.0
    
    /// キャンバスのパンオフセット
    @State private var canvasPanOffset: CGPoint = .zero
    
    /// 保存オプションアクションシートの表示フラグ
    @State private var isShowingSaveOptions = false
    
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
                VStack(spacing: 0) {
                    // キャンバスエリア（固定サイズ）
                    canvasArea
                        .frame(
                            width: geometry.size.width,
                            height: max(200, geometry.size.height - 300)
                        )
                    
                    // プロパティパネル（固定位置）
                    bottomPropertyPanel
                        .frame(
                            width: geometry.size.width,
                            height: 300
                        )
                }
            }
            .ignoresSafeArea(.keyboard) // キーボードエリアを無視
            .navigationTitle(viewModel.project.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // ツールバーアイテム
                toolbarItems
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
                                activeSheet = .imageCrop(image)
                            }
                        }
                    }
                    
                case .imageCrop(let image):
                    ImageCropView(image: image) { croppedImage in
                        viewModel.addCroppedImageElement(image: croppedImage)
                        viewModel.editorMode = .select
                        activeSheet = nil
                    }
                }
            }
            // 手動背景除去画面への遷移
            .navigationDestination(isPresented: $isNavigatingToManualRemoval) {
                if let imageElement = viewModel.selectedElement as? ImageElement {
                    ManualBackgroundRemovalView(imageElement: imageElement, editorViewModel: viewModel)
                }
            }
            // 保存オプションアクションシート
            .actionSheet(isPresented: $isShowingSaveOptions) {
                ActionSheet(
                    title: Text("保存オプション"),
                    message: Text("保存方法を選択してください"),
                    buttons: [
                        .default(Text("通常保存（個別画像）")) {
                            saveIndividualImages()
                        },
                        .default(Text("合成保存（1枚の画像）")) {
                            saveCompositeImage()
                        },
                        .cancel()
                    ]
                )
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
                snapToGrid: snapToGrid,
                zoomScale: $canvasZoomScale,
                panOffset: $canvasPanOffset
            )
            
            // テキスト編集オーバーレイ (InlineTextEditorからTextEditDialogに変更)
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
            }
            
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
            
            // 手動背景除去
            if let selectedElement = viewModel.selectedElement,
               selectedElement is ImageElement {
                Button(action: {
                    // 手動背景除去画面への遷移
                    isNavigatingToManualRemoval = true
                }) {
                    Image(systemName: "paintbrush.pointed")
                        .foregroundColor(.orange)
                }
                .help("手動背景除去")
            }
            
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
            Button(action: { showGrid.toggle() }) {
                Image(systemName: showGrid ? "grid" : "grid.circle")
                    .foregroundColor(showGrid ? .blue : .primary)
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
            // 左側に保存ボタン
            ToolbarItem(placement: .navigationBarLeading) {
                Button("保存") {
                    isShowingSaveOptions = true
                }
                .help("保存")
            }
            
            // 右側にリバートボタン
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Revert") {
                    // リバート機能の確認ダイアログを表示
                    if canRevert() {
                        showConfirmation(
                            message: "画像を初期状態に戻しますか？",
                            action: revertSelectedImageToInitial
                        )
                    } else {
                        showAlert(
                            title: "リバートできません",
                            message: "選択された画像に編集履歴がないか、画像が選択されていません。"
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - アクション処理
    
    /// 個別画像保存（従来の機能）
    private func saveIndividualImages() {
        viewModel.saveProject { success in
            if success {
                showAlert(title: "保存完了", message: "写真が保存されました。")
            } else {
                showAlert(title: "保存エラー", message: "写真の保存に失敗しました。写真へのアクセス権限確認。または写真が選択されていません。")
            }
        }
    }
    
    /// 合成画像保存（新機能）
    private func saveCompositeImage() {
        viewModel.saveAsCompositeImage { success in
            if success {
                showAlert(title: "合成保存完了", message: "すべての要素が合成された1枚の画像が保存されました。")
            } else {
                showAlert(title: "合成保存エラー", message: "合成画像の保存に失敗しました。写真へのアクセス権限確認。または写真が選択されていません。")
            }
        }
    }
    
    /// 編集を保存（旧メソッド - 互換性のため残す）
    private func saveImage() {
        // 現在は保存オプションアクションシートを表示
        isShowingSaveOptions = true
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
}



/// プレビュー
struct EditorView_Previews: PreviewProvider {
    static var previews: some View {
        EditorView(viewModel: EditorViewModel())
    }
}
