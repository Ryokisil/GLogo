//
//  ElementCategoryView.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはライブラリ内の要素カテゴリを表示・選択するためのビューコンポーネントです。
//  テンプレート、図形、テキストスタイル、背景、エフェクトなどの各カテゴリをアイコンと
//  テキストで表示し、ユーザーが選択できるようにします。
//  ElementLibraryViewのサブコンポーネントとして使用され、LibraryViewModelと連携して
//  選択カテゴリの状態を管理します。
//

import SwiftUI

/// 要素カテゴリビュー - ライブラリカテゴリの表示と選択
struct ElementCategoryView: View {
    /// ライブラリビューモデル
    @ObservedObject var viewModel: LibraryViewModel
    
    /// 表示モード
    enum DisplayMode {
        case horizontal  // 水平スクロール
        case vertical    // 垂直リスト
        case grid        // グリッド
    }
    
    /// 表示モード
    var displayMode: DisplayMode = .horizontal
    
    /// カテゴリアイテムサイズ
    private let itemSize: CGFloat = 80
    
    /// 水平モードの場合の高さ
    private let horizontalHeight: CGFloat = 60
    
    var body: some View {
        Group {
            switch displayMode {
            case .horizontal:
                horizontalCategoryView
            case .vertical:
                verticalCategoryView
            case .grid:
                gridCategoryView
            }
        }
        .animation(.spring(), value: viewModel.selectedCategory)
    }
    
    // MARK: - 水平カテゴリビュー
    
    private var horizontalCategoryView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(LibraryCategory.allCases) { category in
                    categoryButton(for: category)
                }
            }
            .padding(.horizontal)
            .frame(height: horizontalHeight)
        }
        .background(Color(UIColor.systemBackground).opacity(0.8))
    }
    
    // MARK: - 垂直カテゴリビュー
    
    private var verticalCategoryView: some View {
        VStack(spacing: 8) {
            ForEach(LibraryCategory.allCases) { category in
                categoryButton(for: category, isVertical: true)
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - グリッドカテゴリビュー
    
    private var gridCategoryView: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: itemSize, maximum: itemSize), spacing: 12)
        ], spacing: 12) {
            ForEach(LibraryCategory.allCases) { category in
                categoryGridItem(for: category)
            }
        }
        .padding()
    }
    
    // MARK: - カテゴリボタン（水平・垂直共通）
    
    private func categoryButton(for category: LibraryCategory, isVertical: Bool = false) -> some View {
        Button(action: {
            viewModel.onCategorySelected(category)
        }) {
            HStack {
                Image(systemName: category.iconName)
                    .font(.headline)
                    .foregroundColor(viewModel.selectedCategory == category ? .white : .primary)
                
                Text(category.rawValue)
                    .font(isVertical ? .body : .subheadline)
                    .foregroundColor(viewModel.selectedCategory == category ? .white : .primary)
                
                if isVertical {
                    Spacer()
                    
                    if viewModel.selectedCategory == category {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(viewModel.selectedCategory == category ? Color.blue : Color.gray.opacity(0.1))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - カテゴリグリッドアイテム
    
    private func categoryGridItem(for category: LibraryCategory) -> some View {
        Button(action: {
            viewModel.onCategorySelected(category)
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(viewModel.selectedCategory == category ? Color.blue : Color.gray.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: category.iconName)
                        .font(.title2)
                        .foregroundColor(viewModel.selectedCategory == category ? .white : .primary)
                }
                
                Text(category.rawValue)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(width: itemSize, height: itemSize)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(viewModel.selectedCategory == category ? Color.blue : Color.clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// カテゴリインジケータービュー - 現在選択されているカテゴリを表示
struct CategoryIndicatorView: View {
    /// 選択されているカテゴリ
    let selectedCategory: LibraryCategory
    
    var body: some View {
        HStack {
            Image(systemName: selectedCategory.iconName)
                .foregroundColor(.blue)
            
            Text(selectedCategory.rawValue)
                .font(.headline)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
}

/// プレビュー
struct ElementCategoryView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 水平モード
            VStack {
                Text("水平モード").font(.headline)
                ElementCategoryView(viewModel: LibraryViewModel(), displayMode: .horizontal)
            }
            .previewLayout(.sizeThatFits)
            .padding(.vertical)
            
            // 垂直モード
            HStack {
                Text("垂直モード").font(.headline)
                ElementCategoryView(viewModel: LibraryViewModel(), displayMode: .vertical)
                    .frame(width: 200)
            }
            .previewLayout(.sizeThatFits)
            .padding()
            
            // グリッドモード
            VStack {
                Text("グリッドモード").font(.headline)
                ElementCategoryView(viewModel: LibraryViewModel(), displayMode: .grid)
            }
            .previewLayout(.sizeThatFits)
            .padding()
        }
    }
}
