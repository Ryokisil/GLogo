///
//  EditorOverlayToolbarView.swift
//  GLogo
//
//  概要:
//  キャンバス上に浮かぶオーバーレイツールバー。
//  モードセレクタ（画像追加・削除・画像役割切替）と設定ボタンを提供する。
//

import SwiftUI
import UIKit

/// キャンバス上のオーバーレイツールバー
struct EditorOverlayToolbarView: View {
    // MARK: - Properties

    /// エディタビューモデル
    @ObservedObject var viewModel: EditorViewModel

    /// 画像ピッカー/クロップシートの表示制御
    @Binding var activeSheet: ActiveSheet?

    /// 削除エフェクトの状態
    @Binding var deleteEffect: DeleteEffectState

    /// 確認ダイアログ表示アクション
    var onShowConfirmation: (_ message: LocalizedStringKey, _ action: @escaping () -> Void) -> Void

    /// 設定画面を開くアクション
    var onOpenAppSettings: () -> Void

    // MARK: - Body

    var body: some View {
        HStack {
            modeSelector

            Spacer()

            viewControls
        }
        .padding(8)
        .background(Color(UIColor.systemBackground).opacity(0.9))
        .cornerRadius(8)
        .shadow(radius: 2)
    }

    // MARK: - Private Views

    /// モードセレクタ（画像追加・削除・画像役割切替）
    private var modeSelector: some View {
        HStack(spacing: 12) {
            // 画像インポートモード
            Button(action: {
                viewModel.editorMode = .imageImport
                activeSheet = .imagePicker
            }) {
                Image(systemName: "photo")
                    .foregroundColor(viewModel.editorMode == .imageImport ? .blue : .primary)
            }
            .accessibilityIdentifier("editor.overlay.addImageButton")
            .help("editor.help.addImage")

            // 削除モード
            Button(action: {
                if let element = viewModel.selectedElement {
                    onShowConfirmation("editor.deleteConfirmation") {
                        deleteEffect.snapshot = element.renderSnapshot()
                        deleteEffect.frame = element.frame
                        deleteEffect.isActive = true
                        viewModel.deleteSelectedElement()
                    }
                } else {
                    viewModel.editorMode = .delete
                }
            }) {
                Image(systemName: "trash")
                    .foregroundColor(viewModel.editorMode == .delete ? .red : .primary)
            }
            .accessibilityIdentifier("editor.overlay.deleteButton")
            .help("editor.help.deleteTool")

            // 画像一覧レール表示切り替え
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.isImageListRailVisible.toggle()
                }
            }) {
                Image(systemName: "square.3.layers.3d.down.left")
                    .foregroundColor(viewModel.isImageListRailVisible ? .blue : .primary)
            }
            .accessibilityIdentifier("editor.overlay.imageListButton")
            .help("editor.help.imageList")

        }
    }

    /// 設定ボタン
    private var viewControls: some View {
        HStack(spacing: 12) {
            Button(action: onOpenAppSettings) {
                Image(systemName: "gearshape")
                    .foregroundColor(.primary)
            }
            .accessibilityIdentifier("editor.overlay.settingsButton")
            .help("editor.help.appSettings")
        }
    }
}
