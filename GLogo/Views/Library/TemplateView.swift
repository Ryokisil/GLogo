//
//  TemplateView.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはロゴテンプレートのプレビューと選択のためのビューを実装しています。
//  テンプレートのサムネイル画像と名前を表示し、ユーザーがテンプレートを選択して
//  新しいプロジェクトを作成できるようにします。
//  テンプレートのプレビュー機能やテンプレート適用時の確認ダイアログなども含みます。
//

import SwiftUI

/// テンプレートビュー
struct TemplateView: View {
    /// ライブラリビューモデル
    @ObservedObject var viewModel: LibraryViewModel
    
    /// テンプレートアイテムの配列
    private var templates: [TemplateItem] {
        viewModel.filteredItems.compactMap { $0 as? TemplateItem }
    }
    
    /// 選択されたテンプレート
    @State private var selectedTemplate: TemplateItem? = nil
    
    /// プレビューの表示フラグ
    @State private var isShowingPreview = false
    
    /// 確認ダイアログの表示フラグ
    @State private var isShowingConfirmation = false
    
    /// 列ごとのアイテム数
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            // ヘッダー
            headerView
            
            // テンプレートグリッド
            templateGrid
            
            // 結果がない場合のメッセージ
            if templates.isEmpty {
                emptyResultsView
            }
        }
        .padding()
        .sheet(isPresented: $isShowingPreview, onDismiss: {
            // プレビューが閉じられたときに確認ダイアログを表示
            if selectedTemplate != nil {
                isShowingConfirmation = true
            }
        }) {
            if let template = selectedTemplate {
                TemplatePreviewView(template: template, isShowingConfirmation: $isShowingConfirmation)
            }
        }
        .alert(isPresented: $isShowingConfirmation) {
            Alert(
                title: Text("テンプレートを適用"),
                message: Text("現在のプロジェクトは上書きされます。続行しますか？"),
                primaryButton: .destructive(Text("適用")) {
                    applySelectedTemplate()
                },
                secondaryButton: .cancel(Text("キャンセル")) {
                    selectedTemplate = nil
                }
            )
        }
    }
    
    // MARK: - ヘッダービュー
    
    private var headerView: some View {
        HStack {
            Text("テンプレート")
                .font(.headline)
            
            Spacer()
            
            // 検索フィールド
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("テンプレートを検索", text: $viewModel.searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: viewModel.searchText) { 
                        viewModel.onSearchTextChanged()
                    }
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                        viewModel.onSearchTextChanged()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(width: 200)
        }
    }
    
    // MARK: - テンプレートグリッド
    
    private var templateGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(templates, id: \.id) { template in
                    templateItemView(template)
                }
            }
        }
    }
    
    // MARK: - テンプレートアイテムビュー
    
    private func templateItemView(_ template: TemplateItem) -> some View {
        VStack {
            // テンプレートプレビュー
            ZStack {
                if let thumbnailImage = template.thumbnailImage {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    // サムネイルがない場合はデフォルト画像
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "doc.on.doc")
                                .font(.largeTitle)
                                .foregroundColor(.blue)
                        )
                }
            }
            .frame(height: 120)
            .cornerRadius(8)
            
            // テンプレート名
            Text(template.name)
                .font(.subheadline)
                .lineLimit(1)
                .padding(.top, 4)
            
            // アクションボタン
            HStack {
                // プレビューボタン
                Button(action: {
                    selectedTemplate = template
                    isShowingPreview = true
                }) {
                    Text("プレビュー")
                        .font(.caption)
                }
                .buttonStyle(BorderedButtonStyle())
                
                Spacer()
                
                // 適用ボタン
                Button(action: {
                    selectedTemplate = template
                    isShowingConfirmation = true
                }) {
                    Text("適用")
                        .font(.caption)
                }
                .buttonStyle(BorderedButtonStyle())
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - 結果なしビュー
    
    private var emptyResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.gray)
            
            Text("テンプレートが見つかりませんでした")
                .font(.headline)
            
            Text("検索条件を変更するか、後でまた確認してください")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - アクション
    
    /// 選択されたテンプレートを適用
    private func applySelectedTemplate() {
        guard let template = selectedTemplate else { return }
        
        // テンプレートを適用
        viewModel.onItemSelected(template)
        
        // 状態をリセット
        selectedTemplate = nil
    }
}

/// テンプレートプレビュービュー
struct TemplatePreviewView: View {
    /// テンプレートアイテム
    let template: TemplateItem
    
    /// 確認ダイアログの表示フラグ
    @Binding var isShowingConfirmation: Bool
    
    /// 表示制御用の状態
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                // プレビュー画像
                if let thumbnailImage = template.thumbnailImage {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding()
                } else {
                    // プレースホルダー
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(1.0, contentMode: .fit)
                        .overlay(
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                        )
                        .padding()
                }
                
                // テンプレート情報
                VStack(alignment: .leading, spacing: 16) {
                    Text(template.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // テンプレートの詳細情報（実際のアプリでは拡張可能）
                    Group {
                        detailRow(title: "サイズ:", value: "\(Int(template.project.canvasSize.width)) × \(Int(template.project.canvasSize.height)) px")
                        detailRow(title: "要素数:", value: "\(template.project.elements.count)")
                    }
                    
                    Spacer()
                    
                    // 適用ボタン
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                        isShowingConfirmation = true
                    }) {
                        Text("このテンプレートを適用")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .padding()
            }
            .navigationTitle("テンプレートプレビュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - 詳細行
    
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
        }
    }
}

/// 詳細ボタンスタイル
struct BorderedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.blue, lineWidth: 1)
            )
            .foregroundColor(configuration.isPressed ? .gray : .blue)
    }
}

/// プレビュー
struct TemplateView_Previews: PreviewProvider {
    static var previews: some View {
        TemplateView(viewModel: {
            let viewModel = LibraryViewModel()
            viewModel.onCategorySelected(.templates)
            return viewModel
        }())
        .previewLayout(.sizeThatFits)
        .padding()
        .frame(height: 600)
    }
}
