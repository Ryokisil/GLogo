///
//  EditorBottomPanelHostView.swift
//  GLogo
//
//  概要:
//  エディタ画面下部のプロパティパネル群のホストビュー。
//  選択中のボトムツールに応じて、Adjust/Frame/AI/Filters/Effects/TextProperty
//  パネルを出し分ける。
//

import SwiftUI

/// エディタ下部パネルのホストビュー
struct EditorBottomPanelHostView: View {
    // MARK: - Properties

    /// 下部ツールバーの選択状態
    @Binding var selectedBottomTool: EditorBottomTool

    /// テキストプロパティパネルの表示フラグ
    @Binding var isTextPanelVisible: Bool

    /// 手動背景除去画面への遷移フラグ
    @Binding var isNavigatingToManualRemoval: Bool

    /// 要素編集ビューモデル
    @ObservedObject var elementViewModel: ElementViewModel

    /// エディタビューモデル
    @ObservedObject var viewModel: EditorViewModel

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            if selectedBottomTool == .adjust {
                AdjustBasicPanelView(
                    viewModel: elementViewModel,
                    onClose: { selectedBottomTool = .select }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if selectedBottomTool == .frame {
                FramePanelView(
                    viewModel: elementViewModel,
                    onClose: { selectedBottomTool = .select }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if selectedBottomTool == .magicStudio {
                AIToolsPanelView(
                    viewModel: elementViewModel,
                    onClose: { selectedBottomTool = .select },
                    onOpenManualBackgroundRemoval: {
                        if viewModel.selectedElement is ImageElement {
                            isNavigatingToManualRemoval = true
                        }
                    }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if selectedBottomTool == .filters {
                FiltersPanelView(
                    viewModel: elementViewModel,
                    onClose: { selectedBottomTool = .select }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if selectedBottomTool == .effects {
                EffectsPanelView(
                    viewModel: elementViewModel,
                    onClose: { selectedBottomTool = .select }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if isTextPanelVisible && !viewModel.isEditingText {
                TextPropertyPanelView(
                    viewModel: elementViewModel,
                    onClose: {
                        isTextPanelVisible = false
                        viewModel.clearSelection()
                        viewModel.editorMode = .select
                    },
                    onOpenTextEditor: {
                        if let textElement = viewModel.selectedElement as? TextElement {
                            viewModel.startTextEditing(for: textElement)
                        }
                    }
                )
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}
