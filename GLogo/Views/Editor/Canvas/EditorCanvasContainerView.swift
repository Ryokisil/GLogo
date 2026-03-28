///
//  EditorCanvasContainerView.swift
//  GLogo
//
//  概要:
//  エディタ画面のキャンバス領域を統括するコンテナビュー。
//  キャンバス描画（CanvasViewRepresentable）、要素選択オーバーレイ、
//  テキスト編集ダイアログ、削除エフェクト、フローティングツールバーを配置する。
//

import SwiftUI

/// エディタキャンバスコンテナ
struct EditorCanvasContainerView: View {
    // MARK: - Properties

    /// エディタビューモデル
    @ObservedObject var viewModel: EditorViewModel

    /// 要素編集ビューモデル
    @ObservedObject var elementViewModel: ElementViewModel

    /// グリッド表示フラグ
    var showGrid: Bool

    /// グリッドスナップフラグ
    var snapToGrid: Bool

    /// 画像ピッカー/クロップシートの表示制御
    @Binding var activeSheet: ActiveSheet?

    /// 確認ダイアログ表示アクション
    var onShowConfirmation: (_ message: LocalizedStringKey, _ action: @escaping () -> Void) -> Void

    /// 設定画面を開くアクション
    var onOpenAppSettings: () -> Void

    // MARK: - Private State

    /// 削除エフェクトの状態
    @State private var deleteEffect = DeleteEffectState()

    // MARK: - Body

    var body: some View {
        ZStack {
            // キャンバス背景
            Color.gray.opacity(0.2)
                .edgesIgnoringSafeArea(.all)

            // キャンバスビュー
            CanvasViewRepresentable(
                viewModel: viewModel,
                showGrid: showGrid,
                snapToGrid: snapToGrid,
                deleteEffect: $deleteEffect
            )

            if viewModel.editorMode == .select {
                Color.clear
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("canvas"))
                            .onEnded { value in
                                let hit = hitTestElement(at: value.startLocation, in: viewModel.project.elements)
                                if let element = hit {
                                    viewModel.selectElement(element)
                                } else {
                                    viewModel.clearSelection()
                                }
                            }
                    )
            }

            // オーバーレイは選択モードのみ表示（作成モードでは入力を塞がない）
            if viewModel.editorMode == .select,
               !viewModel.isEditingText,
               let selected = viewModel.selectedElement {
                ElementSelectionView(
                    element: selected,
                    onManipulationStarted: nil,
                    onManipulationChanged: nil,
                    onManipulationEnded: nil,
                    onMagnifyChanged: { scale in
                        elementViewModel.applyGestureTransform(translation: nil, scale: scale, rotation: nil, ended: false)
                    },
                    onMagnifyEnded: {
                        elementViewModel.applyGestureTransform(translation: nil, scale: nil, rotation: nil, ended: true)
                    },
                    onRotateGestureChanged: { angle in
                        elementViewModel.applyGestureTransform(translation: nil, scale: nil, rotation: angle, ended: false)
                    },
                    onRotateGestureEnded: {
                        elementViewModel.applyGestureTransform(translation: nil, scale: nil, rotation: nil, ended: true)
                    },
                    onMoveChanged: { translation in
                        elementViewModel.applyGestureTransform(translation: translation, scale: nil, rotation: nil, ended: false)
                    },
                    onMoveEnded: {
                        elementViewModel.applyGestureTransform(translation: nil, scale: nil, rotation: nil, ended: true)
                    },
                    onTapSelect: { globalPoint in
                        DispatchQueue.main.async {
                            // まず最前面をヒットテスト
                            if let primary = hitTestElement(at: globalPoint, in: viewModel.project.elements) {
                                if let selected = viewModel.selectedElement {
                                    if primary.id == selected.id {
                                        return // 同じ要素なら切り替えない
                                    }
                                }
                                viewModel.selectElement(primary)
                            } else {
                                viewModel.clearSelection()
                            }
                        }
                    }
                )
            }

            if viewModel.isEditingText,
               let editingElement = viewModel.editingTextElement {
                TextEditDialog(
                    initialText: editingElement.text,
                    onEditComplete: { newText in
                        viewModel.updateTextContent(editingElement, newText: newText)
                        viewModel.endTextEditing()
                    },
                    onCancel: {
                        viewModel.endTextEditing()
                    }
                )
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .zIndex(1000)
                .offset(y: -110)
            }

            // 削除フェードアウトエフェクト
            if deleteEffect.isActive, let snapshot = deleteEffect.snapshot {
                DeleteFadeEffect(
                    snapshot: snapshot,
                    frame: deleteEffect.frame
                ) {
                    deleteEffect.isActive = false
                    deleteEffect.snapshot = nil
                }
                .zIndex(999)
            }

            // ツールバー
            VStack {
                EditorOverlayToolbarView(
                    viewModel: viewModel,
                    activeSheet: $activeSheet,
                    deleteEffect: $deleteEffect,
                    onShowConfirmation: onShowConfirmation,
                    onOpenAppSettings: onOpenAppSettings
                )
                Spacer()
            }
            .padding()
        }
        .frame(maxHeight: .infinity)
        .coordinateSpace(name: "canvas")
    }

    // MARK: - Private Methods

    /// zIndex降順でヒットテスト
    private func hitTestElement(at location: CGPoint, in elements: [LogoElement], excluding excludeId: UUID? = nil) -> LogoElement? {
        elements
            .sorted { $0.zIndex > $1.zIndex }
            .first { element in
                if let excludeId = excludeId, element.id == excludeId { return false }
                return element.hitTest(location)
            }
    }
}
