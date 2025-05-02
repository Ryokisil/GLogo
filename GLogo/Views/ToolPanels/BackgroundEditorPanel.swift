//
//  BackgroundEditorPanel.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはプロジェクトの背景設定を編集するためのパネルを実装するSwiftUIビューです。
//  背景タイプ（単色、グラデーション、画像、透明）の選択や、色、グラデーション方向、
//  不透明度などのプロパティを編集するためのUIコントロールを提供します。
//  EditorViewModelと連携して、ユーザーの背景設定をプロジェクトに反映します。
//

import SwiftUI

/// 背景編集パネル
struct BackgroundEditorPanel: View {
    /// エディタビューモデル
    @ObservedObject var viewModel: EditorViewModel
    
    /// 現在の背景設定の一時保存用
    @State private var backgroundSettings: BackgroundSettings
    
    /// 背景画像選択シートの表示フラグ
    @State private var isShowingImagePicker = false
    
    /// 初期化
    init(viewModel: EditorViewModel) {
        self.viewModel = viewModel
        _backgroundSettings = State(initialValue: viewModel.project.backgroundSettings)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // セクションタイトル
                Text("背景設定")
                    .font(.headline)
                
                // 背景タイプ選択
                VStack(alignment: .leading) {
                    Text("背景タイプ:")
                    
                    Picker("", selection: $backgroundSettings.type) {
                        Text("単色").tag(BackgroundType.solid)
                        Text("グラデーション").tag(BackgroundType.gradient)
                        Text("透明").tag(BackgroundType.transparent)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: backgroundSettings.type) { _ in
                        updateBackground()
                    }
                }
                
                // 背景タイプに応じたプロパティ
                Group {
                    switch backgroundSettings.type {
                    case .solid:
                        solidColorProperties
                    case .gradient:
                        gradientProperties
                    case .image:
                        EmptyView()
                    case .transparent:
                        transparentProperties
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePickerView { image in
                if let image = image {
                    handleSelectedImage(image)
                }
            }
        }
    }
    
    // MARK: - 単色背景プロパティ
    
    private var solidColorProperties: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 背景色
            ColorPicker("背景色:", selection: Binding(
                get: { Color(backgroundSettings.color) },
                set: {
                    backgroundSettings.color = UIColor($0)
                    updateBackground()
                }
            ))
            
            // 不透明度
            HStack {
                Text("不透明度:")
                Slider(value: Binding(
                    get: { backgroundSettings.opacity },
                    set: {
                        backgroundSettings.opacity = $0
                        updateBackground()
                    }
                ), in: 0...1, step: 0.01)
                Text("\(Int(backgroundSettings.opacity * 100))%")
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }
    
    // MARK: - グラデーション背景プロパティ
    
    private var gradientProperties: some View {
        VStack(alignment: .leading, spacing: 12) {
            // グラデーション開始色
            ColorPicker("開始色:", selection: Binding(
                get: { Color(backgroundSettings.gradientStartColor) },
                set: {
                    backgroundSettings.gradientStartColor = UIColor($0)
                    updateBackground()
                }
            ))
            
            // グラデーション終了色
            ColorPicker("終了色:", selection: Binding(
                get: { Color(backgroundSettings.gradientEndColor) },
                set: {
                    backgroundSettings.gradientEndColor = UIColor($0)
                    updateBackground()
                }
            ))
            
            // グラデーションタイプ
            Picker("タイプ:", selection: $backgroundSettings.gradientType) {
                Text("線形").tag(GradientType.linear)
                Text("放射状").tag(GradientType.radial)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: backgroundSettings.gradientType) { _ in
                updateBackground()
            }
            
            // 線形グラデーションの場合は方向も選択可能
            if backgroundSettings.gradientType == .linear {
                VStack(alignment: .leading) {
                    Text("方向:")
                    
                    Picker("", selection: $backgroundSettings.gradientDirection) {
                        Text("上から下").tag(GradientDirection.topToBottom)
                        Text("左から右").tag(GradientDirection.leftToRight)
                        Text("斜め").tag(GradientDirection.diagonal)
                        Text("カスタム").tag(GradientDirection.custom)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: backgroundSettings.gradientDirection) { _ in
                        updateBackground()
                    }
                    
                    // カスタム角度（カスタム方向選択時のみ表示）
                    if backgroundSettings.gradientDirection == .custom {
                        HStack {
                            Text("角度:")
                            Slider(value: Binding(
                                get: { backgroundSettings.gradientAngle },
                                set: {
                                    backgroundSettings.gradientAngle = $0
                                    updateBackground()
                                }
                            ), in: 0...360, step: 1)
                            Text("\(Int(backgroundSettings.gradientAngle))°")
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
            }
            
            // 不透明度
            HStack {
                Text("不透明度:")
                Slider(value: Binding(
                    get: { backgroundSettings.opacity },
                    set: {
                        backgroundSettings.opacity = $0
                        updateBackground()
                    }
                ), in: 0...1, step: 0.01)
                Text("\(Int(backgroundSettings.opacity * 100))%")
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }
    
    // MARK: - 透明背景プロパティ
    
    private var transparentProperties: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("透明背景が有効になっています。")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("プロジェクトを PNG 形式でエクスポートする場合、背景は透明になります。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - ヘルパーメソッド
    
    /// 背景設定を更新してビューモデルに反映
    private func updateBackground() {
        viewModel.updateBackgroundSettings(backgroundSettings)
    }
    
    /// 選択された画像を処理
    private func handleSelectedImage(_ image: UIImage) {
        // AssetManagerを使用して画像を保存
        let imageName = "bg_\(UUID().uuidString)"
        
        if AssetManager.shared.saveImage(image, name: imageName, type: .background) {
            // 背景設定を更新
            backgroundSettings.imageFileName = imageName
            updateBackground()
        }
    }
    
    /// 画像を読み込み
    private func loadImage(named name: String) -> UIImage? {
        // まずAssetManagerから読み込み
        if let image = AssetManager.shared.loadImage(named: name, type: .background) {
            return image
        }
        
        // 次にUIImageから直接読み込み（バンドルリソース）
        return UIImage(named: name)
    }
}

/// プレビュー
struct BackgroundEditorPanel_Previews: PreviewProvider {
    static var previews: some View {
        BackgroundEditorPanel(viewModel: EditorViewModel())
            .frame(width: 300)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
