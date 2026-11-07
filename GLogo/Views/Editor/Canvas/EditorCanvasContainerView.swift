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
                    onMagnifyChanged: { scale in
                        elementViewModel.transform.applyGestureTransform(
                            kind: .magnify,
                            translation: nil,
                            scale: scale,
                            rotation: nil,
                            ended: false
                        )
                    },
                    onMagnifyEnded: {
                        elementViewModel.transform.applyGestureTransform(
                            kind: .magnify,
                            translation: nil,
                            scale: nil,
                            rotation: nil,
                            ended: true
                        )
                    },
                    onRotateGestureChanged: { angle in
                        elementViewModel.transform.applyGestureTransform(
                            kind: .rotate,
                            translation: nil,
                            scale: nil,
                            rotation: angle,
                            ended: false
                        )
                    },
                    onRotateGestureEnded: {
                        elementViewModel.transform.applyGestureTransform(
                            kind: .rotate,
                            translation: nil,
                            scale: nil,
                            rotation: nil,
                            ended: true
                        )
                    },
                    onResetRotation: {
                        elementViewModel.transform.resetRotation()
                    },
                    onMoveChanged: { translation in
                        elementViewModel.transform.applyGestureTransform(
                            kind: .move,
                            translation: translation,
                            scale: nil,
                            rotation: nil,
                            ended: false
                        )
                    },
                    onMoveEnded: {
                        elementViewModel.transform.applyGestureTransform(
                            kind: .move,
                            translation: nil,
                            scale: nil,
                            rotation: nil,
                            ended: true
                        )
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
                // 選択枠が消えると、操作中のジェスチャーは終了通知なしで消える。表示していた要素の ID で終了を伝える。
                .onDisappear { [selectedID = selected.id] in
                    elementViewModel.transform.endGesturesForRemovedOverlay(showing: selectedID)
                }
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

            // ツールバー + 画像一覧レール
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

            // 画像一覧レール（左端オーバーレイ）
            if viewModel.isImageListRailVisible {
                HStack {
                    ImageListRailView(viewModel: viewModel)
                        .padding(.top, 52) // ツールバー分のオフセット
                        .padding(.leading, 8)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    Spacer()
                }
            }
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
