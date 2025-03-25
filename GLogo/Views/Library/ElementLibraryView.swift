//
//  ElementLibraryView.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはロゴ作成用の要素ライブラリを表示するSwiftUIビューです。
//  テンプレート、図形、テキストスタイル、背景、エフェクトなどのカテゴリに分類された
//  ライブラリアイテムをグリッドやリスト形式で表示し、ユーザーが選択してプロジェクトに
//  追加できるようにします。また、カテゴリ選択や検索機能も提供します。
//  LibraryViewModelと連携して、ライブラリの状態管理と操作を行います。
//

import SwiftUI

/// 要素ライブラリビュー
struct ElementLibraryView: View {
    /// ライブラリビューモデル
    @ObservedObject var viewModel: LibraryViewModel
    
    /// 表示モード
    @State private var displayMode: DisplayMode = .grid
    
    /// ライブラリの表示状態
    @State private var isExpanded = true
    
    /// 新規テンプレート確認ダイアログの表示フラグ
    @State private var isShowingTemplateConfirmation = false
    
    /// 選択されたテンプレートアイテム
    @State private var selectedTemplate: TemplateItem? = nil
    
    /// 表示モード
    enum DisplayMode {
        case grid
        case list
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            libraryHeader
            
            // ライブラリが展開されている場合は内容を表示
            if isExpanded {
                VStack(spacing: 0) {
                    // 検索バー
                    searchBar
                    
                    // カテゴリタブ
                    categoryTabs
                    
                    // メインコンテンツ
                    libraryContent
                }
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .shadow(radius: 3)
        .padding()
        .alert(isPresented: $isShowingTemplateConfirmation) {
            Alert(
                title: Text("テンプレートを適用"),
                message: Text("現在のプロジェクトは上書きされます。続行しますか？"),
                primaryButton: .destructive(Text("適用")) {
                    if let template = selectedTemplate {
                        viewModel.onItemSelected(template)
                    }
                },
                secondaryButton: .cancel(Text("キャンセル"))
            )
        }
    }
    
    // MARK: - ヘッダー
    
    private var libraryHeader: some View {
        HStack {
            // ライブラリタイトル
            Text("要素ライブラリ")
                .font(.headline)
            
            Spacer()
            
            // 表示モード切替ボタン
            Button(action: {
                displayMode = displayMode == .grid ? .list : .grid
            }) {
                Image(systemName: displayMode == .grid ? "list.bullet" : "square.grid.2x2")
                    .foregroundColor(.primary)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 展開/折りたたみボタン
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .foregroundColor(.primary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - 検索バー
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("ライブラリを検索", text: $viewModel.searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: viewModel.searchText) { _ in
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
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - カテゴリタブ
    
    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(LibraryCategory.allCases) { category in
                    Button(action: {
                        viewModel.onCategorySelected(category)
                    }) {
                        HStack {
                            Image(systemName: category.iconName)
                            Text(category.rawValue)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(viewModel.selectedCategory == category ? Color.blue : Color.gray.opacity(0.2))
                        )
                        .foregroundColor(viewModel.selectedCategory == category ? .white : .primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - メインコンテンツ
    
    private var libraryContent: some View {
        Group {
            if viewModel.filteredItems.isEmpty {
                // 結果がない場合
                emptyResultsView
            } else {
                // 表示モードに応じたコンテンツ
                if displayMode == .grid {
                    libraryGridView
                } else {
                    libraryListView
                }
            }
        }
    }
    
    // MARK: - 検索結果なしビュー
    
    private var emptyResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.gray)
            
            Text("アイテムが見つかりませんでした")
                .font(.headline)
            
            Text(viewModel.searchText.isEmpty ? "選択したカテゴリにアイテムがありません" : "検索条件に一致するアイテムがありません")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - グリッドビュー
    
    private var libraryGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 120, maximum: 150), spacing: 16)
            ], spacing: 16) {
                ForEach(viewModel.filteredItems, id: \.id) { item in
                    libraryItemView(item)
                        .frame(height: 150)
                }
            }
            .padding()
        }
    }
    
    // MARK: - リストビュー
    
    private var libraryListView: some View {
        List {
            ForEach(viewModel.filteredItems, id: \.id) { item in
                libraryItemRow(item)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        handleItemSelection(item)
                    }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - ライブラリアイテムビュー（グリッド用）
    
    private func libraryItemView(_ item: any LibraryItem) -> some View {
        VStack {
            // プレビュー画像
            if let thumbnailImage = item.thumbnailImage {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 80)
            } else {
                Image(systemName: getCategoryIcon(for: item))
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                    .frame(height: 80)
            }
            
            // アイテム名
            Text(item.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
        .onTapGesture {
            handleItemSelection(item)
        }
    }
    
    // MARK: - ライブラリアイテム行（リスト用）
    
    private func libraryItemRow(_ item: any LibraryItem) -> some View {
        HStack(spacing: 12) {
            // プレビュー画像
            if let thumbnailImage = item.thumbnailImage {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
            } else {
                Image(systemName: getCategoryIcon(for: item))
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
            }
            
            // アイテム情報
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                
                Text(item.category.rawValue)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // 追加ボタン
            Image(systemName: "plus.circle")
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - ヘルパーメソッド
    
    /// カテゴリに応じたアイコンを取得
    private func getCategoryIcon(for item: any LibraryItem) -> String {
        switch item.category {
        case .templates:
            return "doc.on.doc"
        case .shapes:
            return "square.on.circle"
        case .textStyles:
            return "textformat"
        case .backgrounds:
            return "photo.fill"
        case .effects:
            return "sparkles"
        }
    }
    
    /// ライブラリアイテム選択処理
    private func handleItemSelection(_ item: any LibraryItem) {
        // テンプレートの場合は確認ダイアログを表示
        if let templateItem = item as? TemplateItem {
            selectedTemplate = templateItem
            isShowingTemplateConfirmation = true
        } else {
            // その他のアイテムはそのまま適用
            viewModel.onItemSelected(item)
        }
    }
}

/// プレビュー
struct ElementLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        ElementLibraryView(viewModel: LibraryViewModel())
            .previewLayout(.sizeThatFits)
            .frame(height: 500)
            .padding()
    }
}
