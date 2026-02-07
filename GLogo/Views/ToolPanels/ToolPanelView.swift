//
//  ToolPanelView.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはエディタの下側に表示されるツールパネルのコンテナビューを実装しています。
//  選択された要素の種類に応じて、適切な編集パネル（TextEditorPanel、ShapeEditorPanel、
//  BackgroundEditorPanelなど）を表示するコンテナとして機能します。
//  また、パネルの折りたたみ・展開などのUIコントロールも提供します。
//

import SwiftUI

/// ツールパネルビュー - 要素や背景の編集パネルのコンテナ
struct ToolPanelView: View {
    /// エディタビューモデル
    @ObservedObject var editorViewModel: EditorViewModel
    
    /// 要素編集ビューモデル
    @ObservedObject var elementViewModel: ElementViewModel
    
    /// パネルが折りたたまれているかのフラグ
    @State private var isCollapsed = false
    
    /// ツールパネルの幅
    @State private var panelWidth: CGFloat = 300
    
    /// パネルサイズ変更中フラグ
    @State private var isResizing = false
    
    /// 最小パネル幅
    private let minPanelWidth: CGFloat = 250
    
    /// 最大パネル幅
    private let maxPanelWidth: CGFloat = 400
    
    var body: some View {
        ZStack(alignment: .leading) {
            // リサイズハンドル
            resizeHandle
            
            // メインパネル
            mainPanel
        }
        .frame(width: isCollapsed ? 40 : panelWidth)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCollapsed)
    }
    
    // MARK: - メインパネル
    
    private var mainPanel: some View {
        VStack(spacing: 0) {
            // パネルヘッダー
            toolPanelHeader
            
            // パネル内容 - 折りたたまれていない場合のみ表示
            if !isCollapsed {
                // 要素が選択されているか、背景編集かによってパネルを切り替え
                if let elementType = elementViewModel.elementType {
                    // 要素タイプに応じたパネルを表示
                    Group {
                        switch elementType {
                        case .text:
                            TextEditorPanel(viewModel: elementViewModel)
                        case .shape:
                            ShapeEditorPanel(viewModel: elementViewModel)
                        case .image:
                            ImageEditorPanel(viewModel: elementViewModel)
                        }
                    }
                    .transition(.opacity)
                } else {
                    // 背景編集パネル
                    BackgroundEditorPanel(viewModel: editorViewModel)
                        .transition(.opacity)
                }
            }
        }
        .frame(width: isCollapsed ? 40 : panelWidth)
        .background(Color(UIColor.systemBackground))
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color.gray.opacity(0.3)),
            alignment: .leading
        )
    }
    
    // MARK: - パネルヘッダー
    
    private var toolPanelHeader: some View {
        HStack {
            // 折りたたみボタン
            Button(action: {
                isCollapsed.toggle()
            }) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.left")
                    .padding(8)
                    .background(Color(UIColor.systemBackground).opacity(0.8))
                    .clipShape(Circle())
            }
            .foregroundColor(.primary)
            .frame(width: 36, height: 36)
            
            if !isCollapsed {
                // パネルタイトル - 選択状態に応じて変更
                Text(getPanelTitle())
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
                
                // 選択解除ボタン - 要素が選択されている場合のみ表示
                if elementViewModel.element != nil {
                    Button(action: {
                        editorViewModel.clearSelection()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(isCollapsed ? [.top, .bottom] : .all)
        .frame(height: 50)
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    // MARK: - リサイズハンドル
    
    private var resizeHandle: some View {
        // 折りたたまれていない場合のみリサイズハンドルを表示
        Group {
            if !isCollapsed {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 10)
                    .contentShape(Rectangle())
#if targetEnvironment(macCatalyst)
                    .cursor(.resizeLeftRight) // macCatalyst環境でのみ適用
#endif
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isResizing {
                                    isResizing = true
                                }
                                
                                // パネル幅を更新（最小/最大の範囲内に制限）
                                let newWidth = panelWidth - value.translation.width
                                panelWidth = min(max(newWidth, minPanelWidth), maxPanelWidth)
                            }
                            .onEnded { _ in
                                isResizing = false
                            }
                    )
            }
        }
    }
    
    // MARK: - ヘルパーメソッド
    
    /// パネルタイトルを取得
    private func getPanelTitle() -> String {
        if let elementType = elementViewModel.elementType {
            // 要素の種類に応じたタイトル
            switch elementType {
            case .text:
                return "テキスト編集"
            case .shape:
                return "図形編集"
            case .image:
                return "画像編集"
            }
        } else {
            // 背景編集
            return "背景設定"
        }
    }
}

/// ImageEditorPanel - 画像要素の編集用パネル
struct ImageEditorPanel: View {
    @ObservedObject var viewModel: ElementViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 画像プレビュー
                if let imageElement = viewModel.imageElement, let image = imageElement.image {
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
                
                // 色調補正
                if let imageElement = viewModel.imageElement {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("色調補正")
                            .font(.headline)
                        
                        HStack {
                            Text("彩度:")
                            Slider(value: Binding(
                                get: { imageElement.saturationAdjustment },
                                set: { viewModel.updateImageAdjustment(.saturation, value: $0) }
                            ), in: 0...2, step: 0.01, onEditingChanged: { isEditing in
                                if isEditing {
                                    viewModel.beginImageAdjustmentEditing(.saturation)
                                } else {
                                    viewModel.commitImageAdjustmentEditing(.saturation)
                                }
                            })
                            Text("\(imageElement.saturationAdjustment, specifier: "%.2f")")
                                .frame(width: 40, alignment: .trailing)
                        }
                        
                        HStack {
                            Text("明度:")
                            Slider(value: Binding(
                                get: { imageElement.brightnessAdjustment },
                                set: { viewModel.updateImageAdjustment(.brightness, value: $0) }
                            ), in: -0.5...0.5, step: 0.01, onEditingChanged: { isEditing in
                                if isEditing {
                                    viewModel.beginImageAdjustmentEditing(.brightness)
                                } else {
                                    viewModel.commitImageAdjustmentEditing(.brightness)
                                }
                            })
                            Text("\(imageElement.brightnessAdjustment, specifier: "%.2f")")
                                .frame(width: 40, alignment: .trailing)
                        }
                        
                        HStack {
                            Text("コントラスト:")
                            Slider(value: Binding(
                                get: { imageElement.contrastAdjustment },
                                set: { viewModel.updateImageAdjustment(.contrast, value: $0) }
                            ), in: 0.5...1.5, step: 0.01, onEditingChanged: { isEditing in
                                if isEditing {
                                    viewModel.beginImageAdjustmentEditing(.contrast)
                                } else {
                                    viewModel.commitImageAdjustmentEditing(.contrast)
                                }
                            })
                            Text("\(imageElement.contrastAdjustment, specifier: "%.2f")")
                                .frame(width: 40, alignment: .trailing)
                        }
                        
                        HStack {
                            Text("ハイライト:")
                            Slider(value: Binding(
                                get: { imageElement.highlightsAdjustment },
                                set: { viewModel.updateImageAdjustment(.highlights, value: $0) }
                            ), in: -1...1, step: 0.01, onEditingChanged: { isEditing in
                                if isEditing {
                                    viewModel.beginImageAdjustmentEditing(.highlights)
                                } else {
                                    viewModel.commitImageAdjustmentEditing(.highlights)
                                }
                            })
                            Text("\(imageElement.highlightsAdjustment, specifier: "%.2f")")
                                .frame(width: 40, alignment: .trailing)
                        }
                        
                        HStack {
                            Text("シャドウ:")
                            Slider(value: Binding(
                                get: { imageElement.shadowsAdjustment },
                                set: { viewModel.updateImageAdjustment(.shadows, value: $0) }
                            ), in: -1...1, step: 0.01, onEditingChanged: { isEditing in
                                if isEditing {
                                    viewModel.beginImageAdjustmentEditing(.shadows)
                                } else {
                                    viewModel.commitImageAdjustmentEditing(.shadows)
                                }
                            })
                            Text("\(imageElement.shadowsAdjustment, specifier: "%.2f")")
                                .frame(width: 40, alignment: .trailing)
                        }
                        
                        HStack {
                            Text("色相:")
                            Slider(value: Binding(
                                get: { imageElement.hueAdjustment },
                                set: { viewModel.updateImageAdjustment(.hue, value: $0) }
                            ), in: -180...180, step: 1, onEditingChanged: { isEditing in
                                if isEditing {
                                    viewModel.beginImageAdjustmentEditing(.hue)
                                } else {
                                    viewModel.commitImageAdjustmentEditing(.hue)
                                }
                            })
                            Text("\(Int(imageElement.hueAdjustment))°")
                                .frame(width: 40, alignment: .trailing)
                        }
                        
                        HStack {
                            Text("シャープネス:")
                            Slider(value: Binding(
                                get: { imageElement.sharpnessAdjustment },
                                set: { viewModel.updateImageAdjustment(.sharpness, value: $0) }
                            ), in: 0...2, step: 0.01, onEditingChanged: { isEditing in
                                if isEditing {
                                    viewModel.beginImageAdjustmentEditing(.sharpness)
                                } else {
                                    viewModel.commitImageAdjustmentEditing(.sharpness)
                                }
                            })
                            Text("\(imageElement.sharpnessAdjustment, specifier: "%.2f")")
                                .frame(width: 40, alignment: .trailing)
                        }
                        
                        HStack {
                            Text("ブラー:")
                            Slider(value: Binding(
                                get: { imageElement.gaussianBlurRadius },
                                set: { viewModel.updateImageAdjustment(.gaussianBlur, value: $0) }
                            ), in: 0...10, step: 0.1, onEditingChanged: { isEditing in
                                if isEditing {
                                    viewModel.beginImageAdjustmentEditing(.gaussianBlur)
                                } else {
                                    viewModel.commitImageAdjustmentEditing(.gaussianBlur)
                                }
                            })
                            Text("\(imageElement.gaussianBlurRadius, specifier: "%.1f")")
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                    
                    Divider()
                    
                    // フレーム設定
                    VStack(alignment: .leading, spacing: 8) {
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
                                    set: { viewModel.updateImageAdjustment(.frameWidth, value: $0) }
                                ), in: 1...20, step: 0.5, onEditingChanged: { isEditing in
                                    if isEditing {
                                        viewModel.beginImageAdjustmentEditing(.frameWidth)
                                    } else {
                                        viewModel.commitImageAdjustmentEditing(.frameWidth)
                                    }
                                })
                                Text("\(imageElement.frameWidth, specifier: "%.1f")")
                                    .frame(width: 40, alignment: .trailing)
                            }
                        }
                    }

                    Divider()

                    // 角丸設定
                    VStack(alignment: .leading, spacing: 8) {
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
                                    set: { viewModel.updateImageAdjustment(.cornerRadius, value: $0) }
                                ), in: 1...50, step: 1, onEditingChanged: { isEditing in
                                    if isEditing {
                                        viewModel.beginImageAdjustmentEditing(.cornerRadius)
                                    } else {
                                        viewModel.commitImageAdjustmentEditing(.cornerRadius)
                                    }
                                })
                                Text("\(Int(imageElement.cornerRadius))")
                                    .frame(width: 30, alignment: .trailing)
                            }
                        }
                    }

                    Divider()

                    // ティントカラー設定
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("カラーオーバーレイ")
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
                                    set: { viewModel.updateImageAdjustment(.tintIntensity, value: $0) }
                                ), in: 0...1, step: 0.01, onEditingChanged: { isEditing in
                                    if isEditing {
                                        viewModel.beginImageAdjustmentEditing(.tintIntensity)
                                    } else {
                                        viewModel.commitImageAdjustmentEditing(.tintIntensity)
                                    }
                                })
                                Text("\(imageElement.tintIntensity, specifier: "%.2f")")
                                    .frame(width: 40, alignment: .trailing)
                            }
                        }
                    }

                    Divider()

                    // 背景ぼかし設定
                    VStack(alignment: .leading, spacing: 8) {
                        Text("背景ぼかし")
                            .font(.headline)

                        // マスクが設定されているかどうかで表示を切り替え
                        if imageElement.backgroundBlurMaskData != nil {
                            // マスクが設定されている場合
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("マスク設定済み")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)

                            // ぼかし強度スライダー
                            HStack {
                                Text("強度:")
                                Slider(value: Binding(
                                    get: { imageElement.backgroundBlurRadius },
                                    set: { viewModel.updateImageAdjustment(.backgroundBlurRadius, value: $0) }
                                ), in: 0...50, step: 1, onEditingChanged: { isEditing in
                                    if isEditing {
                                        viewModel.beginImageAdjustmentEditing(.backgroundBlurRadius)
                                    } else {
                                        viewModel.commitImageAdjustmentEditing(.backgroundBlurRadius)
                                    }
                                })
                                Text("\(Int(imageElement.backgroundBlurRadius))")
                                    .frame(width: 30, alignment: .trailing)
                            }

                            // 手動補正ボタン
                            Button(action: {
                                viewModel.requestBackgroundBlurMaskEdit()
                            }) {
                                HStack {
                                    Image(systemName: "paintbrush")
                                    Text("マスクを編集")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }

                            // マスク削除ボタン
                            Button(action: {
                                viewModel.removeBackgroundBlurMask()
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("マスクを削除")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .foregroundColor(.red)
                            }
                        } else {
                            // マスクが未設定の場合
                            Text("AIで被写体を検出し、背景をぼかすことができます")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)

                            // AI背景ぼかしボタン
                            Button(action: {
                                viewModel.requestAIBackgroundBlur()
                            }) {
                                HStack {
                                    Image(systemName: "wand.and.stars")
                                    Text("AI背景ぼかし")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color(red: 0.36, green: 0.80, blue: 0.20))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.25), radius: 0, x: 0, y: 3)
                                .foregroundColor(.white)
                            }
                            .disabled(viewModel.isProcessingAI)
                            .opacity(viewModel.isProcessingAI ? 0.6 : 1.0)

                            // 手動補正ボタン
                            Button(action: {
                                viewModel.requestBackgroundBlurMaskEdit()
                            }) {
                                HStack {
                                    Image(systemName: "paintbrush")
                                    Text("手動でマスク作成")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }

                        // AI処理中インジケータ
                        if viewModel.isProcessingAI {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("AIマスク生成中...")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .padding()
        }
    }
}
