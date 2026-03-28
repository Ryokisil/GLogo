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
    /// アプリ設定画面の表示フラグ
    var isShowingAppSettings = false
}

/// アラート・確認ダイアログの状態
private struct EditorAlertState {
    /// 確認ダイアログの表示フラグ
    var isShowingConfirmation = false
    /// 確認ダイアログのメッセージ（ローカライズキー）
    var confirmationMessage: LocalizedStringKey = ""
    /// 確認ダイアログのアクション
    var confirmationAction: () -> Void = {}
    /// アラートの表示フラグ
    var isShowingAlert = false
    /// アラートのタイトル（ローカライズキー）
    var alertTitle: LocalizedStringKey = ""
    /// アラートのメッセージ（ローカライズキー）
    var alertMessage: LocalizedStringKey = ""
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

    /// アプリ設定を閉じたあとにガイドを開く要求
    @State private var shouldOpenEditorGuideAfterSettingsDismiss = false

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
                EditorCanvasContainerView(
                        viewModel: viewModel,
                        elementViewModel: elementViewModel,
                        showGrid: uiState.showGrid,
                        snapToGrid: uiState.snapToGrid,
                        activeSheet: $activeSheet,
                        onShowConfirmation: showConfirmation,
                        onOpenAppSettings: openAppSettings
                    )
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
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                EditorTopBarView(
                    viewModel: viewModel,
                    onSave: saveToPhotoLibraryAuto,
                    onRevert: {
                        if canRevert() {
                            showConfirmation(
                                message: "editor.revertConfirmation",
                                action: revertSelectedImageToInitial
                            )
                        } else {
                            showAlert(
                                title: "editor.cannotRevert.title",
                                message: "editor.cannotRevert.message"
                            )
                        }
                    }
                )
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                EditorBottomToolStrip(
                    selectedTool: $uiState.selectedBottomTool,
                    onSelectTool: { tool in
                        handleBottomToolSelection(tool)
                    }
                )
                .opacity(isBottomToolStripHidden ? 0 : 1)
                .allowsHitTesting(!isBottomToolStripHidden && !viewModel.isSavingImage)
                .accessibilityHidden(isBottomToolStripHidden)
            }
            .overlay(alignment: .bottom) {
                EditorBottomPanelHostView(
                    selectedBottomTool: $uiState.selectedBottomTool,
                    isTextPanelVisible: $uiState.isTextPanelVisible,
                    isNavigatingToManualRemoval: $isNavigatingToManualRemoval,
                    elementViewModel: elementViewModel,
                    viewModel: viewModel
                )
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
                if shouldCollapseBottomTool(for: viewModel.selectedElement, selectedTool: uiState.selectedBottomTool) {
                    uiState.selectedBottomTool = .select
                }
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
            .sheet(
                isPresented: $uiState.isShowingAppSettings,
                onDismiss: handleAppSettingsDismiss
            ) {
                AppSettingsView(
                    onRequestOpenEditorGuide: {
                        shouldOpenEditorGuideAfterSettingsDismiss = true
                    }
                )
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
                    dismissButton: .default(Text("common.ok"))
                )
            }
            .confirmationDialog(
                alertState.confirmationMessage,
                isPresented: $alertState.isShowingConfirmation,
                titleVisibility: .visible
            ) {
                Button("common.ok", role: .destructive) {
                    alertState.confirmationAction()
                }
                .accessibilityIdentifier("editor.confirmation.okButton")
                Button("common.cancel", role: .cancel) {}
            }
            .applySystemOverlayVisibility(isHidden: isSystemOverlayHidden)
            .overlay {
                if viewModel.isSavingImage {
                    savingOverlay
                }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom) // キーボードによるレイアウト変化を画面全体で抑制
    }

    private var isBottomToolStripHidden: Bool {
        uiState.selectedBottomTool == .adjust ||
        uiState.selectedBottomTool == .frame ||
        uiState.selectedBottomTool == .magicStudio ||
        uiState.selectedBottomTool == .filters ||
        uiState.selectedBottomTool == .effects ||
        uiState.isTextPanelVisible ||
        viewModel.isEditingText
    }

    private var isSystemOverlayHidden: Bool {
        uiState.selectedBottomTool == .adjust ||
        uiState.selectedBottomTool == .frame ||
        uiState.selectedBottomTool == .magicStudio ||
        uiState.selectedBottomTool == .filters ||
        uiState.selectedBottomTool == .effects ||
        uiState.isTextPanelVisible
    }

    private func isImagePropertyTool(_ tool: EditorBottomTool) -> Bool {
        tool == .adjust ||
        tool == .frame ||
        tool == .magicStudio ||
        tool == .filters ||
        tool == .effects
    }

    private func shouldCollapseBottomTool(for selectedElement: LogoElement?, selectedTool: EditorBottomTool) -> Bool {
        guard isImagePropertyTool(selectedTool) else { return false }
        return (selectedElement as? ImageElement) == nil
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
            if tool == .adjust || tool == .frame || tool == .magicStudio || tool == .filters || tool == .effects {
                viewModel.editorMode = .select
                if shouldCollapseBottomTool(for: viewModel.selectedElement, selectedTool: tool) {
                    uiState.selectedBottomTool = .select
                }
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

    private static let editorIntroSteps: [EditorIntroStep] = [
        EditorIntroStep(
            titleKey: "guide.editor.addImage.title",
            messageKey: "guide.editor.addImage.message",
            systemImageName: "photo.on.rectangle"
        ),
        EditorIntroStep(
            titleKey: "guide.editor.selectElement.title",
            messageKey: "guide.editor.selectElement.message",
            systemImageName: "hand.tap"
        ),
        EditorIntroStep(
            titleKey: "guide.editor.bottomTools.title",
            messageKey: "guide.editor.bottomTools.message",
            systemImageName: "slider.horizontal.3"
        ),
        EditorIntroStep(
            titleKey: "guide.editor.save.title",
            messageKey: "guide.editor.save.message",
            systemImageName: "square.and.arrow.down"
        )
    ]
    
    // MARK: - アクション処理
    
    /// 編集内容を自動判定で写真ライブラリへ保存
    private func saveToPhotoLibraryAuto() {
        viewModel.saveToPhotoLibrary { result in
            if case .success = result {
                showAlert(title: "editor.saved.title", message: "editor.saved.message")
            } else {
                showAlert(title: "editor.saveFailed.title", message: "editor.saveFailed.message")
            }
        }
    }
    
    /// アラートを表示
    private func showAlert(title: LocalizedStringKey, message: LocalizedStringKey) {
        alertState.alertTitle = title
        alertState.alertMessage = message
        alertState.isShowingAlert = true
    }

    /// 確認ダイアログを表示
    private func showConfirmation(message: LocalizedStringKey, action: @escaping () -> Void) {
        alertState.confirmationMessage = message
        alertState.confirmationAction = action
        alertState.isShowingConfirmation = true
    }
    
    /// 選択された画像のリバートが可能かどうかを判断
    private func canRevert() -> Bool {
        viewModel.canRevertSelectedImageToInitialState()
    }
    
    /// 選択された画像を初期状態に戻す
    private func revertSelectedImageToInitial() {
        viewModel.revertSelectedImageToInitialState()
    }

    /// 使い方ガイドを表示
    private func openEditorGuide() {
        uiState.editorIntroStepIndex = 0
        withAnimation(.easeInOut(duration: 0.3)) {
            uiState.isShowingEditorIntro = true
        }
    }

    /// アプリ設定画面を表示
    private func openAppSettings() {
        uiState.isShowingAppSettings = true
    }

    /// アプリ設定シートを閉じたあとに必要な後続処理を実行
    private func handleAppSettingsDismiss() {
        guard shouldOpenEditorGuideAfterSettingsDismiss else { return }
        shouldOpenEditorGuideAfterSettingsDismiss = false
        openEditorGuide()
    }

    /// 保存中に入力をロックするオーバーレイ
    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                ProgressView()
                Text("editor.saving")
                    .font(.callout)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 6)
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
