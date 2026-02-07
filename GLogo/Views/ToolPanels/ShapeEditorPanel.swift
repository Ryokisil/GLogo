//
//  ShapeEditorPanel.swift
//  GameLogoMaker
//
//  概要:
//  このファイルは図形要素の編集用パネルを実装するSwiftUIビューです。
//  図形タイプの選択、サイズ、色、塗りつぶし設定、枠線設定、角丸の半径、
//  多角形の辺の数など、図形関連プロパティを編集するためのUIコントロールを提供します。
//  ElementViewModelと連携して、ユーザーの編集操作をモデルに反映します。
//

import SwiftUI

/// 図形要素編集パネル
struct ShapeEditorPanel: View {
    /// 要素編集ビューモデル
    @ObservedObject var viewModel: ElementViewModel
    
    /// 図形要素のショートカット参照
    private var shapeElement: ShapeElement? {
        viewModel.shapeElement
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 図形タイプ選択
                shapeTypeSection
                
                // 図形固有のプロパティ
                if let shapeElement = shapeElement {
                    // 特定の図形タイプによって変わるプロパティ
                    Group {
                        switch shapeElement.shapeType {
                        case .rectangle:
                            EmptyView() // 四角形は特別なプロパティがない
                            
                        case .roundedRectangle:
                            // 角丸設定
                            cornerRadiusSection
                            
                        case .circle:
                            EmptyView() // 円は特別なプロパティがない
                            
                        case .ellipse:
                            EmptyView() // 楕円は特別なプロパティがない
                            
                        case .triangle:
                            EmptyView() // 三角形は特別なプロパティがない
                            
                        case .star, .polygon:
                            // 多角形/星の頂点数
                            sidesSection
                            
                        case .custom:
                            // カスタム図形（サポート外）
                            Text("カスタム図形の編集はこのパネルではサポートされていません。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // 塗りつぶし設定
                    fillSection
                    
                    Divider()
                    
                    // 枠線設定
                    strokeSection
                }
            }
            .padding()
        }
    }
    
    // MARK: - 図形タイプセクション
    
    private var shapeTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("図形タイプ")
                .font(.headline)
            
            Picker("図形タイプ", selection: Binding(
                get: { shapeElement?.shapeType ?? .rectangle },
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
    }
    
    // MARK: - 角丸設定セクション
    
    private var cornerRadiusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("角丸")
                .font(.headline)
            
            HStack {
                Text("半径:")
                Slider(value: Binding(
                    get: { shapeElement?.cornerRadius ?? 10 },
                    set: { viewModel.updateShapeCornerRadius($0) }
                ), in: 0...50, step: 1)
                Text("\(Int(shapeElement?.cornerRadius ?? 0))")
                    .frame(width: 30, alignment: .trailing)
            }
        }
    }
    
    // MARK: - 多角形/星の頂点数セクション
    
    private var sidesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("頂点")
                .font(.headline)
            
            Stepper(value: Binding(
                get: { shapeElement?.sides ?? 5 },
                set: { viewModel.updateSides($0) }
            ), in: 3...12) {
                Text("頂点数: \(shapeElement?.sides ?? 5)")
            }
        }
    }
    
    // MARK: - 塗りつぶしセクション
    
    private var fillSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("塗りつぶし")
                .font(.headline)
            
            // 塗りつぶしモード
            Picker("", selection: Binding(
                get: { shapeElement?.fillMode ?? .solid },
                set: { viewModel.updateFillMode($0) }
            )) {
                Text("なし").tag(FillMode.none)
                Text("単色").tag(FillMode.solid)
                Text("グラデーション").tag(FillMode.gradient)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // 塗りつぶしモードによって変わる設定
            if let shapeElement = shapeElement {
                switch shapeElement.fillMode {
                case .none:
                    Text("塗りつぶしなし")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                case .solid:
                    // 単色設定
                    ColorPicker("色:", selection: Binding(
                        get: { Color(shapeElement.fillColor) },
                        set: { viewModel.updateFillColor(UIColor($0)) }
                    ))
                    
                case .gradient:
                    // グラデーション設定
                    ColorPicker("開始色:", selection: Binding(
                        get: { Color(shapeElement.gradientStartColor) },
                        set: {
                            viewModel.updateGradientColors(
                                startColor: UIColor($0),
                                endColor: shapeElement.gradientEndColor
                            )
                        }
                    ))
                    
                    ColorPicker("終了色:", selection: Binding(
                        get: { Color(shapeElement.gradientEndColor) },
                        set: {
                            viewModel.updateGradientColors(
                                startColor: shapeElement.gradientStartColor,
                                endColor: UIColor($0)
                            )
                        }
                    ))
                    
                    // グラデーション角度
                    HStack {
                        Text("角度:")
                        Slider(value: Binding(
                            get: { shapeElement.gradientAngle },
                            set: { viewModel.updateGradientAngle($0) }
                        ), in: 0...360, step: 1)
                        Text("\(Int(shapeElement.gradientAngle))°")
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
    }
    
    // MARK: - 枠線セクション
    
    private var strokeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("枠線")
                .font(.headline)
            
            // 枠線モード
            Picker("", selection: Binding(
                get: { shapeElement?.strokeMode ?? .none },
                set: { viewModel.updateStrokeMode($0) }
            )) {
                Text("なし").tag(StrokeMode.none)
                Text("あり").tag(StrokeMode.solid)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // 枠線が有効な場合の設定
            if let shapeElement = shapeElement, shapeElement.strokeMode == .solid {
                // 枠線色
                ColorPicker("色:", selection: Binding(
                    get: { Color(shapeElement.strokeColor) },
                    set: { viewModel.updateStrokeColor(UIColor($0)) }
                ))
                
                // 枠線太さ
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

/// プレビュー
//struct ShapeEditorPanel_Previews: PreviewProvider {
//    static var previews: some View {
//        // エディタビューモデルを作成
//        let editorViewModel = EditorViewModel()
//        
//        // ShapeElementを追加
//        let shapeElement = ShapeElement(shapeType: .rectangle)
//        shapeElement.size = CGSize(width: 100, height: 100)
//        editorViewModel.addElement(shapeElement)
//        
//        // 要素を選択
//        editorViewModel.selectElement(at: CGPoint(x: 0, y: 0))
//        
//        // 要素編集ビューモデルを作成
//        let elementViewModel = ElementViewModel(editorViewModel: editorViewModel)
//        
//        // プレビューを返す
//        ShapeEditorPanel(viewModel: elementViewModel)
//            .frame(width: 300)
//            .previewLayout(.sizeThatFits)
//    }
//}
