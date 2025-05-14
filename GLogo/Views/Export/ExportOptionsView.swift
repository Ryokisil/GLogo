////
////  ExportOptionsView.swift
////  GameLogoMaker
////
////  概要:
////  このファイルはエクスポート設定の詳細オプションを提供するSwiftUIビューです。
////  ExportViewのサブコンポーネントとして機能し、サイズプリセットの選択、
////  カスタムサイズの指定、エクスポート形式固有の設定（JPEG品質、透明背景など）を
////  編集するためのUIコントロールを提供します。
////  ExportViewModelと連携して、設定の変更を即座に反映します。
////
//
//import SwiftUI
//
///// エクスポート設定オプションビュー
//struct ExportOptionsView: View {
//    /// エクスポートビューモデル
//    @ObservedObject var viewModel: ExportViewModel
//    
//    /// 幅入力の一時保存用
//    @State private var widthText: String = ""
//    
//    /// 高さ入力の一時保存用
//    @State private var heightText: String = ""
//    
//    /// 初期化
//    init(viewModel: ExportViewModel) {
//        self.viewModel = viewModel
//        _widthText = State(initialValue: "\(Int(viewModel.customWidth))")
//        _heightText = State(initialValue: "\(Int(viewModel.customHeight))")
//    }
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 16) {
//            // エクスポート形式
//            formatSection
//            
//            // サイズ設定
//            sizeSection
//            
//            // 形式に応じた特別な設定
//            if viewModel.exportFormat == .jpg {
//                jpegQualitySection
//            } else {
//                transparencySection
//            }
//        }
//        .padding()
//        .background(Color(UIColor.secondarySystemBackground))
//        .cornerRadius(10)
//    }
//    
//    // MARK: - フォーマットセクション
//    
//    private var formatSection: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            Text("エクスポート形式")
//                .font(.headline)
//            
//            Picker("", selection: $viewModel.exportFormat) {
//                ForEach(ExportFormat.allCases) { format in
//                    Text(format.rawValue).tag(format)
//                }
//            }
//            .pickerStyle(SegmentedPickerStyle())
//        }
//    }
//    
//    // MARK: - サイズセクション
//    
//    private var sizeSection: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            Text("サイズ")
//                .font(.headline)
//            
//            // サイズプリセット選択
//            Picker("プリセット", selection: $viewModel.sizePreset) {
//                ForEach(ExportSizePreset.allCases) { preset in
//                    Text(preset.rawValue).tag(preset)
//                }
//            }
//            .pickerStyle(MenuPickerStyle())
//            
//            // カスタムサイズの入力（カスタムプリセット選択時のみ表示）
//            if viewModel.sizePreset == .custom {
//                HStack {
//                    // 幅の入力
//                    VStack(alignment: .leading) {
//                        Text("幅:")
//                        
//                        HStack {
//                            TextField("幅", text: $widthText)
//                                .keyboardType(.numberPad)
//                                .textFieldStyle(RoundedBorderTextFieldStyle())
//                                .onChange(of: widthText) { newValue in
//                                    if let width = Int(newValue) {
//                                        viewModel.updateWidthKeepingAspectRatio(CGFloat(width))
//                                        heightText = "\(Int(viewModel.customHeight))"
//                                    }
//                                }
//                            
//                            Text("px")
//                        }
//                    }
//                    
//                    Spacer()
//                    
//                    Text("×")
//                    
//                    Spacer()
//                    
//                    // 高さの入力
//                    VStack(alignment: .leading) {
//                        Text("高さ:")
//                        
//                        HStack {
//                            TextField("高さ", text: $heightText)
//                                .keyboardType(.numberPad)
//                                .textFieldStyle(RoundedBorderTextFieldStyle())
//                                .onChange(of: heightText) { newValue in
//                                    if let height = Int(newValue) {
//                                        viewModel.updateHeightKeepingAspectRatio(CGFloat(height))
//                                        widthText = "\(Int(viewModel.customWidth))"
//                                    }
//                                }
//                            
//                            Text("px")
//                        }
//                    }
//                }
//            }
//            
//            // エクスポートサイズの表示
//            Text("出力サイズ: \(Int(viewModel.exportSize.width)) × \(Int(viewModel.exportSize.height)) px")
//                .font(.caption)
//                .foregroundColor(.secondary)
//        }
//    }
//    
//    // MARK: - JPEG品質セクション
//    
//    private var jpegQualitySection: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            Text("JPEG品質")
//                .font(.headline)
//            
//            HStack {
//                Text("低")
//                
//                Slider(
//                    value: $viewModel.jpegQuality,
//                    in: 0.1...1.0,
//                    step: 0.05
//                )
//                
//                Text("高")
//            }
//            
//            Text("\(Int(viewModel.jpegQuality * 100))%")
//                .font(.caption)
//                .frame(maxWidth: .infinity, alignment: .trailing)
//                .foregroundColor(.secondary)
//        }
//    }
//    
//    // MARK: - 透明度セクション
//    
//    private var transparencySection: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            Text("透明度")
//                .font(.headline)
//            
//            Toggle("透明背景", isOn: $viewModel.transparentBackground)
//                .toggleStyle(SwitchToggleStyle(tint: .blue))
//            
//            Text("透明背景を有効にすると、背景が透明なPNG画像が生成されます。")
//                .font(.caption)
//                .foregroundColor(.secondary)
//        }
//    }
//}
