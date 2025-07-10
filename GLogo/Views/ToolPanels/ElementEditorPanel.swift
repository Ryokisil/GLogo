//
//  ElementEditorPanel.swift
//  GameLogoMaker
//
//  概要:
//  このファイルは選択された要素の編集パネルのコンテナビューを実装しています。
//  選択された要素の種類（テキスト、図形、画像）に応じて、適切な編集パネル
//  （TextEditorPanel、ShapeEditorPanel、ImageEditorPanel）を表示します。
//  ToolPanelViewから呼び出され、ElementViewModelと連携して要素の編集機能を提供します。
//

import SwiftUI

/// 要素編集パネル - 選択された要素の種類に応じたエディタパネルを表示
struct ElementEditorPanel: View {
    /// 要素編集ビューモデル
    @ObservedObject var viewModel: ElementViewModel
    
    /// 表示タブ
    @State private var selectedTab: EditorTab = .properties
    
    /// エディタタブ
    enum EditorTab: String, CaseIterable {
        case properties = "プロパティ"
        case effects = "エフェクト"
        case transform = "変形"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // タブセレクタ
            tabSelector
            
            // 要素タイプに応じたエディタパネル
            if let elementType = viewModel.elementType {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if selectedTab == .properties {
                            // プロパティタブの内容
                            propertiesTabContent(for: elementType)
                        } else if selectedTab == .effects {
                            // エフェクトタブの内容
                            effectsTabContent(for: elementType)
                        } else if selectedTab == .transform {
                            // 変形タブの内容
                            transformTabContent
                        }
                    }
                    .padding()
                }
            } else {
                // 要素が選択されていない場合（エラー状態）
                noElementSelectedView
            }
        }
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - タブセレクタ
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(EditorTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    Text(tab.rawValue)
                        .font(.subheadline)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(selectedTab == tab ? Color(UIColor.secondarySystemBackground) : Color.clear)
                        .foregroundColor(selectedTab == tab ? .primary : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color(UIColor.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.3)),
            alignment: .bottom
        )
    }
    
    // MARK: - プロパティタブ
    
    /// 要素タイプに応じたプロパティタブの内容を返す
    private func propertiesTabContent(for elementType: LogoElementType) -> some View {
        Group {
            switch elementType {
            case .text:
                textPropertiesContent
            case .shape:
                shapePropertiesContent
            case .image:
                imagePropertiesContent
            }
        }
    }
    
    /// テキスト要素のプロパティ
    private var textPropertiesContent: some View {
        Group {
            if let textElement = viewModel.textElement {
                // テキスト内容編集
                VStack(alignment: .leading, spacing: 8) {
                    Text("テキスト")
                        .font(.headline)
                    
                    TextEditor(text: Binding(
                        get: { textElement.text },
                        set: { viewModel.updateText($0) }
                    ))
                    .frame(minHeight: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                
                Divider()
                
                // フォント設定
                VStack(alignment: .leading, spacing: 8) {
                    Text("フォント")
                        .font(.headline)
                    
                    HStack {
                        Text(textElement.fontName)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                        
                        // フォントサイズ調整
                        Stepper(
                            value: Binding(
                                get: { Int(textElement.fontSize) },
                                set: { viewModel.updateFont(name: textElement.fontName, size: CGFloat($0)) }
                            ),
                            in: 8...100
                        ) {
                            Text("\(Int(textElement.fontSize))pt")
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }
                
                Divider()
                
                // テキスト色と整列
                VStack(alignment: .leading, spacing: 8) {
                    Text("色と整列")
                        .font(.headline)
                    
                    // カラーピッカー
                    ColorPicker("テキスト色:", selection: Binding(
                        get: { Color(textElement.textColor) },
                        set: { viewModel.updateTextColor(UIColor($0)) }
                    ))
                    
                    // 整列ボタン
                    HStack {
                        Text("整列:")
                        Spacer()
                        
                        ForEach([TextAlignment.left, .center, .right], id: \.self) { alignment in
                            Button(action: {
                                viewModel.updateTextAlignment(alignment)
                            }) {
                                Image(systemName: alignmentIconName(for: alignment))
                                    .foregroundColor(textElement.alignment == alignment ? .blue : .gray)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(textElement.alignment == alignment ? Color.blue.opacity(0.1) : Color.clear)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
    }
    
    /// 図形要素のプロパティ
    private var shapePropertiesContent: some View {
        Group {
            if let shapeElement = viewModel.shapeElement {
                // 図形タイプ
                VStack(alignment: .leading, spacing: 8) {
                    Text("図形タイプ")
                        .font(.headline)
                    
                    Picker("", selection: Binding(
                        get: { shapeElement.shapeType },
                        set: { viewModel.updateShapeType($0) }
                    )) {
                        Text("四角形").tag(ShapeType.rectangle)
                        Text("角丸四角形").tag(ShapeType.roundedRectangle)
                        Text("円").tag(ShapeType.circle)
                        Text("楕円").tag(ShapeType.ellipse)
                        Text("三角形").tag(ShapeType.triangle)
                        Text("星").tag(ShapeType.star)
                        Text("多角形").tag(ShapeType.polygon)
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Divider()
                
                // 特定図形のプロパティ
                Group {
                    switch shapeElement.shapeType {
                    case .roundedRectangle:
                        // 角丸半径
                        VStack(alignment: .leading, spacing: 8) {
                            Text("角丸半径:")
                                .font(.subheadline)
                            
                            Slider(value: Binding(
                                get: { shapeElement.cornerRadius },
                                set: { viewModel.updateCornerRadius($0) }
                            ), in: 0...50)
                            
                            Text("\(Int(shapeElement.cornerRadius))")
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .font(.caption)
                        }
                        
                    case .star, .polygon:
                        // 頂点数
                        VStack(alignment: .leading, spacing: 8) {
                            Text("頂点数:")
                                .font(.subheadline)
                            
                            Stepper(value: Binding(
                                get: { shapeElement.sides },
                                set: { viewModel.updateSides($0) }
                            ), in: 3...12) {
                                Text("\(shapeElement.sides)")
                            }
                        }
                        
                    default:
                        EmptyView()
                    }
                }
                
                Divider()
                
                // 塗りつぶし設定
                VStack(alignment: .leading, spacing: 8) {
                    Text("塗りつぶし")
                        .font(.headline)
                    
                    Picker("", selection: Binding(
                        get: { shapeElement.fillMode },
                        set: { viewModel.updateFillMode($0) }
                    )) {
                        Text("なし").tag(FillMode.none)
                        Text("単色").tag(FillMode.solid)
                        Text("グラデーション").tag(FillMode.gradient)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if shapeElement.fillMode == .solid {
                        // 単色設定
                        ColorPicker("色:", selection: Binding(
                            get: { Color(shapeElement.fillColor) },
                            set: { viewModel.updateFillColor(UIColor($0)) }
                        ))
                    } else if shapeElement.fillMode == .gradient {
                        // グラデーション設定
                        VStack(alignment: .leading, spacing: 8) {
                            ColorPicker("開始色:", selection: Binding(
                                get: { Color(shapeElement.gradientStartColor) },
                                set: { viewModel.updateGradientColors(startColor: UIColor($0), endColor: shapeElement.gradientEndColor) }
                            ))
                            
                            ColorPicker("終了色:", selection: Binding(
                                get: { Color(shapeElement.gradientEndColor) },
                                set: { viewModel.updateGradientColors(startColor: shapeElement.gradientStartColor, endColor: UIColor($0)) }
                            ))
                        }
                    }
                }
                
                Divider()
                
                // 枠線設定
                VStack(alignment: .leading, spacing: 8) {
                    Text("枠線")
                        .font(.headline)
                    
                    Picker("", selection: Binding(
                        get: { shapeElement.strokeMode },
                        set: { viewModel.updateStrokeMode($0) }
                    )) {
                        Text("なし").tag(StrokeMode.none)
                        Text("あり").tag(StrokeMode.solid)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if shapeElement.strokeMode == .solid {
                        ColorPicker("色:", selection: Binding(
                            get: { Color(shapeElement.strokeColor) },
                            set: { viewModel.updateStrokeColor(UIColor($0)) }
                        ))
                        
                        HStack {
                            Text("太さ:")
                            Slider(value: Binding(
                                get: { shapeElement.strokeWidth },
                                set: { viewModel.updateStrokeWidth($0) }
                            ), in: 0.5...20, step: 0.5)
                            Text("\(shapeElement.strokeWidth, specifier: "%.1f")")
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }
    
    /// 画像要素のプロパティ
    private var imagePropertiesContent: some View {
        Group {
            if let imageElement = viewModel.imageElement {
                // 画像プレビュー
                if let image = imageElement.image {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("プレビュー")
                            .font(.headline)
                        
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 100)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    Divider()
                }
                
                // フィッティングモード
                VStack(alignment: .leading, spacing: 8) {
                    Text("フィッティング")
                        .font(.headline)
                    
                    Picker("", selection: Binding(
                        get: { imageElement.fitMode },
                        set: { viewModel.updateFitMode($0) }
                    )) {
                        Text("Fill").tag(ImageFitMode.fill)
                        Text("Aspect Fit").tag(ImageFitMode.aspectFit)
                        Text("Aspect Fill").tag(ImageFitMode.aspectFill)
                        Text("Center").tag(ImageFitMode.center)
                        Text("Tile").tag(ImageFitMode.tile)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Divider()
                
                // 色調補正
//                VStack(alignment: .leading, spacing: 8) {
//                    Text("色調補正")
//                        .font(.headline)
//                    
//                    HStack {
//                        Text("彩度:")
//                        Slider(value: Binding(
//                            get: { imageElement.saturationAdjustment },
//                            set: { viewModel.updateSaturation($0) }
//                        ), in: 0...2, step: 0.01)
//                        Text("\(imageElement.saturationAdjustment, specifier: "%.2f")")
//                            .frame(width: 40, alignment: .trailing)
//                    }
//                    
//                    HStack {
//                        Text("明度:")
//                        Slider(value: Binding(
//                            get: { imageElement.brightnessAdjustment },
//                            set: { viewModel.updateBrightness($0) }
//                        ), in: -1...1, step: 0.01)
//                        Text("\(imageElement.brightnessAdjustment, specifier: "%.2f")")
//                            .frame(width: 40, alignment: .trailing)
//                    }
//                    
//                    HStack {
//                        Text("コントラスト:")
//                        Slider(value: Binding(
//                            get: { imageElement.contrastAdjustment },
//                            set: { viewModel.updateContrast($0) }
//                        ), in: 0.5...1.5, step: 0.01)
//                        Text("\(imageElement.contrastAdjustment, specifier: "%.2f")")
//                            .frame(width: 40, alignment: .trailing)
//                    }
//                }
            }
        }
    }
    
    // MARK: - エフェクトタブ
    
    /// 要素タイプに応じたエフェクトタブの内容を返す
    private func effectsTabContent(for elementType: LogoElementType) -> some View {
        Group {
            switch elementType {
            case .text:
                textEffectsContent
            case .shape:
                // 図形エフェクトは現在未実装
                Text("図形エフェクトは現在開発中です。")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            case .image:
                imageEffectsContent
            }
        }
    }
    
    /// テキスト要素のエフェクト
    private var textEffectsContent: some View {
        Group {
            if let textElement = viewModel.textElement {
                // シャドウエフェクト
                if let shadowIndex = textElement.effects.firstIndex(where: { $0.type == .shadow }),
                   let shadowEffect = textElement.effects[shadowIndex] as? ShadowEffect {
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("シャドウ")
                                .font(.headline)
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { shadowEffect.isEnabled },
                                set: { viewModel.updateTextEffect(atIndex: shadowIndex, isEnabled: $0) }
                            ))
                            .labelsHidden()
                        }
                        
                        if shadowEffect.isEnabled {
                            // シャドウ色
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
                            
                            // シャドウぼかし
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
                            
                            // シャドウオフセット
                            Text("オフセット:")
                                .font(.subheadline)
                            
                            // X方向
                            HStack {
                                Text("X:")
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
                            
                            // Y方向
                            HStack {
                                Text("Y:")
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
                    }
                } else {
                    // シャドウエフェクトがない場合、追加ボタンを表示
                    Button(action: {
                        viewModel.addTextEffect(ShadowEffect())
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("シャドウを追加")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // 他のエフェクトタイプの追加も可能
            }
        }
    }
    
    /// 画像要素のエフェクト
    private var imageEffectsContent: some View {
        Group {
            if let imageElement = viewModel.imageElement {
                // カラーフィルター
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("カラーティント")
                            .font(.headline)
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { imageElement.tintColor != nil },
                            set: {
                                viewModel.updateTintColor(
                                    $0 ? (imageElement.tintColor ?? .blue) : nil,
                                    intensity: $0 ? (imageElement.tintIntensity > 0 ? imageElement.tintIntensity : 0.5) : 0
                                )
                            }
                        ))
                        .labelsHidden()
                    }
                    
                    if imageElement.tintColor != nil {
                        // ティント色
                        ColorPicker("色:", selection: Binding(
                            get: { Color(imageElement.tintColor ?? .blue) },
                            set: { viewModel.updateTintColor(UIColor($0), intensity: imageElement.tintIntensity) }
                        ))
                        
                        // ティント強度
                        HStack {
                            Text("強度:")
                            Slider(value: Binding(
                                get: { imageElement.tintIntensity },
                                set: { viewModel.updateTintColor(imageElement.tintColor, intensity: $0) }
                            ), in: 0...1, step: 0.01)
                            Text("\(imageElement.tintIntensity, specifier: "%.2f")")
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
                
                Divider()
                
                // フレーム
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("フレーム")
                            .font(.headline)
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { imageElement.showFrame },
                            set: { viewModel.updateShowFrame($0) }
                        ))
                        .labelsHidden()
                    }
                    
                    if imageElement.showFrame {
                        // フレームの色
                        ColorPicker("色:", selection: Binding(
                            get: { Color(imageElement.frameColor) },
                            set: { viewModel.updateFrameColor(UIColor($0)) }
                        ))
                        
                        // フレームの太さ
                        HStack {
                            Text("太さ:")
                            Slider(value: Binding(
                                get: { imageElement.frameWidth },
                                set: { viewModel.updateFrameWidth($0) }
                            ), in: 1...20, step: 0.5)
                            Text("\(imageElement.frameWidth, specifier: "%.1f")")
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
                
                Divider()
                
                // 角丸
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("角丸")
                            .font(.headline)
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { imageElement.roundedCorners },
                            set: { viewModel.updateRoundedCorners($0, radius: imageElement.cornerRadius) }
                        ))
                        .labelsHidden()
                    }
                    
                    if imageElement.roundedCorners {
                        // 角丸の半径
                        HStack {
                            Text("半径:")
                            Slider(value: Binding(
                                get: { imageElement.cornerRadius },
                                set: { viewModel.updateRoundedCorners(imageElement.roundedCorners, radius: $0) }
                            ), in: 1...50, step: 1)
                            Text("\(Int(imageElement.cornerRadius))")
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 変形タブ
    
    /// 変形タブの内容
    private var transformTabContent: some View {
        Group {
            if let element = viewModel.element {
                // 位置
                VStack(alignment: .leading, spacing: 8) {
                    Text("位置")
                        .font(.headline)
                    
                    HStack {
                        Text("X:")
                        Slider(value: Binding(
                            get: { element.position.x },
                            set: {
                                let newPosition = CGPoint(x: $0, y: element.position.y)
                                viewModel.updatePosition(newPosition)
                            }
                        ), in: 0...1000)
                        Text("\(Int(element.position.x))")
                            .frame(width: 40, alignment: .trailing)
                    }
                    
                    HStack {
                        Text("Y:")
                        Slider(value: Binding(
                            get: { element.position.y },
                            set: {
                                let newPosition = CGPoint(x: element.position.x, y: $0)
                                viewModel.updatePosition(newPosition)
                            }
                        ), in: 0...1000)
                        Text("\(Int(element.position.y))")
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                
                Divider()
                
                // サイズ
                VStack(alignment: .leading, spacing: 8) {
                    Text("サイズ")
                        .font(.headline)
                    
                    HStack {
                        Text("幅:")
                        Slider(value: Binding(
                            get: { element.size.width },
                            set: {
                                let newSize = CGSize(width: max(10, $0), height: element.size.height)
                                viewModel.updateSize(newSize)
                            }
                        ), in: 10...1000)
                        Text("\(Int(element.size.width))")
                            .frame(width: 40, alignment: .trailing)
                    }
                    
                    HStack {
                        Text("高さ:")
                        Slider(value: Binding(
                            get: { element.size.height },
                            set: {
                                let newSize = CGSize(width: element.size.width, height: max(10, $0))
                                viewModel.updateSize(newSize)
                            }
                        ), in: 10...1000)
                        Text("\(Int(element.size.height))")
                            .frame(width: 40, alignment: .trailing)
                    }
                    
                    // アスペクト比を維持するオプションも追加可能
                }
                
                Divider()
                
                // 回転
                VStack(alignment: .leading, spacing: 8) {
                    Text("回転")
                        .font(.headline)
                    
                    HStack {
                        Text("角度:")
                        Slider(value: Binding(
                            get: { element.rotation * 180 / .pi },
                            set: { viewModel.updateRotation($0 * .pi / 180) }
                        ), in: 0...360)
                        Text("\(Int(element.rotation * 180 / .pi))°")
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                
                Divider()
                
                // 不透明度
                VStack(alignment: .leading, spacing: 8) {
                    Text("不透明度")
                        .font(.headline)
                    
                    HStack {
                        Text("不透明度:")
                        Slider(value: Binding(
                            get: { element.opacity },
                            set: { viewModel.updateOpacity($0) }
                        ), in: 0...1)
                        Text("\(Int(element.opacity * 100))%")
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                
                Divider()
                
                // 要素のロックと可視性
                VStack(alignment: .leading, spacing: 8) {
                    Text("その他")
                        .font(.headline)
                    
                    Toggle("表示", isOn: Binding(
                        get: { element.isVisible },
                        set: { viewModel.updateVisibility($0) }
                    ))
                    
                    Toggle("ロック", isOn: Binding(
                        get: { element.isLocked },
                        set: { viewModel.updateLock($0) }
                    ))
                }
            }
        }
    }
    
    // MARK: - 要素未選択ビュー
    
    private var noElementSelectedView: some View {
        VStack {
            Text("要素が選択されていません")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.top, 40)
                .frame(maxWidth: .infinity, alignment: .center)
            
            Text("編集するには要素を選択してください")
                .foregroundColor(.secondary)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - ヘルパーメソッド
    
    /// 整列タイプに応じたアイコン名を返す
    private func alignmentIconName(for alignment: TextAlignment) -> String {
        switch alignment {
        case .left:
            return "text.alignleft"
        case .center:
            return "text.aligncenter"
        case .right:
            return "text.alignright"
        }
    }
}

/// プレビュー
struct ElementEditor_Previews: PreviewProvider {
    static var previews: some View {
        EditorView(viewModel: EditorViewModel())
    }
}
