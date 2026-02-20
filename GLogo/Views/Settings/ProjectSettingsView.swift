//
//  ProjectSettingsView.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはプロジェクトの設定を編集するためのビューを実装しています。
//  プロジェクト名、キャンバスサイズ、基本設定などを変更するためのUIコントロールを提供します。
//  EditorViewModelと連携してプロジェクト設定の変更を管理します。
//  EditorViewから呼び出されるモーダルシートとして表示されます。
//


import SwiftUI

/// プロジェクト設定ビュー
struct ProjectSettingsView: View {
    /// エディタビューモデル
    @ObservedObject var viewModel: EditorViewModel
    
    /// 表示制御用の状態
    @Environment(\.presentationMode) var presentationMode
    
    /// プロジェクト名の一時保存用
    @State private var projectName: String
    
    /// キャンバス幅の一時保存用
    @State private var canvasWidth: String
    
    /// キャンバス高さの一時保存用
    @State private var canvasHeight: String
    
    /// 変更が加えられたかのフラグ
    @State private var hasChanges = false
    
    /// 確認ダイアログの表示フラグ
    @State private var showingDiscardChangesAlert = false
    
    /// 設定変更確認ダイアログの表示フラグ
    @State private var showingApplyChangesAlert = false
    
    /// 初期化
    init(viewModel: EditorViewModel) {
        self.viewModel = viewModel
        
        // 現在のプロジェクト設定を初期値としてStateに設定
        _projectName = State(initialValue: viewModel.project.name)
        _canvasWidth = State(initialValue: "\(Int(viewModel.project.canvasSize.width))")
        _canvasHeight = State(initialValue: "\(Int(viewModel.project.canvasSize.height))")
    }
    
    var body: some View {
        NavigationView {
            Form {
                // 基本情報セクション
                Section(header: Text("基本情報")) {
                    // プロジェクト名
                    TextField("プロジェクト名", text: $projectName)
                        .onChange(of: projectName) {
                            hasChanges = true
                        }
                }
                
                // キャンバスサイズセクション
                Section(header: Text("キャンバスサイズ")) {
                    HStack {
                        Text("幅:")
                        TextField("幅", text: $canvasWidth)
                            .keyboardType(.numberPad)
                            .onChange(of: canvasWidth) {
                                hasChanges = true
                            }
                        Text("px")
                    }
                    
                    HStack {
                        Text("高さ:")
                        TextField("高さ", text: $canvasHeight)
                            .keyboardType(.numberPad)
                            .onChange(of: canvasHeight) {
                                hasChanges = true
                            }
                        Text("px")
                    }
                    
                    // プリセットボタン
                    HStack {
                        Text("プリセット:")
                        
                        Spacer()
                        
                        // 各種プリセットボタン
                        ForEach(canvasSizePresets, id: \.name) { preset in
                            Button(preset.name) {
                                canvasWidth = "\(preset.size.width)"
                                canvasHeight = "\(preset.size.height)"
                                hasChanges = true
                            }
                            .buttonStyle(BorderedButtonStyle())
                        }
                    }
                }
                
                // 注意メッセージ
                Section(footer: Text("注意: キャンバスサイズの変更はロゴ要素の位置やサイズに影響する場合があります。").foregroundColor(.secondary)) {
                    EmptyView()
                }
            }
            .navigationTitle("プロジェクト設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // キャンセルボタン
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        // 変更があれば確認ダイアログを表示
                        if hasChanges {
                            showingDiscardChangesAlert = true
                        } else {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                
                // 保存ボタン
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        if hasValidInput() {
                            if isCanvasSizeChanged() {
                                // キャンバスサイズの変更がある場合は確認を表示
                                showingApplyChangesAlert = true
                            } else {
                                // プロジェクト名のみの変更は直ちに適用
                                applyChanges()
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }
                    .disabled(!hasValidInput())
                }
            }
            .alert(isPresented: $showingDiscardChangesAlert) {
                Alert(
                    title: Text("変更を破棄"),
                    message: Text("変更内容を破棄してよろしいですか？"),
                    primaryButton: .destructive(Text("破棄")) {
                        presentationMode.wrappedValue.dismiss()
                    },
                    secondaryButton: .cancel(Text("キャンセル"))
                )
            }
            .alert(isPresented: $showingApplyChangesAlert) {
                Alert(
                    title: Text("キャンバスサイズの変更"),
                    message: Text("キャンバスサイズの変更はロゴ要素の位置やサイズに影響する場合があります。変更を適用しますか？"),
                    primaryButton: .default(Text("適用")) {
                        applyChanges()
                        presentationMode.wrappedValue.dismiss()
                    },
                    secondaryButton: .cancel(Text("キャンセル"))
                )
            }
        }
    }
    
    // MARK: - キャンバスサイズプリセット
    
    /// キャンバスサイズのプリセット
    private let canvasSizePresets = [
        CanvasSizePreset(name: "HD", size: CGSize(width: 1920, height: 1080)),
        CanvasSizePreset(name: "2K", size: CGSize(width: 2560, height: 1440)),
        CanvasSizePreset(name: "4K", size: CGSize(width: 3840, height: 2160)),
        CanvasSizePreset(name: "8K", size: CGSize(width: 7680, height: 4320))
    ]
    
    /// キャンバスサイズプリセット構造体
    private struct CanvasSizePreset {
        let name: String
        let size: CGSize
    }
    
    // MARK: - ヘルパーメソッド
    
    /// 入力が有効かどうかを検証
    private func hasValidInput() -> Bool {
        guard !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let width = Int(canvasWidth), width >= 100 && width <= 5000,
              let height = Int(canvasHeight), height >= 100 && height <= 5000 else {
            return false
        }
        
        return true
    }
    
    /// キャンバスサイズが変更されたかどうかを判定
    private func isCanvasSizeChanged() -> Bool {
        guard let width = Int(canvasWidth),
              let height = Int(canvasHeight) else {
            return false
        }
        
        return width != Int(viewModel.project.canvasSize.width) ||
        height != Int(viewModel.project.canvasSize.height)
    }
    
    /// 変更を適用
    private func applyChanges() {
        // プロジェクト名の更新
        viewModel.updateProjectName(projectName)
        
        // キャンバスサイズの更新
        if let width = Int(canvasWidth), let height = Int(canvasHeight) {
            let newSize = CGSize(width: width, height: height)
            viewModel.updateCanvasSize(newSize)
        }
    }
}

/// プレビュー
struct ProjectSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ProjectSettingsView(viewModel: EditorViewModel())
    }
}
