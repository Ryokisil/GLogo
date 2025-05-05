//
//  TextEditorPanel.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはテキスト要素の編集用パネルを実装するSwiftUIビューです。
//  テキスト内容、フォント、サイズ、色、整列、行間、文字間隔、エフェクトなどの
//  テキスト関連プロパティを編集するためのUIコントロールを提供します。
//  ElementViewModelと連携して、ユーザーの編集操作をモデルに反映します。
//

import SwiftUI

/// テキスト要素編集パネル
struct TextEditorPanel: View {
    /// 要素編集ビューモデル
    @ObservedObject var viewModel: ElementViewModel
    
    /// テキスト要素のショートカット参照
    private var textElement: TextElement? {
        viewModel.textElement
    }
    
    /// テキスト内容の一時保存用
    @State private var textContent: String = ""
    
    /// フォント検索用テキスト
    @State private var fontSearchText: String = ""
    
    /// フォント選択メニューの表示フラグ
    @State private var isShowingFontPicker = false
    
    /// エフェクト編集メニューの表示フラグ
    @State private var isEditingShadow = false
    
    /// 初期化
    init(viewModel: ElementViewModel) {
        self.viewModel = viewModel
        _textContent = State(initialValue: viewModel.textElement?.text ?? "")
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // テキスト内容編集
                textContentSection
                
                Divider()
                
                // フォント設定
                fontSection
                
                Divider()
                
                // テキスト色と整列
                colorAndAlignmentSection
                
                Divider()
                
                // 行間と文字間隔
                spacingSection
                
                Divider()
                
                // テキストエフェクト
                effectsSection
            }
            .padding()
            .sheet(isPresented: $isShowingFontPicker) {
                fontPickerSheet
            }
        }
    }
    
    // MARK: - テキスト内容セクション
    
    private var textContentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("テキスト")
                .font(.headline)
            
            TextEditor(text: $textContent)
                .frame(minHeight: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .onChange(of: textContent) { newValue in
                    viewModel.updateText(newValue)
                }
        }
    }
    
    // MARK: - フォントセクション
    
    private var fontSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("フォント")
                .font(.headline)
            
            // 現在のフォント表示と選択ボタン
            Button(action: {
                isShowingFontPicker = true
            }) {
                HStack {
                    if let fontName = textElement?.fontName {
                        Text(fontName)
                            .font(.custom(fontName, size: 16))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("フォントを選択")
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            }
            
            // フォントサイズ
            HStack {
                Text("サイズ:")
                
                // デクリメントボタン
                Button(action: {
                    if let fontSize = textElement?.fontSize, fontSize > 8 {
                        viewModel.updateFont(name: textElement?.fontName ?? "", size: fontSize - 1)
                    }
                }) {
                    Image(systemName: "minus")
                        .padding(5)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
                
                // フォントサイズ表示
                TextField("サイズ", value: Binding(
                    get: { Int(textElement?.fontSize ?? 36) },
                    set: {
                        if let fontName = textElement?.fontName {
                            viewModel.updateFont(name: fontName, size: CGFloat($0))
                        }
                    }
                ), formatter: NumberFormatter())
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 50)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                
                // インクリメントボタン
                Button(action: {
                    if let fontSize = textElement?.fontSize {
                        viewModel.updateFont(name: textElement?.fontName ?? "", size: fontSize + 1)
                    }
                }) {
                    Image(systemName: "plus")
                        .padding(5)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Text("pt")
            }
        }
    }
    
    // MARK: - フォント選択シート
    
    private var fontPickerSheet: some View {
        NavigationView {
            VStack {
                // 検索フィールド
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("フォントを検索", text: $fontSearchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding()
                
                // フォントリスト
                List {
                    ForEach(filteredFontNames, id: \.self) { fontName in
                        Button(action: {
                            if let fontSize = textElement?.fontSize {
                                viewModel.updateFont(name: fontName, size: fontSize)
                            }
                            isShowingFontPicker = false
                        }) {
                            HStack {
                                Text(fontName)
                                    .font(.custom(fontName, size: 16))
                                
                                Spacer()
                                
                                // 現在選択中のフォントにチェックマーク
                                if fontName == textElement?.fontName {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("フォントを選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("キャンセル") {
                        isShowingFontPicker = false
                    }
                }
            }
        }
    }
    
    // 検索フィルタリングされたフォント名
    private var filteredFontNames: [String] {
        let fontNames = UIFont.familyNames.flatMap { family -> [String] in
            UIFont.fontNames(forFamilyName: family)
        }.sorted()
        
        if fontSearchText.isEmpty {
            return fontNames
        } else {
            return fontNames.filter { $0.lowercased().contains(fontSearchText.lowercased()) }
        }
    }
    
    // MARK: - テキスト色と整列セクション
    
    private var colorAndAlignmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("色と整列")
                .font(.headline)
            
            // テキスト要素の色とカラーピッカーを双方向バインディングで接続
            ColorPicker("テキスト色:", selection: Binding(
                get: { Color(textElement?.textColor ?? .white) }, // UIColorからSwiftUI Colorに変換、nilの場合は白色
                set: { viewModel.updateTextColor(UIColor($0)) }   // ユーザー選択色をViewModelに通知
            ))
            
            // テキスト整列
            HStack {
                Text("整列:")
                Spacer()
                
                Picker("", selection: Binding(
                    get: { textElement?.alignment ?? .center },
                    set: { viewModel.updateTextAlignment($0) }
                )) {
                    Image(systemName: "text.alignleft").tag(TextAlignment.left)
                    Image(systemName: "text.aligncenter").tag(TextAlignment.center)
                    Image(systemName: "text.alignright").tag(TextAlignment.right)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 180)
            }
        }
    }
    
    // MARK: - 行間と文字間隔セクション
    
    private var spacingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("間隔")
                .font(.headline)
            
            // 行間
            HStack {
                Text("行間:")
                Slider(value: Binding(
                    get: { textElement?.lineSpacing ?? 1.0 },
                    set: { viewModel.updateLineSpacing($0) }
                ), in: 0...10, step: 0.1)
                Text("\(textElement?.lineSpacing ?? 1.0, specifier: "%.1f")")
                    .frame(width: 30, alignment: .trailing)
            }
            
            // 文字間隔
            HStack {
                Text("文字間隔:")
                Slider(value: Binding(
                    get: { textElement?.letterSpacing ?? 0 },
                    set: { viewModel.updateLetterSpacing($0) }
                ), in: -5...10, step: 0.1)
                Text("\(textElement?.letterSpacing ?? 0, specifier: "%.1f")")
                    .frame(width: 30, alignment: .trailing)
            }
        }
    }
    
    // MARK: - テキストエフェクトセクション
    
    private var effectsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("エフェクト")
                .font(.headline)
            
            // シャドウエフェクト
            if let textElement = textElement, let shadowIndex = textElement.effects.firstIndex(where: { $0.type == .shadow }) {
                let shadowEffect = textElement.effects[shadowIndex] as? ShadowEffect
                
                VStack {
                    HStack {
                        Toggle("シャドウ", isOn: Binding(
                            get: { shadowEffect?.isEnabled ?? false },
                            set: { viewModel.updateTextEffect(atIndex: shadowIndex, isEnabled: $0) }
                        ))
                        
                        Spacer()
                        
                        // 詳細設定の表示切替ボタン
                        Button(action: {
                            isEditingShadow.toggle()
                        }) {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // シャドウの詳細設定（展開時のみ表示）
                    if isEditingShadow, let shadowEffect = shadowEffect, shadowEffect.isEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            // シャドウカラー
                            ColorPicker("色:", selection: Binding(
                                get: { Color(shadowEffect.color) },
                                set: {
                                    viewModel.updateShadowEffect(
                                        atIndex: shadowIndex,
                                        color: UIColor($0),
                                        offset: shadowEffect.offset,
                                        blurRadius: shadowEffect.blurRadius
                                    )
                                }
                            ))
                            
                            // ぼかし半径
                            HStack {
                                Text("ぼかし:")
                                Slider(value: Binding(
                                    get: { shadowEffect.blurRadius },
                                    set: {
                                        viewModel.updateShadowEffect(
                                            atIndex: shadowIndex,
                                            color: shadowEffect.color,
                                            offset: shadowEffect.offset,
                                            blurRadius: $0
                                        )
                                    }
                                ), in: 0...20, step: 0.5)
                                Text("\(shadowEffect.blurRadius, specifier: "%.1f")")
                                    .frame(width: 30, alignment: .trailing)
                            }
                            
                            // オフセットX
                            HStack {
                                Text("X オフセット:")
                                Slider(value: Binding(
                                    get: { shadowEffect.offset.width },
                                    set: {
                                        let newOffset = CGSize(width: $0, height: shadowEffect.offset.height)
                                        viewModel.updateShadowEffect(
                                            atIndex: shadowIndex,
                                            color: shadowEffect.color,
                                            offset: newOffset,
                                            blurRadius: shadowEffect.blurRadius
                                        )
                                    }
                                ), in: -20...20, step: 0.5)
                                Text("\(shadowEffect.offset.width, specifier: "%.1f")")
                                    .frame(width: 30, alignment: .trailing)
                            }
                            
                            // オフセットY
                            HStack {
                                Text("Y オフセット:")
                                Slider(value: Binding(
                                    get: { shadowEffect.offset.height },
                                    set: {
                                        let newOffset = CGSize(width: shadowEffect.offset.width, height: $0)
                                        viewModel.updateShadowEffect(
                                            atIndex: shadowIndex,
                                            color: shadowEffect.color,
                                            offset: newOffset,
                                            blurRadius: shadowEffect.blurRadius
                                        )
                                    }
                                ), in: -20...20, step: 0.5)
                                Text("\(shadowEffect.offset.height, specifier: "%.1f")")
                                    .frame(width: 30, alignment: .trailing)
                            }
                        }
                        .padding(.leading, 10)
                    }
                }
            } else {
                // シャドウエフェクトがない場合は追加ボタンを表示
                Button(action: {
                    viewModel.addTextEffect(ShadowEffect())
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("シャドウを追加")
                    }
                }
            }
            
            // 他のエフェクトタイプも同様に実装可能
            // （グロー、アウトライン、グラデーションなど）
        }
    }
}

/// プレビュー
//struct TextEditorPanel_Previews: PreviewProvider {
//    static var previews: some View {
//        // エディタビューモデルを作成
//        let editorViewModel = EditorViewModel()
//        
//        // TextElementを追加
//        let textElement = TextElement(text: "サンプルテキスト")
//        editorViewModel.addElement(textElement)
//        
//        // 要素を選択
//        editorViewModel.selectElement(at: CGPoint(x: 0, y: 0))
//        
//        // 要素編集ビューモデルを作成
//        let elementViewModel = ElementViewModel(editorViewModel: editorViewModel)
//        
//        // プレビューを返す
//        TextEditorPanel(viewModel: elementViewModel)
//            .frame(width: 300)
//            .previewLayout(.sizeThatFits)
//    }
//}
